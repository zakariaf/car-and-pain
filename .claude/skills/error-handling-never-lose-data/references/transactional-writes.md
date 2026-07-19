# Transactional multi-table writes (Drift + SQLCipher over WAL)

A single logical action in Car and Pain touches several tables at once: logging a fill inserts the fill row, appends an odometer ledger reading, recomputes a reminder/projection anchor, and invalidates a rollup revision key. Either **all** of it lands or **none** of it does — a half-applied write silently corrupts consumption stats, TCO, and reminder timing with no way to notice offline.

## The rule

Wrap the whole unit in one `_db.transaction(...)`. Any throw rolls the entire unit back. Map the throw to `Err(TransactionRolledBack())` at the boundary (log first).

```dart
Future<Result<void, DbFailure>> logFill(FillDraft d) async {
  try {
    await _db.transaction(() async {          // journal_mode=WAL, foreign_keys=ON
      final id = await _fillDao.insert(d);
      await _ledgerDao.appendOdometer(d.odometer, sourceId: id);
      await _rollupDao.bumpRevision(d.vehicleId, d.period); // invalidate rollup key
    });
    return const Ok(null);
  } on Object catch (e, st) {
    _log.error('db.log_fill', e, st);
    return const Err(TransactionRolledBack());
  }
}
```

## Synchronous `txn.*` calls ONLY inside the body

Inside a Drift transaction, issue **only** DB statements that run on the active transaction executor. **Never** `await` an unrelated future (network — there is none here — file IO, `Future.delayed`, secure-storage reads) and **never** re-enter the same DB (open a second connection, call a method that starts its own transaction). Both **deadlock or break atomicity**: Drift serializes access through the transaction's zone, and awaiting something outside it either lets a concurrent statement interleave or blocks forever.

| Inside the transaction body | Verdict | Why |
| --- | --- | --- |
| `_fillDao.insert(d)` on the txn executor | OK | runs on the transaction's connection |
| Another `_db.transaction(...)` (nested) | AVOID | Drift maps it to a SAVEPOINT — only when a genuine partial-rollback sub-unit is needed; never accidentally |
| `await secureStorage.read(...)` | FORBIDDEN | platform channel, unrelated future — read it BEFORE the transaction and pass the value in |
| `await http/file/Future.delayed` | FORBIDDEN | unrelated future — blocks the txn zone / interleaves |
| `await _otherDb.transaction(...)` | FORBIDDEN | re-entering a DB inside a txn deadlocks |
| Reading `DateTime.now()` | AVOID | inject `Clock` and compute the instant before the txn for determinism |

**Do the prep before the transaction.** Read the DB key / secure storage, resolve `Clock.now()`, run pure validation and canonical-unit conversion — all *outside* — then open the transaction and issue only the synchronous DAO writes.

## WAL + SQLCipher specifics

- The DB opens with `PRAGMA journal_mode=WAL` and `PRAGMA foreign_keys=ON`. FK enforcement means a bad `sourceId` throws mid-transaction → the whole unit rolls back → `TransactionRolledBack`, exactly the intended behavior.
- WAL is what lets the backup subsystem checkpoint + `VACUUM INTO` a consistent snapshot; do not switch journal modes ad hoc.
- SQLCipher decrypt failures surface at open/read as a `SqliteException` mapped to `DecryptFailed` — a distinct `DbFailure` from a rolled-back write.

## `ConstraintViolation` vs `TransactionRolledBack`

Map the *cause* when it is known and actionable (a unique constraint the UI can explain — "this odometer reading already exists"): return `ConstraintViolation(table)`. When the cause is opaque or the unit simply could not complete atomically, return `TransactionRolledBack()`. Both are `DbFailure`; the exhaustive UI switch handles each.

## Rollback test recipe (blocking)

Drive a multi-table write whose **2nd** statement throws (force an FK/constraint violation), then assert:

1. the method returns `Err(TransactionRolledBack)` (or `ConstraintViolation`), and
2. the DB is **byte-unchanged** — the 1st statement's row is NOT present (proving atomic rollback, not just an error return).

```dart
test('logFill rolls back atomically when the ledger append violates FK', () async {
  final db = TestDb(NativeDatabase.memory());
  final before = await db.dumpAllRows();
  final result = await repo.logFill(fillWithBadLedgerRef);
  expect(result, isA<Err<void, DbFailure>>());
  expect((result as Err).failure, isA<TransactionRolledBack>());
  expect(await db.dumpAllRows(), equals(before)); // no partial write survived
});
```

Use in-memory Drift (`NativeDatabase.memory()`); no device needed. See docs/flutter/03-data-persistence.md for the schema, WAL, and migration/snapshot machinery these writes depend on.
