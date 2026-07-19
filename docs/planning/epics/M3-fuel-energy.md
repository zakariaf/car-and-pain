# M3 · Fuel & Energy

> The unified energy entry-and-economy engine — petrol/diesel/LPG/CNG/ethanol/hydrogen fills and EV/PHEV charge sessions — with correct full/partial/missed/first-fill economy math, EV break-even vs ICE, canonical-unit storage, and PULSE entry plus economy visualizations.

## Goal

Ship the one honest energy engine that fuel-tracking rivals get subtly wrong. Fuel is the entry owners make most often; a single mishandled partial or forgotten fill, or a US-gallon/UK-gallon/litre mix-up, produces the "why is my MPG wrong?" complaint that drives users off Drivvo and Fuelly. This epic delivers a **unified entry-and-economy engine** covering every way a vehicle takes on energy:

- **One record, every energy type.** Petrol, diesel, LPG, CNG, ethanol, and hydrogen fills plus EV and PHEV charge sessions share a single `FuelEntry` schema and repository, each writing to the shared per-vehicle **odometer ledger** and storing money in integer **minor units** keyed to the ISO-4217 exponent.
- **A correct economy state machine.** A precise full / partial / missed / first-fill state machine drives a **full-to-full consumption algorithm** — partials deferred and summed, missed fills excluded from economy (cost retained), first fill shown as "pending" (never 0, never ∞) — with over-capacity and outlier validation on save.
- **EV/PHEV as first-class.** Charge sessions capture kWh, start/end SoC (with energy-from-SoC derivation), connector/charger type, home-vs-public tariff split, wall-energy true cost-per-distance, and an **EV-vs-ICE break-even** calculator.
- **Canonical storage, display-only conversion.** Everything stored in SI volume/energy, UTC instants, and base currency; litres today can be read as MPG (UK) tomorrow with no historical value shifting.
- **PULSE entry + economy visualizations.** An energy-adaptive quick-add form with unit-aware inputs and autosave drafts, plus CustomPainter economy/cost/consumption/spend charts — every status redundantly encoded (icon + label + shape/position), fully localized across en/de/fr + fa/ar/ckb with correct numerals, calendars, and RTL mirroring.

Everything runs fully offline: no live price feed, no live tariff, no live FX — personal price memory, saved stations, locally stored TOU tariffs, and per-trip manual exchange rates instead.

## Tier & dependencies

- **Tier:** mvp
- **Module:** `fuel-energy`
- **Depends on:** F2 (data layer / canonical repos), F3 (PULSE design system), F4 (i18n / RTL / calendars / numerals), F6 (backup / export / import), M2 (Vehicles, Garage & Odometer — ledger, tank/battery capacity, fuel-type config)

## References

- [docs/features/02-fuel-energy.md](../../features/02-fuel-energy.md)
- [docs/flutter/14-money-currency-fx.md](../../flutter/14-money-currency-fx.md)
- [docs/flutter/03-data-persistence.md](../../flutter/03-data-persistence.md)
- [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md)
- [docs/design/pulse/02-components.md](../../design/pulse/02-components.md)
- [docs/reference/data-model.md](../../reference/data-model.md)

## Tasks

### M3-T1 · FuelEntry schema & repository

**Description.** The canonical data foundation. Define a single unified `FuelEntry` Drift entity that covers liquid fills, gaseous fills, and EV/PHEV charge sessions in one table — liquid/gas fields (`volume` + `volume_unit` of L/US gal/UK gal/kg/m³, `fuel_type`, `octane_grade`, `secondary_fuel_type`, `tank_number`), charge fields (`energy_kwh`, `price_per_kwh`, `charger_type`, `connector_type`, `start_soc_pct`/`end_soc_pct`, `is_home_charge`, `tou_rate`, `energy_from_wall_kwh`, `self_generated_kwh`), the economy-state flags (`is_full_tank`, `is_partial`, `is_missed_previous`, `exclude_from_economy`, `is_free`), and shared fields (odometer/trip-meter, station, payment, tags, notes, `trip_id`). Store measures in **SI base units** and money as **integer minor units + ISO-4217 currency code** honoring each currency's real exponent (0 IRR/JPY, 2 USD/EUR, 3 KWD). Every saved entry writes a reading to the shared per-vehicle **odometer ledger** with `source = fuel`, carrying UUID + `updated_at` + tombstone for backup/merge/sync. Repository exposes the canonical contract at the boundary and returns a sealed `Result<T, ValidationFailure|DbFailure>`.

