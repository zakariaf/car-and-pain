# F6 · Backup, export/import & key recovery

> The first-class disaster-recovery subsystem: encrypted single-file backups that round-trip attachments, hand-written CSV/JSON export, a merge-aware import wizard, format versioning, and recoverable-by-default key management.

## Goal

Deliver backup/export/import as a **first-class v1 subsystem**, not a settings menu item — the single biggest trust moat for a 100%-offline, account-free app where losing the device must never mean losing the data.

Concretely this epic ships:

- **Encrypted single-file backups.** A WAL checkpoint followed by `VACUUM INTO` a temp path (never a raw copy of a live WAL-mode file), then AES-GCM encryption under a key derived by native/FFI **Argon2id**, written atomically via temp-then-rename. Attachments (app-private media) travel inside the archive and are re-linked on restore.
- **Human-readable export.** `dart:convert` JSON of every entity plus **hand-written per-entity CSV** (built-in-first: no CSV package), using locale-neutral canonical values (SI units, integer minor-unit money + ISO code, UTC epoch instants) so files diff cleanly and re-import losslessly.
- **A real import wizard.** Parse the app's own archives and **foreign CSV/JSON** through field-mapping competitor presets, behind a mandatory dry-run and an automatic pre-restore snapshot, with tombstone-aware last-write-wins merge and record-count reconciliation.
- **Versioning & integrity.** `backup_format_version`, `min_supported_version`, and checksums; a newer-than-supported archive is **refused, never partially applied**.
- **Recoverable-by-default keys.** The random 256-bit master key is wrapped by a passphrase-derived KEK plus a one-time recovery code, gated by an **un-skippable data-loss warning**.
- **Scheduled auto-backup** with retention and an optional self-hosted destination.

Everything surfaces through PULSE components, is fully localized (LTR en/de/fr + RTL fa/ar/ckb) with correct numerals/calendars, and is exercised by export→wipe→import round-trip tests across every entity plus attachments.

## Tier & dependencies

- **Tier:** foundation
- **Module:** `data-offline-backup`
- **Depends on:** F1, F2, F7, F8

## References

- [docs/features/18-data-offline-backup.md](../../features/18-data-offline-backup.md)
- [docs/flutter/13-backup-export-recovery.md](../../flutter/13-backup-export-recovery.md)
- [docs/flutter/09-security-privacy.md](../../flutter/09-security-privacy.md)
- [docs/flutter/14-money-currency-fx.md](../../flutter/14-money-currency-fx.md)
- [docs/reference/data-model.md](../../reference/data-model.md)

## Tasks

### F6-T1 · Backup writer

**Description.** The core producer. On demand, checkpoint the WAL (`PRAGMA wal_checkpoint(TRUNCATE)`), run `VACUUM INTO` a temp file to obtain a consistent, defragmented snapshot of the encrypted SQLite DB, then AES-256-GCM-encrypt the snapshot under a key derived by native/FFI Argon2id (device-calibrated params fixed at the week-1 encryption spike, stored in the archive header). Assemble a single-file archive (header + manifest + DB payload + attachment payloads) and commit it with an atomic temp-then-rename so a killed process never leaves a half-written backup at the destination. Return a sealed `Result<BackupHandle, BackupFailure>` at the boundary — never throw across the module edge.

**Acceptance criteria.**
- [ ] Backup is produced from a `VACUUM INTO` snapshot after a WAL checkpoint, never a raw file copy of a live WAL-mode DB.
- [ ] Payload is AES-256-GCM encrypted; the GCM auth tag is verified before any restore reads plaintext.
- [ ] The Argon2id KDF salt and calibrated params (memory/iterations/parallelism) are stored in the archive header, not hardcoded in the reader.
- [ ] Final file appears at the destination only via atomic rename; an interrupted run leaves no partial/visible artifact and cleans its temp files.
- [ ] Free-space / write-failure paths return a typed `BackupFailure` (stable code + params), surfaced as a PULSE error state with a localized message.
- [ ] Backup never blocks the UI thread; long runs report progress and are cancellable.

**Size:** L
**Depends on:** F1 (DB/schema), F2 (canonical repos), F8 (encryption/keystore)
**Governing docs:** flutter/13-backup-export-recovery.md, flutter/09-security-privacy.md, features/18-data-offline-backup.md

### F6-T2 · Attachment bundling & re-link

