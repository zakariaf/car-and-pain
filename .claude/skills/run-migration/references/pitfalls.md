# Migration pitfalls (the failure modes that silently destroy data)

Car and Pain has **no server, no cloud, no account** — there is no re-sync path.
A bad migration on the encrypted DB permanently destroys records that exist
nowhere else. Each pitfall below is a way user data disappears silently; the
migration test suite is the guard.

## Editing a shipped migration step

Editing a released `fromN toN+1` branch corrupts data for every user who upgrades
across it (skips versions). **Always append a new step and bump `schemaVersion`**,
even to fix a bug in a prior step. The multi-version-jump migration test
(`3 → 7`) exists to catch a rewritten history.

## Attempting a down migration

SQLite has no true down-migration. A hand-rolled "down" runs untested reverse
DDL on real data. The **only** rollback is `SnapshotGuard.restore`. Never add an
`onDowngrade` data transform.

## Running a step before the snapshot exists

If any step runs before `SnapshotGuard.take(dbFile)`, a failure leaves a
half-migrated DB with no recovery point. The snapshot MUST be the first statement
in `onUpgrade`. The forced-mid-migration-throw test asserts the snapshot restores
the prior state atomically — keep it green.

## Raw copy of a live WAL-mode DB as the "snapshot"

A WAL-mode SQLite file copied while `-wal`/`-shm` sidecars hold pending writes is
**corrupt and unrestorable**. `SnapshotGuard.take` must produce a self-contained
copy (checkpoint first). This is the same latent bug that dooms backups — see the
backup subsystem's `wal_checkpoint(TRUNCATE)` → `VACUUM INTO` rule.

## Forgetting to bump schemaVersion or regenerate the schema snapshot

If `schemaVersion` is not bumped, `onUpgrade` never fires and the new step is dead
code — the DB and generated code drift apart. If `drift_dev make-migrations` is
not run (or its `migrations/schema/` output not committed), the schema-verification
test has nothing to diff against. Bump, scaffold, commit the snapshot.

## Not regenerating codegen after the table edit

`app_database.g.dart` / `*.drift.dart` are gitignored and regenerated. After
editing a table or bumping `schemaVersion`, run
`dart run build_runner build --delete-conflicting-outputs` (the `run-codegen`
skill) or the analyzer emits misleading "missing part file" / undefined-class
errors on the new columns.

## Non-canonical column types

Adding a float-money column, a display-string, a localized/native-numeral, or a
wall-clock-as-instant column breaks canonical-storage invariance and TCO/economy
math. Money is integer minor units keyed to the ISO-4217 exponent; distance is
whole metres; volume millilitres; engine time whole minutes; instants UTC epoch
millis. The canonical-invariance test asserts rows stay byte-identical across
unit/currency/calendar/numeral switches.

## Autoincrement PK on a new table

Autoincrement collides across export/re-import and multi-device creation. Always
UUIDv7 text PK via the `AuditColumns` mixin.

## Skipping the ledger/rollup recompute on a rollup-shape change

Rollups are pre-aggregated and revision-keyed; if a migration changes their shape
without recomputing from the ledger in the same step, TCO/statistics silently
show stale numbers. Recompute the affected (vehicle, period) slices in the step
and assert it in a test.

## Trusting a green analyzer instead of the migration suite

`flutter analyze` cannot see data loss. A migration is only safe once the
all-paths-preserve-data test, the multi-version-jump test, the forced-throw
snapshot-restore test, and the schema-verification test are all green. Never
commit or ship on the analyzer alone.