**Acceptance criteria.**
- [ ] One `FuelEntry` schema represents petrol/diesel/LPG/CNG/ethanol/hydrogen fills **and** EV/PHEV charge sessions; no separate charge table.
- [ ] All measures persist in SI base units (volume in L, energy in kWh→J-canonical or documented base, distance per ledger) with display-only conversion; no floats-as-money and no fixed-2-decimal assumption.
- [ ] Money stored as integer minor units keyed to the record's ISO-4217 exponent; per-record `currency` retained with the original amount.
- [ ] Saving a fill/charge writes a monotonic reading to the shared odometer ledger tagged `source = fuel`; trip-meter entries reconcile to an absolute reading.
- [ ] Records carry UUID + `updated_at` + tombstone; soft-delete routes to trash/undo, never a hard delete.
- [ ] Repository returns sealed `Result` at every module boundary; canonical values are the single source of truth.

**Size:** M
**Depends on:** F2 (Drift/canonical repos, odometer ledger, money model), M2 (per-vehicle fuel-type & capacity config)
**Governing docs:** flutter/03-data-persistence.md, flutter/14-money-currency-fx.md, reference/data-model.md

### M3-T2 · Economy state machine

**Description.** The correctness core and the reason this app exists. A pure-Dart engine that walks a vehicle's chronologically ordered fills and computes real-world consumption via the **full-to-full algorithm**: `distance = odo_end − odo_start`, `fuel = Σ volumes across the interval`. It classifies each entry through the full / partial / missed / first-fill / excluded state machine — a **partial** defers economy to the next full tank (consecutive partials summed across the whole span), a **missed** fill excludes that gap from economy while keeping its cost in spend totals, the **first fill** (or first after reset) yields economy = "pending" (never 0, never ∞), and **splash-fill/jerrycan** entries keep cost but drop volume from economy. Produces latest-interval, rolling-N, and lifetime averages (lifetime excludes baseline and missed intervals), best/worst tank, and cost-per-distance — all as pure functions with no I/O. A **backdated / out-of-order** insert triggers a deterministic recompute of every affected interval. Enter-any-two auto-calc (`total = volume × price`, etc.) runs at 3-decimal pricing precision with a user-marked authoritative field so rounding never fights the receipt. **Over-capacity** volume, outlier economy, and duplicate double-tap are validated on save with an override path.

**Acceptance criteria.**
- [ ] Full-to-full economy sums all volumes across a full→full interval and divides by ledger distance; consecutive partials are summed, never averaged into nonsense.
- [ ] A partial fill produces no standalone economy figure and correctly folds into the next full-tank interval.
- [ ] A missed/forgotten fill excludes its interval from economy while its cost remains in spend totals.
- [ ] The first fill and the first after a reset report economy as "pending" — never 0 and never infinity.
- [ ] Splash-fill/jerrycan and free/$0 fills retain cost but do not distort economy or per-unit price averages.
- [ ] Enter-any-two computes the third field at 3-decimal precision honoring the user-selected authoritative field; 3-decimal pricing never corrupts the result.
- [ ] A backdated insert re-sorts the timeline and deterministically recomputes every affected interval; identical inputs yield identical outputs.
- [ ] On-save validation flags over-capacity volume (against tank/battery capacity), outlier economy, and duplicate submission, warning with an override rather than blocking.
- [ ] Engine is pure Dart (no DB/I/O) returning typed results; all state transitions are unit-test-addressable.

**Size:** L
**Depends on:** M3-T1, M2 (tank/battery capacity for over-capacity checks), F2 (odometer ledger)
**Governing docs:** features/02-fuel-energy.md, reference/data-model.md

### M3-T3 · EV/PHEV charge sessions