**Description.** Extend the archive so app-private media (photos, receipts, scans, PDFs, dashcam clips) referenced by any record is bundled alongside the DB payload. On restore, write files back to app-private storage and **re-link `linked_entity`** so every attachment resolves to its restored record. Account for total attachment bytes in the manifest, skip already-orphaned media, and run orphan cleanup after restore so no dangling files or dangling references survive.

**Acceptance criteria.**
- [ ] Every attachment referenced by a live (non-tombstoned) record is included in the archive; orphaned media is excluded.
- [ ] On restore, files land in app-private storage and each `linked_entity` reference resolves to a restored record.
- [ ] Manifest records per-attachment size and an aggregate byte total; UI shows expected backup size before writing.
- [ ] Post-restore orphan cleanup removes files with no referencing record and references with no file.
- [ ] Attachment content integrity is checksum-verified on restore (see F6-T4).

**Size:** M
**Depends on:** F6-T1, F1 (attachments/media pipeline schema)
**Governing docs:** features/18-data-offline-backup.md, reference/data-model.md

### F6-T3 · JSON/CSV export

**Description.** Human-readable, portable export independent of the encrypted binary backup. Emit a combined `dart:convert` JSON document covering **every entity** and a **hand-written per-entity CSV** set (built-in-first — no CSV dependency; correct RFC-4180-style quoting/escaping, UTF-8 BOM handling, deterministic column order). All values are **locale-neutral canonical**: SI base units, integer minor units + ISO-4217 currency code (never floats/fixed-2-decimals), UTC epoch-millisecond instants, and canonical enum tokens — display formatting happens only at read time, never in the file.

**Acceptance criteria.**
- [ ] JSON export includes every entity in the data model, with schema/format version and generation metadata.
- [ ] Per-entity CSV is generated by hand-written writer code; fields containing commas/quotes/newlines are correctly quoted and escaped; round-trips through a spreadsheet without corruption.
- [ ] Money is exported as integer minor units + ISO code honoring each currency's real exponent (0 IRR/JPY, 2 USD/EUR, 3 KWD); measures in SI base units; instants as UTC epoch millis.
- [ ] Numerals in exported files are Western-ASCII canonical regardless of the app's display numeral system; VIN/plate/IBAN stay LTR/unaltered.
- [ ] Export runs off the UI thread with progress and produces files sharable via the OS share sheet.

**Size:** M
**Depends on:** F2 (canonical repos), F7 (money/currency model)
**Governing docs:** flutter/13-backup-export-recovery.md, flutter/14-money-currency-fx.md, reference/data-model.md

### F6-T4 · Format versioning & checksums

**Description.** Define and enforce the archive/export contract. Every artifact carries `backup_format_version`, `min_supported_version`, the DB `schema_version`, and per-payload checksums (DB payload + each attachment + a whole-archive digest). The reader **refuses** — cleanly, without mutating any data — an archive whose format version exceeds what this build supports or whose checksum fails, returning a typed `ImportFailure` rather than corrupting state.

**Acceptance criteria.**
- [ ] Header carries `backup_format_version`, `min_supported_version`, and `schema_version`; documented in flutter/13.
- [ ] Checksums cover the DB payload, each attachment, and the whole archive; any mismatch aborts before restore with a localized "backup damaged" state.
- [ ] An archive newer than the running build is refused with a clear "made by a newer version" message — never partially applied.
- [ ] An archive older than `min_supported_version` is either migrated or refused explicitly (documented behavior), never silently misread.
- [ ] Version/checksum decisions return typed `ImportFailure` codes consumable by tests and UI.

**Size:** M
**Depends on:** F1 (schema_version/migrations)
**Governing docs:** flutter/13-backup-export-recovery.md, reference/data-model.md

### F6-T5 · Import wizard & competitor presets

**Description.** A guided PULSE flow to bring data in — from the app's own archive and from **foreign CSV/JSON** (Fuelly, Drivvo, aCar, Simply Auto, etc.). Ship field-mapping **presets** per known source plus a manual column-mapping step for unknown files, with type/unit/currency coercion into the canonical model. Every import runs behind a **mandatory dry-run** (preview counts, conflicts, warnings) and takes an automatic **pre-restore snapshot** before any write, so the user can undo. Merge behavior is delegated to F6-T6.

