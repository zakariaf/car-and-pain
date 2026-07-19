# 🛟 Backup, Export & Disaster Recovery

> This document governs how Car and Pain proactively protects irreplaceable user data: verified encrypted local backups, portable exports/imports, key recovery, and the round-trip guarantees that make "backup succeeded" a proven fact rather than a hopeful log line.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · see also **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)**, **[Security, Privacy & At-Rest Encryption](./09-security-privacy.md)**, and the product spec **[Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md)**.

## Decision

Backup is a **first-class v1 subsystem, not a menu item**. Backups are produced by `VACUUM INTO` a temp path **after a WAL checkpoint** (never a raw copy of a live WAL-mode file), then encrypted (**AES-256-GCM** with an **FFI/native Argon2id-derived key**), written to a **temp file that is atomically renamed** into place, and **verified by re-opening and integrity-checking the copy before success is reported**. A **pre-import auto-snapshot is mandatory**. Proactive durability ships in v1: **scheduled/silent auto-backup to a user-chosen local location**, **"last backup N days ago" nagging**, and an **un-skippable "passphrase loss = total loss" warning** plus a **one-time recovery code**. Export is a **single-file archive** (DB + attachments + CSV/JSON) with competitor importers; CSV export is **sanitized against formula injection**, **prepends a UTF-8 BOM**, and **round-trips Persian/Arabic text, Eastern digits, and localized decimal separators**. Packages: `archive`, `csv`, `crypto`, `cryptography`/`cryptography_flutter` (AES-GCM), a native/FFI Argon2id, `file_picker` + `share_plus`, `path_provider`. Pin verified current-stable majors at kickoff.

## Why

With **no account and no cloud, the user's backup is the only defense against device loss** — the encrypted DB on the phone is the working copy, not the backup. This subsystem, not the encryption, is the product's real durability guarantee.

Alternatives considered and rejected:

- **"Atomic temp-file-then-rename" of the live DB file** — the draft's latent field bug. Copying a WAL-mode SQLite file while writes may be in the `-wal`/`-shm` sidecars yields a **corrupt, unrestorable** archive. Rejected in favor of `VACUUM INTO` after a `wal_checkpoint(TRUNCATE)`, which serializes a consistent, defragmented single file.
- **Backup with no verification step** — silently ships unrestorable archives. Rejected: we re-open the produced DB, run `PRAGMA integrity_check`, and confirm expected row counts before reporting success.
- **"Key only in secure storage" as the default** — Keystore/Keychain loss after OEM OS updates, biometric re-enrollment, or restore is well documented on exactly our target devices. Rejected as the default; the key is **recoverable by default** (passphrase-wrapped and/or one-time recovery code). See **[Security, Privacy & At-Rest Encryption](./09-security-privacy.md)**.
- **No auto-backup / no passphrase-loss warning** — leaves catastrophic loss undefended. Rejected.
- **Unsanitized CSV export** — formula injection (`=`, `+`, `-`, `@` cells) and mojibake/garbled Persian text in Excel. Rejected: cells are neutralized and a UTF-8 BOM is emitted.
- **Putting attachment BLOBs inside the DB / backup by DB-copy alone** — bloats the encrypted DB, slows every checkpoint, and defeats content-addressed dedupe. Rejected: attachments live on disk, SHA-256-addressed, and are packaged alongside the DB in the archive.

## How we do it

The engine lives in the `data` package (see **[Architecture & Module Structure](./01-architecture-and-structure.md)**) so it is callable from the widget tree **and** background isolates, and returns a typed `Result<T, BackupFailure>` (see **[Error Handling & Never-Lose-Data](./08-error-handling.md)**).

