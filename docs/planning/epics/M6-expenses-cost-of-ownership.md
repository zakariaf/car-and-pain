# M6 · Expenses & Cost of Ownership

> The financial backbone: capture every car cost with rich + custom categories, recurring and amortized bills, budgets with real alerts, full loan/lease amortization (early-payoff/refinance/negative-equity), depreciation, and a true on-device Total-Cost-of-Ownership engine feeding dashboards and sell/dispose.

## Goal

Money is the reason most people open a car app, and it is where competitors are weakest — they treat "expenses" as a flat list of amounts and call it a day. M6 makes Car and Pain's cost layer the **financial backbone of the whole product**: every other module's spend (fuel, service, tires, documents, insurance) rolls up here, and the numbers that come out feed the dashboard, the repair-or-replace helper, and the final sell/dispose close-out.

Concretely, M6 delivers:

- A **canonical expense ledger** — money stored as integer **minor units** keyed to each currency's real ISO-4217 exponent (0 for IRR/JPY, 2 for USD/EUR, 3 for KWD/BHD/OMR) with the ISO code, never a float and never a hardcoded two decimals — with **dated user-entered FX rates** (offline) so multi-currency spend converts correctly to a base currency at the rate that applied on the transaction date.
- **Rich + fully custom categories** driven by the shared taxonomy (icons/colours/analytic-bucket mapping), a **receipt attachment** on every entry via the F8 media pipeline, and quick-add friction kept to a minimum.
- A **recurrence engine** for repeating bills (road tax, subscriptions, parking permits) and **amortization of lump costs** so a one-off annual premium or a set of tyres spreads correctly across the months/distance it actually covers — so TCO and cost/distance aren't spiked by the month a big bill landed.
- **Per-category budgets** with **real alerts** wired into the F5 notification engine (threshold + projected-overspend), not just a coloured bar.
- **Full loan/lease amortization** — a complete payment schedule handling **early payoff, refinance, and negative equity**, plus a **depreciation** curve — the shared financing backbone.
- A **true on-device TCO engine**: deterministic, table-tested aggregation across every module's costs, netted against depreciation and financing, expressed as absolute cost and **cost per distance / per day**, scoped per-vehicle / per-driver / all-vehicles.
- Everything **localized** (categories + strings across en/de/fr/fa/ar/ckb, correct currency-exponent and numeral formatting), **RTL-verified**, **in backup/export**, and **accessible** with redundant (non-colour) status encoding — per the app's promises.

This epic owns the cost data model, the financial math engines, and their PULSE surfaces; downstream modules read the TCO/financing outputs rather than re-deriving them.

## Tier & dependencies

- **Tier:** MVP
- **Depends on:**
  - **F2** — Encrypted data layer, canonical model & odometer ledger: the expense/loan/budget tables live in the encrypted DB, use the canonical units/money contract, and link to the shared odometer ledger for cost/distance math.
  - **F3** — PULSE design system implementation: tokens/components for quick-add, budget meters, and TCO charts.
  - **F4** — i18n / RTL / calendars / numerals engine: localized categories/strings, calendar-correct recurrence dates, numeral/separator formatting.
  - **F6** — Backup, export/import & key recovery: expense/loan/budget entities must round-trip through the single-file backup and CSV/JSON export.
  - **F8** — Attachments & media pipeline: receipt attachment on expense entries.
  - **M2** — Vehicles, Garage & Odometer: expenses are vehicle-scoped and read the shared odometer/engine-hour ledger for cost/distance and amortization-by-distance.

Downstream, the **Dashboard, Statistics & Reports** module renders the TCO/budget outputs, **Sell, Dispose & Ownership Transfer** consumes the final TCO close-out and financing payoff, and every spend-producing module (fuel, service, tires, documents, insurance) contributes rows the TCO engine aggregates.

## References

- [docs/features/05-expenses-cost-ownership.md](../../features/05-expenses-cost-ownership.md)
- [docs/flutter/14-money-currency-fx.md](../../flutter/14-money-currency-fx.md)
- [docs/flutter/03-data-persistence.md](../../flutter/03-data-persistence.md)
- [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md)
- [docs/design/pulse/02-components.md](../../design/pulse/02-components.md)
- [docs/reference/data-model.md](../../reference/data-model.md)

