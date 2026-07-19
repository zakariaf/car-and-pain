---
name: drift-sqlcipher-data-layer
description: >-
  Governs the Car and Pain on-device data layer in packages/data: the encrypted
  Drift over SQLCipher store, table and @DriftAccessor DAO definitions, the
  shared odometer_readings ledger plus revision-keyed rollups, the index plan,
  UUIDv7 text PKs with audit columns (updated_at, row_revision, soft-delete
  tombstones), repositories mapping rows to core domain models with
  vehicle-scoped .watch streams, forward-only migrations guarded by a mandatory
  pre-migration snapshot, WAL mode, and verified backups via
  wal_checkpoint(TRUNCATE) then VACUUM INTO. PRAGMA key is first, the cipher is
  asserted, and CI proves the raw DB header is never plaintext. Use when editing
  packages/data (app_database.dart, open_connection.dart, tables, daos,
  repositories, migrations, backup); adding a table, DAO, index, or rollup;
  wiring a Drift .watch provider; writing a migration or snapshot guard;
  building or verifying a backup; or debugging plaintext-DB, WAL, or migration
  failures. Pairs with error-handling-never-lose-data.
metadata:
  project: car-and-pain
  area: data-persistence-backup
---

# Drift + SQLCipher Data Layer

Ground rules for the Car and Pain persistence layer. Everything lives in the
`packages/data` package: one shared **encrypted** Drift-over-SQLite store, per
feature `@DriftAccessor` DAOs, repositories that emit `core` **domain models**,
and the verified backup subsystem. The encrypted DB is the single source of
truth — there is no server and no telemetry; everything must rebuild from this
DB alone after process death, reboot, Doze, or restore.

Assume general Flutter/Dart/Drift/Riverpod/SQLite knowledge. What follows is
only what is project-specific and non-negotiable.

## Non-negotiable rules

- **`PRAGMA key` is the FIRST statement on every raw connection; assert the
  cipher before any app query.** Run any query first, or key after open, and you
  silently get an unusable or **plaintext** DB. The key is a random 256-bit
  value (raw 64-hex — no per-open KDF) read from secure storage on the **main
  isolate** and passed into background isolates. After keying, `PRAGMA
  cipher_version` must be non-empty; empty means a stock `sqlite3` won the native
  link — throw, never open. See the canonical snippet below.
- **The DB header is never plaintext, and CI proves it.** A blocking test reads
  the first 16 bytes of the raw DB file and fails the build if they equal
  `SQLite format 3\000`. Ship on the proven **`sqlcipher_flutter_libs`** by
  default; only adopt drift's `sqlite3mc` build-hook path if a blocking week-one
  device spike proves it links and encrypts on real iOS **and** Android. Confirm
  no dependency pulls a plaintext `sqlite3` that wins the link.
  `scripts/verify_encryption.sh` runs these checks.
- **WAL mode always; foreign keys ON.** `PRAGMA journal_mode = WAL` in the open
  setup — WAL/`-shm`/temp side files inherit the cipher. To change the key use
  `PRAGMA rekey`, never a re-encrypt-by-copy.
- **One shared DB, one background isolate.** Per-feature `@DriftAccessor` DAOs
  over one `@DriftDatabase`. Never open the encrypted file from multiple isolates
  concurrently — cipher lock contention. Use `drift_flutter` share-across-isolates
  with one background DB isolate.
- **UUIDv7 text PKs, never autoincrement.** Time-ordered, collision-free
  multi-device creation, stable identity across export/re-import. Every table
  mixes in `AuditColumns` (id, createdAt, updatedAt, rowRevision, isDeleted,
  deletedAt). Stamp `updated_at` and increment `row_revision` on **every** write
  through the single write wrapper.
- **Every read filters `is_deleted = 0` — analytics included.** Route every read
  through the shared base-query helper. Soft-delete moves rows to trash
  (`deleted_at`); never hard-delete on user action.
- **Store canonical values only.** Distance in whole metres, volume in
  millilitres, engine time in whole minutes, money as **integer minor units
  keyed to the ISO-4217 exponent** (never a float / `REAL` / `double`), true
  instants as UTC epoch millis. No display strings, native numerals, or
  localized formats in any column. Convert only at the presentation edge, so
  switching unit/currency/calendar/numeral leaves stored rows byte-identical.
- **Parent row and its ledger row in ONE transaction.** Every fuel/service/
  expense/trip write inserts its own row **and** the `odometer_readings` ledger
  row **and** bumps the affected rollup inside a single `db.transaction`. Never
  insert them separately — the spine must never desync. Pairs with
  `error-handling-never-lose-data`.
- **Scope `.watch()` by vehicle + time window; read rollups.** Never subscribe
  to unscoped app-wide streams, and never recompute full history on the UI
  thread. TCO/analytics read pre-aggregated **revision-keyed rollup tables**;
  heavy recompute runs via `Isolate.run` keyed off the revision counter over
  only the affected slice.
- **Attachment bytes never live in SQLite.** Hash the **plaintext** for the
  content-addressed dedupe key (`sha256`), persist each file as per-file AES-GCM
  ciphertext on disk (app-private), keep only metadata rows with a `ref_count`.
  A refcount GC sweep deletes a blob only when `ref_count` reaches 0.
