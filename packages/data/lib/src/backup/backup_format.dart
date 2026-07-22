import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';

/// The Argon2id KDF descriptor stored (in the clear) in the archive header so a
/// reader can re-derive the passphrase KEK. Mirrors the flat `m/t/p` + salt
/// encoding the master-key envelope uses (one param vocabulary).
class ArchiveKdf {
  const ArchiveKdf({
    required this.salt,
    required this.memory,
    required this.iterations,
    required this.parallelism,
  });

  factory ArchiveKdf.fromJson(Map<String, dynamic> j) => ArchiveKdf(
        salt: base64.decode(j['salt'] as String),
        memory: j['m'] as int,
        iterations: j['t'] as int,
        parallelism: j['p'] as int,
      );

  final List<int> salt;
  final int memory;
  final int iterations;
  final int parallelism;

  Map<String, dynamic> toJson() => {
        'kdf': 'argon2id',
        'salt': base64.encode(salt),
        'm': memory,
        't': iterations,
        'p': parallelism,
      };
}

/// The archive header — plaintext, parsed BEFORE deriving the KEK. Carries the
/// format contract (versions), the DB schema version, the KDF descriptor, and a
/// digest of the sealed payload for fast "damaged backup" detection (F6-T4).
class ArchiveHeader {
  const ArchiveHeader({
    required this.schemaVersion,
    required this.kdf,
    required this.payloadSha256,
    this.backupFormatVersion = currentFormatVersion,
    this.minSupportedVersion = minReadableVersion,
  });

  factory ArchiveHeader.fromJson(Map<String, dynamic> j) => ArchiveHeader(
        backupFormatVersion: j['backupFormatVersion'] as int,
        minSupportedVersion: j['minSupportedVersion'] as int,
        schemaVersion: j['schemaVersion'] as int,
        kdf: ArchiveKdf.fromJson(j['kdf'] as Map<String, dynamic>),
        payloadSha256: j['payloadSha256'] as String,
      );

  /// The archive-container format version — independent of DB `schemaVersion`
  /// and of the payload cipher's own version.
  static const int currentFormatVersion = 1;

  /// The oldest container format this build can still read.
  static const int minReadableVersion = 1;

  final int backupFormatVersion;
  final int minSupportedVersion;
  final int schemaVersion;
  final ArchiveKdf kdf;
  final String payloadSha256;

  Map<String, dynamic> toJson() => {
        'backupFormatVersion': backupFormatVersion,
        'minSupportedVersion': minSupportedVersion,
        'schemaVersion': schemaVersion,
        'kdf': kdf.toJson(),
        'payloadSha256': payloadSha256,
      };
}

/// A read-time summary of what an unsealed archive holds — for the restore
/// preview (entity counts, attachment count + total bytes, when it was made).
class ArchiveSummary {
  const ArchiveSummary({
    required this.createdAtUtcMillis,
    required this.entityCounts,
    required this.attachmentCount,
    required this.totalAttachmentBytes,
  });

  final int createdAtUtcMillis;
  final Map<String, int> entityCounts;
  final int attachmentCount;
  final int totalAttachmentBytes;

  int get totalRecords => entityCounts.values.fold(0, (a, b) => a + b);
}

/// The 4-byte archive magic — 'CAPB' (Car And Pain Backup).
const List<int> archiveMagic = [0x43, 0x41, 0x50, 0x42];

/// Frame an archive: `[magic(4)][headerLen(4, big-endian)][header json][sealed]`.
Uint8List assembleArchive(ArchiveHeader header, List<int> sealedPayload) {
  final headerBytes = utf8.encode(jsonEncode(header.toJson()));
  final len = ByteData(4)..setUint32(0, headerBytes.length);
  return Uint8List.fromList([
    ...archiveMagic,
    ...len.buffer.asUint8List(),
    ...headerBytes,
    ...sealedPayload,
  ]);
}

/// The framed parts of a parsed archive.
typedef ParsedArchive = ({ArchiveHeader header, Uint8List sealedPayload});

/// The SHA-256 hex digest of [bytes] — the payload integrity check.
String archiveSha256(List<int> bytes) => sha256.convert(bytes).toString();

/// Parse + version-gate + integrity-check an archive's framing (does NOT unseal).
/// Refuses a newer-than-supported format and a payload-digest mismatch cleanly,
/// returning a typed [ImportFailure] and never touching any data.
Result<ParsedArchive, ImportFailure> parseArchive(List<int> bytes) {
  if (bytes.length < 8 || !_startsWith(bytes, archiveMagic)) {
    return const Err(CorruptArchive());
  }
  final headerLen =
      ByteData.sublistView(Uint8List.fromList(bytes.sublist(4, 8)))
          .getUint32(0);
  final headerEnd = 8 + headerLen;
  if (headerLen <= 0 || headerEnd > bytes.length) {
    return const Err(CorruptArchive());
  }

  final ArchiveHeader header;
  try {
    final map = jsonDecode(utf8.decode(bytes.sublist(8, headerEnd)))
        as Map<String, dynamic>;
    header = ArchiveHeader.fromJson(map);
  } on Object {
    return const Err(CorruptArchive());
  }

  // Version gate: refuse a container made by a newer build, or too old to read.
  if (header.backupFormatVersion > ArchiveHeader.currentFormatVersion) {
    return Err(SchemaVersionMismatch(
      expected: ArchiveHeader.currentFormatVersion,
      found: header.backupFormatVersion,
    ));
  }
  if (header.backupFormatVersion < ArchiveHeader.minReadableVersion) {
    return Err(SchemaVersionMismatch(
      expected: ArchiveHeader.minReadableVersion,
      found: header.backupFormatVersion,
    ));
  }

  final sealed = Uint8List.fromList(bytes.sublist(headerEnd));
  // Damaged-backup detection before any crypto: the payload must match its
  // recorded digest (catches truncation/bit-rot fast, as a localized error).
  if (archiveSha256(sealed) != header.payloadSha256) {
    return const Err(CorruptArchive());
  }
  return Ok((header: header, sealedPayload: sealed));
}

bool _startsWith(List<int> bytes, List<int> prefix) {
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}