**Description.** Treat a charge session as the exact analogue of a fill-up, not a bolted-on afterthought. Capture kWh delivered, cost/`price_per_kwh`, charger type (AC/DC + level), physical `connector_type`, network + membership/RFID card, and start/end **state-of-charge**. Derive delivered energy from SoC when no meter reading exists: `energy = (end_soc − start_soc) / 100 × usable_capacity_kwh`. Split **home vs public** charging, each with its own time-of-use tariff drawn from a locally stored TOU rate table (no online lookup); auto-cost home charges. Compute EV **true cost-per-distance on wall energy** applying a documented AC `loss_factor` (~10–15%): `cost/100 = (energy_from_wall × price_per_kwh) / distance × 100`, and present EV economy in Wh/km, mi/kWh, and kWh/100km. For **PHEV**, blend fuel and electric against the one shared odometer into a single cost-per-distance (blended, never added). Provide the **EV-vs-ICE break-even**: `months_to_payback = price_premium / (ice_cost_per_period − ev_cost_per_period)`. Track traction-battery **State-of-Health** over time.

**Acceptance criteria.**
- [ ] A charge session is a first-class `FuelEntry` capturing kWh, cost, charger/connector type, network/membership, and start/end SoC.
- [ ] Energy is derived from SoC delta × usable capacity when no meter reading is entered.
- [ ] Home and public charges are tracked separately, each priced by its own locally stored TOU tariff; home charges auto-cost offline.
- [ ] EV true cost-per-distance is computed on wall energy with a documented AC loss factor; economy shown in Wh/km, mi/kWh, and kWh/100km.
- [ ] PHEV fuel + electric costs blend against one shared odometer into a single cost-per-distance, never summed as separate distances.
- [ ] EV-vs-ICE break-even returns months-to-payback from the price premium and per-period running-cost delta; guards divide-by-zero / negative-savings cases honestly.
- [ ] Battery State-of-Health is tracked over time so usable-capacity decline is visible.
- [ ] All charge economy runs fully offline; no live tariff or availability claim.

**Size:** M
**Depends on:** M3-T1, M3-T2, M2 (usable battery capacity), F2
**Governing docs:** features/02-fuel-energy.md, flutter/14-money-currency-fx.md

### M3-T4 · Fuel entry UI

**Description.** The energy-adaptive quick-add form, built from PULSE components. Opening a new entry pre-fills last station, fuel type, and price for that **specific vehicle** so a routine top-up is a two-tap confirm. The form **adapts to the energy type**: liquid/gas shows volume + unit (L/US gal/UK gal/kg/m³) and grade; a charge shows kWh, connector/charger, SoC, and home/public. Unit-aware inputs parse and render 3-decimal prices and locale numerals; enter-any-two fills the third field live with the authoritative-field marker. Full/partial toggle, missed-fill flag, exclude-from-economy, and log-without-mileage / log-without-cost are all reachable. Odometer entry supports absolute reading, trip-meter, and last-3-digits shortcut. Every in-progress entry **autosaves a draft**; back/exit prompts a confirmation so a half-typed fill is never lost. Optional receipt/pump-display photo attaches via the shared pipeline. Save surfaces validation warnings (over-capacity, outlier, duplicate) as PULSE states with override.

**Acceptance criteria.**
- [ ] Quick-add pre-fills last station/fuel-type/price per active vehicle; a routine fill is a two-tap confirm.
- [ ] The form is energy-adaptive: liquid/gas vs charge fields switch by fuel type; unit selectors match how each fuel is sold.
- [ ] Enter-any-two updates the third field live at 3-decimal precision with a visible authoritative-field control.
- [ ] Full/partial, missed-fill, exclude-from-economy, log-without-mileage, and log-without-cost are all supported from the form.
- [ ] Odometer accepts absolute, trip-meter, and last-3-digits shortcut (expanded against the known reading).
- [ ] In-progress entries autosave as drafts; back/exit confirms before discarding; a restored draft repopulates every field.
- [ ] Validation warnings render as redundantly-encoded PULSE states (icon + label + shape) with an override path, never color-only.
- [ ] All widgets are PULSE components; the completion "exhale" plays on successful save.