**Acceptance criteria.**
- [ ] Wizard imports the app's own encrypted archive and foreign CSV/JSON via selectable presets.
- [ ] Each preset maps foreign columns → canonical fields with unit/currency/date coercion; unknown files fall back to manual mapping.
- [ ] A dry-run preview shows records to add/update/skip, detected conflicts, and validation warnings before any write.
- [ ] An automatic pre-restore snapshot is taken before mutation and is restorable if the user cancels or the import fails.
- [ ] Malformed rows are reported per-row (row number + reason) without aborting the whole import unless the user chooses strict mode.
- [ ] All wizard steps are PULSE components, fully localized, RTL-mirrored, and screen-reader navigable.

**Size:** L
**Depends on:** F6-T3, F6-T4, F6-T6, F2 (repos/validation)
**Governing docs:** features/18-data-offline-backup.md, flutter/13-backup-export-recovery.md

### F6-T6 · Merge/conflict resolution

**Description.** The deterministic merge engine shared by import and (later) household sync. Records carry UUID + `updated_at` + tombstone; merge is **last-write-wins by `updated_at`**, tombstone-aware (a deletion beats a stale edit), producing a record-count reconciliation report (added/updated/skipped/deleted, before vs after). Deterministic given the same inputs so tests and dry-runs agree with the committed result.

**Acceptance criteria.**
- [ ] Merge keys on UUID; conflicts resolve by newest `updated_at`; ties resolve by a documented stable tiebreak.
- [ ] Tombstones are honored — a tombstoned record is not resurrected by an older incoming edit.
- [ ] A reconciliation report enumerates added/updated/skipped/deleted counts and matches the dry-run preview exactly.
- [ ] Merge is deterministic and side-effect-free until commit; dry-run and real run produce identical reconciliation for identical inputs.
- [ ] Referential integrity (FKs, `linked_entity`) holds after merge; the shared odometer ledger stays monotonic/consistent.

**Size:** M
**Depends on:** F1 (UUID/tombstone/updated_at schema), F6-T5
**Governing docs:** flutter/13-backup-export-recovery.md, reference/data-model.md

### F6-T7 · Key recovery flow

**Description.** Make the master key **recoverable by default**. The random 256-bit master key is wrapped by a passphrase-derived KEK (native/FFI Argon2id) and, separately, escrowed under a **one-time recovery code** the user must save. Daily unlock uses biometric/PIN (F8); this flow is the fallback when the device/biometric is lost. Generation, display, and redemption of the recovery code are gated by an **un-skippable data-loss warning** making explicit that losing both passphrase and recovery code means the data is unrecoverable.

**Acceptance criteria.**
- [ ] Master key is wrapped under a passphrase-derived KEK and separately under a one-time recovery code; neither is stored in plaintext.
- [ ] Recovery-code generation shows an un-skippable warning; the user must confirm they have saved it before proceeding.
- [ ] Redeeming a valid passphrase **or** recovery code re-derives/unwraps the master key and restores access.
- [ ] A recovery code is single-use; redeeming or rotating it invalidates the old one and can issue a replacement.
- [ ] Wrong passphrase/code attempts fail closed with a typed failure and no key material leaks to logs.
- [ ] All copy is localized (incl. RTL) and the warning is redundantly encoded (icon + label + text), not color-only.

**Size:** M
**Depends on:** F8 (encryption/keystore/app-lock)
**Governing docs:** flutter/09-security-privacy.md, flutter/13-backup-export-recovery.md

### F6-T8 · Scheduled auto-backup

**Description.** Periodic local backups driven by the same writer (F6-T1), with a user-configurable interval and a **retention policy** (keep-N / age-based pruning). Support an **optional self-hosted destination** (user-chosen folder / SAF / WebDAV-style target — no first-party cloud, no account) in addition to the on-device default location. Failures are non-fatal and surfaced honestly ("last successful backup" timestamp), consistent with offline-honesty degradation.

**Acceptance criteria.**
- [ ] User can enable/disable auto-backup and choose an interval; the schedule survives app restart and device reboot.
- [ ] Retention prunes old backups per the configured policy without ever deleting the most recent successful backup.
- [ ] An optional self-hosted destination can be configured and validated; default remains fully on-device.
- [ ] Each run records success/failure + timestamp; failures are shown as a "last successful backup" state, not a crash.
- [ ] Settings surface is a PULSE component, localized, RTL-correct, and accessible; schedule state is itself included in backup/export.

**Size:** M
**Depends on:** F6-T1
**Governing docs:** features/18-data-offline-backup.md, flutter/13-backup-export-recovery.md

### F6-T9 · Round-trip tests