## Tasks

### M6-T1 · Expense schema & repository

**Description**

Define the `expense` Drift entity and its repository — the canonical ledger every cost writes into. Each row carries: a UUID primary key; `vehicle_id` (and optional `driver_id`) scoping; a **category ref** into the shared taxonomy (custom categories supported, with analytic-bucket mapping); `amount_minor` (integer) + `currency_code` (ISO-4217) honouring the currency's real exponent; the transaction `date` (stored as UTC instant plus the wall-clock/calendar it was entered in); optional **dated FX** fields (`fx_rate`, `fx_as_of`, `base_amount_minor`) so the entry converts to the base currency at the rate that applied on its date; an optional **odometer reading link** into the shared ledger (for cost/distance); a polymorphic **source link** (`source_entity_type`/`source_entity_id`) so fuel/service/tire rows can project into the ledger without duplication; a receipt **attachment link** (F8); free-text note/tags; and `created_at`/`updated_at` + soft-delete/trash fields per F2. The repository enforces the canonical contract (minor units, UTC, SI) at the boundary and returns sealed `Result<T, Failure>`. Index `(vehicle_id, date)`, `category_ref`, and `(source_entity_type, source_entity_id)`.

**Acceptance criteria**

- [ ] `expense` table created with `vehicle_id`, optional `driver_id`, category ref, `amount_minor` + `currency_code` (exponent-correct), UTC `date` + entry calendar, dated-FX fields, odometer link, polymorphic source link, attachment link, note/tags, UTC timestamps and soft-delete fields.
- [ ] Money is stored as integer minor units keyed to the ISO-4217 exponent (0/2/3) with the currency code — never a float, never hardcoded two decimals; a table test covers IRR/JPY (0), USD/EUR (2), KWD/BHD/OMR (3).
- [ ] Repository exposes create / read / list-by-vehicle / list-by-category / list-by-date-range / soft-delete / hard-delete returning sealed `Result` over the `Failure` hierarchy (stable codes, no user strings).
- [ ] Reactive `watch` streams (per vehicle, per category, per date range) update on change and drive the UI without manual refresh.
- [ ] Drift migration added and versioned; a migration test proves the upgrade is non-destructive.
- [ ] Indexes on `(vehicle_id, date)`, `category_ref` and `(source_entity_type, source_entity_id)` exist and are exercised by a query test.
- [ ] Cross-module source rows (fuel/service/tire) project into the ledger via the source link without double-counting when both the source module and the ledger are summed.

**Size:** M
**Depends on:** F2, F8, M2
**Governing docs:** [data-persistence](../../flutter/03-data-persistence.md), [money-currency-fx](../../flutter/14-money-currency-fx.md), [data-model](../../reference/data-model.md)

### M6-T2 · Recurring & amortized bills

**Description**

Two related pure-Dart engines plus their persistence. **Recurrence:** a rule model (interval + unit, anchor date, optional end/occurrence count, calendar-aware so a Jalali/Hijri "monthly" lands on the right civil date) that materialises upcoming bill instances and feeds F5 reminders and budget projection. **Amortization of lump costs:** spread a one-off cost (an annual insurance premium, a set of tyres, a major service) across the period **or distance** it actually covers, so cost/distance and TCO reflect steady consumption rather than a spike in the month the money left. Amortization is a derived view over the canonical row (the ledger keeps the true cash-out date and amount); schedules are recomputed deterministically, never stored as lossy duplicates.

**Acceptance criteria**

- [ ] Recurrence rules materialise the correct instance dates for daily/weekly/monthly/quarterly/annual intervals, honouring end date / occurrence count.
- [ ] Recurrence is **calendar-correct**: a rule entered in Jalali/Hijri produces civil dates matching the intended calendar month, verified by table tests including month-length edge cases (e.g. 31st, Esfand, leap handling).
- [ ] Lump-cost amortization spreads a cost across a chosen period **or distance** window; the spread sums back exactly to the original minor-unit amount (no rounding leakage — remainder distributed deterministically).
- [ ] Amortized and cash-basis views are both derivable from the same canonical row; switching views never mutates stored data.
- [ ] Materialised recurring instances feed budget projection (M6-T3) and F5 reminder scheduling.
- [ ] Engines are pure Dart (no I/O), fully unit-tested, and return typed results for invalid rules (e.g. zero interval).

