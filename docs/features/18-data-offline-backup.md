# 🗄️ Data, Offline, Backup & Portability

> The pain: you tracked five years of fuel, service, and receipts — then a forced account, a bad sync, or a phone swap wiped it all, and there was no file you could hold in your hand.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Settings & Preferences](./21-settings-preferences.md) · [Drivers, Household & Sharing](./15-drivers-household.md) · [Canonical Data Model & Schema](../reference/data-model.md)

## The pain

The single most-documented failure across Fuelly, aCar, CARFAX, Simply Auto, and AUTOsist is not a missing feature — it is catastrophic data loss. Owners log years of fill-ups, repairs, and scanned documents, then lose everything to a mandatory account, a broken cloud sync, a reinstall, or an OS-to-OS migration that quietly wipes app-private storage. When they try to leave one app for another, there is no clean file to take with them, and importers either don't exist or silently mangle units, dates, and full-tank flags. The result is a graveyard of abandoned logbooks and a justified fear that the data was never really theirs.

Car and Pain treats this as the product's foundation, not a settings afterthought. Everything lives in a local database on the device; a free single-file backup captures every record and attachment; export and import are first-class; and nothing is ever held hostage behind an account or a subscription.

## What it does

This module is the offline-first data engine underneath every other feature. It stores all data in an embedded, optionally encrypted SQLite database in WAL mode with stable UUID keys, audit timestamps, and soft-delete tombstones, so records survive edits, merges, device swaps, and language/unit changes without corruption. A one-tap full backup produces a single portable file — a zip of a manifest, human-readable JSON, and all attachments — that round-trips losslessly across devices and operating systems.

On top of that foundation sit the tools that make the data genuinely yours: per-entity CSV and combined JSON/XLSX export, a real import wizard with competitor presets and column mapping, merge-aware non-destructive restore with automatic pre-restore snapshots, a user-facing recycle bin with multi-step undo, safe versioned schema migrations with automatic rollback, and a full menu of backup targets — local, scheduled, SD-card, self-hosted (WebDAV/Nextcloud/SFTP), or strictly-opt-in cloud. No network is ever required, and no telemetry is ever sent.

## Features

### ✅ Must-have