**Description.** The fidelity guarantee. Table-driven tests seed every entity plus attachments, produce a backup/export, **wipe** the DB, import/restore, and assert byte-for-value equality on canonical fields plus resolved attachment links. Cover CSV/JSON export re-import, encrypted-archive restore, version-refusal, checksum-corruption rejection, merge/tombstone determinism, and recovery-code redemption.

**Acceptance criteria.**
- [ ] Export→wipe→import restores every entity with canonical values (money minor-units+code, SI measures, UTC instants) unchanged.
- [ ] Attachments round-trip: bytes match by checksum and `linked_entity` resolves post-restore.
- [ ] A corrupted-checksum archive and a newer-format archive are both rejected without mutating existing data (tested).
- [ ] Merge/tombstone cases produce deterministic reconciliation counts matching the dry-run.
- [ ] Recovery-code and passphrase unwrap paths are tested, including single-use invalidation and wrong-secret fail-closed.
- [ ] Foreign-preset import of at least one competitor sample file maps to canonical fields correctly.

**Size:** M
**Depends on:** F6-T1 … F6-T8
**Governing docs:** flutter/13-backup-export-recovery.md, features/18-data-offline-backup.md

### F6-T10 · Backup/restore UI surface & i18n (added)

**Description.** The user-facing PULSE surface that ties the subsystem together: a Backup & Recovery room/section with "Back up now", restore/import entry, recovery-code management, and auto-backup settings. Following PULSE, every status (in-progress, success "exhale", failure, damaged/refused archive) is **redundantly encoded** (icon + label + shape/position), never color alone. All strings live in ARB; numerals, dates, and sizes render per the active locale/calendar/numeral system while files stay canonical.

**Acceptance criteria.**
- [ ] All entry points (backup now, restore/import wizard, recovery, schedule) are reachable through PULSE navigation and components.
- [ ] Progress, success, and failure states are redundantly encoded (icon + label + shape), not color-only.
- [ ] 100% of strings are in ARB across en/de/fr/fa/ar/ckb; no hardcoded UI text; sizes/dates/numbers use locale formatting.
- [ ] Layout mirrors correctly in RTL; focus/traversal order is mirrored; VIN/IDs/checksums stay LTR via bidi isolation.
- [ ] Screen-reader labels announce backup state, sizes, and warnings correctly, including Eastern-Arabic/Persian numerals.

**Size:** M
**Depends on:** F6-T1, F6-T5, F6-T7, F6-T8, F3 (PULSE), F4 (i18n/RTL)
**Governing docs:** flutter/13-backup-export-recovery.md, features/18-data-offline-backup.md

## Definition of Done

- **Vertical slice complete:** schema/format contract → canonical repos → backup writer/attachment bundling → export/import + merge engine → key recovery → PULSE UI → tests, all landed and wired.
- **Tests:** table-driven unit tests on the pure-Dart export/CSV/merge/version logic; export→wipe→import round-trip green for **every entity plus attachments**; version-refusal, checksum-corruption, tombstone-determinism, and recovery-code paths covered. `flutter analyze` and `dart format --set-exit-if-changed` clean.
- **Built-in-first honored:** JSON via `dart:convert`, CSV hand-written, no new runtime CSV/crypto-archive dependency beyond the sanctioned encryption/keystore stack.
- **i18n complete:** 100% of user-facing strings in ARB across en/de/fr/fa/ar/ckb; no hardcoded text; sizes/dates/numerals localized while exported files remain locale-neutral canonical.
- **RTL verified:** every backup/restore/recovery screen mirrors correctly with mirrored focus order; VIN/IBAN/plate/checksums held LTR via bidi isolation.
- **In backup/export:** the subsystem's own state — auto-backup schedule, retention, destination, recovery metadata (non-secret) — is itself included in backup/export coverage.
- **Accessible per the redundant-encoding rule:** all backup/restore status is encoded with icon + label + shape/position beyond color; custom widgets carry `Semantics`; screen readers announce state, sizes, and the un-skippable loss warning correctly in every locale.
- **Failure discipline:** all module-boundary APIs return sealed `Result<T, BackupFailure|ImportFailure>` with stable codes + typed params (never user strings); no partial/corrupting restore on any refusal path.
- **Security:** master key recoverable-by-default (passphrase KEK + one-time code) with un-skippable loss warning; no key material or passphrase in logs; GCM tags and checksums verified before any plaintext restore.