**Size:** M
**Depends on:** M6-T1, F4
**Governing docs:** [money-currency-fx](../../flutter/14-money-currency-fx.md), [i18n-rtl-calendars](../../flutter/06-i18n-rtl-calendars.md), [data-model](../../reference/data-model.md)

### M6-T3 · Budgets & alerts

**Description**

Per-category (and optional overall / per-vehicle) **budgets** with a period (monthly/quarterly/annual, calendar-aware) and a target `amount_minor`. A budget-evaluation engine computes spend-to-date against the budget using the amortized/cash basis the user chose, plus a **projected end-of-period** spend from run-rate and known upcoming recurring instances (M6-T2). When a **threshold** (e.g. 80/100%) or a **projected overspend** is crossed, it emits an alert into the **F5 notification engine** — a real scheduled/local notification naming the vehicle and category, not merely an in-app coloured bar. Alert state is de-duplicated (fire once per crossing per period) and survives reboot via the DB-as-source-of-truth model.

**Acceptance criteria**

- [ ] Budgets can be set per category, per vehicle, and overall, with a calendar-aware period and a minor-unit target in the base currency.
- [ ] Spend-to-date is computed correctly against the chosen basis (cash vs amortized) and respects date ranges/period boundaries.
- [ ] Projected end-of-period spend combines run-rate + known upcoming recurring instances and is table-tested.
- [ ] Crossing a configured threshold or a projected overspend enqueues an F5 notification naming the vehicle + category; the alert is a real notification, not only an in-app indicator.
- [ ] Alerts de-duplicate — one notification per threshold crossing per period — and reconcile after app restart / device reboot from the DB.
- [ ] Budget meters expose the current/limit/projected values to the UI (M6-T6) via reactive streams.
- [ ] Evaluation logic is pure and unit-tested across under/at/over/projected-over scenarios and multi-currency spend normalised via dated FX.

**Size:** M
**Depends on:** M6-T1, M6-T2, F5
**Governing docs:** [money-currency-fx](../../flutter/14-money-currency-fx.md), [data-model](../../reference/data-model.md)

### M6-T4 · Loan/lease amortization & depreciation

**Description**

The shared **financing backbone**. Model a `financing` entity (loan or lease) — principal, APR/money-factor, term, start date, payment amount/frequency, residual/balloon for leases — and a pure-Dart **amortization engine** that produces the full period-by-period schedule (payment → interest/principal split → running balance). Handle the hard cases competitors skip: **early payoff** (payoff quote at any date, interest saved), **refinance** (close one schedule, open another mid-life, carry balance), and **negative equity** (balance owed exceeds vehicle value — surfaced, not hidden). Add a **depreciation** curve (straight-line and declining-balance / configurable) giving estimated current value over time, which nets against the loan balance to expose equity position and feeds TCO and sell/dispose. All money in minor units; all interest math rounded deterministically to the currency exponent.

**Acceptance criteria**

- [ ] Amortization produces a correct full schedule (payment, interest, principal, running balance) for a loan; the final balance reaches zero within one minor unit and the interest total matches a table-tested reference.
- [ ] Lease schedules handle money-factor/residual and produce correct monthly cost and end-of-term position.
- [ ] **Early payoff** computes a payoff amount at an arbitrary date plus interest saved vs running to term.
- [ ] **Refinance** closes the current schedule at a date and opens a successor carrying the outstanding balance, with both linked in history.
- [ ] **Negative equity** is detected and surfaced (balance owed − depreciated value) as an explicit, labelled state — never silently clamped.
- [ ] Depreciation supports at least straight-line and declining-balance, yields an estimated value over time, and nets against the loan balance to report equity.
- [ ] All monetary results are minor-unit integers rounded deterministically to the currency exponent; the engine is pure and exhaustively table-tested.
- [ ] Financing outputs (monthly cost, interest, current balance, depreciation) are exposed to the TCO engine (M6-T5).

**Size:** L
**Depends on:** M6-T1, F2
**Governing docs:** [money-currency-fx](../../flutter/14-money-currency-fx.md), [data-model](../../reference/data-model.md)

### M6-T5 · TCO engine

**Description**

