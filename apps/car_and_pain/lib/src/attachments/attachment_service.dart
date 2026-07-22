import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:security/security.dart';

import 'media_processor.dart';

/// Supplies the raw 32-byte master key (from the keystore / an unlock). Cached
/// by the caller — never hit secure storage per blob.
typedef MasterKeyProvider = Future<List<int>> Function();

/// The app-side attachment pipeline (F8-T2→T4 coordination): process staged
/// bytes (image downscale + thumbnail), de-dup by content hash, optionally seal
/// at rest with the F7 master key, write to the app-private store, and record
/// the metadata row. Reads are transparent — sealed blobs are unsealed on the
/// way out. Pure over its ports (repo, store, sealer, key provider), so it's
/// host-testable with an in-memory store + a fake key.
class AttachmentService {
  AttachmentService({
    required this.repo,
    required this.store,
    required this.sealer,
    required this.keyProvider,
    required this.encryptionEnabled,
    this.processor = const MediaProcessor(),
  });

  final AttachmentsRepository repo;
  final AttachmentBlobStore store;
  final BlobSealer sealer;
  final MasterKeyProvider keyProvider;

  /// Whether new blobs are sealed at rest (the per-install setting).
  final bool Function() encryptionEnabled;
  final MediaProcessor processor;

  static const _supported = {
    AttachmentKind.image,
    AttachmentKind.pdf,
    AttachmentKind.video,
  };

  /// Attach staged [bytes] to an owner record. Images are downscaled +
  /// thumbnailed; PDFs/videos are stored as-is (poster/transcode deferred).
  /// Unsupported types are refused. Content is de-duped by plaintext SHA-256.
  Future<Result<Attachment, Failure>> attach({
    required String ownerType,
    required String ownerId,
    required Uint8List bytes,
    required String mimeType,
    String? filename,
  }) async {
    final kind = Attachment.kindForMime(mimeType);
    if (!_supported.contains(kind)) {
      return Err(UnsupportedMediaType(mimeType));
    }

    var primary = bytes;
    Uint8List? thumbnail;
    if (kind == AttachmentKind.image) {
      try {
        final processed = await processor.processImage(bytes);
        primary = processed.bytes;
        thumbnail = processed.thumbnail;
      } on Object {
        return const Err(MediaProcessingFailed());
      }
    }

    final sha = contentSha256(primary);

    // De-dup: reuse an already-stored blob for identical content.
    final existing = (await repo.findBySha(sha)).valueOrNull;
    final String relativePath;
    final String? thumbPath;
    final bool encrypted;
    if (existing != null) {
      relativePath = existing.relativePath;
      thumbPath = existing.thumbnailRelativePath;
      encrypted = existing.isEncrypted;
    } else {
      encrypted = encryptionEnabled();
      final key = encrypted ? await keyProvider() : null;
      relativePath = await _writeBlob(sha, primary, key);
      thumbPath = thumbnail == null
          ? null
          : await _writeBlob(sha, thumbnail, key, suffix: '.thumb');
    }

    return repo.add(
      linkedEntityType: ownerType,
      linkedEntityId: ownerId,
      sha256: sha,
      relativePath: relativePath,
      mimeType: mimeType,
      sizeBytes: primary.length,
      thumbnailRelativePath: thumbPath,
      originalFilename: filename,
      isEncrypted: encrypted,
    );
  }

  /// Read an attachment's plaintext bytes, unsealing transparently. A missing or
  /// wrong key, or a tampered blob, returns a typed failure — never a crash.
  Future<Result<Uint8List, Failure>> readBytes(Attachment att) =>
      _readPath(att.relativePath, att.isEncrypted);

  /// Read the thumbnail bytes (unsealed), or null when there is none.
  Future<Result<Uint8List?, Failure>> readThumbnail(Attachment att) async {
    final path = att.thumbnailRelativePath;
    if (path == null) return const Ok(null);
    final r = await _readPath(path, att.isEncrypted);
    return switch (r) {
      Ok(:final value) => Ok(value),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<Uint8List, Failure>> _readPath(
    String relativePath,
    bool encrypted,
  ) async {
    final Uint8List raw;
    try {
      raw = await store.read(relativePath);
    } on Object {
      return const Err(BlobNotFound());
    }
    if (!encrypted) return Ok(raw);
    final blob = SealedBlob.fromBytes(raw);
    if (blob == null) return const Err(EnvelopeCorrupt());
    final unsealed = await sealer.unseal(blob, await keyProvider());
    return switch (unsealed) {
      Ok(:final value) => Ok(Uint8List.fromList(value)),
      Err(:final failure) => Err(failure),
    };
  }

  /// Bulk (de)encrypt the whole library to match the target setting (F8-T4).
  /// Idempotent — rows already in the target state are skipped — and reports
  /// progress via [onProgress]. Each blob is transformed then flagged; because
  /// a `SealedBlob` is self-describing, a crash mid-migration is recoverable by
  /// a reconciliation pass (on-device QA). Returns the number of rows changed.
  Future<Result<int, Failure>> reencryptLibrary({
    required bool encrypt,
    void Function(int done, int total)? onProgress,
  }) async {
    final all = await repo.listAllLive();
    if (all case Err(:final failure)) return Err(failure);
    final rows = (all as Ok<List<Attachment>, DbFailure>)
        .value
        .where((a) => a.isEncrypted != encrypt)
        .toList();

    final key = await keyProvider();
    var done = 0;
    for (final att in rows) {
      final plain = await readBytes(att);
      if (plain case Err(:final failure)) return Err(failure);
      final bytes = (plain as Ok<Uint8List, Failure>).value;

      await _rewriteBlob(att.sha256, bytes, att.relativePath, encrypt, key);
      final thumbPath = att.thumbnailRelativePath;
      if (thumbPath != null) {
        final t = await _readPath(thumbPath, att.isEncrypted);
        if (t case Ok(:final value)) {
          await _rewriteBlob(att.sha256, value, thumbPath, encrypt, key);
        }
      }
      final marked = await repo.markEncrypted(att.id, encrypted: encrypt);
      if (marked case Err(:final failure)) return Err(failure);
      onProgress?.call(++done, rows.length);
    }
    return Ok(rows.length);
  }

  Future<String> _writeBlob(
    String sha,
    Uint8List bytes,
    List<int>? key, {
    String suffix = '',
  }) async {
    final toStore =
        key == null ? bytes : (await sealer.seal(bytes, key)).toBytes();
    return store.write(sha, toStore, suffix: suffix);
  }

  Future<void> _rewriteBlob(
    String sha,
    Uint8List plaintext,
    String path,
    bool encrypt,
    List<int> key,
  ) async {
    final bytes =
        encrypt ? (await sealer.seal(plaintext, key)).toBytes() : plaintext;
    // Content-addressed → same path; overwrite in place.
    await store.write(sha, bytes,
        suffix: path.endsWith('.thumb') ? '.thumb' : '');
  }
}
