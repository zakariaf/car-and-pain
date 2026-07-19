# F8 · Attachments & media pipeline

> The cross-cutting media backbone: photos, receipts, scans, PDFs and dashcam clips attach polymorphically to any record, are compressed with thumbnails/transcode, stored app-private (optionally encrypted), size-accounted, orphan-cleaned, and bundled + re-linked through backup/restore.

## Goal

Every module in Car and Pain needs to hang media off its records — a fuel receipt, a service invoice PDF, a tire-tread photo, a registration scan, an accident dashcam clip. Rather than each feature re-inventing storage, this foundation epic delivers **one media backbone** that every entity links into polymorphically.

Concretely, F8 provides:

- A single `attachment` table with **polymorphic linkage** (`linked_entity_type` + `linked_entity_id`) so any record type can own zero-or-more attachments without schema churn per feature.
- **Capture & import** intake from camera, file picker and the OS share sheet (using the one small first-party-ish file/share access dependency), always with a manual fallback so the flow never dead-ends.
- **Compression, thumbnail generation and dashcam transcode** so originals never bloat the device: images are re-encoded and down-scaled, a thumbnail is derived for gallery/list rendering, and video clips are transcoded to a bounded profile — all into **app-private** storage outside any gallery/media-scanner reach.
- **Optional encryption at rest**: when the user enables at-rest encryption, blobs are sealed with the app master key (the same recoverable-by-default key hierarchy used by the DB), consistent with the security architecture.
- **Size accounting and orphan cleanup**: a per-vehicle / per-entity size roll-up so the user can see and reclaim space, plus deterministic orphan detection and garbage collection when the owning record is hard-deleted (post trash-retention).
- A **PULSE attachment viewer** — an RTL-aware, accessible gallery + PDF/image viewer with redundant (non-colour) status encoding.
- **Backup mapping hooks** so F6 (backup/export) can bundle the blobs into the single-file backup and **re-link** them on restore by checksum + storage ref, with round-trip tests proving nothing is lost or mis-attached.

This epic owns the storage, lifecycle and rendering of media; individual feature epics only declare "this record can have attachments" and call into F8.

## Tier & dependencies

- **Tier:** Foundation
- **Depends on:**
  - **F1** — data layer (Drift + encrypted SQLite, canonical model, soft-delete/trash, migrations) that the `attachment` table and its foreign links live in.
  - **F2** — security & encryption (master-key hierarchy, at-rest encryption toggle) that optional attachment encryption reuses.

Downstream, **F6** (backup / export / import) consumes F8's bundle + re-link hooks, and effectively every MVP and Tier-2/3 feature module (fuel, service, expenses, documents, tires, safety-incidents, etc.) attaches media through this backbone.

## References

- [docs/features/18-data-offline-backup.md](../../features/18-data-offline-backup.md)
- [docs/flutter/03-data-persistence.md](../../flutter/03-data-persistence.md)
- [docs/flutter/09-security-privacy.md](../../flutter/09-security-privacy.md)
- [docs/flutter/10-performance-rendering.md](../../flutter/10-performance-rendering.md)
- [docs/reference/data-model.md](../../reference/data-model.md)

## Tasks

### F8-T1 · Attachment table & polymorphic linkage

**Description**

Define the `attachment` Drift entity and its repository. Each row carries: a UUID primary key; polymorphic linkage (`linked_entity_type` enum + `linked_entity_id` UUID); a **storage ref** (relative app-private path or content-addressed key); `content_type`/kind (image/pdf/video/other); byte `size`; a content `checksum` (e.g. SHA-256) used for de-dup and restore re-linking; `thumbnail_ref`; encryption flag + nonce/IV metadata; `created_at`/`updated_at` (UTC) and soft-delete/trash fields consistent with F1. Repository enforces the canonical contract at the boundary and exposes typed `Result<T, Failure>` returns. Add a covering index on `(linked_entity_type, linked_entity_id)` and on `checksum`.

**Acceptance criteria**

