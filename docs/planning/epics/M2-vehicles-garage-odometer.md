# M2 · Vehicles, Garage & Odometer

> The account-free unlimited multi-vehicle garage and the shared, auditable odometer/engine-hour ledger that every other module scopes to.

## Goal

Deliver the hub of the whole app: an unlimited, account-free, offline-first multi-vehicle garage. Each vehicle carries a rich, **powertrain-adaptive** profile (fields appear and validate based on vehicle type + energy type), full **lifecycle states** (active / archived / sold / scrapped / stolen / written-off), **VIN capture with offline ISO 3779 decode**, and **per-vehicle unit/currency overrides** that let an imported US car (mi / US-gal / USD) and a local car (km / L / EUR) coexist without ever corrupting each other.

Underneath the profiles sits the **shared odometer / engine-hour ledger** built on M1's canonical reading timeline: a single monotonic per-vehicle series, written by fuel/service/expense/trip/tire/manual entries and read by reminders, statistics, tires, warranties, and financing. Corrections, cluster swaps, and rollovers are recorded as first-class **audited events**, never overwrites, so mileage history stays trustworthy for the life of the vehicle — through unit changes, device migrations, and eventual sale. This epic also ships the PULSE Garage room and per-vehicle screens, the `avg_daily_distance` / `estimated_odometer_today` projection surface every reminder depends on, and full i18n + export/backup coverage of the vehicle and reading entities.

## Tier & dependencies

- **Tier:** MVP (`mvp`) — first MVP module, the hub every later module scopes to.
- **Depends on:**
  - **F2** — Data layer (Drift + SQLCipher, canonical units/money, odometer ledger primitives, migrations, soft-delete/trash).
  - **F3** — PULSE design system implementation (tokens + components in Flutter).
  - **F4** — i18n / RTL / calendars / numerals engine.
  - **F6** — Backup / export / import + key recovery subsystem.
  - **F8** — Security & app-lock (encryption, biometric/PIN).
  - **M1** — Shared odometer/engine-hour ledger + canonical-contract repository foundation this module extends.

## References

- [docs/features/01-vehicles-garage.md](../../features/01-vehicles-garage.md) — feature spec, field list, formulas, edge cases.
- [docs/flutter/03-data-persistence.md](../../flutter/03-data-persistence.md) — Drift schema, encrypted SQLite, migrations, canonical-contract repositories.
- [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md) — gen-l10n/ARB, RTL mirroring, bidi isolation, calendars, numerals.
- [docs/design/pulse/02-components.md](../../design/pulse/02-components.md) — Vital Card, Rooms nav, list row, status chip, quick-log keypad, chart primitives.
- [docs/design/pulse/03-screens.md](../../design/pulse/03-screens.md) — A1 first-run add-vehicle, A4 vehicle profile, B1 list / B2 timeline / B3 form patterns.
- [docs/reference/data-model.md](../../reference/data-model.md) — canonical conventions, `Vehicle` and `OdometerReading` entity contracts, export/backup mapping.

## Tasks

### M2-T1 · Vehicle schema finalize & repository

**Description.** Extend the Drift `vehicles` table to the full canonical `Vehicle` contract from the data model (identity, plate + `plate_history[]`, VIN fields, engine/drivetrain, energy + secondary energy, tank/battery/connector/SoH, per-vehicle `distance_unit`/`volume_unit`/`consumption_unit`/`currency` overrides, purchase/valuation, lifecycle status, cached `current_odometer`, `offset_after_cluster_swap`, factory specs, cover/gallery refs, `group_id`/`tags[]`, `is_default`, and the universal audit/tombstone columns). Build a `VehicleRepository` over the M1 canonical-contract boundary: stores SI/base-currency canonically, applies per-record → per-vehicle → global precedence, exposes Drift `.watch()` streams for reactive UI, and returns a sealed `Result<T, Failure>` (e.g. `ValidationFailure`, `DbFailure`) at every method boundary. Child collections (`plate_history`, `valuation_history`, `state_of_health_log`) stored as normalized child tables keyed by `vehicle_id`, not JSON blobs, so they export as linked child CSVs.