- **Migrations are forward-only, transactional, and snapshot-guarded.** SQLite
  has no true down-migration; do not pretend. Every `onUpgrade` takes a
  **mandatory pre-migration file-copy snapshot** before touching data and
  restores it on any failure. Migration steps are **append-only** — never edit a
  shipped step; add a new one and bump `schemaVersion`. Generate snapshots with
  `dart run drift_dev make-migrations`. See `run-migration` for the manual apply.
- **Backup is a data-package citizen produced the ONLY correct way.** Never
  `File.copy` a live WAL-mode DB — the `-wal`/`-shm` sidecars make the copy
  corrupt and unrestorable. Produce every backup (including silent auto-backups)
  via `wal_checkpoint(TRUNCATE)` then `VACUUM INTO` a temp path, encrypt the
  archive, write to a temp file, **atomically rename** after `flush: true`, and
  **verify by re-opening** (`PRAGMA integrity_check` + manifest row-count /
  attachment SHA-256 match) before reporting success. A backup that was not
  verified did not succeed.
- **`data` has zero network dependencies by construction.** No telemetry, no
  network code, ever. Set `NSURLIsExcludedFromBackupKey` on the DB/attachment
  paths so the encrypted store never leaks into an iOS device backup; choose the
  iOS file-protection class deliberately (couples to background re-arm).
- **Use keyset (seek) pagination, never `OFFSET`.** History screens use
  `WHERE taken_at < :cursor ORDER BY taken_at DESC LIMIT n`; `OFFSET` degrades
  badly on large ledgers.

## Canonical snippet — the encrypted open sequence

`PRAGMA key` first, cipher asserted, WAL on. This is the one flow that must never
be reordered.

```dart
LazyDatabase openEncrypted({required String hexKey}) {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'car_and_pain.sqlite'));

    return NativeDatabase.createInBackground(
      file,
      setup: (raw) {
        // 1. KEY FIRST — before any other statement. Raw 64-hex, no per-open KDF.
        raw.execute("PRAGMA key = \"x'$hexKey'\";");

        // 2. ASSERT the cipher is real — empty on a stock sqlite3 => plaintext risk.
        final cipher = raw.select('PRAGMA cipher_version;');
        if (cipher.isEmpty) {
          throw StateError('Encryption library missing — refusing to open plaintext DB');
        }

        // 3. WAL for durable concurrent-read writes (side files inherit the cipher).
        raw.execute('PRAGMA journal_mode = WAL;');
        raw.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}
```

To change the key: `PRAGMA rekey`. Never re-encrypt by copying.

## Folder layout (`packages/data/lib/src/`)

```text
db/        app_database.dart (@DriftDatabase, schemaVersion, MigrationStrategy)
           open_connection.dart (encrypted open: PRAGMA key FIRST, cipher asserted)
           tables/  vehicles, odometer_readings (ledger), fuel_entries,
                    service_records, expenses, reminders, attachments,
                    rollups (revision-keyed), common.dart (AuditColumns mixin)
daos/      one @DriftAccessor per feature (vehicles_dao, ledger_dao, fuel_dao, …)
repositories/  emit core DOMAIN models; single source of truth; expose .watch()
migrations/    schema/ (generated snapshots), steps.dart (stepByStep()),
               snapshot_guard.dart (pre-migration copy + restore-on-failure)
attachments/   hash-plaintext, store AES-GCM ciphertext, refcount GC
backup/        backup_service, vacuum_source, archive_codec, crypto/, recovery/,
               export/ (sanitized CSV), auto_backup/, failures.dart
```

## Workflows

- **Add or evolve a table / DAO / index** → `references/schema-and-daos.md`
  (AuditColumns mixin, ledger + rollup shape, the index plan, EXPLAIN QUERY PLAN
  gate, attachment metadata).
- **Write a migration or snapshot guard** → `references/migrations-and-snapshots.md`
  (forward-only contract, `make-migrations`, SnapshotGuard, append-only steps,
  migration test matrix). Manual apply: the `run-migration` skill.
- **Map rows to domain models / wire a scoped stream provider** →
  `references/repositories-streams.md` (repository boundary, row↔`core` mapping,
  vehicle+window `.watch`, rollup recompute, keyset pagination).
- **Build or verify a backup / export** → `references/backup-export-wal.md`
  (the checkpoint→vacuum→encrypt→rename→verify primitive, WAL rules, CSV
  sanitization + BOM, recovery-key wrap, the flagship round-trip test).

## Scripts

- `scripts/verify_encryption.sh` — greps `open_connection` for `PRAGMA key`
  ordering and the cipher assertion, checks for a banned `File.copy` backup path,
  asserts the header CI test exists, and (if a built DB is present) reads its
  first 16 bytes to confirm it is NOT `SQLite format 3`.

## Examples

- `examples/transactional_write.dart` — parent + ledger row + rollup bump in one
  `db.transaction`, stamping `updated_at` / `row_revision`.
- `examples/scoped_watch_repository.dart` — a repository exposing a
  vehicle+window-scoped `.watch` stream mapped to `core` domain models.
