---
name: run-migration
description: >-
  Runs the mandatory, forward-only Drift schema migration workflow for the Car
  and Pain encrypted SQLCipher database in packages/data — the single most
  dangerous deterministic operation in the app, because there is no server and
  no re-sync path, so a bad migration on the at-rest-encrypted DB destroys
  irreplaceable user records permanently. Enforces the exact ordered ritual:
  take the mandatory pre-migration file-copy snapshot BEFORE touching data, bump
  schemaVersion in app_database.dart, scaffold versioned schema snapshots with
  drift_dev make-migrations, write an append-only stepByStep forward step (never
  edit a shipped step, never add a down migration), regenerate with build_runner,
  then verify against the exported schema with the migration test suite
  (every from-to path plus a forced mid-migration throw that restores the
  snapshot). Manual-only side-effecting human workflow. Use when adding or
  altering a Drift table, column, index, or the odometer_readings ledger or
  rollups; bumping schemaVersion; editing app_database.dart, migrations/steps.dart,
  migrations/snapshot_guard.dart, or migrations/schema/; running
  drift_dev make-migrations; or writing migration tests. Pairs with
  drift-sqlcipher-data-layer for schema shape and error-handling-never-lose-data
  for the snapshot and transactional guarantees.
disable-model-invocation: true
license: Proprietary
metadata:
  project: Car and Pain
  domain: data-persistence, drift-migrations, encrypted-sqlite, disaster-recovery
  source-docs: docs/flutter/03-data-persistence.md, docs/flutter/13-backup-export-recovery.md
---

# Run migration (forward-only Drift schema migration)

Apply a schema change to the Car and Pain **encrypted Drift over SQLCipher**
database in `packages/data` by following the exact ordered ritual below. This is
a **manual, low-freedom, human-run** workflow: there is **no account, no cloud,
no server to re-sync from**, so the on-device encrypted DB is the single source
of truth. A migration that drops or corrupts a column silently and permanently
destroys hand-entered fuel, service, and odometer records that exist nowhere
else. Execute the steps in order. Do not improvise, reorder, or skip.

## Non-negotiable rules

- **Take the mandatory pre-migration snapshot FIRST — before touching data.**
  `SnapshotGuard.take(dbFile)` runs at the top of `onUpgrade`, before any step.
  The snapshot is the only "rollback" SQLite has; restore it on any failure.
  Never run a migration step before the snapshot exists.
- **Forward-only. Never write a down migration.** SQLite has no true
  down-migration and we do not pretend to. "Rollback" means `SnapshotGuard.restore`,
  nothing else.
- **Migration steps are append-only. NEVER edit a shipped step.** Editing a
  released step corrupts data for every user who skips versions. Add a **new**
  step and bump `schemaVersion` — even to fix a bug in a prior step.
- **Bump `schemaVersion` by exactly one** in `app_database.dart` for each shipped
  schema change, and add the matching `from → to` step in `migrations/steps.dart`.
- **Regenerate versioned schema snapshots** with `dart run drift_dev make-migrations`
  and **commit** the `migrations/schema/` snapshot for the new version. The
  migration test suite diffs the live schema against these exported snapshots.
- **Every migration runs inside the transactional guard** — the whole
  `runMigrationSteps` is wrapped in try/restore. A partial migration must never
  be left on disk.
- **Store canonical values only** in any new column: distance in whole metres,
  volume in millilitres, engine time in whole minutes, money as integer minor
  units keyed to the ISO-4217 exponent, instants as UTC epoch millis. Never add
  a float-money, display-string, or localized/native-numeral column.
- **New tables use the `AuditColumns` mixin** (UUIDv7 text PK, `created_at`,
  `updated_at`, `row_revision`, `is_deleted`, `deleted_at`) and their reads go
  through the shared `is_deleted = 0` query layer. Never add an autoincrement PK.