**Acceptance criteria**
- [ ] Drift table + generated companion cover every field in the canonical `Vehicle` contract, with UUID PK, `created_at`/`updated_at`, and soft-delete (`is_deleted`/`deleted_at`/`trash_expires_at`) columns.
- [ ] Per-vehicle unit/currency overrides persist and resolve via per-record → per-vehicle → global precedence; canonical storage stays SI + base-currency.
- [ ] Repository exposes reactive `watchGarage()` / `watchVehicle(id)` streams and CRUD returning `Result` over a sealed `Failure` hierarchy (stable codes, no user strings).
- [ ] `plate_history`, `valuation_history`, `state_of_health_log` persist as normalized child tables joined by `vehicle_id`.
- [ ] Forward-only migration from the M1 baseline is guarded by a pre-migration snapshot and bumps `schema_version`.
- [ ] Soft-delete moves a vehicle to trash with tombstone; permanent delete cascades/tombstones children so backup + future P2P sync stay consistent.

**Size:** M · **Depends on:** F2, M1 · **Governing docs:** data-model.md (Vehicle, conventions), 03-data-persistence.md, 01-vehicles-garage.md.

### M2-T2 · Powertrain-adaptive profile form

**Description.** Build the add/edit vehicle form (PULSE B3 form pattern + A1 first-run) whose visible/required fields are driven by `vehicle_type` and `energy_type`/`secondary_energy_type`: EV shows battery capacity, usable capacity, connectors, SoH log and hides tank; ICE shows tank capacity, octane; PHEV/bi-fuel shows both energy sources plus split config; boats/RV/equipment expose the engine-hour meter and can disable distance tracking; motorcycle exposes chain/belt + front/rear tire specs; `vehicle_type` sets sensible `wheel_count`/`axle_config` defaults. Make/model/year/trim use a bundled offline picker with mandatory free-text fallback for classics/imports. All input flows through **transactional autosave drafts** (M1 draft store) so a back/exit never loses in-progress data, with back-confirmation. Validation is inline, localized, and unit-aware.

**Acceptance criteria**
- [ ] Field visibility + required/optional validation recompute reactively when `vehicle_type` or `energy_type` changes; hidden-field values are preserved (not destroyed) on toggle so switching back restores them.
- [ ] EV / ICE / PHEV / bi-fuel / hour-metered / motorcycle profiles each show exactly their relevant field set per the feature spec.
- [ ] Make/model/year/trim offer a bundled offline picker with always-available free-text fallback.
- [ ] In-progress edits autosave to a draft transactionally; back/exit prompts a confirmation and the draft survives process death.
- [ ] Distance tracking can be disabled per vehicle (time-only classics) without blocking save.
- [ ] Numeric fields honor the vehicle's unit overrides and display in the active numeral system; validation messages are externalized strings.

**Size:** L · **Depends on:** F3, F4, M2-T1 · **Governing docs:** 01-vehicles-garage.md (adaptive fields), 03-screens.md (A1, B3), 02-components.md (supporting controls).

### M2-T3 · VIN capture & offline decode

**Description.** VIN entry via camera barcode/QR scan (Code 39 / Data Matrix, door-jamb and windshield) with manual entry always available and any scan editable. Implement a pure-Dart VIN decoder: ISO 3779 **weighted modulus-11 check-digit** validation, **WMI** (World Manufacturer Identifier) → manufacturer/region lookup from a bundled offline table, and **model-year** decode from position 10, cross-checked against the entered `model_year`. Persist `vin`, `vin_scanned`, `vin_checksum_valid`, `wmi_decoded`. Honor offline-honesty: full trim/options decode needs a network and is out of scope — surface it as a cached/"last checked" degrade with mandatory free-text fallback, never blocking the entry.

