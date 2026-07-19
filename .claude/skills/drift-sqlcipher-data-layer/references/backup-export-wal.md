# Backup, export, WAL & verify-by-reopen

Detail for the backup subsystem, which lives in `packages/data/lib/src/backup/`
so it is callable from the widget tree **and** background isolates. The encrypted
DB is NOT the backup — this verified local backup is the product's real
disaster-recovery guarantee. There is no cloud fallback by default.

## The backup primitive — the ONLY correct order

Never `File.copy` a live WAL-mode DB: copying while writes may be in the
`-wal`/`-shm` sidecars yields a **corrupt, unrestorable** archive — the single
most dangerous latent bug in this area.

```dart
Future<Result<BackupHandle, BackupFailure>> createBackup({
  required File targetDir,
  required Uint8List dbKey,        // read on the MAIN isolate, passed in
  required SecretKey archiveKey,   // Argon2id(passphrase | recoveryCode)
}) async {
  final tmpDb = _tmp('backup.db');
  final tmpArchive = _tmp('backup.cap.tmp');

  // 1. Quiesce the WAL so the file we copy is self-contained.
  await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');

  // 2. VACUUM INTO — a consistent, defragmented single file. NEVER File.copy the live DB.
  await db.customStatement("VACUUM INTO '${tmpDb.path}';");

  // 3. Package DB + attachment blobs + CSV/JSON + manifest into one archive.
  final archiveBytes = await _archiveCodec.build(
    db: tmpDb,
    attachments: _attachmentBlobs(),   // SHA-256-addressed files on disk
    manifest: Manifest.current(schemaVersion: db.schemaVersion),
  );

  // 4. Encrypt the WHOLE archive with a FRESH nonce (never reuse a key+nonce pair).
  final sealed = await _aead.encrypt(archiveBytes, key: archiveKey);
  await tmpArchive.writeAsBytes(sealed, flush: true);

  // 5. Atomic publish — rename only AFTER bytes are fully flushed.
  final finalFile = File('${targetDir.path}/car-and-pain-$_stamp.cap');
  await tmpArchive.rename(finalFile.path);

  // 6. VERIFY BY REOPEN before ever saying "success".
  final ok = await _verifyByReopen(finalFile, archiveKey, dbKey);
  if (!ok) { await finalFile.delete(); return Err(BackupFailure.verifyFailed()); }

  return Ok(BackupHandle(finalFile, sizeBytes: sealed.length));
}
```

`_verifyByReopen` decrypts the archive to scratch, opens the DB with the real
cipher, runs `PRAGMA integrity_check`, and asserts the manifest's row counts and
attachment SHA-256s match. Only then is the backup a proven fact.

## WAL rules

| Do | Never |
|---|---|
| `wal_checkpoint(TRUNCATE)` then `VACUUM INTO` for every backup | `File.copy` a live WAL-mode DB |
| Back up when no write transaction is open | Back up mid write-transaction |
| Let WAL/`-shm`/temp side files inherit the cipher | Assume side files are plaintext |
| Verify every backup — including silent auto-backups | Skip verification "because it's automatic" |
| Temp-file then atomic `rename` after `flush:true` | Write the final path incrementally |

Auto-backup uses the **same verified primitive** — a silent backup that skips
verification would be worse than none. A `lastBackupAt` timestamp drives the
"last backup N days ago" escalating banner.

## Key recovery (recoverable by default)

The 256-bit master key that encrypts the DB is **never only in secure storage** —
Keystore/Keychain loss after OEM OS updates, biometric re-enrollment, or restore
is well documented on target devices. At first run, wrap it two ways:

```dart
final kek = await argon2id(passphrase, salt, memMiB: cal.mem, iters: cal.iters);
final wrappedByPassphrase = await aeadWrap(masterKey, kek);
final recoveryCode = RecoveryCode.generate();      // one-time, shown once
final wrappedByCode = await aeadWrap(masterKey, await argon2id(recoveryCode, salt2, ...));
```

Show the **un-skippable** warning at first backup: lose the passphrase AND the
recovery code and the data is gone. Read the DB key on the **main isolate** and
pass bytes into the backup isolate — never call `flutter_secure_storage` from a
background isolate.

## Export / import (portability)

The single-file archive (`.cap`) is canonical; alongside it, per-entity CSV/JSON
for competitor interop (Fuelio/Drivvo/aCar/Fuelly). Exports are **locale-neutral**:
UTF-8 + BOM, Western digits, ISO-8601 instants, SI/canonical units, integer
minor-unit money — so they round-trip losslessly regardless of UI locale.

```dart
// Formula-injection neutralization: prefix a leading =,+,-,@,tab,CR with a single quote.
String sanitizeCell(String v) =>
    RegExp(r'^[=\+\-@\t\r]').hasMatch(v) ? "'$v" : v;

Uint8List encodeCsv(List<List<String>> rows) {
  const bom = [0xEF, 0xBB, 0xBF];               // Excel needs this for Persian/Arabic
  final body = const ListToCsvConverter().convert(
    rows.map((r) => r.map(sanitizeCell).toList()).toList());
  return Uint8List.fromList([...bom, ...utf8.encode(body)]);
}
```

Import **normalizes before math or storage** (Eastern-Arabic/Persian digits →
ASCII; `٫` decimal / `٬` grouping separators; decimal-comma vs point; `;` vs
`,`), is one atomic transaction preceded by a **mandatory auto-snapshot**,
idempotent via `dedupe_key` (`vehicle_id + odometer + date`), and validates
`backup_format_version >= min_supported` with a dry-run before touching live
data. Restore is non-destructive and merge-aware (last-write-wins by
`updated_at`, tombstones honored).

## The flagship blocking CI test

`export → wipe → import → deep-equal` **with WAL ACTIVE**: seed a realistically
large ledger, keep a write transaction / WAL pending, back up, wipe, restore,
then assert **row-level deep equality** across every table, **per-attachment
SHA-256**, and preserved **full/partial/missed fill flags**. A raw-copy backup
passes a naive test and fails here — that is the point. Also: CSV round-trip
(BOM present, formula cells neutralized, Persian text + `٫`/`٬` survive), and
verify-by-reopen negative tests (corrupt one byte → GCM tag / `integrity_check`
fails → `Err`, file deleted, never "success").

## Pitfalls

- **Raw-copy of a live WAL file** — corrupt, unrestorable. Checkpoint then
  `VACUUM INTO`, always.
- **Skipping verification** — ships silent unrestorable archives. Verify every
  time.
- **GCM nonce reuse** — catastrophic. Fresh random nonce per blob.
- **Secure storage from a background isolate** — fails (platform channel is main-
  isolate only). Read on main, pass bytes in.
- **Unsanitized / no-BOM CSV** — formula injection and mojibake Persian text in
  Excel.
- **Attachment BLOBs in the DB** — bloats every checkpoint, defeats dedupe. Keep
  bytes on disk, SHA-256-addressed.
- **iOS iCloud sweeping the sandbox** — set `NSURLIsExcludedFromBackupKey` on the
  working DB/attachments; the app's own encrypted archive is the intended
  transfer path.