- **Embedded on-device database** — All data lives in a local SQLite database running in WAL (write-ahead logging) mode for crash safety and concurrent reads, with no external database server and no network dependency.
- **Zero-network / airplane-mode guarantee** — Every core feature functions fully in airplane mode; connectivity is never a precondition for logging, viewing, exporting, or backing up.
- **No-account, local-only identity** — There is no signup and no login. The only identifier is a random per-install ID used internally for device attribution; it is never a user account and never leaves the device.
- **Stable UUID primary keys** — Every record carries a globally unique UUID so it can be merged, migrated, and re-imported without collisions or renumbering.
- **One-tap full backup to a single file** — A single action produces one portable zip containing a manifest, the combined JSON, and an `/attachments` folder — the complete, self-contained backup.
- **Backup manifest / metadata index** — The archive includes a manifest recording schema and app version, locale, unit system, currency, calendar, entity counts, the attachment list, and checksums, so any restore knows exactly what it is reading.
- **Human-readable combined JSON** — The backup's data payload is plain, inspectable JSON — not an opaque binary blob — so a technical user can read, diff, or recover it by hand if needed.
- **Attachments bundled and re-linked on restore** — Photos, receipts, PDFs, and clips travel inside the backup and are automatically re-linked to their parent records on restore, so nothing points at a dead file.
- **Complete restore with replace-or-merge choice** — Restoring offers an explicit choice between replacing the current dataset and merging into it, and always writes an automatic pre-restore snapshot first.
- **Pre-restore integrity verification & dry-run** — Before touching live data, the app verifies checksums, format version, and parseability and runs a dry-run so a corrupt or incompatible file is caught before anything changes.
- **Scheduled automatic local backups** — Daily or weekly local backups run automatically with no network involved, so a recent restore point always exists even if the user never remembers to make one.
- **Auto-snapshot before every risky operation** — Every import, restore, merge, and migration is preceded by an automatic snapshot, giving a guaranteed rollback point.
- **Crash-safe transactional writes & draft autosave** — Writes are transactional so a crash or kill never leaves a half-written record, and in-progress entries autosave as drafts.
- **Per-entity CSV export** — Fuel, expenses, service, reminders, trips, vehicles, and every other entity export to clean CSV for spreadsheets, accountants, or other tools.
- **Locale-aware CSV with embedded format** — CSV export formats numbers and dates for the user's locale but embeds the exact format used, so the same file re-imports unambiguously later.
- **Share via OS share sheet & Save-to-Files** — Exports and backups flow through the native share sheet and Save-to-Files (Android SAF / iOS Files), so they land wherever the user wants.
- **CSV import with column-mapping wizard** — Importing walks through mapping source columns to fields with a live sample preview, so messy third-party files map correctly before anything is committed.
- **Pre-import validation & preview** — The wizard shows valid/invalid row counts and the detected units, currency, and date format up front, so surprises surface before import, not after.
- **Import conflict & duplicate handling** — On collision the user chooses skip, overwrite, keep-both, or field-level merge, per the rules that keep re-imports idempotent.
- **Unit & currency normalization on import** — Imported data declares its units and currency explicitly and is normalized to canonical storage, so a US-gallon file and a litre file coexist correctly.
- **Device-to-device migration via file** — Moving to a new phone is a file transfer verified by checksum and record-count reconciliation, with no cloud and no account in the loop.
- **Explicit no-telemetry assurance surface** — A clear in-app statement confirms no analytics, tracking, or telemetry, with nothing to opt out of because nothing is collected.
- **Schema version tracking with ordered forward migrations** — The database records its schema version and applies ordered, forward-only migration scripts on upgrade.
- **Versioned, min-supported backup format** — Backups carry a format version and a minimum-supported version so compatibility is always explicit.
- **Migration failure automatic rollback** — If a schema migration fails, the app automatically rolls back to the pre-migration snapshot rather than leaving a broken database.
- **Attach media to any record** — Photos, receipts, and documents can be attached to any record across the app, all captured by the backup pipeline.
- **Fill flags preserved end-to-end** — Full-tank, partial, and missed-fill flags survive export, import, and merge intact, because consumption statistics silently break without them.
- **i18n-safe export** — Exports use UTF-8 with BOM, canonical Western digits, base SI units, and ISO-8601 dates, so files re-import losslessly regardless of the user's display preferences.
- **Canonical multi-unit / multi-currency model** — Data is stored in canonical units and a base currency with per-record overrides, so display preferences convert on the fly without ever rewriting history.
- **Recycle bin with restore and multi-step undo** — A user-facing trash holds deleted records for a retention window with restore and multi-step undo, so an accidental delete is recoverable.

### 🔵 Should-have

