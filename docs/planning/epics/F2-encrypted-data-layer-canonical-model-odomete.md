# F2 · Encrypted data layer, canonical model & odometer ledger

> Build the Drift-over-encrypted-SQLite foundation that every feature reads and writes through, enforcing the canonical contract (SI units, ISO-4217 minor-unit money, UTC instants, the shared odometer ledger) at every repository boundary.

## Goal

Stand up the persistence backbone for Car and Pain: an AES-256 whole-database encrypted SQLite store opened through Drift and keyed with a raw 64-hex SQLCipher PRAGMA key. On top of it, establish the **canonical storage contract** that keeps the app honest across 25+ feature modules, five locales, and full round-trip export/import:

- **Canonical units** — all measures persisted in one SI base unit (metres, litres, kPa, kelvin, joules), converted only at display and export time, with per-record → per-vehicle → global precedence.
- **Canonical money** — integer minor units keyed to each currency's real ISO-4217 exponent plus the ISO code and a stored dated FX rate; never a float, never a hardcoded two decimals; explicit Iranian Rial/Toman handling.
- **The shared odometer / engine-hour ledger** — a single monotonic per-vehicle reading timeline written by fuel, service, expense, trip, tire, and manual entries and read by reminders, stats, tires, warranties, and financing, with source tagging, cluster-swap offsets, and rollover/regression validation.
- **Forward-only migrations** guarded by a pre-migration snapshot, **soft-delete / trash** tombstones with restore and scheduled purge, the **shared custom taxonomy** (categories, tags, cost-centres), a **data-integrity validation layer** that warns-with-override, **pre-aggregated rollup tables** for scale, and a **base repository** that enforces the contract and exposes reactive Drift `.watch()` streams.

This epic is pure foundation: it ships no end-user feature screens beyond the user-facing Trash, but it is the single source of truth that F1's scaffold hands off to and that every MVP and later-tier module builds on. Getting the canonical contract, the ledger math, and the migration/trash safety net right here is what prevents rounding drift, gallon/litre confusion, silent data loss, and un-migratable schemas downstream.

## Tier & dependencies

- **Tier:** foundation
- **Depends on:** F1 (project scaffold, pub workspace, tooling, CI, flavors, opened-DB / secure-key-store / app-dirs root providers)

## References

- [docs/flutter/03-data-persistence.md](../../flutter/03-data-persistence.md) — Drift + encrypted SQLite, schema, migrations
- [docs/flutter/14-money-currency-fx.md](../../flutter/14-money-currency-fx.md) — money as ISO-4217 minor units, FX, IRR/Toman
- [docs/flutter/08-error-handling.md](../../flutter/08-error-handling.md) — sealed `Result<T,F>` / `Failure` hierarchy, `ValidationFailure`
- [docs/features/01-vehicles-garage.md](../../features/01-vehicles-garage.md) — vehicles hub and the odometer/engine-hour ledger
- [docs/features/18-data-offline-backup.md](../../features/18-data-offline-backup.md) — backup/export/import coverage of every entity
- [docs/reference/data-model.md](../../reference/data-model.md) — canonical entity/table definitions
- [docs/reference/glossary.md](../../reference/glossary.md) — canonical terms (minor units, ledger, tombstone, rollup)

## Tasks

### F2-T1 · Drift schema & encrypted DB open

**Description.** Define the hub-and-spoke Drift schema: a central `vehicles` hub with spoke tables (fuel, service, expense, trip, tire, document, reminder, ledger, taxonomy, rollups) referencing it. Every table gets a **UUID (v7/v4) text primary key** and the **universal audit columns**: `created_at`, `updated_at` (UTC epoch millis), `is_deleted`, `deleted_at`, `trash_expires_at`, and a `source`/origin tag where applicable — schema shaped so household P2P sync (UUID + tombstone + `updated_at`) is possible later without migration. Open the database through `sqlcipher_flutter_libs` (SQLCipher default per the week-1 spike decision), setting the raw **64-hex `PRAGMA key`** from the F1-provided secure key store before any query, with WAL mode enabled and foreign keys on.

