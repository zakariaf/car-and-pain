# M4 · Service & Maintenance

> A complete, editable service history — multi-line-item visits mapped to one receipt, fully custom service types, parts with part numbers and warranties, DIY procedure logs, bundled offline schedule templates, and appointment/next-due reminders — all layered over the shared taxonomy and odometer ledger.

## Goal

Deliver the Service & Maintenance feature module: the trustworthy, fully editable, printable service record that survives shop closures and proves the car was cared for. It records what actually happens to a vehicle and layers the planning tools owners need on top, entirely offline and account-free:

- **Multi-line-item visits mapped to one receipt** — several jobs done in one visit under a single dated record and receipt, mirroring a real shop invoice, with labour-vs-parts-vs-tax cost splits per line item and a visit-level DIY/shop flag.
- **Fully custom service types over the shared taxonomy** — a built-in, editable catalog of common jobs (oil/filters, brakes, fluids, belts, plugs, inspection) plus user-defined types that behave identically, each carrying icon, colour, and default distance/time/whichever-first intervals sourced from F2's custom-taxonomy tables.
- **Parts, warranties & DIY logs** — parts with brand, OEM and aftermarket part numbers, supplier, quantity and unit cost; part-and-workmanship warranties tracked by both date and mileage; DIY procedure logs with ordered steps, torque specs, fluid capacities, tools, and time.
- **Bundled offline schedule templates** — generic and severe-duty maintenance schedules shipped on-device, applicable to a vehicle to auto-generate the full set of reminders anchored to its current odometer and date.
- **Appointment & next-due** — per-service-type last-done / next-due status cards and interval reminders, plus a deliberately separate appointment class (date, time, shop, `.ics` deep-link), both fed to the shared notification engine.
- **Canonical & ledger-honest** — every visit captures the odometer into the shared per-vehicle ledger; all measures store canonically (SI distance, ISO-8601/UTC dates, minor-unit money) and convert only for display, so back-dating, cluster swaps, unit changes, or a language switch never rewrite history.

Every service visit, line item, part, fluid, quote, checklist, procedure log, and schedule state round-trips through backup, per-entity CSV, and combined JSON with attachments re-linked. This epic is the third MVP feature module and a primary producer for the reminders engine and the TCO cost stack.

## Tier & dependencies

- **Tier:** mvp
- **Depends on:**
  - **F2** — encrypted data layer: canonical units/money, the shared odometer/engine-hour ledger, the custom-taxonomy tables, soft-delete/trash, and the repository boundary contract this module writes through.
  - **F3** — PULSE design-system implementation (tokens + components) the entry and status-card screens are built on.
  - **F4** — i18n / RTL / calendars / numerals engine that localizes service-type strings and renders intervals, dates, and numerals.
  - **F6** — backup / export / import + key-recovery subsystem this module registers its entities with.
  - **F8** — attachments & media pipeline for receipt/photo/PDF attachment and in-app scan.
  - **M2** — the prerequisite MVP feature module establishing the shared vehicle hub and the entry → receipt → ledger → taxonomy → PULSE pattern this epic extends.

> Note: the shared local-notification engine (F5) is the downstream consumer of M4-T5's next-due and appointment output; this epic produces triggers for it rather than reimplementing scheduling.

## References

- [docs/features/03-service-maintenance.md](../../features/03-service-maintenance.md) — the feature spec: visits, line items, parts, DIY logs, templates, appointments
- [docs/flutter/03-data-persistence.md](../../flutter/03-data-persistence.md) — Drift schema, repositories, transactions, `.watch()` streams
- [docs/flutter/14-money-currency-fx.md](../../flutter/14-money-currency-fx.md) — minor-unit money, per-entry currency, labour/parts/tax splits
- [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md) — ARB strings, RTL, calendar-aware interval arithmetic, numerals
- [docs/design/pulse/02-components.md](../../design/pulse/02-components.md) — PULSE components for the visit editor and status cards
- [docs/reference/data-model.md](../../reference/data-model.md) — canonical service/line-item/part/fluid/appointment entity definitions

## Tasks

### M4-T1 · Service schema & repository