- **Soft-delete with tombstones** — Deletions leave tombstones so a merge or sync never resurrects a record the user intentionally removed.
- **Encrypted backup with passphrase** — Backups can be encrypted with a user passphrase using AES-256-GCM with an Argon2id/PBKDF2 key derivation and a stored hint.
- **Backup versioning & retention rotation** — Automatic backups keep the last N copies and rotate old ones out, balancing safety against storage.
- **Database integrity self-check & guided repair** — The app can run an integrity check and guide the user through repair or quarantine if the database is damaged.
- **Storage & low-space guard** — Before any write or backup, the app checks free space and warns rather than producing a truncated file.
- **Combined workbook export** — A single XLSX workbook (or zipped CSV bundle) exports every entity at once for accountants and power users.
- **Filtered / scoped export** — Exports can be scoped by vehicle, date range, category, or type, so the user shares exactly the slice they mean to.
- **Competitor import presets** — Built-in presets import from Fuelio, Drivvo, aCar, Fuelly, Fuel Log, Simply Auto, and MileIQ, with mapping and unit/locale detection tuned per source.
- **Atomic / resumable import with rollback** — Imports are atomic — an interrupted or failed import rolls back cleanly instead of leaving half the data in.
- **Merge two datasets without duplicates** — Datasets merge on UUID plus tombstone plus `updated_at`, so combining devices or files never creates duplicates or revives deletions.
- **Deterministic conflict resolution** — Conflicts resolve by a deterministic rule (last-write-wins by timestamp) with per-field manual override available when clocks disagree.
- **Self-hosted & SD-card backup targets** — Backups can target WebDAV, Nextcloud, or SFTP, and Android can auto-backup to an SD card — full ownership with no cloud provider involved.
- **Opt-in cloud backup** — The user may enable backup to Google Drive, iCloud, Dropbox, or OneDrive, but only by explicit, strictly opt-in choice; it is never default or forced.
- **Cloud / self-hosted restore picker** — A listing UI browses backups on the configured cloud or self-hosted target and restores the chosen one.
- **App lock (PIN) + biometric unlock** — An optional PIN plus biometric unlock protects the app, with the key held in the hardware keystore/keychain.
- **At-rest database encryption** — The database itself can be encrypted at rest via SQLCipher / AES-256 for privacy-first users.
- **Restore from older backup versions** — Older backups restore cleanly, mapping deprecated or renamed fields forward to the current schema.
- **Attachment compression, thumbnails & cleanup** — Attachments are compressed with generated thumbnails, integrity-checked, and swept for orphans to keep backups lean.
- **Localized-aware import parsing** — Import understands Eastern-Arabic/Persian/Devanagari digits, localized decimal, grouping, and list separators, and non-Gregorian dates.
- **Household peer-to-peer sync entry point** — A link into local peer-to-peer sync lets two devices on a shared car reconcile without any cloud (see Drivers & Household).
- **Selective vehicle share / sale-handoff export** — A single vehicle and its records can be exported for sharing or a sale handoff, cleanly separated from the rest of the garage.

### ⚪ Nice-to-have

- **Audit timestamps + local change history** — Optional per-record change history and an undo stack built on audit timestamps for fine-grained recovery.
- **Saved import mapping profiles** — Column-mapping choices can be saved as reusable profiles for repeat imports from the same source.
- **Offline local transfer** — Device-to-device transfer over QR code, Wi-Fi Direct, or NFC, with no file server or internet in between.
- **Secure wipe / panic reset** — A one-action secure wipe irreversibly clears all data for resale or emergencies.
- **Offline document scanner & on-device OCR** — An optional on-device scanner with OCR captures documents and receipts without ever uploading them.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `install_id` | text | Random per-install identifier; local-only, never an account |
| `entity_id` | uuid | Stable UUID primary key on every record |
| `created_at` | date | Audit timestamp, UTC/ISO-8601 |
| `updated_at` | date | Audit timestamp; drives last-write-wins merge |
| `device_origin_id` | text | Which device authored the row (for merge attribution) |
| `row_revision` | number | Monotonic revision counter per record |
| `is_deleted` | bool | Soft-delete tombstone flag |
| `deleted_at` | date | When the record was soft-deleted |
| `trash_expires_at` | date | When trash auto-purge removes it unless restored |
| `schema_version` | number | Current database schema version |
| `backup_format_version` | number | Version of the backup file format |
| `min_supported_version` | number | Oldest app/format version that can read this backup |
| `app_version` | text | App version that wrote the backup |
| `manifest` | array | Backup index: `{locale, unit_system, currency, calendar_system, entity_counts, attachment_list, checksums}` |
| `checksum_sha256` | text | SHA-256 of the backup archive |
| `includes_attachments` | bool | Whether attachments are bundled in this backup |
| `encryption` | array | `{cipher, kdf, salt, iterations, hint}` for encrypted backups |
| `attachment` | attachment | `{id, relative_path, mime_type, sha256, original_filename, linked_entity}` |
| `conflict_strategy` | enum | skip / overwrite / keep-both / field-merge |
| `dedupe_key` | text | `vehicle_id + odometer + date` for idempotent re-import |
| `column_map` | array | Import column-to-field mapping |
| `source_app` | enum | Origin app for import presets (Fuelio, Drivvo, aCar, …) |
| `detected_units` | enum | Units detected/declared on import |
| `detected_currency` | enum | Currency detected/declared on import |
| `detected_date_format` | text | Date format detected on import |
| `auto_backup` | array | `{enabled, frequency, dir, keep_last_n, last_run}` |
| `targets` | array | `{cloud{provider,folder,opt_in}, selfhosted{type,url,path}, sdcard{enabled,path}}` |