**Acceptance criteria**
- [ ] Drift tables defined for the hub and all foundation spokes with UUID text PKs and the full universal audit-column set.
- [ ] DB opens via `sqlcipher_flutter_libs` with a raw 64-hex `PRAGMA key`; a wrong/absent key fails closed with a typed `DbFailure`, never a plaintext read.
- [ ] `PRAGMA cipher_version` / a round-trip write-read test proves the file on disk is encrypted (not readable by plain sqlite3).
- [ ] WAL mode and `PRAGMA foreign_keys = ON` are set on every connection open.
- [ ] Key is injected from F1's async-initialized secure-key-store root provider; no key material is hardcoded or logged.
- [ ] Generated Drift code builds clean under `dart run build_runner` and `flutter analyze`.

**Size:** L · **Depends on:** F1 · **Governing docs:** flutter/03-data-persistence, reference/data-model

### F2-T2 · Canonical units engine

**Description.** A pure-Dart units engine storing every measure in its SI base unit (distance = metres, volume = litres, pressure = kPa, temperature = kelvin, energy = joules) and converting only at display and export. Resolve the active unit via **per-record → per-vehicle → global** precedence, covering the ambiguous cases (US vs UK gallon, mi vs km, psi/bar/kPa, °C/°F, kWh/MJ). No storage-time conversion ever happens; the boundary contract rejects non-canonical writes.

**Acceptance criteria**
- [ ] Base-unit constants and bidirectional converters for distance, volume, pressure, temperature, and energy, with US-gallon vs UK-gallon disambiguated.
- [ ] Precedence resolver returns per-record override, else per-vehicle, else global default.
- [ ] Round-trip (store → display → parse-back) is lossless within a defined tolerance; no accumulated rounding drift across conversions.
- [ ] Conversions are pure functions with zero DB/I/O dependencies (unit-testable in isolation).
- [ ] Repository boundary rejects any attempt to persist a non-canonical unit.

**Size:** M · **Depends on:** F2-T1 · **Governing docs:** flutter/03-data-persistence, reference/glossary

### F2-T3 · Money & FX model

**Description.** Model money as an integer **minor-unit** amount keyed to each currency's real **ISO-4217 exponent** (0 for IRR/JPY, 2 for USD/EUR, 3 for KWD/BHD/OMR) plus the ISO currency code, never a float and never a hardcoded two decimals. Persist an optional **dated FX rate** with each cross-currency amount for offline, user-entered rates. Handle the Iranian Rial explicitly and support **Toman** as a display-only ×10 presentation over IRR (default for Iran, configurable) without changing stored minor units.

**Acceptance criteria**
- [ ] `Money` value type = (int minor units, ISO code); exponent looked up from a real ISO-4217 table, not assumed.
- [ ] Zero-exponent (IRR/JPY) and three-exponent (KWD/BHD/OMR) currencies store and render correctly.
- [ ] Toman is a display transform over stored IRR minor units; stored value is unchanged and round-trips.
- [ ] FX rates are stored dated and user-entered; conversion uses the rate effective at the record's date, offline.
- [ ] Arithmetic (sum, split, allocate) is integer-only with defined rounding; no float appears in the money path.

**Size:** M · **Depends on:** F2-T1 · **Governing docs:** flutter/14-money-currency-fx

### F2-T4 · Odometer / engine-hour ledger

**Description.** The shared, auditable per-vehicle reading timeline. Every reading records its value (canonical metres / engine-hours), timestamp, and **source** (fuel, service, expense, trip, tire, manual, import). Enforce **monotonicity** with validation for regression, rollover (cluster wrap at max digits), and duplicates; support **cluster-swap offsets** so a replaced odometer keeps a continuous logical distance. Derive `avg_daily_distance` and `estimated_odometer_today` for reminder projection and stats.