**Description.** Define the Drift schema for the service domain as spokes off F2's vehicle hub: a `service_visit` header (vehicle ref, actual service date as UTC instant, `odometer_at_service`, provider ref, visit-level DIY flag, tax/discount/fees, per-entry currency, notes, tags) with a child `service_line_item` table (service-type taxonomy ref, labour cost, parts cost, `resets_interval_flag`, per-item DIY flag) — so one visit bundles many line items and maps to a single receipt. Reuse F2's UUID PKs, universal audit columns, soft-delete tombstones, and `source` tag. Service types resolve through F2's custom-taxonomy tables (built-in-but-editable + fully custom), never a hardcoded enum. The `ServiceRepository` extends F2's base repository, writes each visit's `odometer_at_service` into the shared ledger in the **same transaction** as the visit, returns sealed `Result<T, Failure>`, and exposes `.watch()` streams for history.

**Acceptance criteria**
- [ ] `service_visit` and `service_line_item` tables defined with UUID PKs, universal audit/tombstone columns, and a FK making a visit own many line items (one receipt per visit).
- [ ] Service types are taxonomy refs (built-in-editable + custom), not an enum; a custom type behaves identically to a built-in.
- [ ] Saving a visit writes its odometer reading into the shared ledger with a `source` of `service`, atomically in the same transaction; a failure rolls back both.
- [ ] Repository extends the F2 base, enforces canonical units/money/UTC at the boundary, and returns `Result<T, Failure>` from every method.
- [ ] History reads exposed as `.watch()` streams, filterable by type, provider, date, and DIY/shop; tombstoned rows excluded.
- [ ] Generated Drift code builds clean under `build_runner` and `flutter analyze`.

**Size:** M · **Depends on:** F2, M2 · **Governing docs:** flutter/03-data-persistence, reference/data-model

### M4-T2 · Parts, warranty & DIY logs

**Description.** The detail entities hanging off a line item. A `part_used` table (name, brand, `oem_number`, `aftermarket_number`, quantity, unit cost as minor units, supplier) with part numbers kept LTR-safe for RTL layouts and export. A `fluid_used` table (type, spec e.g. 5W-30/DOT4/G12, quantity, unit). Warranty fields on parts and workmanship tracked by **both date and mileage** (`warranty_until_date`, `warranty_until_mileage`) so coverage feeds the warranty-compliance surface. A `procedure_log` for DIY jobs: ordered steps, torque specs, fluid capacities, tools, and time. Cost is captured as a labour-vs-parts split per line item (money as minor units per F2/money doc); a reusable parts catalog with autocomplete backs fast repeat entry.

**Acceptance criteria**
- [ ] `part_used` stores brand, OEM and aftermarket part numbers, supplier, quantity, and unit cost in minor units; part numbers are LTR-isolated and never reordered in RTL or export.
- [ ] `fluid_used` captures type, spec, quantity, and unit with canonical storage and display conversion.
- [ ] Warranty tracked by both date and mileage on parts and workmanship, exposed for the shared warranty/reminder surface.
- [ ] `procedure_log` captures ordered steps, torque specs, capacities, tools, and time, editable and re-orderable.
- [ ] Labour and parts costs are stored and split per line item as integer minor units; no float in the money path.
- [ ] Reusable parts catalog supports autocomplete of prior entries with search-folding.

**Size:** M · **Depends on:** M4-T1 · **Governing docs:** flutter/14-money-currency-fx, reference/data-model

### M4-T3 · Bundled schedule templates

**Description.** Ship editable, offline generic and severe-duty maintenance-schedule templates on-device (no network, honestly labelled "generic" and user-overridable). Each template entry maps a service type to a **default interval** (distance, time, or whichever-first) drawn from the taxonomy's default-interval columns. Provide an **apply-to-vehicle** operation that instantiates the template's reminders anchored to the vehicle's current odometer and date, with a severe-duty profile applying shortened interval overrides on top of the generic schedule. Optional community per-make schedule import/export as JSON is a later extension the format anticipates.