## Calculations & formulas

| Purpose | Formula / rule |
| --- | --- |
| Integrity | `SHA-256` checksum computed for the backup archive and for each attachment |
| Idempotent re-import | `dedupe_key = vehicle_id + odometer + date` |
| Merge conflict | Last-write-wins by `updated_at`, with field-level manual override when clocks are skewed |
| Schema migration | Ordered migration scripts run inside a transaction with a pre-migration snapshot |
| Space check | Estimated `backup + attachment size` compared against free space before writing |
| Encryption | `KDF (Argon2id / PBKDF2)` derives a key, then `AES-256-GCM` encrypts the backup |
| Trash purge | Records auto-purge after the retention window unless restored first |

## Offline & data

This module *is* the offline story. Every operation — logging, editing, backup, export, import, restore, merge, migration — runs entirely on the device with no network, no account, and no telemetry. Scheduled local backups and the recycle bin work in airplane mode, and self-hosted or SD-card targets give privacy-first users a complete backup regime that never touches a third-party cloud. Opt-in cloud backup exists for those who want it, but it is strictly an explicit choice layered on top of a system that is already whole without it.

For export, backup, and import, this module defines the canonical behavior the rest of the app relies on. Every entity's records, settings, reminders with their live state, and attachments are captured in the single-file backup, per-entity CSV, and combined JSON — with schema and format versioning, checksums, merge-aware restore, and trash/undo — so nothing is orphaned when the user migrates devices. Exports are written locale-neutral (UTF-8+BOM, Western digits, base SI units, ISO-8601 dates) precisely so they re-import losslessly regardless of display preferences.

## Localization & RTL

Correctness under localization is a data-integrity requirement here, not a cosmetic layer. All values are stored canonically — SI units, UTC/ISO-8601 dates, base currency — and localized only at display, and every export is written locale-neutral (Western digits, base units, ISO-8601, UTF-8 with BOM) so a file created under Persian display with the Jalali calendar re-imports identically under English display with the Gregorian calendar.

- **Numerals** — Import parsing accepts Western, Eastern-Arabic, Persian, and Devanagari digits; export always emits canonical Western digits for unambiguous round-trip.
- **Calendars** — Dates entered in Jalali/Shamsi, Hijri, or Hebrew calendars are stored as canonical UTC/ISO-8601 and converted for display; leap-year and month-length conversions are handled both directions.
- **Units** — US vs UK gallon and L/100km ↔ mpg are preserved losslessly via explicit unit declaration on export and import, never inferred or rounded away.
- **Currency** — With no live FX offline, multi-currency uses manual per-record rates; cross-currency totals are labeled rather than blindly summed, and the base currency stays canonical.
- **Separators** — Import detects and export embeds the exact locale format: decimal comma vs point, list separator `;` vs `,`, and DD/MM vs MM/DD ordering, including Indian lakh/crore grouping.
- **RTL & bidi** — Text stays bidi-safe in every CSV and PDF export; Persian/Arabic/Urdu normalization (ye/kaf/heh/ZWNJ) and Hebrew handling are applied on import matching, and identifiers like VIN and plate stay LTR-isolated.