**Acceptance criteria**
- [ ] A single ledger table is the sole writer/reader contract for readings; feature modules append, never store their own odometer.
- [ ] Regression, rollover, and duplicate readings are detected and surfaced as `ValidationFailure` (warn-with-override, not hard block).
- [ ] Cluster-swap offset produces a continuous logical odometer across a physical instrument change.
- [ ] `avg_daily_distance` and `estimated_odometer_today` are derived deterministically from the timeline with an insufficient-data fallback.
- [ ] Source tag is mandatory on every reading and preserved through export/import.
- [ ] Ledger math is pure-Dart and table-driven testable.

**Size:** L · **Depends on:** F2-T1, F2-T2 · **Governing docs:** features/01-vehicles-garage, reference/data-model

### F2-T5 · Migration framework

**Description.** A `schema_version` tracked, **ordered forward-only** migration system (no down-migrations). Each migration is guarded by a **pre-migration snapshot** (safe copy via `VACUUM INTO` after a WAL checkpoint) so a failed migration can be rolled back to the prior file. Include a migration test harness that upgrades a fixture DB from every historical version to head.

**Acceptance criteria**
- [ ] `schema_version` persisted; app refuses to open a DB newer than the binary understands, with a typed failure.
- [ ] Migrations run strictly in order, forward-only; there is no path that mutates schema without bumping the version.
- [ ] A pre-migration snapshot is taken before each run and a failed migration restores from it atomically.
- [ ] Migration tests upgrade a seeded fixture from each prior schema version to head and assert data integrity.
- [ ] Foreign keys and canonical constraints hold after every migration step.

**Size:** M · **Depends on:** F2-T1 · **Governing docs:** flutter/03-data-persistence

### F2-T6 · Soft-delete & trash

**Description.** Non-destructive deletion via `is_deleted` / `deleted_at` / `trash_expires_at` tombstones on every user-facing entity. A shared **trash repository** lists trashed items across modules, supports **restore**, and runs a **scheduled purge** of expired tombstones. All normal repository queries transparently exclude tombstoned rows.

**Acceptance criteria**
- [ ] Delete sets tombstone columns and a retention window; the row is never hard-deleted at delete time.
- [ ] Every default query and `.watch()` stream excludes tombstoned rows unless explicitly querying trash.
- [ ] Trash repository lists, restores (clearing tombstone + restoring references), and reports items across all entity types.
- [ ] Scheduled purge hard-deletes rows past `trash_expires_at`, cascading to orphaned attachments.
- [ ] Tombstones round-trip through backup/export so a restore does not resurrect trashed data.

**Size:** M · **Depends on:** F2-T1 · **Governing docs:** features/18-data-offline-backup, reference/data-model

### F2-T7 · Custom taxonomy tables

**Description.** The shared, fully custom taxonomy underpinning entry, filtering, budgets, and analytics across modules: service types, expense categories, trip categories, tags, and cost-centres/projects — each with **icon, colour, default interval** (where meaningful), and an **analytic bucket mapping** so custom user categories still roll into stable report buckets. Seeded with sensible localized defaults, fully editable.

**Acceptance criteria**
- [ ] Taxonomy tables for categories, tags, and cost-centres with icon, colour, optional default interval, and bucket-mapping columns.
- [ ] User-created categories map to a fixed analytic bucket set so reports remain stable regardless of custom naming.
- [ ] Default taxonomy is seeded and re-seed-safe (idempotent), with label keys resolvable to all locales.
- [ ] Colour is stored as a token/value that the PULSE redundant-encoding rule can pair with icon+label (never colour alone).
- [ ] Deleting a taxonomy row soft-deletes and reassigns/keeps referencing records consistent (no dangling FKs).

**Size:** M · **Depends on:** F2-T1, F2-T6 · **Governing docs:** reference/data-model, reference/glossary

### F2-T8 · Data-integrity validation layer

**Description.** Shared guardrails invoked at the repository boundary: odometer regression / rollover / duplicates, over-capacity fuel volume (vs tank size), outlier economy, out-of-order / backdated entries, and import duplicates. The policy is **warn-with-override**: validation returns a typed `ValidationFailure` (stable code + typed params, never a user string) that the UI can present as a dismissible warning, preserving partial/missed-fill semantics rather than silently rejecting.

