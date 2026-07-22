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
  /// Each **physical** blob is transformed at most once per pass — content
  /// de-dup means many rows share one file, so this dedups the work by path
  /// (a naive per-row loop would double-seal a shared blob and corrupt it).
  /// The current state is read from the BYTES (a valid, key-matching SealedBlob
  /// ⇒ already sealed), not a possibly-stale row flag, so the pass is idempotent
  /// and self-heals a half-done (crashed) migration. Returns rows re-flagged.
  Future<Result<int, Failure>> reencryptLibrary({
    required bool encrypt,
    void Function(int done, int total)? onProgress,
  }) async {
    final all = await repo.listAllLive();
    if (all case Err(:final failure)) return Err(failure);
    final rows = (all as Ok<List<Attachment>, DbFailure>).value;

    final key = await keyProvider();
    final processed = <String>{};
    var changed = 0;
    for (final att in rows) {
      final r1 = await _retarget(att.relativePath,
          encrypt: encrypt, key: key, done: processed);
      if (r1 case Err(:final failure)) return Err(failure);
      final thumb = att.thumbnailRelativePath;
      if (thumb != null) {
        final r2 =
            await _retarget(thumb, encrypt: encrypt, key: key, done: processed);
        if (r2 case Err(:final failure)) return Err(failure);
      }
      if (att.isEncrypted != encrypt) {
        final marked = await repo.markEncrypted(att.id, encrypted: encrypt);
        if (marked case Err(:final failure)) return Err(failure);
        changed++;
      }
      onProgress?.call(changed, rows.length);
    }
    return Ok(changed);
  }

  /// Bring ONE physical blob to the target sealed/plaintext state, exactly once
  /// per pass. The on-disk bytes decide the current state — a real sealed blob
  /// is one that both parses AND unseals under the key — so a shared blob is
  /// never double-transformed and a re-run after a crash converges.
  Future<Result<void, Failure>> _retarget(
    String path, {
    required bool encrypt,
    required List<int> key,
    required Set<String> done,
  }) async {
    if (!done.add(path)) return const Ok(null); // shared blob already handled

    final Uint8List raw;
    try {
      raw = await store.read(path);
    } on Object {
      return const Err(BlobNotFound());
    }

    final parsed = SealedBlob.fromBytes(raw);
    List<int>? plaintext;
    if (parsed != null) {
      final unsealed = await sealer.unseal(parsed, key);
      if (unsealed case Ok(:final value)) plaintext = value;
    }
    final isSealed = plaintext != null;

    if (encrypt) {
      if (isSealed) return const Ok(null); // already sealed
      await store.writeAt(path, (await sealer.seal(raw, key)).toBytes());
    } else {
      if (!isSealed) return const Ok(null); // already plaintext
      await store.writeAt(path, plaintext);
    }
    return const Ok(null);
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
}
