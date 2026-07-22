import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The content-addressed app-private blob store (F8). Bytes never live in
/// SQLite; they are written under the attachments dir at a path derived from
/// their content hash. The store is a dumb path↔bytes port — hashing,
/// compression and sealing happen above it — so the bundler and GC can run
/// against an in-memory fake in host tests.
abstract interface class AttachmentBlobStore {
  /// Persist [bytes] content-addressed by [sha256] and return the app-private
  /// **relative** path where they now live. A derived blob (e.g. a thumbnail)
  /// passes a [suffix]; the on-disk [extension] is cosmetic.
  Future<String> write(
    String sha256,
    List<int> bytes, {
    String suffix = '',
    String extension = '',
  });

  Future<Uint8List> read(String relativePath);
  Future<bool> exists(String relativePath);
  Future<int> size(String relativePath);
  Future<void> delete(String relativePath);

  /// Every blob's relative path currently on disk — for orphan detection (T5).
  Future<List<String>> listAll();
}

/// The relative path a blob with [sha256] is stored at — a two-level shard
/// (`ab/cd/abcd…`) so no directory holds a runaway number of files.
String blobRelativePath(
  String sha256, {
  String suffix = '',
  String extension = '',
}) {
  final a = sha256.length >= 2 ? sha256.substring(0, 2) : '00';
  final b = sha256.length >= 4 ? sha256.substring(2, 4) : '00';
  return '$a/$b/$sha256$suffix$extension';
}

/// The SHA-256 hex digest of [bytes] — the content address + de-dup key.
String contentSha256(List<int> bytes) => sha256.convert(bytes).toString();

/// The production [AttachmentBlobStore] over a real app-private directory.
/// Device-only for the actual filesystem, but pure enough to test against a
/// temp dir on the host.
class DirectoryAttachmentBlobStore implements AttachmentBlobStore {
  DirectoryAttachmentBlobStore(this.rootDir);

  /// Absolute app-private root (typically `AppDirs.attachmentsDir`).
  final String rootDir;

  File _file(String relativePath) => File('$rootDir/$relativePath');

  @override
  Future<String> write(
    String sha256,
    List<int> bytes, {
    String suffix = '',
    String extension = '',
  }) async {
    final rel = blobRelativePath(sha256, suffix: suffix, extension: extension);
    final file = _file(rel);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return rel;
  }

  @override
  Future<Uint8List> read(String relativePath) =>
      _file(relativePath).readAsBytes();

  @override
  Future<bool> exists(String relativePath) async =>
      _file(relativePath).existsSync();

  @override
  Future<int> size(String relativePath) async =>
      _file(relativePath).lengthSync();

  @override
  Future<void> delete(String relativePath) async {
    final file = _file(relativePath);
    if (file.existsSync()) file.deleteSync();
  }

  @override
  Future<List<String>> listAll() async {
    final root = Directory(rootDir);
    if (!root.existsSync()) return const [];
    final prefix = rootDir.endsWith('/') ? rootDir : '$rootDir/';
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.startsWith(prefix)
            ? f.path.substring(prefix.length)
            : f.path)
        .toList();
  }
}

/// An in-memory [AttachmentBlobStore] for host tests — same path derivation as
/// the real store, no filesystem.
class InMemoryAttachmentBlobStore implements AttachmentBlobStore {
  final Map<String, Uint8List> _blobs = {};

  @override
  Future<String> write(
    String sha256,
    List<int> bytes, {
    String suffix = '',
    String extension = '',
  }) async {
    final rel = blobRelativePath(sha256, suffix: suffix, extension: extension);
    _blobs[rel] = Uint8List.fromList(bytes);
    return rel;
  }

  @override
  Future<Uint8List> read(String relativePath) {
    final b = _blobs[relativePath];
    if (b == null) throw const FileSystemException('blob not found');
    return Future.value(b);
  }

  @override
  Future<bool> exists(String relativePath) async =>
      _blobs.containsKey(relativePath);

  @override
  Future<int> size(String relativePath) async =>
      _blobs[relativePath]?.length ?? 0;

  @override
  Future<void> delete(String relativePath) async => _blobs.remove(relativePath);

  @override
  Future<List<String>> listAll() async => _blobs.keys.toList();
}
