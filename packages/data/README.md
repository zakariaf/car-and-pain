# data

The encrypted data layer — the single owner of the source of truth. Backup reads
across **every** table, so this is a package (never per-feature).

## F1 scope (this epic)

Only the **DI seam** exists yet:

- **Placeholder root providers** (`src/providers.dart`) — `appDatabaseProvider`,
  `secureKeyStoreProvider`, `appDirsProvider`, `appTimeZoneProvider`. Each throws
  `UnimplementedError` until it is **overridden with a real instance in the
  `ProviderScope` at bootstrap**. This is the canonical Riverpod pattern for
  async-constructed infrastructure and doubles as the per-test override seam.
- **Infra ports** (`src/infra/`) — `AppDatabase`, `SecureKeyStore`, `AppDirs`,
  `AppTimeZone`. Placeholders let the shell boot before F2/F7.
- **A sample repository** (`DiagnosticsRepository`) that consumes
  `appDatabaseProvider` purely through DI — the template every real repository
  follows.

## Arriving later

- **F2** — Drift over encrypted SQLite (SQLCipher default), per-feature
  `@DriftAccessor` DAOs, forward-only migrations + pre-migration snapshot, the
  shared odometer/engine-hour ledger + revision-keyed rollups, scoped `.watch()`
  repositories mapping rows → domain models at the boundary.
- **F6/F7/F8** — backup/export engine, secure recoverable key, attachments.

## Rules

- Repositories return `Result<T, F extends Failure>` from `core` and **never**
  leak Drift row/companion classes into ViewModels or widgets.
- Enforce the canonical contract (SI units, ISO-4217 minor-unit money, UTC
  instants) at every repository boundary.
- Import only the barrel `package:data/data.dart`.