The on-device **Total-Cost-of-Ownership** aggregator — a pure-Dart engine that sums every cost source for a vehicle over a period: the expense ledger (M6-T1) including projected cross-module rows, financing interest + depreciation (M6-T4, netting the sale/residual where known), amortized lump costs (M6-T2), all normalised to the base currency via **dated FX**. It computes absolute TCO and **cost per distance** and **cost per day** using the shared odometer/engine-hour ledger for the denominator, with an explicit **insufficient-data / min-samples fallback** (never a divide-by-zero or a misleading number on a brand-new vehicle). Results are scoped per-vehicle / per-driver / all-vehicles and are broken down by category bucket for the UI. To keep it fast at scale, TCO reads from the **pre-aggregated summary/rollup tables** (per vehicle, per period) that the ledger maintains, recomputing incrementally rather than scanning the whole history each call.

**Acceptance criteria**

- [ ] TCO sums expense ledger + financing (interest + depreciation, net of residual/sale) + amortized lump costs, all normalised to base currency via the dated-FX table.
- [ ] Cost/distance and cost/day are computed against the shared odometer/engine-hour ledger denominator; a documented min-samples/insufficient-data fallback returns an explicit "not enough data" state rather than a wrong or infinite value.
- [ ] Results scope correctly per-vehicle, per-driver, and all-vehicles/fleet, and break down by analytic category bucket.
- [ ] Cross-module rows are counted exactly once (no double-count between a module's own total and its ledger projection).
- [ ] Aggregation reads pre-aggregated rollups and recomputes incrementally; a large-history vehicle computes within the performance budget (verified, not just asserted).
- [ ] The engine is pure Dart, deterministic, and exhaustively table-tested including multi-currency, amortized, and financed scenarios.
- [ ] TCO outputs are exposed via reactive streams for the dashboard and sell/dispose consumers.

**Size:** L
**Depends on:** M6-T1, M6-T2, M6-T4, F2
**Governing docs:** [money-currency-fx](../../flutter/14-money-currency-fx.md), [data-persistence](../../flutter/03-data-persistence.md), [data-model](../../reference/data-model.md)

### M6-T6 · Expense & TCO UI

**Description**

The **PULSE** surfaces. A low-friction **quick-add** expense sheet (amount + currency, category picker from the taxonomy, date in the active calendar, receipt capture via F8, optional odometer + note) with draft **autosave** so a half-entered expense is never lost. A **budget meters** view rendering current/limit/projected per category with the ache/exhale PULSE affect (a category over budget shows the scoped ache, logging within budget gives the exhale). A **TCO breakdown** screen with category-bucket charts and cost/distance + cost/day headlines, plus a **loan/lease** detail view showing the schedule, payoff, and equity/negative-equity position. All charts are **CustomPainter** (no charting dependency), status is **redundantly encoded** beyond colour (icon + label + shape + position), layouts use logical properties for RTL, and loading/empty/insufficient-data/error states are first-class.

**Acceptance criteria**

- [ ] Quick-add sheet captures amount + currency, taxonomy category, calendar-correct date, optional odometer/note and a receipt (F8) with minimal taps; drafts autosave and survive back/exit.
- [ ] Budget meters show current / limit / projected per category and reflect over-budget via icon + label + shape, not colour alone; PULSE ache/exhale affect is applied correctly.
- [ ] TCO breakdown renders category-bucket charts (CustomPainter) plus cost/distance and cost/day headlines, with a clear "insufficient data" state where the engine reports it.
- [ ] Loan/lease detail view shows the amortization schedule, an early-payoff figure, and the equity / negative-equity position with an explicit labelled indicator.
- [ ] No third-party charting/UI dependency is introduced; all visuals use PULSE tokens/components and CustomPainter.
- [ ] Every chart and stat tile carries Semantics labels; touch targets meet the minimum; reduced-motion is honoured.
- [ ] Loading, empty, insufficient-data and error states are handled and localized on every screen.

**Size:** M
**Depends on:** M6-T1, M6-T3, M6-T4, M6-T5, F3
**Governing docs:** [pulse-components](../../design/pulse/02-components.md), [i18n-rtl-calendars](../../flutter/06-i18n-rtl-calendars.md)

### M6-T7 · i18n & currency display

**Description**

Localize every user-facing string in the module — expense flow, budgets, TCO, loan/lease — through gen-l10n ARB across **en/de/fr/fa/ar/ckb**, including the **default + custom category** display names (custom categories store a user string; built-in categories are translated keys). Ensure **currency formatting** respects each currency's real exponent and symbol/placement, that amounts and cost/distance values render with locale-correct **numerals** (Western vs Eastern-Arabic/Persian) and grouping separators, and that VIN/plate/IBAN-style IDs stay LTR-isolated inside RTL text. Counts ("3 expenses", "N months") use ICU plurals.

**Acceptance criteria**

- [ ] Every module string is localized in all six languages with no hardcoded literals; the missing-key check passes in CI.
- [ ] Built-in categories render translated; custom category names round-trip verbatim and display correctly in RTL.
- [ ] Currency amounts format with the correct exponent (0/2/3 decimals), symbol and placement per locale + currency, verified by table tests (incl. IRR/Toman handling).
- [ ] Numerals and grouping separators are locale-correct (Western + Eastern-Arabic/Persian), and cost/distance/date values format consistently.
- [ ] Counts and periods use ICU plurals; no string concatenation for grammar.
- [ ] Numbers/units/IDs are bidi-isolated so they don't corrupt RTL layout.

**Size:** S
**Depends on:** M6-T6, F4
**Governing docs:** [i18n-rtl-calendars](../../flutter/06-i18n-rtl-calendars.md), [money-currency-fx](../../flutter/14-money-currency-fx.md)

### M6-T8 · Export/backup mapping

**Description**

Map the **expense**, **financing (loan/lease)** and **budget** entities into F6's backup/export subsystem. Each entity gets a serializer for the single-file backup (full fidelity: minor units + currency code, dated-FX fields, calendar-entry metadata, source links, attachment refs) and for **per-entity CSV** and **combined JSON** export, with schema/format versioning and checksums. Receipts travel via the F8 backup hooks and re-link on restore. Import re-materialises rows preserving UUIDs so cross-module source links and odometer links survive a round trip.

**Acceptance criteria**

- [ ] Expense, financing and budget entities serialize into the single-file backup with full fidelity (minor units + currency, dated FX, calendar metadata, source/odometer/attachment links).
- [ ] Per-entity CSV and combined JSON exports are produced with correct headers, schema/format version and checksums.
- [ ] Restore/import re-materialises rows preserving UUIDs so cross-module source links, odometer links and attachment refs re-link correctly.
- [ ] A backup→restore round-trip test asserts byte/semantic equality of amounts (no float drift), FX rates, dates and links, with no orphaned or double-linked rows.
- [ ] Receipts attached to expenses round-trip via F8's backup hooks and re-link to the correct expense.
- [ ] Export honours the app's redaction rules where a handover/redacted pack is requested.

**Size:** S
**Depends on:** M6-T1, M6-T3, M6-T4, F6
**Governing docs:** [data-persistence](../../flutter/03-data-persistence.md), [data-model](../../reference/data-model.md)

### M6-T9 · Tests

**Description**

The logic-heavy test layer this module demands — the "diamond-topped pyramid" applied to the financial engines. Exhaustive **table-driven** unit tests at 100% on the pure engines: loan/lease **amortization** (including early-payoff, refinance, negative-equity, minor-unit rounding), **TCO** aggregation (multi-currency, amortized, financed, insufficient-data fallback), **budget-alert** evaluation (under/at/over/projected-over), and **dated-FX** conversion (rate selection by date, exponent-correct rounding). Add recurrence/amortization calendar-edge tests, widget tests for the quick-add and TCO screens (LTR + RTL), and the M6-T8 backup round-trip. All green under `flutter analyze` + `dart format --set-exit-if-changed`.

**Acceptance criteria**

- [ ] Amortization engine has table-driven tests hitting standard loans, leases, early payoff, refinance, negative equity and rounding edges, with reference figures.
- [ ] TCO engine tests cover multi-currency (dated FX), amortized and financed inputs, per-scope aggregation, no-double-count, and the insufficient-data fallback.
- [ ] Budget-alert tests cover under/at/over/projected-over and de-duplication across a period.
- [ ] Dated-FX tests cover rate-by-date selection and exponent-correct rounding for 0/2/3-decimal currencies.
- [ ] Recurrence/amortization tests cover Gregorian + Jalali/Hijri calendar edges (month length, leap, Esfand).
- [ ] Widget tests exercise quick-add and TCO/budget screens in LTR and RTL, including insufficient-data and error states.
- [ ] The backup→restore round-trip test (M6-T8) passes; the full suite is green in CI with analyze + format gates.

**Size:** M
**Depends on:** M6-T1, M6-T2, M6-T3, M6-T4, M6-T5, M6-T8
**Governing docs:** [data-persistence](../../flutter/03-data-persistence.md), [money-currency-fx](../../flutter/14-money-currency-fx.md)

### M6-T10 · Data-integrity & validation guardrails

**Description**

_(Added for a complete vertical slice.)_ Wire the module into the shared data-integrity/validation layer so bad cost data is caught at entry with warn-and-override, not silently persisted. Detect: an expense whose linked **odometer reading regresses** or duplicates against the shared ledger; a **dated-FX** rate that is missing, zero, or wildly outside a sanity band for that currency pair; **duplicate** expenses (same vehicle/date/amount/category) suggesting a double-tap or double-import; a budget target of zero/negative; and a financing schedule whose inputs can't amortize (negative principal, zero term). Each surfaces an accessible, localized PULSE warning with an explicit override that preserves the user's intended value.

**Acceptance criteria**

- [ ] Odometer regression/duplicate on an expense's ledger link is detected and surfaced as a warn-with-override, not a hard block or silent accept.
- [ ] Missing/zero/out-of-band dated-FX rates are flagged before the row is committed; the user can correct or override with a recorded rate.
- [ ] Duplicate-expense heuristic warns on likely double entries (manual or import) without preventing a genuine repeat.
- [ ] Invalid budget (≤0) and un-amortizable financing inputs are rejected with typed `Failure`s and localized messages.
- [ ] All validation messages are localized (en/de/fr/fa/ar/ckb), accessible, and encode severity by icon + label + shape, not colour alone.
- [ ] Validation logic is pure and unit-tested across the trigger and clean cases.

**Size:** S
**Depends on:** M6-T1, M6-T3, M6-T4, F2
**Governing docs:** [data-persistence](../../flutter/03-data-persistence.md), [money-currency-fx](../../flutter/14-money-currency-fx.md), [data-model](../../reference/data-model.md)

## Definition of Done

- [ ] **Tests:** the M6-T9 suite is green — exhaustive table-driven unit tests at 100% on the amortization, TCO, budget-alert, dated-FX, recurrence and validation engines (including early-payoff/refinance/negative-equity, insufficient-data fallback, minor-unit rounding, calendar edges); widget tests on quick-add/budget/TCO in LTR + RTL; and the backup→restore round-trip — all passing under `flutter analyze` + `dart format --set-exit-if-changed`.
- [ ] **i18n complete:** every expense/budget/TCO/financing string and all built-in category names are translated across en/de/fr/fa/ar/ckb with ICU plurals; custom category names round-trip; currency amounts format with the correct ISO-4217 exponent and locale numerals/separators; no hardcoded strings and the missing-key check passes.
- [ ] **RTL verified:** quick-add, budget meters, TCO breakdown, loan/lease detail and all dialogs mirror correctly (layout, focus order, chart orientation), with numbers/units/currency/IDs bidi-isolated.
- [ ] **Backup/export:** expense, financing and budget entities (with receipts, dated FX, and cross-module/odometer links) are bundled in the single-file backup and per-entity CSV + combined JSON export, versioned and checksummed, and re-link by UUID on restore — verified by round-trip tests and consumed cleanly by F6.
- [ ] **Accessible per the redundant-encoding rule:** all charts, stat tiles, budget meters and interactive elements carry Semantics labels with correct RTL reading order, touch targets meet the minimum, reduced-motion is honoured, and every status (over-budget, negative-equity, insufficient-data, validation severity) is encoded by icon + label + shape + position, never colour alone.
- [ ] **Built-in-first & PULSE:** no new runtime dependency — money math is hand-rolled minor-unit integer arithmetic, charts are CustomPainter, budget alerts reuse the F5 engine, encryption/backup reuse F2/F6, receipts reuse F8; all UI uses PULSE tokens/components and honours the ache/exhale affect; nothing leaves the device.