**Acceptance criteria**
- [ ] Barcode/QR scan populates the VIN field; result is editable and manual entry works with the scanner unavailable.
- [ ] ISO 3779 check-digit validation runs identically for scanned and typed VINs; `vin_checksum_valid` reflects the result and an invalid checksum warns without blocking save.
- [ ] WMI decodes to manufacturer/region from a bundled offline table; year (position 10) decodes and cross-checks `model_year`, flagging mismatch.
- [ ] Decoder is pure Dart with no network dependency; full trim/options decode is presented as an honest offline-degraded stub.
- [ ] VIN renders LTR (bidi-isolated) even inside RTL layouts.

**Size:** M · **Depends on:** M2-T1 · **Governing docs:** 01-vehicles-garage.md (VIN, edge cases), data-model.md (VIN fields), 06-i18n-rtl-calendars.md (bidi isolation).

### M2-T4 · Odometer ledger UI

**Description.** The reading-timeline surface over the M1 shared ledger (PULSE B2 detail/timeline): a chronological list of readings showing value, date, and `source` module, plus manual-entry via the quick-log keypad. Implement the audited event flows: **manual reading**, **audited correction** (preserves the original value + reason, never overwrites), **cluster-swap / odometer-replacement** (records `offset_after_cluster_swap` so `lifetime_distance = value + cumulative_offset` stays continuous), and **rollover**. Wire **anomaly detection** (regression below previous, implausible jump, rollback) that warns and requires an explicit **override** (`is_regression_override`), preserving the sequence. Distance vs engine-hour meter is chosen by vehicle profile; time-only vehicles never require a reading.

**Acceptance criteria**
- [ ] Timeline lists readings with value, effective date, and source module; supports backdated entries ordered by `date` while preserving true `created_at` order.
- [ ] Manual reading writes a ledger row with `source = manual`; keypad entry respects the vehicle's distance unit.
- [ ] Correction creates a new audited row preserving the prior value + reason; original is never mutated.
- [ ] Cluster-swap records an offset; displayed lifetime distance is continuous across the swap and rollover.
- [ ] Regression/implausible-jump/rollback anomalies warn and require explicit override; override sets `is_regression_override` and keeps the sequence intact.
- [ ] Engine-hour meter path works for hour-metered vehicles; time-only vehicles are never blocked by a required reading.
- [ ] Ledger writes are transactional and surface `Result`/`Failure` on error.

**Size:** L · **Depends on:** M1, M2-T1, F3 · **Governing docs:** 01-vehicles-garage.md (ledger, corrections, anomaly), data-model.md (OdometerReading), 03-screens.md (B2), 02-components.md (quick-log keypad).

### M2-T5 · Lifecycle & garage management

**Description.** Lifecycle state machine: active / archived / sold / scrapped / stolen / written-off with `status_changed_at` and disposal close-out fields (`sold_date`/`sold_price`/`final_odometer`). Archived and non-active vehicles retain full history + export but are excluded from active dashboards and averages. Restore and permanent-delete (with explicit confirmation, cascade/tombstone). Garage management UI: search (digit-folding + script normalization on nicknames), sort, filter, custom manual order, **pinned default** (`is_default`), and **groups** (household/personal/business/fleet/project/gig) + free custom **tags**. A persistent active-vehicle switcher remembers the last-used vehicle (feeds cross-module scoping).

**Acceptance criteria**
- [ ] All six lifecycle states settable with `status_changed_at`; sold/scrapped/etc. capture disposal close-out fields where applicable.
- [ ] Non-active vehicles are excluded from active stats/averages queries but remain fully readable and exportable.
- [ ] Restore returns an archived vehicle; permanent delete confirms explicitly and tombstones/cascades children.
- [ ] Garage supports search (script-normalized/digit-folded), sort, filter, manual custom order, and a single pinned `is_default`.
- [ ] Groups and free custom tags apply and filter; a vehicle can carry multiple tags.
- [ ] Active-vehicle switcher persists the last-used selection across app restarts.

**Size:** M · **Depends on:** M2-T1 · **Governing docs:** 01-vehicles-garage.md (lifecycle, groups/tags), data-model.md (status fields), multi-vehicle scoping cross-cut.

### M2-T6 · PULSE garage & vehicle screens