**Acceptance criteria**
- [ ] Validators for odometer regression/rollover/duplicate, over-capacity fuel, economy outlier, and backdated/out-of-order entry.
- [ ] Each validator returns a `ValidationFailure` with a stable code and typed params; no user-facing English is embedded in the failure.
- [ ] Warnings are overridable — an overridden write still persists and records that it was overridden.
- [ ] Validation runs at the repository boundary for both interactive entry and import paths.
- [ ] Partial/missed/first-fill and other legitimate edge cases are not misflagged.

**Size:** M · **Depends on:** F2-T4, F2-T9 · **Governing docs:** flutter/08-error-handling, features/01-vehicles-garage

### F2-T9 · Repository boundary contract & streams

**Description.** A base repository that **enforces the canonical contract at the boundary** — SI units in, minor-unit money in, UTC instants in — and returns a sealed `Result<T, Failure>` for every operation. Writes are **transactional**; reads expose Drift `.watch()` wrapped in stream providers (built-in reactive + DB streams, Riverpod stream providers where wiring is heavy) so UI is push-updated. Concrete feature repositories extend it.

**Acceptance criteria**
- [ ] Base repository validates canonical inputs (units/money/time) before any write and rejects non-canonical data with a typed `DbFailure`/`ValidationFailure`.
- [ ] All mutations run inside a Drift transaction; a failure rolls back with no partial write.
- [ ] Reads expose `.watch()` streams wrapped as providers; a write is observably reflected in the corresponding stream.
- [ ] Every public method returns `Result<T, Failure>`; no exceptions leak across the boundary.
- [ ] Tombstone exclusion and canonical enforcement are inherited by all concrete repositories (not re-implemented per feature).

**Size:** M · **Depends on:** F2-T1, F2-T2, F2-T3 · **Governing docs:** flutter/08-error-handling, flutter/03-data-persistence

### F2-T10 · Pre-aggregated rollup tables

**Description.** Per-vehicle / per-period summary tables (e.g. distance, cost, fuel volume, economy per month) fed by the ledger and transactional writes, so dashboards and stats scale without full-table scans. Rollups are kept consistent by **recompute triggers** (DB triggers or repository-side recompute on write) and are fully rebuildable from source records.

**Acceptance criteria**
- [ ] Summary tables keyed by vehicle + period store the aggregates the dashboard/stats layer needs.
- [ ] A write to a source record (or ledger reading) updates the affected rollup rows within the same transaction.
- [ ] Rollups are deterministically rebuildable from scratch and a rebuild matches incremental values exactly.
- [ ] Rollup reads are exposed as `.watch()` streams for push-updated dashboards.
- [ ] Rollups exclude tombstoned rows and honour cluster-swap offsets.

**Size:** M · **Depends on:** F2-T4, F2-T9 · **Governing docs:** reference/data-model, features/18-data-offline-backup

### F2-T11 · Canonical model unit tests

