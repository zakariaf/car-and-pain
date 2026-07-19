# Forward-only migrations & the pre-migration snapshot

Detail for evolving the schema safely. The contract: **forward-only,
transactional, snapshot-guarded, append-only.** SQLite has no true
down-migration, so we do not pretend to offer one — "rollback" means restoring a
pre-migration file-copy snapshot.

## The migration strategy

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    final snapshot = await SnapshotGuard.take(dbFile); // MANDATORY, before touching data
    try {
      await m.runMigrationSteps(from: from, to: to, steps: migrationSteps); // stepByStep()
    } catch (_) {
      await SnapshotGuard.restore(snapshot); // "rollback" == restore the snapshot
      rethrow;
    }
  },
);
```

Rules:
- **The snapshot is mandatory and taken BEFORE any data is touched.** No
  migration path may skip it. On any throw, restore the snapshot and rethrow — a
  half-migrated DB must never be left in place.
- **Append-only steps.** Never edit a shipped migration step — it corrupts data
  for users who skip versions. Add a new step and bump `schemaVersion`.
- **Forward-only.** No "down" migration exists. Removing a column is a new
  forward step, not a reversal.
- The DB carries `schema_version`; backups additionally carry
  `backup_format_version` and `min_supported_version` so an older build refuses
  (rather than corrupts) a newer archive.

## Generating snapshots and step scaffolds

```bash
dart run drift_dev make-migrations
```

This generates the versioned schema snapshots under `migrations/schema/` and the
`.steps.dart` scaffold. Regenerate other codegen at the workspace root with
`dart run build_runner build --delete-conflicting-outputs` (see the
`monorepo-codegen-toolchain` skill). The **manual apply / run step** is covered
by the `run-migration` skill.

## SnapshotGuard

`SnapshotGuard.take` file-copies the quiesced DB to a scratch path before the
migration; `SnapshotGuard.restore` copies it back on failure. Because the copy
happens with no migration transaction open (before `runMigrationSteps`), a plain
file copy is safe here — this is distinct from the backup path, which must use
`VACUUM INTO` because the live DB may have pending WAL writes.

## Migration test matrix (blocking)

Run on a **realistically large seeded DB**:

| Case | Assertion |
|---|---|
| Every `from → to` path | data preserved (including multi-version jumps `v1→v4`) |
| Forced mid-migration throw | pre-migration snapshot is restored; DB equals pre-state |
| Index presence after migrate | `EXPLAIN QUERY PLAN` still uses the intended index |
| New non-null column | back-fill/default applied for existing rows |
| Renamed/dropped column | forward step maps old data; no silent loss |

Drive all clock-dependent logic with an injected `Clock` (`package:clock`).

## Restore-time migration

Restoring an older backup maps deprecated/renamed fields forward to the current
schema; restoring a **newer**-format backup onto an older app is **refused
safely** (checked against `min_supported_version`) rather than corrupting data.
Every restore, migration, and peer-to-peer merge is preceded by an automatic
snapshot.

## Pitfalls

- **Editing a shipped step** — corrupts data for version-skippers. Append-only,
  always.
- **Skipping the snapshot** — a failed migration then leaves an unrecoverable
  broken DB. The snapshot is the only "rollback".
- **Assuming a down-migration exists** — it does not. Model every change as a
  forward step.
- **Forgetting to bump `schemaVersion`** — the new step never runs.