**Acceptance criteria**
- [ ] Generic and severe-duty templates are bundled as on-device assets and load fully offline; both are editable, not locked.
- [ ] Each template entry maps a service type to a default interval (distance/time/whichever-first) via the taxonomy default-interval mapping.
- [ ] Applying a template to a vehicle anchors intervals to the vehicle's current odometer and date and produces the corresponding next-due state.
- [ ] Severe-duty profile applies shortened interval overrides layered over the generic schedule without mutating it.
- [ ] Templates are honestly labelled "generic" and every applied interval remains user-overridable per vehicle.
- [ ] Template JSON has a versioned schema that a later community import/export can round-trip.

**Size:** M · **Depends on:** M4-T1, F2 · **Governing docs:** features/03-service-maintenance, reference/data-model

### M4-T4 · Service entry UI

**Description.** The multi-line visit editor on PULSE screens (Garage/Pit-lane room conventions, tokens + components from F3): visit header (date in active calendar, odometer, provider from the offline directory, DIY toggle), an add/remove list of line items each with service type, parts, fluids, labour/parts cost, and reset-interval toggle, receipt/photo/PDF attachment via the F8 pipeline (incl. in-app scan), and per-service-type last-done / next-due status cards showing OK / due-soon / overdue. **Autosave** in-progress drafts transactionally with back/exit confirmation (the shared data-loss-prevention pattern). Status is **redundantly encoded** — icon + label + shape/position, never colour alone — and every custom chart/stat tile carries Semantics.

**Acceptance criteria**
- [ ] Multi-line visit editor built with PULSE tokens/components; line items can be added, edited, reordered, and removed, all under one receipt.
- [ ] Receipt/photo/PDF attachment (including in-app scan) works through the F8 attachments pipeline and re-links on restore.
- [ ] Last-done / next-due status cards show OK / due-soon / overdue with status redundantly encoded (icon + label + shape/position), never colour alone.
- [ ] In-progress edits autosave transactionally; a back/exit with unsaved changes prompts confirmation and no data is lost.
- [ ] Minimum touch targets met; screen-reader labels on all fields, cards, and custom stat tiles read correctly.
- [ ] Provider is selectable from the offline workshop/mechanic directory with no connectivity.

**Size:** M · **Depends on:** M4-T1, M4-T2, F3, F8 · **Governing docs:** design/pulse/02-components, features/03-service-maintenance

### M4-T5 · Appointment & next-due

**Description.** Feed the shared notification engine (F5) two deliberately separate reminder classes. **Interval reminders** track when a recurring service is next due (date/distance/whichever-first), using odometer-freshness projection so a "due in 1,000 km" rule resolves to an estimated date with early-warning lead time, and several services due together surface as one grouped reminder. **Appointment reminders** track a specific booked date/time with a shop, writing a local `.ics` calendar file that respects the display calendar and first-day-of-week. Cancelling one class never clears the other. Optional warranty-expiry reminders (from M4-T2 limits) reuse the same engine. This task owns the appointment entity and the mapping of next-due/appointment output into the engine's trigger contract.

**Acceptance criteria**
- [ ] Interval reminders emit date, distance, and whichever-first triggers into the F5 engine's contract, with distance rules projected to an estimated date via average daily distance.
- [ ] Appointment entity (`datetime`, `shop_id`, status) generates a local `.ics` respecting the active calendar and first-day-of-week; no server involved.
- [ ] Interval and appointment reminders are independent — cancelling one never clears the other.
- [ ] Services due together produce a single grouped reminder rather than a burst.
- [ ] Optional warranty-expiry reminders (date and mileage) reuse the shared engine.
- [ ] Deleting a last-done anchor service recomputes next-due from the previous valid record.

**Size:** M · **Depends on:** M4-T1, M4-T9, F2 · **Governing docs:** features/03-service-maintenance, flutter/03-data-persistence

### M4-T6 · i18n strings & taxonomy localization

**Description.** All service UI strings and built-in service-type/category names exist in en/de/fr (LTR) and fa/ar/ckb (RTL) ARB files, with ICU plurals where counts appear. Custom (user-generated) service-type names are preserved across languages with **search-folding** so they stay findable regardless of interface language. Part numbers, VIN, and phone numbers stay LTR even inside RTL layouts and exports. Interval arithmetic is calendar-aware (Jalali/Hijri/Hebrew leap years and variable month lengths) by storing absolute dates and converting only for display; localized numerals (Western/Eastern-Arabic/Persian) and decimal separators round-trip without corrupting parsing.

