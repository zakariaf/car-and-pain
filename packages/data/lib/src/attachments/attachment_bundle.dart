import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'blob_store.dart';

/// One attachment's entry in the backup manifest (F8-T7) — the metadata F6's
/// container serializes alongside the blob bytes so restore can verify + re-link.
class AttachmentManifestEntry {
  const AttachmentManifestEntry({
    required this.id,
    required this.relativePath,
    required this.sha256,
    required this.storedSha256,
    required this.sizeBytes,
    required this.mimeType,
    required this.linkedEntityType,
    required this.linkedEntityId,
    this.thumbnailRelativePath,
  });

  factory AttachmentManifestEntry.fromJson(Map<String, dynamic> j) =>
      AttachmentManifestEntry(
        id: j['id'] as String,
        relativePath: j['relativePath'] as String,
        sha256: j['sha256'] as String,
        // Back-compat: an older manifest without the on-disk digest falls back
        // to the plaintext sha (correct for the un-encrypted case).
        storedSha256: (j['storedSha256'] ?? j['sha256']) as String,
        sizeBytes: j['sizeBytes'] as int,
        mimeType: j['mimeType'] as String,
        linkedEntityType: j['linkedEntityType'] as String,
        linkedEntityId: j['linkedEntityId'] as String,
        thumbnailRelativePath: j['thumbnailRelativePath'] as String?,
      );

  final String id;
  final String relativePath;

  /// The PLAINTEXT content hash — the content-address (drives the storage path)
  /// and the re-link/de-dup key. NOT what the on-disk bytes hash to when sealed.
  final String sha256;

  /// The hash of the EXACT bytes stored on disk (ciphertext when sealed) — the
  /// byte-level integrity check restore verifies against, so an encrypted blob
  /// verifies without needing the master key.
  final String storedSha256;

  final int sizeBytes;
  final String mimeType;
  final String linkedEntityType;
  final String linkedEntityId;
  final String? thumbnailRelativePath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'relativePath': relativePath,
        'sha256': sha256,
        'storedSha256': storedSha256,
        'sizeBytes': sizeBytes,
        'mimeType': mimeType,
        'linkedEntityType': linkedEntityType,
        'linkedEntityId': linkedEntityId,
        if (thumbnailRelativePath != null)
          'thumbnailRelativePath': thumbnailRelativePath,
      };
}

/// A collected attachment bundle: the manifest plus every blob's bytes keyed by
/// relative path (primary blobs + thumbnails). F6 streams these into the
/// single-file backup container.
class AttachmentBundle {
  const AttachmentBundle({required this.entries, required this.blobs});

  final List<AttachmentManifestEntry> entries;
  final Map<String, Uint8List> blobs;
}

/// Bundles attachment blobs for backup and re-links them on restore (F8-T7).
/// The container itself (zip, seal, verify-by-reopen) is F6's; this provides the
/// two pure hooks + their manifest contract, testable against an in-memory
/// store. Because blobs are content-addressed, the relative path is portable and
/// stable across a round-trip; restore verifies each blob's SHA-256 and refuses
/// corrupt media rather than silently attaching it.
class AttachmentBundler {
  AttachmentBundler({required this.db, required this.store});

  final AppDatabase db;
  final AttachmentBlobStore store;

  /// Collect every **live** attachment's manifest entry + blob bytes (primary
  /// and thumbnail). Tombstoned/orphaned media is excluded.
  Future<AttachmentBundle> collect() async {
    final rows = await (db.select(db.attachments)
          ..where((t) => t.isDeleted.equals(false)))
        .get();

    final entries = <AttachmentManifestEntry>[];
    final blobs = <String, Uint8List>{};
    for (final r in rows) {
      // A row whose blob file is missing is already broken/orphaned — skip it
      // rather than aborting the whole backup (GC reaps the dangling row).
      if (!await store.exists(r.relativePath)) continue;
      final raw = await store.read(r.relativePath);
      blobs[r.relativePath] = raw;
      final thumb = r.thumbnailRelativePath;
      if (thumb != null && await store.exists(thumb)) {
        blobs[thumb] = await store.read(thumb);
      }
      entries.add(
        AttachmentManifestEntry(
          id: r.id,
          relativePath: r.relativePath,
          sha256: r.sha256,
          storedSha256: contentSha256(raw),
          sizeBytes: r.sizeBytes,
          mimeType: r.mimeType,
          linkedEntityType: r.linkedEntityType,
          linkedEntityId: r.linkedEntityId,
          thumbnailRelativePath: thumb,
        ),
      );
    }
    return AttachmentBundle(entries: entries, blobs: blobs);
  }

  /// Materialise blobs from a bundle into the store and re-link the rows.
  ///
  /// Two-phase for safety: **verify every** primary blob's SHA-256 first — a
  /// single mismatch aborts with `AttachmentChecksumMismatch` and writes
  /// nothing — then write all blobs + rewrite each row's `relativePath` (re-link
  /// by the stable owner UUID, which never changed). Returns the count restored.
  Future<Result<int, ImportFailure>> restore(AttachmentBundle bundle) async {
    // Phase 1 — verify against the ON-DISK byte digest (not the plaintext sha),
    // so a sealed blob verifies without the master key. No side effects until
    // every checksum passes.
    for (final e in bundle.entries) {
      final bytes = bundle.blobs[e.relativePath];
      final found = bytes == null ? '' : contentSha256(bytes);
      if (found != e.storedSha256) {
        return Err(AttachmentChecksumMismatch(
          attachmentId: e.id,
          expected: e.storedSha256,
          found: found,
        ));
      }
    }

    // Phase 2 — materialise + re-link.
    for (final e in bundle.entries) {
      final path = await store.write(e.sha256, bundle.blobs[e.relativePath]!);
      String? thumbPath;
      final thumb = e.thumbnailRelativePath;
      if (thumb != null && bundle.blobs.containsKey(thumb)) {
        thumbPath = await store.write(
          e.sha256,
          bundle.blobs[thumb]!,
          suffix: '.thumb',
        );
      }
      await (db.update(db.attachments)..where((t) => t.id.equals(e.id))).write(
        AttachmentsCompanion(
          relativePath: Value(path),
          thumbnailRelativePath: Value(thumbPath),
        ),
      );
    }
    return Ok(bundle.entries.length);
  }
}
