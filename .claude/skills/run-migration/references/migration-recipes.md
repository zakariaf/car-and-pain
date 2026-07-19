# Migration recipes

Canonical append-only step patterns for `packages/data/lib/src/db/migrations/steps.dart`.
Every recipe assumes the snapshot guard already wraps `runMigrationSteps` in
`app_database.dart`. Always **add a new `fromN toN+1` branch** — never edit a
shipped one — and bump `schemaVersion` by one.

## 1. Add a nullable column (safest)

```dart
from6To7: (m, schema) async {
  // laborMinutes: whole minutes (canonical engine-time unit), nullable => no backfill.
  await m.addColumn(schema.serviceRecords, schema.serviceRecords.laborMinutes);
},
```

Prefer nullable or defaulted columns. A `NOT NULL` column with no default forces
a rewrite and a backfill (recipe 4).

## 2. Add a table (must use AuditColumns)

Define the table with the `AuditColumns` mixin (UUIDv7 text PK, `created_at`,
`updated_at`, `row_revision`, `is_deleted`, `deleted_at`) in
`tables/*.dart`, register it on `@DriftDatabase`, then create it in the step:

```dart
from7To8: (m, schema) async {
  await m.createTable(schema.tireSets);
  // Reads MUST go through the shared is_deleted = 0 query layer, like every table.
},
```

Never add an autoincrement PK. UUIDv7 text PKs keep identity stable across
export/re-import and multi-device creation.

## 3. Add an index

Index for the real access pattern (`(vehicle_id, <time>)` for ledger/analytics),
then prove it with `EXPLAIN QUERY PLAN` in a test.

```dart
from8To9: (m, schema) async {
  await m.createIndex(schema.idxServiceVehicleTime); // (vehicle_id, performed_at)
},
```

## 4. Add a NOT NULL column with backfill

Add nullable, backfill canonical values in the same step, then rely on app-level
writes to keep it populated. Do heavy backfills in bounded batches — the whole
step is already inside the transactional guard.

```dart
from9To10: (m, schema) async {
  await m.addColumn(schema.fuelEntries, schema.fuelEntries.pricePerLitreMinor);
  // Backfill canonical integer minor units (ISO-4217 exponent), never a float.
  await m.database.customStatement('''
    UPDATE fuel_entries
       SET price_per_litre_minor = CAST(total_cost_minor * 1000 / volume_ml AS INTEGER)
     WHERE price_per_litre_minor IS NULL AND volume_ml > 0;
  ''');
},
```

## 5. Ledger- or rollup-touching change (highest risk)

The `odometer_readings` ledger is written by ~6 modules and read by more, and
rollups are pre-aggregated and revision-keyed. Any change here can desync the
spine. In the step:

- Preserve `(vehicle_id, reading_metres, engine_minutes, taken_at, source_type,
  source_record_id)` semantics; never drop `source_*` linkage.
- If a rollup shape changes, **recompute the affected rollups from the ledger in
  the same step** (bounded per vehicle + period) so rollups never trail the ledger.
- Add a migration test asserting one seeded ledger insert still recomputes only
  the affected slice after the migration, and a historical-edit reconcile still
  fires.

## 6. Rename / drop a column (destructive — last resort)

SQLite cannot truly rename in place cheaply and dropping loses data. Prefer
add-new + backfill + stop-writing-old and leave the old column dormant. If a true
table rebuild is unavoidable, do it as an explicit create-new-table → copy-rows →
drop-old inside the step, and add a `from → to` migration test proving row-level
deep equality of preserved fields on the large seeded DB.

## Append-only reminder

Once a `fromN toN+1` branch ships, it is frozen. To correct a released migration,
add a **new** later step that repairs the state and bump `schemaVersion` again.
Editing the shipped branch corrupts data for users who skip versions.
