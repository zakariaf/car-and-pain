# 🗄️ Local Database, Schema, Indexing & Migrations

> This document governs how Car and Pain stores every byte of user data on-device: the encrypted SQLite database, its schema and indexes, the shared odometer/engine-hour ledger and rollup tables, attachments, and forward-only migrations.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · See also **[Security, Privacy & At-Rest Encryption](./09-security-privacy.md)**, **[Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)**, and the **[Canonical Data Model](../reference/data-model.md)**.

## Decision

Use **Drift over encrypted SQLite** as the single on-device store. Ship on the **proven `sqlcipher_flutter_libs`** (SQLCipher, AES-256, raw 64-hex `PRAGMA key`) as the day-one default; only adopt drift's `sqlite3mc` build-hook path if a **blocking week-one spike** proves it links and encrypts on real iOS **and** Android. Whichever cipher ships, cipher/KDF selection is **explicit and asserted**, `PRAGMA key` is the **first statement** before any query, and a **blocking CI test reads the raw DB-file header and asserts it is NOT `SQLite format 3`**. One shared encrypted DB with per-feature `@DriftAccessor` DAOs; **UUIDv7 text PKs**, `updated_at` + `row_revision` + soft-delete tombstones; an explicit index plan for the join-heavy TCO/analytics queries and the shared ledger; **pre-aggregated rollup tables** updated in the same transaction as the ledger; and **forward-only, transactional migrations** each guarded by a mandatory pre-migration DB-file snapshot.

## Why

The canonical data model is deeply relational: a `vehicle` hub, a shared `odometer_reading` ledger written by ~6 modules and read by more, polymorphic `attachment` rows, and join-heavy TCO/economy/analytics. Every entity maps 1:1 to a table that mirrors the required per-entity CSV export. A NoSQL object store fights that grain. Drift uniquely satisfies the hard constraints together — reactive SQL `.watch()` streams, type-safe codegen, testable migrations, and active sponsored maintenance for a multi-year lifespan.

Alternatives considered and rejected:

- **Isar / isar_community** — NO built-in DB-file encryption (hard fail for a privacy-first app), longevity risk (v3 stable is ~3 years old, v4 perpetual-dev, only a community fork keeps v3 alive), and no ordered/verifiable data-transform migrations. Rejected.
- **ObjectBox** — at-rest encryption needs a **paid/commercial license**, wrong for a buy-once no-subscription product; NoSQL grain also fights SQL analytics. Rejected.
- **sqflite / sqflite_sqlcipher** — it *is* SQLite, but low-level: raw SQL strings, no compile-time type safety, no reactive streams, manual error-prone migrations. Drift runs on the same engine and is strictly better here. Fallback/floor only.
- **Pinning at-rest encryption to `sqlite3mc` build-hooks on day one** — native-assets/build-hooks are still maturing; betting the single most dangerous decision in a data-custody app on an experimental toolchain is rejected. The proven library is the default; the build-hook path must **earn** its place via the device spike.
- **A raw passphrase key instead of a raw hex key** — rejected because a passphrase forces PBKDF2 on every cold start and notification wake. We use a random 256-bit key (raw 64-hex `PRAGMA key`) and wrap it separately for recovery (see [Security, Privacy & At-Rest Encryption](./09-security-privacy.md)).

## How we do it

### Package list (`packages/data/pubspec.yaml`)

```yaml
# Pin every major to VERIFIED current-stable at kickoff — these are illustrative.
dependencies:
  drift:                    # reactive, type-safe SQL
  drift_flutter:            # per-platform open via path_provider; background-isolate sharing
  sqlcipher_flutter_libs:   # DEFAULT cipher. Swap for sqlite3(source: sqlite3mc) only if the spike passes
  uuid:                     # UUIDv7 text PKs
  path_provider:            # app-private DB + attachments dirs
  path:
  crypto:                   # SHA-256 for content-addressed attachments
dev_dependencies:
  drift_dev:
  build_runner:
  test:
```

### Folder layout