**Acceptance criteria**
- [ ] All service strings and built-in service-type/category names present in en/de/fr/fa/ar/ckb with ICU plurals; no user-facing English is hardcoded.
- [ ] Custom service-type names round-trip across a language switch and are findable via search-folding.
- [ ] Part numbers, VIN, and phone numbers render LTR (bidi-isolated) inside RTL layouts and in exports.
- [ ] Interval date math is calendar-aware across Jalali/Hijri/Hebrew (leap years, variable months) using stored absolute dates.
- [ ] Localized numerals and decimal separators render per preference and round-trip losslessly through CSV/JSON.
- [ ] RTL verified: mirrored layout and focus/traversal order on all M4 screens for fa/ar/ckb.

**Size:** S · **Depends on:** M4-T4, F4 · **Governing docs:** flutter/06-i18n-rtl-calendars, features/03-service-maintenance

### M4-T7 · Export/backup mapping

**Description.** Register every service entity with F6's backup/export/import subsystem using F2's versioned canonical serializers: service visits and their line items, parts, fluids, quotes, checklists, procedure logs, warranty limits, and schedule/applied-template state all round-trip through the single-file full backup (attachments re-linked), per-entity CSV, and combined JSON. Serialization emits canonical base units and minor-unit money (not display-converted) with stable ordering. Import re-validates through F2's integrity layer and supports column mapping for Drivvo/aCar/Fuelio/generic-CSV history. Tombstones survive so a restore does not resurrect trashed records.

**Acceptance criteria**
- [ ] Every service entity (visit, line item, part, fluid, quote, checklist, procedure log, warranty, applied-schedule state) has a versioned to/from-canonical serializer.
- [ ] Export emits canonical units + minor-unit money with an explicit schema/format version and stable ordering; attachments re-link on restore.
- [ ] Round-trip is lossless (export → wipe → import equals original) and re-runs integrity validation flagging duplicates.
- [ ] Tombstones and ledger continuity survive the round-trip; restore does not resurrect trashed service records.
- [ ] Import supports column mapping for Drivvo, aCar, Fuelio, and generic CSV.

**Size:** S · **Depends on:** M4-T1, M4-T2, F6 · **Governing docs:** flutter/03-data-persistence, reference/data-model

### M4-T8 · Tests

**Description.** The verification layer, weighted to the diamond-topped pyramid: exhaustive table-driven pure-Dart tests for the interval/next-due projection engine (M4-T9) and the cost/savings math (M4-T10), plus repository integration tests for line-item-to-receipt integrity, ledger-write atomicity, and export/import round-trip. Cover the feature-doc edge cases: back-dated re-anchoring, partial vs full-change reset, whichever-first with one dimension known, deleting an anchor service, and appointment/interval independence.

**Acceptance criteria**
- [ ] Line-item-to-receipt integrity tested: a visit owns its line items, deleting the visit cascades correctly, and one receipt maps to one visit.
- [ ] Next-due/whichever-first projection tested table-driven, incl. back-date re-anchoring, one-dimension-known projection, and anchor-deletion recompute; pure engine at 100%.
- [ ] Cost/savings math tested (visit total = Σ(parts+labour)+tax−discount+fees, DIY-vs-shop savings) with integer-only money and defined rounding.
- [ ] Ledger-write atomicity tested: a failed visit save rolls back the ledger reading too.
- [ ] Export/import round-trip golden test passes; partial-service reset semantics are not misflagged.
- [ ] All suites green in CI with `flutter analyze` and `dart format --set-exit-if-changed` clean.

**Size:** M · **Depends on:** M4-T1, M4-T7, M4-T9, M4-T10 · **Governing docs:** flutter/03-data-persistence, features/03-service-maintenance

---

### M4-T9 · Interval & next-due projection engine *(added — logic slice)*

**Description.** The pure-Dart heart of scheduling, isolated from persistence and notifications so it can be exhaustively unit-tested (diamond-topped pyramid base). Computes `next_due_date = last_done_date + interval_time` and `next_due_odometer = last_done_odometer + interval_distance`; resolves the **whichever-first governing dimension** as the earliest of the time threshold and the projected date the odometer threshold is reached; projects a due date from `avg_daily_distance` (from the F2 ledger) when only distance is known; **re-anchors** intervals to a back-dated true event date, not the entry-creation date; and recomputes from the previous valid record when a last-done anchor is deleted. Honours reset-interval flags so a top-up never restarts a full-change clock, and falls back to time-only/projection when a historical odometer is unknown.