**Description.** Implement the Garage room (Rooms nav: Cockpit / Garage / Pit-lane) as a set of per-vehicle **Vital Cards** — no raw list on home — each surfacing key status + next actions with **scoped emotional-temperature** (ache only on the card needing care) and capped ambient halo. Build the per-vehicle **summary card** and the A4 vehicle-profile "car-as-body" screen: identity, specs, cover photo (via the attachments pipeline), photo gallery, and **estimated-odometer display** derived from `avg_daily_distance` × days-since-last-reading with an explicit "estimated" marker. Status is **always redundantly encoded** (icon + label + shape + position), never color alone.

**Acceptance criteria**
- [ ] Garage room renders per-vehicle Vital Cards using PULSE tokens/components; emotional-temperature is scoped to the card that needs care with the ambient halo capped.
- [ ] Vehicle profile screen follows the A4 blueprint; cover photo and gallery use the shared attachments pipeline (compressed + thumbnailed, app-private).
- [ ] Estimated-current-odometer is shown when no fresh reading exists, computed as `last_actual + avg_daily_distance × days_since`, clearly flagged as estimated.
- [ ] Every status/lifecycle indicator carries icon + text label + shape/position, not color alone (redundant-encoding contract).
- [ ] Screens reflow correctly under dynamic type and have Semantics labels on custom cards/charts/stat tiles.

**Size:** M · **Depends on:** F3, M2-T1, M2-T4, M2-T5 · **Governing docs:** 03-screens.md (A2 home, A4 profile), 02-components.md (Vital Card, Rooms nav, chart primitives), 01-vehicles-garage.md (estimated odometer), 04-motion-rtl-accessibility.

### M2-T7 · i18n strings & plate/VIN LTR isolation

**Description.** Externalize every user-facing string in this module to ARB via gen-l10n across en/de/fr (LTR) and fa/ar/ckb (RTL). Ensure full RTL layout mirroring of garage/profile screens while keeping structural identifiers — **VIN, license plate, paint code, tire-position labels** — LTR via bidi isolation. Render numeric/value fields in the active numeral system (Latin / Eastern-Arabic / Persian / Devanagari) with correct grouping (incl. Indian lakh/crore). Purchase/registration/valuation dates entered and displayed in the user's calendar (Gregorian / Jalali / Hijri / Hebrew) while stored as canonical ISO; date-only records kept as local calendar dates to avoid timezone off-by-one.

**Acceptance criteria**
- [ ] No hardcoded user-facing strings remain; all resolve through ARB with keys for all six locales.
- [ ] VIN, plate, and paint code render LTR (bidi-isolated) inside RTL text; wheel/axle diagrams mirror while position labels stay accurate.
- [ ] Numeric fields render in the active numeral system with correct grouping; date fields honor the active calendar and store canonical ISO.
- [ ] RTL screens mirror layout and traversal/focus order; pseudolocale/RTL smoke check passes.

**Size:** S · **Depends on:** F4, M2-T2, M2-T6 · **Governing docs:** 06-i18n-rtl-calendars.md, 01-vehicles-garage.md (Localization & RTL), 04-motion-rtl-accessibility.

### M2-T8 · Export/backup mapping

**Description.** Map the `Vehicle` and `OdometerReading` entities (plus child tables: plate/valuation/SoH history, and cluster-swap offsets) into the F6 export/backup subsystem: per-entity CSV (`vehicles.csv`, `odometer_readings.csv`, linked child CSVs keyed by `vehicle_id`) and the combined JSON/ZIP backup, with cover photo / gallery / owner's-manual attachments bundled and re-linked via `linked_entity` + `sha256`. CSV values written in the vehicle's display units/currency/calendar with canonical value+unit recoverable (lossless re-import). Restore is merge-aware by UUID; `dedupe_key = vehicle_id + odometer + date` keeps re-imported readings idempotent; tombstones honored.