```text
packages/data/
  lib/
    src/
      db/
        app_database.dart          # @DriftDatabase, schemaVersion, MigrationStrategy
        app_database.g.dart        # generated
        open_connection.dart       # encrypted open: PRAGMA key FIRST, cipher asserted
        tables/
          vehicles.dart
          odometer_readings.dart   # the shared ledger
          fuel_entries.dart
          service_records.dart
          expenses.dart
          reminders.dart
          attachments.dart
          rollups.dart             # pre-aggregated summary tables (revision-keyed)
          common.dart              # audit-column mixin (UUIDv7, updated_at, row_revision, soft-delete)
      daos/
        vehicles_dao.dart          # @DriftAccessor per feature
        ledger_dao.dart
        fuel_dao.dart
        ...
      repositories/                # emit DOMAIN models; single source of truth; expose .watch()
      migrations/
        schema/                    # generated versioned schema snapshots
        steps.dart                 # stepByStep() forward migrations
        snapshot_guard.dart        # pre-migration file-copy snapshot + restore-on-failure
      attachments/                 # hash-plaintext, store per-file AES-GCM ciphertext, refcount GC
```

### Encrypted open sequence — `PRAGMA key` FIRST, cipher ASSERTED

`PRAGMA key` must be the very first statement on the raw connection. Running any query first, or keying after open, silently yields an unusable or **plaintext** DB. The key is a random 256-bit value fetched from secure storage (raw 64-hex — no per-open KDF), read on the **main isolate** and passed in for background isolates.

```dart
LazyDatabase openEncrypted({required String hexKey}) {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'car_and_pain.sqlite'));

    return NativeDatabase.createInBackground(
      file,
      setup: (raw) {
        // 1. KEY FIRST — before any other statement.
        raw.execute("PRAGMA key = \"x'$hexKey'\";");

        // 2. EXPLICIT cipher/KDF selection (never rely on library defaults).
        //    (SQLCipher: cipher params are compile-time; assert page/kdf if using sqlite3mc.)

        // 3. ASSERT encryption is real — the first query must succeed under the key.
        final cipher = raw.select('PRAGMA cipher_version;'); // empty on stock sqlite3 => misconfig
        if (cipher.isEmpty) {
          throw StateError('Encryption library missing — refusing to open plaintext DB');
        }

        // 4. WAL for durable, concurrent-read writes (WAL/temp files are also encrypted).
        raw.execute('PRAGMA journal_mode = WAL;');
        raw.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}
```

> To change the key, use `PRAGMA rekey`, never a re-encrypt-by-copy. WAL mode is compatible with the cipher and its side files inherit the encryption.

### Audit columns — one mixin, every table

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

Every read — **including analytics** — goes through a base query helper that filters `is_deleted = 0`. A single write wrapper stamps `updated_at` and increments `row_revision` on every mutation so soft-delete, Undo, and future household P2P merge stay consistent.

### The shared odometer/engine-hour ledger + rollups

A single `odometer_readings` ledger carries `(vehicle_id, reading_metres, engine_minutes, taken_at, source_type, source_record_id)`. Each fuel/service/expense/trip write inserts its parent row **and** the ledger row inside **one transaction**, so the spine never desyncs:

```dart
Future<void> addFuelEntry(FuelEntry e) => db.transaction(() async {
  await into(db.fuelEntries).insert(e.toRow());
  await into(db.odometerReadings).insert(e.toLedgerRow());
  await _bumpRollup(e.vehicleId, e.period, revision: e.rowRevision); // same txn
});
```

TCO/economy/statistics read from **pre-aggregated rollup tables** (per vehicle, per period, stamped with a revision counter) rather than scanning years of ledger rows. Drift `.watch()` subscriptions are **scoped by vehicle + time window**; heavy recompute runs via `Isolate.run` keyed off the revision counter and only over the affected slice. A **historical edit** (correcting a past odometer/fuel row) triggers a bounded, explicitly-modeled recompute-and-reconcile cascade over the affected window (economy between fills, projections, pending reminders) — never a full-history recompute on the UI thread.

### Index & query-plan strategy

Index for the real access patterns, then prove it with `EXPLAIN QUERY PLAN` in tests:

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

History screens use **keyset (seek) pagination** — `WHERE taken_at < :cursor ORDER BY taken_at DESC LIMIT n` — not `OFFSET`, which degrades on large ledgers.

### Attachments — content-addressed, encrypted, refcounted

