# Migration workflow checklist

Copy/paste checklist for shipping one Drift schema change in `packages/data`.
Run every command from the repo root unless noted. Do the steps in order.

## Before you start

- [ ] Confirm the change is genuinely a schema change (new/altered table, column,
      index, ledger, or rollup). Pure query/DAO edits need no migration.
- [ ] Read the table conventions in the `drift-sqlcipher-data-layer` skill:
      `AuditColumns` mixin, UUIDv7 text PK, canonical SI/UTC/ISO-4217 columns,
      the index plan, and ledger/rollup transactional coupling.

## Apply

1. [ ] Edit the table under `packages/data/lib/src/db/tables/*.dart`
       (new tables MUST use `AuditColumns`; new columns are canonical-typed).
2. [ ] Bump `schemaVersion` by **exactly one** in
       `packages/data/lib/src/db/app_database.dart`.
3. [ ] Scaffold the versioned schema export + step stub:
       ```bash
       dart run drift_dev make-migrations
       ```
4. [ ] Add a **new** `fromN toN+1` branch in
       `packages/data/lib/src/db/migrations/steps.dart`.
       Never edit a shipped branch.
5. [ ] Confirm the snapshot guard is intact in `app_database.dart`
       (`SnapshotGuard.take` first, `runMigrationSteps` in try, `restore` on catch).
6. [ ] Regenerate codegen (invoke `run-codegen` / `melos run gen`):
       ```bash
       dart run build_runner build --delete-conflicting-outputs
       ```

## Verify (blocking)

7. [ ] Run the migration suite:
       ```bash
       cd packages/data && dart test test/db/migration/
       ```
8. [ ] Confirm all `from to` paths (incl. multi-version jumps) pass on the
       large seeded DB.
9. [ ] Confirm the forced mid-migration throw restores the pre-migration snapshot.
10. [ ] Confirm the live schema matches the committed exported snapshot.
11. [ ] Confirm canonical-storage invariance tests still pass.

## Pre-commit gate

12. [ ] `melos run analyze` clean, `melos run format` applied.
13. [ ] Commit together in ONE commit:
        - the table change,
        - the bumped `schemaVersion`,
        - the new `migrations/steps.dart` branch,
        - the generated `migrations/schema/` snapshot for the new version,
        - the migration tests.
14. [ ] Never `git add -f` generated `*.g.dart` / `*.drift.dart` — those are
        gitignored and regenerated. The committed schema snapshot JSON under
        `migrations/schema/` IS committed.

## Hard stops

- Do NOT ship if any migration test is red — a green analyzer is not sufficient.
- Do NOT edit a previously shipped step to "fix" it — add a new step + bump.
- Do NOT add a down migration — restore-from-snapshot is the only rollback.