**Size:** M
**Depends on:** M3-T1, M3-T2, M3-T3, F3 (PULSE components), F8 (attachments pipeline)
**Governing docs:** design/pulse/02-components.md, features/02-fuel-energy.md

### M3-T5 · Economy visualizations

**Description.** On-device CustomPainter charts for economy, price, consumption, and spend trends over time — built-in-first, no charting dependency. Render latest-interval, rolling-N, and lifetime series; separate multi-fuel/bi-fuel and EV series so petrol and electric never blend into a meaningless average; highlight best/worst tanks. Chart chrome **mirrors for RTL** and the time axis inverts so trends read naturally right-to-left; numerals render in the active numeral system while units/prices stay LTR via bidi isolation. Every chart is wrapped in `Semantics` exposing a text summary and per-point values so screen readers (including RTL / Eastern-Arabic numerals) can read the trend; reduced-motion honored.

**Acceptance criteria.**
- [ ] Economy, price, consumption, and spend charts are drawn with CustomPainter — no third-party chart library.
- [ ] Latest / rolling-N / lifetime series are selectable; multi-fuel, bi-fuel, and EV series stay separated.
- [ ] Chart chrome mirrors in RTL with an inverted time axis; numerals localize while units/prices/IDs stay LTR via bidi isolation.
- [ ] Each chart is `Semantics`-wrapped with a readable summary and point values; announces correctly with Persian/Eastern-Arabic numerals.
- [ ] Charts honor reduced-motion and PULSE tokens; status/highlights are redundantly encoded (shape/label), not color-only.
- [ ] Charts recompute from canonical values and update reactively when entries change.

**Size:** M
**Depends on:** M3-T2, M3-T3, F3 (PULSE tokens), F4 (numerals/RTL)
**Governing docs:** design/pulse/02-components.md, flutter/06-i18n-rtl-calendars.md

### M3-T6 · i18n & unit/currency display

**Description.** Localize every user-facing string across en/de/fr + fa/ar/ckb via ARB (gen-l10n), with no hardcoded UI text. Implement the **multi-mode economy projections** — L/100km, MPG (US), MPG (UK), km/L, Wh/km, mi/kWh, kWh/100km — from canonical SI values using correct unit constants (`US gal = 3.785 L`, `UK gal = 4.546 L`, plus CNG mass conversions). Parse and render **3-decimal fuel prices** across locale conventions including Persian `٫` decimal and `٬` grouping, accept Western/Eastern-Arabic/Persian/Devanagari digits on input, and support Indian 2-2-3 grouping. Dates display in the vehicle's chosen calendar (Gregorian/Jalali/Hijri/Hebrew) from the canonical ISO instant. Per-vehicle distance unit (km/mi), volume unit, and currency drive display without touching stored values; foreign station/network strings are preserved verbatim under bidi isolation.

**Acceptance criteria.**
- [ ] 100% of user-facing strings are in ARB across en/de/fr/fa/ar/ckb; no hardcoded text.
- [ ] Economy projects into all seven modes from canonical values; US vs UK gallon conversions are exact and never conflated.
- [ ] 3-decimal prices parse and render across locales including Persian decimal `٫` / grouping `٬`; Western/Eastern-Arabic/Persian/Devanagari digits accepted on input.
- [ ] Dates render in Gregorian/Jalali/Hijri/Hebrew from the canonical ISO instant; switching calendars never shifts a stored record.
- [ ] Per-vehicle distance/volume/currency selections are display-only; toggling them never rewrites history.
- [ ] Numbers, units, prices, VINs, plates, and IDs stay LTR via bidi isolation inside RTL layouts; foreign UGC strings preserved verbatim.

**Size:** S
**Depends on:** M3-T2, M3-T3, M3-T4, F4 (i18n/RTL/calendars/numerals engine)
**Governing docs:** flutter/06-i18n-rtl-calendars.md, flutter/14-money-currency-fx.md

### M3-T7 · Export/backup mapping