Bytes never live in SQLite (it bloats the DB and slows encryption). Store files app-private, **content-addressed by hashing the PLAINTEXT** (enables dedupe), but persist each file as **per-file AES-GCM ciphertext** on disk. The DB holds only metadata:

```dart
class Attachments extends Table with AuditColumns {
  TextColumn get sha256 => text()();               // hash of PLAINTEXT (dedupe key)
  TextColumn get relativePath => text()();         // ciphertext blob path, app-private
  TextColumn get mimeType => text()();
  TextColumn get linkedEntityType => text()();
  TextColumn get linkedEntityId => text()();
  IntColumn  get refCount => integer().withDefault(const Constant(1))();
}
```

Deleting an owner decrements `ref_count`; a **reference-counting GC** sweep deletes the ciphertext blob only when `ref_count` reaches 0, so a shared receipt attached to two records is never orphaned prematurely.

### Forward-only transactional migrations

SQLite has no true down-migration, so we do not pretend to. Migrations are **forward-only and transactional**; each is guarded by a **mandatory pre-migration file-copy snapshot** restored on any failure:

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

Use `dart run drift_dev make-migrations` to generate versioned schema snapshots and the `.steps.dart` scaffold. Migration steps are **append-only**: never edit a shipped step; add a new one and bump `schemaVersion`.

## Rules

- **DO** make `PRAGMA key` the first statement on every raw connection and assert `cipher_version` is non-empty before running app queries.
- **DO** ship the CI test that reads the first 16 bytes of the raw DB file and fails the build if they equal `SQLite format 3\000`.
- **DO** store canonical values only: distance in whole metres, volume in millilitres, engine time in whole minutes, money as integer minor units keyed to the ISO-4217 exponent, true instants as UTC epoch millis. **DON'T** persist floats for money, display strings, native numerals, or localized formats.
- **DO** route every read (analytics included) through the shared query layer that filters `is_deleted = 0`.
- **DO** write a parent row and its ledger row in one transaction; **DON'T** insert them separately.
- **DO** scope `.watch()` by vehicle + time window and read rollups; **DON'T** subscribe to unscoped app-wide streams or recompute full history on the UI thread.
- **DON'T** put attachment BLOBs in the DB. Hash plaintext, store ciphertext on disk, keep metadata rows.
- **DON'T** edit a shipped migration step or add a "down" migration. Forward-only + snapshot restore is the contract.
- **DON'T** open the encrypted file from multiple isolates concurrently; use one background DB isolate (`drift_flutter` share-across-isolates) to avoid cipher lock contention.
- **DO** use UUIDv7 text PKs, never autoincrement — collision-free multi-device creation and stable identity across export/re-import.

## For Car and Pain specifically

- **Offline-first:** there is no server to re-sync from, so the encrypted DB is the single source of truth and the OS pending-notification set is a disposable cache reconstructed from it. Everything must rebuild from the database alone after process death, reboot, Doze, or restore.
- **The encrypted DB is NOT the backup.** At-rest encryption protects confidentiality, not durability — the real disaster-recovery guarantee is the verified local backup subsystem in [Backup, Export & Disaster Recovery](./13-backup-export-recovery.md), and a **recoverable key** in [Security, Privacy & At-Rest Encryption](./09-security-privacy.md). Never soften either into a "nice to have".
- **Notifications:** the shared ledger + rollups feed the `UsageProjector` that converts odometer/engine-hour reminders into concrete time instants. Reboot re-arm reads reminders from this DB (see [Local Notifications & Background Reliability](./07-notifications.md)). Choose the iOS file-protection class deliberately so the DB/WAL/attachments stay readable when a boot receiver or scheduled backup needs them while the device is locked.
- **RTL/i18n:** rows are stored canonically and locale-neutral; calendar/numeral/currency projection happens only at the presentation edge, so switching unit/currency/calendar/numeral leaves stored rows byte-identical.
- **No-telemetry:** all persistence is on-device; nothing leaves the process. The `data` package has zero network dependencies by construction.

## Testing