**Acceptance criteria**
- [ ] `vehicles.csv` + `odometer_readings.csv` + linked child CSVs export one row per record; nested logs export as child CSVs keyed by parent UUID.
- [ ] Combined JSON/ZIP backup includes every vehicle profile, the full reading ledger (corrections + cluster offsets), plate/valuation history, factory specs, and all attachments re-linked by `linked_entity` + `sha256`.
- [ ] CSV shows display units/currency/calendar while preserving canonical value + unit; a round-trip export→import is lossless.
- [ ] Restore reconciles by UUID, is idempotent under `dedupe_key`, resolves conflicts last-write-wins by `updated_at`, and honors tombstones.

**Size:** S · **Depends on:** F6, M2-T1, M2-T4 · **Governing docs:** data-model.md (export/import & backup mapping), 01-vehicles-garage.md (Offline & data), 18-data-offline-backup.

### M2-T9 · Tests

**Description.** Layered tests per the diamond-topped pyramid. Exhaustive table-driven pure-Dart unit tests for the VIN check-digit (ISO 3779 mod-11) and WMI/year decode, ledger **monotonicity/regression/rollover/cluster-offset** math, `avg_daily_distance` and `estimated_odometer_today` projection (incl. insufficient-data fallback), and per-vehicle unit/currency override resolution. Repository integration tests over an in-memory encrypted Drift DB (CRUD, precedence, soft-delete/tombstone, migration from baseline). Widget tests for the adaptive form (field visibility per powertrain, autosave-draft survival) and the ledger anomaly-override flow. RTL/pseudolocale and Semantics/a11y checks on garage + profile screens. Golden coverage of the redundant status encoding.

**Acceptance criteria**
- [ ] VIN checksum + WMI/year decode covered by exhaustive table-driven cases including known-good and known-bad VINs.
- [ ] Ledger tests cover monotonic advance, regression override, rollover, cluster-swap offset continuity, and backdated ordering.
- [ ] Projection tests cover `avg_daily_distance`, `estimated_odometer_today`, and the min-samples/insufficient-data fallback.
- [ ] Repository tests cover CRUD, override precedence, soft-delete/tombstone, and baseline→M2 migration on an encrypted in-memory DB.
- [ ] Adaptive-form widget tests assert field visibility per powertrain and draft autosave survival; ledger widget test asserts anomaly warn + override.
- [ ] RTL/pseudolocale render check and Semantics/a11y assertions pass for garage and profile screens.

**Size:** M · **Depends on:** M2-T1..T8 · **Governing docs:** 11-testing (strategy), 01-vehicles-garage.md (formulas/edge cases), 15-accessibility-dynamic-type.

## Definition of Done

- **Functionality:** Unlimited account-free garage with powertrain-adaptive profiles, all six lifecycle states, VIN capture + offline ISO 3779/WMI/year decode, per-vehicle unit/currency overrides, and the audited odometer/engine-hour ledger (manual, correction, cluster-swap, rollover, anomaly override) all working fully offline over the M1 shared ledger. Active-vehicle switcher persists for cross-module scoping.
- **Built-in-first:** No new runtime third-party dependency beyond the sanctioned set; VIN decode, projection math, and CSV are pure Dart; state via DB streams + `ValueNotifier`/Riverpod providers; charts (if any) via CustomPainter.
- **Tests:** Pure-Dart engines (VIN, ledger math, projection, override precedence) at exhaustive table-driven coverage; repository, adaptive-form, and ledger-anomaly widget/integration tests green; `flutter analyze` + `dart format --set-exit-if-changed` clean.
- **i18n complete:** All user-facing strings externalized to ARB for en/de/fr/fa/ar/ckb; numerals/calendars honored; no hardcoded strings.
- **RTL verified:** Garage and profile screens mirror layout and traversal order; VIN/plate/paint-code stay LTR via bidi isolation; RTL/pseudolocale check passes.
- **Backup/export:** `Vehicle` + `OdometerReading` (and child tables + attachments) round-trip losslessly through per-entity CSV and the combined JSON/ZIP backup; merge-aware restore is idempotent and tombstone-honoring.
- **Accessible:** Every status/lifecycle indicator is redundantly encoded (icon + label + shape + position), never color alone; custom cards/charts/stat tiles carry Semantics labels; screens reflow under dynamic type; minimum touch targets met.