- [ ] `attachment` table created with polymorphic `linked_entity_type` + `linked_entity_id`, `storage_ref`, `checksum`, `size`, `content_type`, `thumbnail_ref`, encryption metadata, UTC timestamps and soft-delete fields.
- [ ] Drift migration added and versioned; migration test proves upgrade from prior schema is non-destructive.
- [ ] Repository exposes create / read-by-owner / list / soft-delete / hard-delete returning sealed `Result` over the `Failure` hierarchy (no user strings).
- [ ] Indexes on `(linked_entity_type, linked_entity_id)` and `checksum` exist and are exercised by a query test.
- [ ] Reactive `watch`-by-owner stream returns attachments for a given record and updates on change.
- [ ] Checksum + size are computed and stored on insert; duplicate content (same checksum) is detectable.

**Size:** M
**Depends on:** F1
**Governing docs:** [data-persistence](../../flutter/03-data-persistence.md), [data-model](../../reference/data-model.md)

### F8-T2 · Capture & import

**Description**

Build the intake layer: capture from **camera**, pick from the **file system**, and receive from the OS **share sheet** (share-to-app), using the single small file/share access dependency sanctioned by the dependency policy. Normalise every intake into a staged temp file handed to the compression pipeline (F8-T3). Provide a **manual fallback** path (plain file pick) so the flow always completes even where camera/share is unavailable or permission-denied, with clear PULSE rationale copy. Respect the offline-first, no-telemetry stance — nothing leaves the device.

**Acceptance criteria**

- [ ] Camera capture, file pick and share-sheet ingest are wired and each yields a staged temp file.
- [ ] Permission requests carry PULSE rationale copy; denial degrades gracefully to the manual file-pick fallback rather than dead-ending.
- [ ] Multiple files can be imported in one action; each is queued to the pipeline.
- [ ] Ingest errors return typed `Failure`s and surface as accessible, localized PULSE error states.
- [ ] Unsupported types are rejected with a clear localized message; large files are streamed, not fully buffered in memory.
- [ ] No network egress occurs during capture/import (verified).

**Size:** M
**Depends on:** F8-T1
**Governing docs:** [data-persistence](../../flutter/03-data-persistence.md), [security-privacy](../../flutter/09-security-privacy.md)

### F8-T3 · Compression, thumbnails & transcode

**Description**

The processing pipeline that turns staged intake into stored assets. Images are re-encoded and down-scaled to a bounded max dimension/quality; a **thumbnail** is derived for list/gallery rendering; PDFs get a first-page thumbnail; dashcam **video is transcoded** to a bounded resolution/bitrate/codec profile to cap size. Processing runs off the UI isolate (heavy work in a background isolate) to keep the app responsive per the performance doc. Final assets are written to **app-private** storage (not the shared gallery / media store), and the resulting `storage_ref`, `thumbnail_ref`, `size` and `checksum` are persisted via F8-T1.

**Acceptance criteria**

- [ ] Images are compressed + down-scaled to configured bounds; output size is materially smaller than a typical original.
- [ ] A thumbnail is generated for images, PDFs (first page) and video (poster frame) and referenced from the row.
- [ ] Dashcam clips are transcoded to a bounded profile; over-budget originals are reduced, and a clip that cannot be transcoded fails safely with a typed `Failure`.
- [ ] All processing runs off the main isolate; a large batch does not jank the UI (verified against the performance-rendering guidance).
- [ ] Final blobs land in app-private storage, excluded from OS media scanners / backups-to-cloud.
- [ ] Original EXIF/location metadata is stripped or preserved per an explicit, privacy-conscious default (no silent location leakage).

**Size:** M
**Depends on:** F8-T1, F8-T2
**Governing docs:** [performance-rendering](../../flutter/10-performance-rendering.md), [data-persistence](../../flutter/03-data-persistence.md)

### F8-T4 · Optional encryption at rest

**Description**

When the user enables at-rest encryption, seal attachment blobs (and thumbnails) with the app **master key** from F2's recoverable-by-default hierarchy (AES-GCM, per-blob random nonce, authenticated). Store nonce/tag metadata alongside the row. Encryption is a per-install setting consistent with whole-DB encryption; toggling on encrypts existing blobs (migration/bulk pass), toggling semantics and key-loss warnings follow the security architecture. Decryption happens transparently at read time for the viewer and for backup bundling.