```text
packages/data/lib/src/backup/
  backup_service.dart        # orchestrates checkpoint→vacuum→encrypt→rename→verify
  vacuum_source.dart         # WAL checkpoint + VACUUM INTO temp path
  archive_codec.dart         # single-file container {manifest, db, attachments/, csv/}
  crypto/
    aead.dart                # AES-256-GCM encrypt/decrypt (fresh nonce per blob)
    kdf.dart                 # FFI/native Argon2id KEK derivation (device-calibrated)
  recovery/
    recovery_code.dart       # one-time code issue + verify
    key_wrap.dart            # wrap/unwrap master key with passphrase KEK / recovery code
  export/
    csv_export.dart          # sanitized, BOM, locale-neutral serialization
    csv_import.dart          # digit/separator normalization + competitor mappers
    manifest.dart            # backup_format_version, schema_version, checksums
  auto_backup/
    scheduler.dart           # "last backup N days ago", silent auto-backup
  failures.dart              # sealed BackupFailure hierarchy
```

### The backup primitive (the only correct order)

```dart
Future<Result<BackupHandle, BackupFailure>> createBackup({
  required File targetDir,
  required Uint8List dbKey,        // read on the main isolate, passed in
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

  // 5. Atomic publish — rename only after the bytes are fully flushed.
  final finalFile = File('${targetDir.path}/car-and-pain-$_stamp.cap');
  await tmpArchive.rename(finalFile.path);

  // 6. VERIFY BY REOPEN before we ever say "success".
  final ok = await _verifyByReopen(finalFile, archiveKey, dbKey);
  if (!ok) { await finalFile.delete(); return Err(BackupFailure.verifyFailed()); }

  return Ok(BackupHandle(finalFile, sizeBytes: sealed.length));
}
```

`_verifyByReopen` decrypts the archive to a scratch location, opens the DB with the real cipher, runs `PRAGMA integrity_check`, and asserts the manifest's row counts and attachment SHA-256s match. Only then is the backup a proven fact.

### Key recovery (recoverable by default)

The 256-bit **master key** that encrypts the DB is never only in secure storage. At first run we **wrap it two ways** and store the wraps in the backup manifest and secure storage:

```dart
// KEK from the user passphrase (device-calibrated Argon2id params).
final kek = await argon2id(passphrase, salt, memMiB: cal.mem, iters: cal.iters);
final wrappedByPassphrase = await aeadWrap(masterKey, kek);

// One-time recovery code shown once at first run; user writes it down.
final recoveryCode = RecoveryCode.generate();      // e.g. grouped base32
final wrappedByCode = await aeadWrap(masterKey, await argon2id(recoveryCode, salt2, ...));
```

Losing the phone but keeping the passphrase (or the recovery code) restores access from any backup. The **un-skippable warning** is shown at first backup creation: *lose the passphrase AND the recovery code → the data is gone, we cannot help you.* This is honest and mandatory for a no-account app.

### Auto-backup & nagging

A silent auto-backup runs to the user-chosen local location on a cadence; a `lastBackupAt` timestamp drives a **"last backup N days ago"** banner that escalates. Auto-backup uses the **same verified primitive** — a silent backup that skips verification would be worse than none.

### Export / import (portability)

The **single-file archive** (`.cap`) is the canonical backup. Alongside it, **per-entity CSV/JSON** is emitted for portability and competitor interop (Fuelio/Drivvo/aCar/Fuelly importers). Exports are **locale-neutral**: UTF-8 + BOM, Western digits, ISO-8601 instants, SI/canonical units, integer minor-unit money (see **[Money, Currency, Units & FX](./14-money-currency-fx.md)**) — so they round-trip losslessly regardless of the UI language.

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

Import **normalizes before math or storage**: Eastern-Arabic/Persian digits → ASCII, the Persian decimal (`٫`) and grouping (`٬`) separators, and decimal-comma vs point / `;` vs `,` detection — matching the rule in **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)**. Import is one atomic transaction preceded by the **mandatory auto-snapshot**, idempotent via a `dedupe_key` (`vehicle_id + odometer + date`), and validates `backup_format_version >= min_supported` with a dry-run before touching live data.

## Rules