- **In-memory Drift** (`NativeDatabase.memory()`) for fast DAO/repository logic tests — no encryption needed for pure logic.
- **One keyed encryption suite** proving encryption is real: wrong key fails to open, correct key succeeds, `PRAGMA rekey` changes the key, and the **raw file header is NOT `SQLite format 3`**. An on-device integration test confirms the cipher is present at runtime and the DB is readable under the chosen iOS file-protection class while backgrounded.
- **Migration tests on a realistically large seeded DB**, asserting every `from→to` path (including multi-version jumps) preserves data, plus a **forced mid-migration throw** that must restore the pre-migration snapshot.
- **Canonical-storage invariance:** switching display unit/currency/calendar/numeral leaves persisted rows byte-identical; instants vs wall-clock schedules stored distinctly.
- **Rollup/scoped-watch tests:** one ledger insert recomputes only the affected slice; a historical edit triggers the bounded reconcile cascade; `EXPLAIN QUERY PLAN` confirms the intended index is used.
- **Attachment GC:** orphan-blob sweep deletes only `ref_count == 0` blobs; shared-blob delete decrements without orphaning.
- **Flagship blocking CI test** (detailed in [Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)): export→wipe→import→deep-equal **with WAL active**, asserting attachment SHA-256 and preserved full/partial/missed fill flags.
- Drive all clock-dependent logic with injected `Clock` (`package:clock`) for determinism.

## Pitfalls

- **`PRAGMA key` not first / keyed after open** — silently yields an unusable or plaintext DB. Always key first; always assert the cipher.
- **A link mismatch shipping plaintext** — if some dependency pulls a stock `sqlite3` that wins the native link, the DB is unencrypted with no error. The header CI test is the guard.
- **Money as `REAL`/double** — floating-point drift corrupts TCO totals. Integer minor units only.
- **Attachment BLOBs in SQLite** — bloats the DB, slows encryption, defeats space-aware backups.
- **Raw live-file copy for backup** — a WAL-mode file copied raw is corrupt/unrestorable. Use `VACUUM INTO` after a WAL checkpoint (see backup doc), never a raw copy.
- **Editing a shipped migration step** — corrupts data for users who skip versions. Append-only.
- **Biometric/Keystore invalidation** — a changed biometric or OEM OS update can invalidate a hardware-backed key; the recoverable-key path (passphrase-wrap / recovery code) is the survivable default, not "key only in secure storage".
- **iOS file protection too strict** — can make the DB/WAL/attachments unreadable while locked, breaking background notification rescheduling and scheduled backups. Choose the class deliberately.
- **iCloud sweeping the sandbox** — set `NSURLIsExcludedFromBackupKey` on the DB/attachment paths so the encrypted store doesn't leak into a device backup.
- **Concurrent isolate opens** — cipher lock contention; use one shared background DB isolate.
- **`OFFSET` pagination on large ledgers** — degrades badly; use keyset/seek pagination.

## Decisions to confirm

- **Run the week-one encryption spike:** does drift's `sqlite3mc` build-hook path link and encrypt on real iOS **and** Android, or does v1 ship on `sqlcipher_flutter_libs`? Record the decision and confirm no dependency pulls a plaintext `sqlite3` that wins the native link. Pin verified current-stable Flutter/Dart and the `drift` major at that time.
- **Household peer-to-peer sync** (QR/Wi-Fi Direct/NFC, UUIDv7 + tombstone + `updated_at` + `row_revision` merge) is a should-have the schema already enables. Confirm it is **OUT of MVP scope** before kickoff — if in-scope it changes the merge/tombstone/conflict design and couples to backup and notification-reconcile work.

## Related

- **[Security, Privacy & At-Rest Encryption](./09-security-privacy.md)** — the recoverable master key, Argon2id KEK wrap, and app-lock that make the encrypted DB durable, not just confidential.
- **[Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)** — `VACUUM INTO` + verify-by-reopen backups, the real durability guarantee, and the flagship round-trip test.
- **[Architecture & Module Structure](./01-architecture-and-structure.md)** — where the `data` package sits, DAOs per feature, repositories as the single source of truth.
- **[State Management with Riverpod](./02-state-management.md)** — mapping scoped Drift `.watch()` streams onto stream providers and derived TCO/analytics.
- **[Local Notifications & Background Reliability](./07-notifications.md)** — how reminders re-arm from this DB after reboot/Doze via the projection engine.
- **[Canonical Data Model](../reference/data-model.md)** — the authoritative table/field definitions this schema implements.
- **[Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md)** — the product-side promise this persistence layer delivers.