**Acceptance criteria**
- [ ] `next_due_date` / `next_due_odometer` and whichever-first governing-dimension computed as pure functions with zero DB/I/O.
- [ ] Distance-only intervals project a due date from ledger `avg_daily_distance` with an insufficient-data fallback.
- [ ] Back-dated services re-anchor the recurring interval to the true event date.
- [ ] Reset-interval flag respected: a top-up line item does not reset a full-change interval.
- [ ] Deleting a last-done anchor recomputes next-due from the previous valid record.
- [ ] Unknown historical odometer falls back to time-only/projection rather than guessing distance.

**Size:** M · **Depends on:** M4-T1, F2 · **Governing docs:** features/03-service-maintenance, flutter/03-data-persistence

### M4-T10 · Service cost & DIY-savings math *(added — logic slice)*

**Description.** A pure-Dart cost engine over the line-item/labour/parts/tax data. Computes the **visit total** = Σ(parts + labour) + tax − discount + fees; the labour-vs-parts split and per-visit `labour_hours × labour_rate`; **DIY-vs-shop savings** = estimated shop cost − actual DIY cost; and running cost (`cost_per_km`, `cost_per_month`) derived from history against distance and time. All arithmetic is integer minor-unit money with defined rounding and per-entry currency converted from the canonical base only for display; `best_quote = min(quotes.amount)` supports pre-booking comparison. Feeds service cost analytics and, upstream, the TCO stack.

**Acceptance criteria**
- [ ] Visit total = Σ(parts + labour) + tax − discount + fees, computed integer-only with defined rounding; no float in the money path.
- [ ] Labour/parts split and DIY-vs-shop savings computed and exposed for analytics.
- [ ] Running cost (`cost_per_km`, `cost_per_month`) derived deterministically from history with an insufficient-data fallback.
- [ ] Per-entry currency is converted from the canonical base for display only; stored values are unchanged and never silently mixed.
- [ ] `best_quote = min(quotes.amount)` surfaced for pre-booking comparison.
- [ ] Engine is pure, I/O-free, and table-driven testable.

**Size:** S · **Depends on:** M4-T1, M4-T2 · **Governing docs:** flutter/14-money-currency-fx, features/03-service-maintenance

## Definition of Done

- **Tests green:** pure-engine suites for next-due/whichever-first projection and cost/savings math at 100%; repository integration tests for line-item-to-receipt integrity, ledger-write atomicity, and export/import round-trip — all passing in CI with `flutter analyze` and `dart format --set-exit-if-changed` clean.
- **Canonical & ledger-honest:** every visit writes its odometer into the shared ledger atomically; all measures store as SI units / UTC instants / minor-unit money and convert only for display; back-date, cluster-swap, unit-change, and language-switch never rewrite history.
- **i18n complete:** all service strings and built-in service-type/category names exist in en/de/fr/fa/ar/ckb with ICU plurals; custom type names round-trip via search-folding; no user-facing English is hardcoded.
- **RTL verified:** every M4 screen renders mirrored with correct focus/traversal order in fa/ar/ckb; numerals and dates render in the active numeral system and calendar; part numbers/VIN/phone stay LTR (bidi-isolated).
- **In backup/export:** every service entity (visits, line items, parts, fluids, quotes, checklists, procedure logs, warranties, applied-schedule state) round-trips losslessly through single-file backup, per-entity CSV, and combined JSON with attachments re-linked; tombstones survive restore.
- **Accessible:** the entry UI and status cards meet minimum touch targets, expose screen-reader labels (incl. RTL reading order), and encode all status (OK / due-soon / overdue, DIY/shop) **redundantly** — icon + label + shape/position — per the PULSE redundant-encoding rule, never colour alone.
- **Reminders wired:** interval and appointment reminder classes feed the shared notification engine independently, distance rules project to estimated dates with lead time, and co-due services group into one reminder.