- **Do** produce every backup via `wal_checkpoint(TRUNCATE)` → `VACUUM INTO`. **Never** `File.copy()` a live WAL-mode DB, and never back up while a write transaction is open.
- **Do** write to a temp file and **atomically rename** only after `flush: true`. Never write the final path incrementally.
- **Do** verify **every** backup (including silent auto-backups) by re-opening, `PRAGMA integrity_check`, and manifest checksum match before reporting success. A backup that was not verified did not succeed.
- **Do** take a **pre-import auto-snapshot** and a **pre-migration snapshot** (see **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)**) before any destructive operation; restore it on failure.
- **Do** wrap the master key by passphrase **and** recovery code at first run. **Never** ship "key only in secure storage" as the default.
- **Do** show the **un-skippable passphrase-loss warning** at first backup and issue the one-time recovery code exactly once.
- **Do** use a **fresh random nonce per AES-GCM encryption**; never reuse a `(key, nonce)` pair.
- **Do** sanitize every CSV cell against formula injection and prepend a UTF-8 BOM. **Never** export raw user strings to CSV.
- **Do** keep exports **locale-neutral** (Western digits, ISO-8601, SI units, minor-unit money). **Never** persist localized/display strings or Eastern numerals in an export.
- **Do** keep attachment bytes on disk (SHA-256-addressed) and package them into the archive; **never** stuff BLOBs into the DB.
- **Do** read the DB key on the **main isolate** and pass bytes into the backup isolate. Never call `flutter_secure_storage` from a background isolate.
- **CI must** run the flagship `export → wipe → import → deep-equal` test **with WAL active** as a blocking gate, plus the CSV formula-injection + Persian-digit/separator round-trip.

## For Car and Pain specifically

- **Offline-first:** there is no server to re-sync from, so the local verified backup is the entire disaster-recovery story. `VACUUM INTO` + verify-by-reopen turns durability from a promise into a checked invariant.
- **No-telemetry:** we never learn a backup failed in the field, so failure must surface **locally** as a typed `BackupFailure` driving a concrete, localized recovery action — not a silent log. The backup subsystem holds zero network code; the offline flavor omits the INTERNET permission.
- **RTL/i18n:** the CSV round-trip is a first-class correctness surface for the primary audience — Persian/Arabic text, Eastern digits, and `٫`/`٬` separators must survive export→import byte-faithfully after normalization. Store canonically, convert only at the presentation edge.
- **Notifications:** a restore rebuilds the DB, which is the single source of truth for the pending-notification set; after import the **reconcile pass re-arms** reminders from the restored rows (see **[Local Notifications & Background Reliability](./07-notifications.md)**). Fill flags (full/partial/missed) must survive the round-trip or consumption stats and projections break silently.
- **Canonical storage:** because everything is stored canonically (SI/UTC-instant vs wall-clock schedule/minor-unit money) and the DB is fully encrypted, switching language, calendar, units, or currency never touches the backup or crypto layer — the archive is the same bytes regardless of UI locale.

## Testing

Deterministic and mostly off-device, driven by an injected `Clock` (`package:clock`) so nagging cadence and timestamps are reproducible.

- **Flagship blocking test — `export → wipe → import → deep-equal`, WAL ACTIVE:** open an in-memory (or keyed) Drift DB, seed a realistically large ledger, keep a write transaction/WAL pending, back up, wipe, restore, then assert **row-level deep equality** across every table, **per-attachment SHA-256**, and preserved **full/partial/missed fill flags**. A raw-copy backup passes a naive test and fails here — that is the point.
- **CSV round-trip:** assert UTF-8 BOM present, formula-injection cells neutralized (`=`, `+`, `-`, `@`), and Persian text + Eastern digits + `٫`/`٬` separators survive export→import with correct numeric parsing.
- **Verify-by-reopen negative tests:** corrupt one byte of the produced archive → `integrity_check`/GCM tag fails → `createBackup` returns `Err` and deletes the file; never reports success.
- **Key recovery:** destroy the Keystore/Keychain key, then restore access via passphrase and via the one-time recovery code; assert a wrong passphrase cannot unwrap the master key.
- **Pre-import snapshot rollback:** force a mid-import throw and assert the snapshot restores the prior state atomically.
- **Idempotency:** import the same file twice → `dedupe_key` prevents double-counting; skewed `updated_at` resolves last-write-wins.
- **Competitor-import goldens:** fixture files for Fuelio/Drivvo/aCar/Fuelly asserting correct unit/currency/date-format/digit detection and full-tank inference.
- **Crypto:** AES-GCM encrypt→decrypt round-trip; a flipped ciphertext byte fails the tag; nonce uniqueness across N backups.