## Edge cases

- **Fill flags must survive round-trip** — Full-tank/partial/missed flags are preserved through every export/import/merge, or consumption statistics silently break.
- **Odometer reset/rollover** — Odometer resets, rollovers, and km↔mi are kept canonical and monotonic so the reading ledger never regresses.
- **Out-of-order / backdated imports** — Backdated and out-of-order rows are validated on import rather than silently corrupting consumption math.
- **Dual-fuel / hybrid two-tank** — Per-fill tank and fuel-type are preserved for dual-fuel and two-tank hybrids.
- **US vs UK gallon** — Gallon variants and L/100km↔mpg round-trip losslessly through explicit unit declaration.
- **Multi-currency with no live FX** — Manual per-record rates are used; cross-currency totals are labeled, not blindly summed.
- **Locale CSV formats** — Decimal comma vs point, list separator `;` vs `,`, and DD/MM vs MM/DD are embedded exactly and detected on import.
- **RTL text in CSV/PDF** — Bidi mixing, UTF-8 BOM for Excel, and Eastern-Arabic vs Western vs Devanagari numerals are all handled in exports.
- **Non-Gregorian calendar entry** — Jalali/Hijri/Hebrew entries are stored canonical UTC/ISO with correct leap-year and month-length conversion both ways.
- **Timezone / DST** — Timestamps are stored in UTC and rendered in local time.
- **Large attachment libraries** — Big media libraries that bloat backups or exceed cloud limits are compressed and warned about, with self-hosted/SD-card paths offered for privacy-first users.
- **Corrupted / truncated backup** — Interrupted writes or a full disk are guarded by atomic writes and a checksum verified before any restore.
- **Newer-version backup on older app** — Restoring a newer-format backup onto an older app is refused safely with a clear message rather than corrupting data.
- **Duplicate / overlapping re-import** — Repeated or overlapping imports are deduped by the stable dedupe key.
- **Legacy non-UTF-8 files** — Non-UTF-8 source files are detected and re-decoded on import.
- **Emoji & numeric precision** — Emoji and special characters survive round-trip and numeric precision is preserved.
- **Reinstall / OS-to-OS migration** — Because app-private storage can be wiped on reinstall or OS migration, the app prompts early and keeps automatic local backups.
- **Scoped storage vs iOS sandbox** — Android scoped storage/SAF and the iOS sandbox are abstracted behind a single file layer.
- **Biometric change/removal** — A changed or removed biometric invalidates the hardware key, so a PIN/passphrase fallback always exists.
- **Forgotten passphrase** — A forgotten backup/encryption passphrase is unrecoverable; a hint field and an explicit irreversibility warning make that clear up front.
- **Deleting a vehicle with records** — Cascade vs tombstone is kept consistent in backups, and trash allows undo before purge.
- **Changing display units/currency mid-history** — Switching display units or currency never rewrites or reinterprets stored canonical values.

## Related features

- **[Settings & Preferences](./21-settings-preferences.md)** — Hosts the backup schedule, encryption, targets, app-lock, and no-telemetry controls this module implements.
- **[Drivers, Household & Sharing](./15-drivers-household.md)** — Consumes the merge engine and tombstone model for peer-to-peer local sync of a shared car.
- **[Canonical Data Model & Schema](../reference/data-model.md)** — Defines the UUIDs, audit timestamps, tombstones, and canonical units this module serializes and migrates.
- **[Localization, RTL & Calendars](./19-localization-rtl.md)** — Supplies the numeral, calendar, and bidi rules that keep exports locale-neutral and imports lossless.
- **[Accessibility & Inclusive Design](./20-accessibility.md)** — Pairs with i18n QA to validate the import wizard, restore flows, and warnings for all users.
- **[Sell, Dispose & Ownership Transfer](./24-sell-dispose.md)** — Uses the per-vehicle sale-handoff export and redaction to hand a clean record to the next owner.