**Description.** Exhaustive, table-driven pure-Dart tests (the diamond-topped pyramid's wide base) for units conversion, money exponents/Toman, FX date resolution, ledger math (monotonicity, rollover, cluster-swap, derived averages), and precedence resolution. Target 100% on the pure engines with explicit edge/fallback cases.

**Acceptance criteria**
- [ ] Table-driven cases cover every unit family incl. US vs UK gallon and each temperature/pressure/energy pair.
- [ ] Money tests cover exponent 0/2/3 currencies, IRR↔Toman display, integer rounding, and dated-FX resolution.
- [ ] Ledger tests cover regression, rollover wrap, cluster-swap continuity, duplicates, and insufficient-data fallback.
- [ ] Precedence resolver tested across all record/vehicle/global override combinations.
- [ ] Pure engines hit 100% line/branch coverage; tests are deterministic and I/O-free.

**Size:** M · **Depends on:** F2-T2, F2-T3, F2-T4 · **Governing docs:** flutter/03-data-persistence, reference/glossary

---

### F2-T12 · Canonical export / import serialization hooks *(added — export/backup slice)*

**Description.** Serialization contract so this data layer participates in the first-class backup/export subsystem from day one: each foundation entity exposes a canonical, versioned JSON/CSV representation (canonical units + minor-unit money + UTC instants, **not** display-converted) and a matching deserializer that re-validates through the F2-T8 layer on import. Attachments/refs re-link on restore. This is the boundary the F-backup epic and household-sync-later build on.

**Acceptance criteria**
- [ ] Every foundation entity (vehicle, ledger, taxonomy, rollups, tombstones) has a versioned to/from-canonical serializer.
- [ ] Export emits canonical base units and minor-unit money with an explicit schema/format version and checksum-friendly stable ordering.
- [ ] Import round-trips losslessly (export → wipe → import equals original) and re-runs integrity validation, flagging duplicates.
- [ ] Tombstones and cluster-swap offsets survive the round-trip; restore does not resurrect trashed data or break ledger continuity.
- [ ] Round-trip is covered by a golden/fixture test.

**Size:** M · **Depends on:** F2-T6, F2-T8, F2-T9 · **Governing docs:** features/18-data-offline-backup, flutter/03-data-persistence

### F2-T13 · Trash PULSE UI + validation/trash i18n *(added — PULSE UI + i18n slice)*

**Description.** The one user-facing surface this epic ships: a **Trash room/screen** built with PULSE tokens and components — list of trashed items grouped by type, restore and purge-now actions, and retention countdown — plus the ARB message keys for every `ValidationFailure` code and every trash/restore string, in all five locales (en/de/fr LTR, fa/ar/ckb RTL). Status (trashed, expiring, restored) is **redundantly encoded** (icon + label + shape/position), never colour alone; numerals and dates render per the active numeral system and calendar.

**Acceptance criteria**
- [ ] Trash screen uses PULSE tokens/components (Garage/Pit-lane room conventions), listing trashed items with restore + purge-now and a retention countdown.
- [ ] Every `ValidationFailure` code maps to a localized message key; no raw code or English string reaches the user.
- [ ] All trash/validation strings exist in en/de/fr/fa/ar/ckb ARB files with ICU plurals where counts appear.
- [ ] RTL verified for fa/ar/ckb: mirrored layout/focus order, bidi-isolated numerals, dates in the active calendar.
- [ ] Status is redundantly encoded (icon + label + shape/position) and screen-reader labels read correctly incl. RTL.

**Size:** M · **Depends on:** F2-T6, F2-T8 · **Governing docs:** features/18-data-offline-backup, reference/glossary

## Definition of Done

- **Tests green:** pure-engine unit suites (units, money, FX, ledger, precedence) at 100%; migration upgrade tests from every prior schema version to head; export/import round-trip golden test; repository transaction/rollback and tombstone-exclusion tests — all passing in CI with `flutter analyze` and `dart format --set-exit-if-changed` clean.
- **Canonical contract enforced:** no non-canonical unit, float money, or non-UTC instant can be persisted; every repository method returns a sealed `Result<T, Failure>`; the DB file on disk is verifiably encrypted.
- **i18n complete:** all validation, trash, and taxonomy-default strings exist in en/de/fr/fa/ar/ckb with ICU plurals; no user-facing English is embedded in `Failure` types.
- **RTL verified:** the Trash surface and any localized strings render mirrored with correct focus/traversal order and bidi-isolated numerals/IDs in fa/ar/ckb.
- **In backup/export:** every foundation entity (incl. tombstones, ledger, taxonomy, rollups) is covered by the versioned canonical serializer and round-trips losslessly; restore honours tombstones and ledger continuity.
- **Accessible:** the Trash UI meets minimum touch targets, exposes screen-reader labels, and encodes all status **redundantly** (icon + label + shape/position) per the PULSE redundant-encoding rule — never colour alone.
- **Safety net proven:** pre-migration and (where applicable) pre-restore snapshots are taken and a simulated failed migration restores cleanly; scheduled trash purge and orphan-attachment cleanup run without data loss.