See **[Testing Strategy](./11-testing.md)** for the coverage gates (100% enforced on logic packages).

## Pitfalls

- **Raw-copy of a live WAL file** produces corrupt, unrestorable backups — the single most dangerous latent bug in this area. Always checkpoint then `VACUUM INTO`.
- **Skipping verification** ships silent unrestorable archives; the user discovers it only when they need the backup most. Verify every time, including silent auto-backups.
- **Excel mangles Persian/Arabic/Kurdish CSV without a UTF-8 BOM**, and imports that don't normalize Eastern digits or detect `٫`/`٬` and `;`/`,` separators silently corrupt numbers.
- **Fill-flag loss** across export→import→merge breaks consumption statistics with no error — assert flags explicitly in round-trip tests.
- **Passphrase/recovery-code loss is unrecoverable** for encrypted backups — the warning must be un-skippable and the recovery code shown at issue time only.
- **GCM nonce reuse is catastrophic** — a fresh random nonce per blob, never a reused `(key, nonce)` pair.
- **Reading secure storage from a background isolate** fails (platform channel lives on the main isolate) — read on main, pass bytes in.
- **iOS iCloud sweeps the app sandbox** — set `NSURLIsExcludedFromBackupKey` on the working DB/attachments so private data doesn't leak into the user's device backup; the app's own encrypted archive is the intended transfer path.
- **iOS file-protection class** can make the DB/attachments unreadable while locked, breaking scheduled auto-backup and background re-arm — choose the protection class deliberately (couples to notifications).
- **Non-atomic writes** — a crash mid-write leaves a truncated final file that looks valid; temp-then-rename after flush is mandatory.

## Decisions to confirm

- **Key-recovery UX (owner):** confirm the **default** mechanism — user passphrase that wraps the key, an auto-issued one-time recovery code, or **both** — and the exact first-run flow, since this is now the app's primary durability guarantee rather than an opt-in high-security mode.
- **Argon2id parameters (owner):** settle the FFI/native library and the device-calibrated memory/iteration params (with a defined low-end fallback), benchmarked against the slowest target device so backup encryption and unlock don't take multiple seconds or OOM.
- **Household P2P sync scope (owner):** confirm peer-to-peer sync (UUIDv7 + tombstone + `updated_at` + `row_revision` merge) is **out of MVP**; if in-scope it changes the merge/conflict design and the backup/import round-trip must account for cross-device merge, not just restore.

## Related

- **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)** — the encrypted Drift DB, WAL, and the pre-migration snapshot pattern backups build on.
- **[Security, Privacy & At-Rest Encryption](./09-security-privacy.md)** — the recoverable master key, Argon2id KEK wrap, and archive vs at-rest crypto boundary.
- **[Error Handling & Never-Lose-Data](./08-error-handling.md)** — the sealed `BackupFailure`/`ImportFailure` hierarchy and the never-lose-data subsystem.
- **[Money, Currency, Units & FX](./14-money-currency-fx.md)** — minor-unit money and canonical values that exports serialize losslessly.
- **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)** — digit/separator normalization the CSV importer depends on.
- **[Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md)** — the product-side requirements this subsystem implements.
- **[Canonical Data Model](../reference/data-model.md)** — the per-entity table shapes that map 1:1 to CSV export.