- **Migrations do not run alone in the test suite** — they run against a
  **realistically large seeded DB** asserting every `from → to` path (including
  multi-version jumps) preserves data, PLUS a **forced mid-migration throw** that
  must restore the pre-migration snapshot.

## The ordered workflow

Run every command from the repository root (`car-and-pain/`) unless noted.

1. **Design the change** against `drift-sqlcipher-data-layer` conventions
   (table mixin, index plan, ledger/rollup impact). Edit the table under
   `packages/data/lib/src/db/tables/*.dart`.
2. **Bump `schemaVersion`** by one in
   `packages/data/lib/src/db/app_database.dart`.
3. **Scaffold the versioned schema snapshot + step stub:**
   ```bash
   dart run drift_dev make-migrations
   ```
   This writes the new export under `packages/data/lib/src/db/migrations/schema/`
   and scaffolds the `.steps.dart` entry. Commit the generated schema snapshot.
4. **Write the append-only forward step** in
   `packages/data/lib/src/db/migrations/steps.dart` — add a new `from: N, to: N+1`
   branch. Never modify an existing branch.
5. **Regenerate codegen** so `app_database.g.dart` picks up the new version and
   tables (invoke the **`run-codegen`** skill / `melos run gen`):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
6. **Run the migration test suite** (see Verification below). All `from → to`
   paths, multi-version jumps, and the forced-throw restore test must pass.
7. **Analyze & format**, then commit the table change, the bumped
   `schemaVersion`, the new step, the schema snapshot, and the tests together.

## Canonical migration guard

The pre-migration snapshot wraps the whole stepwise run. This is the single
inline snippet; keep the guard and the append-only step list exactly this shape.

```dart
// packages/data/lib/src/db/app_database.dart
@override
int get schemaVersion => 7; // bump by exactly ONE per shipped schema change

@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    // 1. MANDATORY snapshot BEFORE touching data — the only "rollback" SQLite has.
    final snapshot = await SnapshotGuard.take(dbFile);
    try {
      // 2. Forward-only, append-only stepwise migration inside the guard.
      await m.runMigrationSteps(from: from, to: to, steps: migrationSteps);
    } catch (_) {
      // 3. "Rollback" == restore the pre-migration snapshot, then rethrow.
      await SnapshotGuard.restore(snapshot);
      rethrow;
    }
  },
);

// packages/data/lib/src/db/migrations/steps.dart — APPEND a new branch; never edit a shipped one.
final migrationSteps = stepByStep(
  from1To2: (m, schema) async { /* shipped — DO NOT EDIT */ },
  // ...
  from6To7: (m, schema) async {
    await m.addColumn(schema.serviceRecords, schema.serviceRecords.laborMinutes);
  },
);
```

## Verification (blocking, must pass before commit)

Run the data-package migration suite:

```bash
cd packages/data && dart test test/db/migration/
```

The suite must prove:

- **Every `from → to` path preserves data** on a realistically large seeded DB,
  including multi-version jumps (e.g. `3 → 7`).
- **The forced mid-migration throw restores the pre-migration snapshot**
  atomically, leaving the prior schema and rows intact.
- **The live schema matches the committed exported snapshot** for the new version
  (drift's generated schema-verification helper).
- **Canonical-storage invariance** still holds — switching display
  unit/currency/calendar/numeral leaves persisted rows byte-identical.

Never mark a migration done on a green analyzer alone; the migration is only safe
once the snapshot-restore and all-paths tests are green.

## References

- `references/workflow-checklist.md` — the copy/paste step-by-step checklist and
  the pre-commit gate.
- `references/migration-recipes.md` — canonical recipes (add column, add table
  with `AuditColumns`, add index, backfill data, ledger/rollup-touching changes)
  and the append-only step patterns.
- `references/pitfalls.md` — the failure modes that silently destroy data
  (editing a shipped step, keying after open, raw-copy snapshot of a WAL file,
  down-migration attempts, float-money columns) and how the tests catch them.