**Acceptance criteria**

- [ ] With encryption enabled, blobs + thumbnails are written AES-GCM sealed with a per-blob nonce; ciphertext on disk is unreadable without the master key.
- [ ] Encryption metadata (nonce/tag/flag) is persisted on the attachment row.
- [ ] The viewer and backup pipeline read blobs transparently via the key hierarchy; a missing/locked key returns a typed `Failure`, never a crash.
- [ ] Enabling encryption on an existing library bulk-encrypts prior blobs; the operation is resumable/atomic and reports progress.
- [ ] Encryption reuses F2's master key — no second key system is introduced.
- [ ] Tamper (bit-flip) on a sealed blob is detected via the GCM auth tag and reported as a typed integrity failure.

**Size:** M
**Depends on:** F8-T1, F8-T3, F2
**Governing docs:** [security-privacy](../../flutter/09-security-privacy.md), [data-persistence](../../flutter/03-data-persistence.md)

### F8-T5 · Size accounting & orphan cleanup

**Description**

Maintain a **size roll-up** — total attachment bytes per vehicle and per owning entity/type — surfaced to Settings/Storage so users can see and reclaim space. Implement **orphan detection**: blobs on disk with no live row, and rows whose owning record was hard-deleted past trash retention. Run **garbage collection** as an idempotent, safe sweep (only after trash-retention grace, never touching in-flight staging) that deletes orphaned blobs + thumbnails and reconciles the roll-up. GC is transactional and logs counts via typed results.

**Acceptance criteria**

- [ ] Per-vehicle and per-entity byte roll-ups are computed and query-fast (pre-aggregated or indexed), and update as attachments are added/removed.
- [ ] Orphan detection finds both disk-blobs-without-rows and rows-without-owner and lists them without deleting.
- [ ] GC deletes only true orphans past trash-retention grace; a dry-run reports what would be removed.
- [ ] GC is idempotent and safe to run repeatedly; concurrent capture is not corrupted.
- [ ] Hard-deleting an owning record cascades its attachments (blobs + thumbnails) and updates the roll-up.
- [ ] Roll-up totals reconcile exactly with on-disk usage in a round-trip test.

**Size:** S
**Depends on:** F8-T1, F8-T3
**Governing docs:** [data-persistence](../../flutter/03-data-persistence.md), [performance-rendering](../../flutter/10-performance-rendering.md)

### F8-T6 · Attachment viewer widget

**Description**

A reusable **PULSE** widget set: a thumbnail strip / gallery for a record's attachments, a full-screen image viewer (pinch-zoom, swipe between items) and an in-app **PDF viewer**, plus add/remove affordances routing into F8-T2/T5. Fully **RTL-aware** (mirrored layout, correct swipe direction, logical properties), **accessible** (Semantics labels, screen-reader order, minimum touch targets, reduced-motion honoured), and status **redundantly encoded** beyond colour (icon + label + shape) per PULSE. Loading/empty/error/encrypted-locked states are first-class.

**Acceptance criteria**

- [ ] Gallery renders thumbnails for a record; tapping opens the full-screen viewer with zoom + swipe.
- [ ] PDF and image types both render in-app; unsupported types show an accessible localized fallback with open-externally affordance.
- [ ] Layout mirrors correctly in RTL locales including swipe/paging direction; numerals/labels bidi-isolated.
- [ ] Every interactive element has a Semantics label; screen-reader traversal order is correct in LTR and RTL; touch targets meet the minimum.
- [ ] All status/type indicators use icon + label + shape, never colour alone.
- [ ] Loading, empty, error and encrypted-locked states are handled and localized.
- [ ] Reduced-motion setting suppresses non-essential transitions.

**Size:** M
**Depends on:** F8-T1, F8-T3
**Governing docs:** [performance-rendering](../../flutter/10-performance-rendering.md), [security-privacy](../../flutter/09-security-privacy.md)

### F8-T7 · Backup mapping & tests

**Description**