**Description.** Wire the fuel/charge entity into the F6 backup/export/import subsystem. Map `FuelEntry` — with all state flags (full/partial/missed/excluded/free), station and charge fields, tags, and its live economy-relevant state — into the combined `dart:convert` JSON export, the hand-written per-entity CSV, and the encrypted single-file backup, using **locale-neutral canonical values** (SI measures, integer minor-units + ISO code, UTC epoch instants, canonical enum tokens) with explicit unit/currency labels so the other side is never ambiguous. Round-trip losslessly on import, and reconcile backdated/duplicate imports deterministically via the shared tombstone-aware merge.

**Acceptance criteria.**
- [ ] `FuelEntry` (all fields + state flags + station/charge/tags) appears in JSON export, per-entity CSV, and the encrypted single-file backup.
- [ ] Exported values are canonical and locale-neutral (SI measures, minor-units + ISO code, UTC millis, canonical enums) with explicit unit/currency labels.
- [ ] Export→wipe→import restores every fuel/charge record with canonical values and economy state unchanged.
- [ ] Backdated and duplicate/re-imported entries reconcile deterministically through the shared tombstone-aware merge; the odometer ledger stays monotonic.
- [ ] Attachment (receipt/pump photo) references round-trip and re-link to their restored entry.

**Size:** S
**Depends on:** M3-T1, F6 (backup/export/import + merge engine), F8 (attachments)
**Governing docs:** flutter/03-data-persistence.md, reference/data-model.md

### M3-T8 · Economy engine tests

**Description.** The fidelity guarantee for the state machine. Exhaustive **table-driven** unit tests on the pure-Dart economy/EV engines at effectively 100% branch coverage: full-fill chains, partial-fill chains (single and consecutive), missed-fill exclusion, first-fill/reset "pending", splash-fill/jerrycan exclusion, free/$0 non-distortion, enter-any-two at 3-decimal precision with each authoritative field, over-capacity and outlier validation, backdated-insert recompute determinism, and duplicate detection. Cover EV paths: SoC-derived energy, wall-energy cost-per-distance with loss factor, home/public TOU costing, PHEV blended cost, EV-vs-ICE break-even (including zero/negative-savings guards). Verify unit-constant correctness (US vs UK gallon, CNG mass) and currency-exponent handling.

**Acceptance criteria.**
- [ ] Table-driven tests cover full, partial (single + consecutive), missed, first-fill/reset, splash/jerrycan, and free/$0 cases with expected economy and spend outcomes.
- [ ] Enter-any-two is tested at 3-decimal precision for each authoritative field with no rounding corruption.
- [ ] Backdated-insert recompute is proven deterministic (same inputs → same outputs) and duplicate detection is covered.
- [ ] EV tests cover SoC-derived energy, wall-energy cost-per-distance with loss factor, home/public TOU costing, PHEV blending, and break-even edge cases (zero/negative savings).
- [ ] Unit constants (US/UK gallon, CNG mass) and currency exponents (0/2/3) are asserted; US↔UK gallon is never conflated.
- [ ] `flutter analyze` and `dart format --set-exit-if-changed` are clean; the pure engines reach the targeted ~100% coverage.

**Size:** M
**Depends on:** M3-T2, M3-T3, M3-T6
**Governing docs:** features/02-fuel-energy.md, reference/data-model.md

### M3-T9 · Saved stations, price memory & tariff store (added)

**Description.** The offline substitute for a live price feed. A personal, fully offline library of **saved stations** (name/brand + raw GPS pinned on the bundled offline map, no reverse-geocoding) and **per-station price memory** built entirely from the user's own history, plus a local **home electricity TOU tariff** store that auto-costs home charges. Feeds the quick-add pre-fill (M3-T4) and honest own-history price comparison. Supports multi-currency fills abroad via a per-trip **manual exchange rate** that preserves the original amount. No claim of live market pricing or availability.

**Acceptance criteria.**
- [ ] Stations can be saved (name/brand/GPS) and re-selected; GPS pins render on the bundled offline map with no online geocoding.
- [ ] Per-station and personal price memory is built from the user's own history and feeds quick-add pre-fill and comparison — never presented as live pricing.
- [ ] Home electricity TOU tariffs are stored locally and auto-cost home charges offline.
- [ ] Foreign fills accept a per-trip manual exchange rate while preserving the original amount and currency.
- [ ] Stations, price memory, and tariffs are included in backup/export and localized/RTL-correct.

