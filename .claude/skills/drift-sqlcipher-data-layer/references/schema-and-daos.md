# Schema, DAOs & the index plan

Detail for defining and evolving the source of truth: tables, the shared ledger,
rollups, DAOs, and the index/query-plan strategy. Read alongside the canonical
data model (`docs/reference/data-model.md`).

## The audit-column mixin — every table

Every table mixes in `AuditColumns`. Never redefine these per table; never add a
table without it.

```dart
mixin AuditColumns on Table {
  TextColumn get id => text()();                       // UUIDv7 — time-ordered, merge-safe
  IntColumn  get createdAt => integer()();             // UTC epoch millis, set once
  IntColumn  get updatedAt => integer()();             // bumped on every write (LWW tiebreaker)
  IntColumn  get rowRevision => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn  get deletedAt => integer().nullable()();  // Trash / Undo
  @override
  Set<Column> get primaryKey => {id};
}
```

Rules:
- **UUIDv7 text PK** (`uuid` package), never `autoIncrement()`. Collision-free
  multi-device creation, stable identity across export/re-import.
- `created_at` preserves true entry order independent of any user-typed
  backdated `date` field. `updated_at` is the last-write-wins merge tiebreaker.
- A single write wrapper stamps `updated_at` and increments `row_revision` on
  **every** mutation — do not stamp ad-hoc in each DAO method.
- **Every read filters `is_deleted = 0`**, analytics included, via the shared
  base-query helper. Deletes are soft (set `is_deleted`, `deleted_at`), moving
  the row to user-facing trash until `trash_expires_at`.

## Column type discipline (canonical storage)

| Concept | Column | Canonical unit | Never store |
|---|---|---|---|
| Distance / odometer | `IntColumn` | whole metres | km, miles, floats |
| Volume | `IntColumn` | millilitres | litres, gallons |
| Engine time | `IntColumn` | whole minutes | hours, floats |
| Money amount | `IntColumn` | integer minor units + ISO-4217 code column | `REAL`/`double`, a `TOMAN` code, formatted strings |
| FX rate | `TextColumn` | exact `Decimal` string + `asOf` date | a float rate |
| Instant | `IntColumn` | UTC epoch millis | local time, ISO strings, wall-clock |
| Wall-clock schedule | store distinctly from instants | — | conflating the two |

Money is `int minorUnits` + a separate ISO code column; minor-units-per-major
comes from the currency's real ISO-4217 exponent (`0` IRR/JPY/VND, `2` most, `3`
KWD/BHD/OMR) — never a hardcoded `* 100`. IRR is canonical; Toman is a display
view (×10 in / ÷10 out), never a stored currency. See `14-money-currency-fx.md`.

## The shared odometer_readings ledger

One monotonic per-vehicle ledger, written by ~6 modules
(fuel/service/expense/trip/tire/manual) and read by even more
(reminders/statistics/tires/warranties/financing). Columns carry
`(vehicle_id, reading_metres | engine_minutes, taken_at, source_type,
source_record_id, cumulative_offset, is_regression_override)`.
`lifetime_distance = value + cumulative_offset` handles cluster-swap / rollover.

- **Parent + ledger row in one transaction** — never insert separately (see
  `examples/transactional_write.dart`). The same transaction bumps the affected
  rollup.
- A historical edit triggers a **bounded, explicitly-modeled recompute-and-
  reconcile cascade** over the affected window (economy between fills,
  projections, pending reminders) — never a full-history recompute on the UI
  thread.

## Rollup tables (revision-keyed)

TCO/economy/statistics read from **pre-aggregated rollup tables** (per vehicle,
per period, stamped with a revision counter) rather than scanning years of ledger
rows. Recompute runs via `Isolate.run` keyed off the revision counter and only
over the affected slice. Rollups are updated **in the same transaction** as the
ledger write that invalidates them.

## Attachments — content-addressed, encrypted, refcounted

Bytes never live in SQLite (bloats the DB, slows every checkpoint, defeats
space-aware backups). Only metadata rows:

```dart
class Attachments extends Table with AuditColumns {
  TextColumn get sha256 => text()();               // hash of PLAINTEXT (dedupe key)
  TextColumn get relativePath => text()();         // ciphertext blob path, app-private
  TextColumn get mimeType => text()();
  TextColumn get linkedEntityType => text()();     // polymorphic parent type
  TextColumn get linkedEntityId => text()();        // polymorphic parent id
  IntColumn  get refCount => integer().withDefault(const Constant(1))();
}
```

Hash the **plaintext** (enables dedupe) but persist each file as **per-file
AES-GCM ciphertext** on disk. Deleting an owner decrements `ref_count`; a
refcount GC sweep deletes the ciphertext only when `ref_count` reaches 0 (a
shared receipt attached to two records is never orphaned prematurely).

## DAOs — one @DriftAccessor per feature

- One `@DriftDatabase` with per-feature `@DriftAccessor` DAOs (`vehicles_dao`,
  `ledger_dao`, `fuel_dao`, …). DAOs hold table queries; **repositories** hold
  cross-table transactions and domain mapping.
- Fast logic tests use `NativeDatabase.memory()` (no encryption needed for pure
  logic). One separate keyed suite proves encryption is real.

## The index & query-plan strategy

Index the real access patterns, then **prove it with `EXPLAIN QUERY PLAN` in a
test** — a test asserts the intended index is used.

```sql
-- Ledger + analytics: nearly every read is "this vehicle, ordered by time".
CREATE INDEX idx_odo_vehicle_time   ON odometer_readings (vehicle_id, taken_at);
CREATE INDEX idx_fuel_vehicle_time  ON fuel_entries      (vehicle_id, filled_at);
CREATE INDEX idx_expense_vehicle_t  ON expenses          (vehicle_id, spent_at);
-- Rollup lookups are keyed by (vehicle, period).
CREATE INDEX idx_rollup_vehicle_per ON rollups           (vehicle_id, period_key);
-- Attachment GC + relink by content hash and owner.
CREATE INDEX idx_attach_sha         ON attachments       (sha256);
CREATE INDEX idx_attach_owner       ON attachments       (linked_entity_type, linked_entity_id);
-- Soft-delete filters ride on a partial predicate where the engine supports it.
```

- Compose the index key to match the `WHERE` + `ORDER BY` of the hot query
  (leading `vehicle_id`, then the time column) so the index serves both filter
  and sort.
- History screens use **keyset (seek) pagination** —
  `WHERE taken_at < :cursor ORDER BY taken_at DESC LIMIT n` — never `OFFSET`.
- When adding a new join-heavy query, add its index in the same change and add
  the `EXPLAIN QUERY PLAN` assertion.

## Edge cases

- **Regression / rollover** — a lower-than-previous reading needs
  `is_regression_override` or a `cumulative_offset`; never silently accept a
  ledger regression.
- **Dual-tank / bi-fuel** — per-fill `tank_number` and secondary fuel type are
  distinct columns; do not collapse them.
- **Partial fills** — `is_full_tank` / `is_partial` / `is_missed_previous` flags
  drive the economy state machine and MUST survive export/import (asserted in the
  round-trip test).