Provide the hooks F6 uses to include attachments in the single-file backup and to **re-link** them on restore. On export, enumerate live attachment rows, stream their (decrypted-then-rebundled or raw) blobs + thumbnails into the backup container with a manifest carrying `storage_ref`, `checksum`, `size` and owner linkage. On restore, materialise blobs into fresh app-private paths, re-write `storage_ref`, verify each `checksum`, and re-attach to the (possibly re-keyed) owning records by stable UUID. Deliver **round-trip tests**: a library with mixed image/PDF/video, encrypted and plain, backed up and restored, asserting byte-identical content, correct re-linkage and no orphans.

**Acceptance criteria**

- [ ] Export hook streams all live attachment blobs + thumbnails plus a manifest (ref, checksum, size, owner) into the backup container.
- [ ] Restore hook materialises blobs to new app-private paths, rewrites `storage_ref`, verifies checksums and re-links to owners by UUID.
- [ ] Checksum mismatch on restore is reported as a typed `Failure` and does not silently attach corrupt media.
- [ ] Round-trip test covers image + PDF + video, encrypted and plain, asserting byte-identical restore and correct owner linkage.
- [ ] Restore into a library with encryption enabled/disabled respects the target setting.
- [ ] No orphaned or double-linked attachments exist after a full backup→restore cycle (verified by size-accounting reconciliation from F8-T5).

**Size:** S
**Depends on:** F8-T1, F8-T5, F6
**Governing docs:** [data-offline-backup](../../features/18-data-offline-backup.md), [data-persistence](../../flutter/03-data-persistence.md)

### F8-T8 · i18n, error copy & storage settings surface

**Description**

_(Added for a complete vertical slice.)_ Wire all user-facing strings from the capture flow, viewer, storage roll-up and error states through gen-l10n ARB (en/de/fr + fa/ar/ckb), with correct plurals for counts ("N attachments", size units) and Eastern-Arabic/Persian numeral + separator formatting for sizes. Add the **Storage** surface in Settings/Preferences showing the per-vehicle/per-entity roll-up (F8-T5), an at-rest-encryption toggle entry point (F8-T4) and a "reclaim space" (run GC) action, all in PULSE.

**Acceptance criteria**

- [ ] Every attachment-facing string is localized in all six languages with no hardcoded literals; missing-key check passes in CI.
- [ ] Counts use ICU plurals and byte sizes format with locale-correct numerals, grouping and units.
- [ ] Storage settings surface shows roll-up, encryption toggle and reclaim-space action, RTL-mirrored and accessible.
- [ ] Reclaim-space action invokes GC dry-run then confirmed sweep with an accessible confirmation.

**Size:** S
**Depends on:** F8-T4, F8-T5, F8-T6
**Governing docs:** [security-privacy](../../flutter/09-security-privacy.md), [data-persistence](../../flutter/03-data-persistence.md)

## Definition of Done

- [ ] **Tests:** table-driven unit tests on checksum/size/dedup logic, compression/transcode bounds, orphan-GC idempotency and size reconciliation; widget tests on the viewer (LTR + RTL); and the F8-T7 backup→restore round-trip proving byte-identical, correctly-linked, orphan-free media (encrypted and plain). All green in CI under `flutter analyze` + `dart format --set-exit-if-changed`.
- [ ] **i18n complete:** all attachment/viewer/storage strings translated across en/de/fr/fa/ar/ckb with correct ICU plurals and locale numeral/size formatting; no hardcoded strings.
- [ ] **RTL verified:** viewer, gallery, storage surface and all dialogs mirror correctly (layout, swipe/paging direction, focus order), with numbers/units/IDs bidi-isolated.
- [ ] **Backup/export:** attachments are bundled into the single-file backup and re-linked on restore by checksum + UUID, verified by round-trip tests and consumed cleanly by F6.
- [ ] **Accessible per redundant-encoding rule:** all interactive elements carry Semantics labels with correct RTL reading order, touch targets meet the minimum, reduced-motion is honoured, and every status/type indicator is encoded by icon + label + shape (never colour alone).
- [ ] **Built-in-first & PULSE:** no new runtime dependency beyond the sanctioned small file/share access dep; encryption reuses F2's master key; all UI uses PULSE tokens/components; storage stays app-private and no telemetry/network egress is introduced.