**Size:** S
**Depends on:** M3-T1, M3-T3, M3-T7, F4 (i18n/RTL)
**Governing docs:** features/02-fuel-energy.md, flutter/14-money-currency-fx.md

### M3-T10 · Reminders & anomaly integration (added)

**Description.** Wire Fuel & Energy into the shared offline local-notification engine as both consumer and producer: **fuel-log** reminders (prompt to record a possibly-missed fill, keeping the economy chain intact), **low-fuel** and **next-fill / range** projection from rolling consumption (`range = tank_capacity ÷ rolling_avg_consumption`), and a **rising-consumption anomaly** alert when an interval's economy degrades beyond tolerance. All notifications name the specific vehicle, survive reboot/Doze/app-kill, and re-arm after a backup restore.

**Acceptance criteria.**
- [ ] Optional fuel-log, low-fuel, next-fill/range, and rising-consumption alerts schedule through the shared F5 notification engine.
- [ ] Range/next-fill projection derives from rolling consumption, not a live sensor, with a documented insufficient-data fallback.
- [ ] Rising-consumption anomaly fires when interval economy degrades beyond tolerance and names the vehicle.
- [ ] Notifications survive reboot/Doze/app-kill and re-arm after a backup restore.
- [ ] Reminder configuration is a PULSE surface, localized, RTL-correct, and included in backup/export.

**Size:** S
**Depends on:** M3-T2, M3-T3, F5 (notification engine)
**Governing docs:** features/02-fuel-energy.md, flutter/03-data-persistence.md

## Definition of Done

- **Vertical slice complete:** `FuelEntry` schema/repo → economy + EV state machine → PULSE energy-adaptive entry UI + CustomPainter visualizations → i18n/unit/currency projections → export/backup mapping → stations/price memory + reminders → exhaustive tests, all landed and wired to the shared odometer ledger.
- **Tests:** table-driven unit tests at effectively 100% on the pure-Dart economy/EV engines covering full/partial/missed/first-fill chains, splash/free exclusion, enter-any-two precision, backdated recompute determinism, SoC/wall-energy/PHEV/break-even, and unit-constant + currency-exponent correctness; export→wipe→import round-trip green for every fuel/charge field. `flutter analyze` and `dart format --set-exit-if-changed` clean.
- **Built-in-first honored:** charts via CustomPainter, JSON via `dart:convert`, CSV hand-written, calendars/numerals via first-party engine — no new runtime charting/CSV dependency.
- **i18n complete:** 100% of user-facing strings in ARB across en/de/fr/fa/ar/ckb; no hardcoded text; economy projects into all seven modes; 3-decimal prices and Western/Eastern-Arabic/Persian/Devanagari numerals parse and render correctly; exported files stay locale-neutral canonical.
- **RTL verified:** every entry screen and chart mirrors correctly with mirrored focus/traversal order; time axis inverts; numbers, units, prices, VINs, plates, station/network strings held LTR via bidi isolation.
- **In backup/export:** every fuel/charge record with its full/partial/missed/excluded/free flags, station/charge fields, price memory, tariffs, and attachment refs is included in the single-file backup, per-entity CSV, and combined JSON, and round-trips losslessly with the odometer ledger staying monotonic.
- **Accessible per the redundant-encoding rule:** all entry and chart status is encoded with icon + label + shape/position beyond color; every custom chart/stat tile carries `Semantics`; screen readers announce economy, prices, and validation warnings correctly in every locale including Eastern-Arabic/Persian numerals.
- **Failure discipline:** all module-boundary APIs return sealed `Result<T, ValidationFailure|DbFailure>` with stable codes + typed params (never user strings); validation warnings (over-capacity, outlier, duplicate) always offer an override rather than silently blocking or corrupting.
- **Offline honesty:** no live price feed, tariff, or FX — personal price memory, locally stored TOU tariffs, and per-trip manual exchange rates only; charging availability is never claimed live.
