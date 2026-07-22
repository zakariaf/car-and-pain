import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:security/security.dart';

import '../attachments/attachment_bundle.dart';
import '../attachments/blob_store.dart';
import '../db/app_database.dart';
import '../serialization/canonical_codec.dart';
import 'archive_cipher.dart';
import 'backup_format.dart';

/// The unsealed contents of a backup — ready to preview, merge, or restore.
class BackupContents {
  const BackupContents({
    required this.doc,
    required this.bundle,
    required this.summary,
  });

  /// The canonical [CanonicalCodec] document (all entity rows).
  final Map<String, dynamic> doc;

  /// The attachment entries + blob bytes (re-linked on restore by the bundler).
  final AttachmentBundle bundle;

  final ArchiveSummary summary;
}

/// Produces and consumes the single-file encrypted backup archive (F6-T1/T2/T4).
///
/// The archive payload is the canonical JSON document (every entity row) plus
/// the attachment blobs, AES-256-GCM-sealed under a passphrase-derived Argon2id
/// KEK. A JSON (not opaque-SQLite) payload is what lets the import wizard, merge
/// engine, and dry-run preview read a backup. Consistency comes from a WAL
/// checkpoint before the export; integrity from the payload digest (fast) + the
/// GCM tag (cryptographic) + per-attachment checksums (the F8 bundler).
class BackupEngine {
  BackupEngine({
    required this.db,
    required this.store,
    ArchiveCipher? cipher,
    Clock clock = const SystemClock(),
  })  : _cipher = cipher ?? ArchiveCipher(),
        _clock = clock;

  final AppDatabase db;
  final AttachmentBlobStore store;
  final ArchiveCipher _cipher;
  final Clock _clock;

  /// Seal the whole DB + attachments into an archive under [passphrase]. Runs a
  /// WAL checkpoint first for a consistent snapshot. Never throws across the
  /// edge — I/O or crypto failure returns a typed [BackupFailure].
  Future<Result<Uint8List, BackupFailure>> writeArchive(
    String passphrase, {
    Argon2idParams params = Argon2idParams.floor,
  }) async {
    try {
      await _checkpoint();
      final doc = await CanonicalCodec(db).export();
      final bundle = await AttachmentBundler(db: db, store: store).collect();

      final entities = doc['entities'] as Map<String, dynamic>;
      final payload = <String, dynamic>{
        'createdAtUtcMillis': _clock.nowUtc().millisecondsSinceEpoch,
        'entityCounts': {
          for (final e in entities.entries) e.key: (e.value as List).length,
        },
        'totalAttachmentBytes':
            bundle.blobs.values.fold<int>(0, (a, b) => a + b.length),
        'canonical': doc,
        'attachments': {
          'entries': [for (final e in bundle.entries) e.toJson()],
          'blobs': {
            for (final p in bundle.blobs.keys)
              p: base64.encode(bundle.blobs[p]!),
          },
        },
      };
      final payloadBytes = utf8.encode(jsonEncode(payload));

      final sealed = await _cipher.seal(payloadBytes, passphrase, params);
      final header = ArchiveHeader(
        schemaVersion: db.schemaVersion,
        kdf: ArchiveKdf(
          salt: sealed.salt,
          memory: params.memory,
          iterations: params.iterations,
          parallelism: params.parallelism,
        ),
        payloadSha256: archiveSha256(sealed.sealed),
      );
      return Ok(assembleArchive(header, sealed.sealed));
    } on Object {
      return const Err(BackupWriteFailed());
    }
  }

  /// Write an archive to [path] atomically (temp-then-rename) so a killed
  /// process never leaves a half-written, visible backup at the destination.
  Future<Result<String, BackupFailure>> writeArchiveToFile(
    String passphrase,
    String path, {
    Argon2idParams params = Argon2idParams.floor,
  }) async {
    final built = await writeArchive(passphrase, params: params);
    if (built case Err(:final failure)) return Err(failure);
    final bytes = (built as Ok<Uint8List, BackupFailure>).value;
    final tmp = '$path.tmp';
    try {
      final tmpFile = File(tmp);
      await tmpFile.parent.create(recursive: true);
      await tmpFile.writeAsBytes(bytes, flush: true);
      await tmpFile.rename(path); // atomic on the same filesystem
      // Verify-by-reopen: the just-written file must parse + digest-check.
      final reparsed = parseArchive(await File(path).readAsBytes());
      if (reparsed.isErr) return const Err(BackupVerifyFailed());
      return Ok(path);
    } on Object {
      try {
        final t = File(tmp);
        if (t.existsSync()) t.deleteSync();
      } on Object {
        // best-effort temp cleanup
      }
      return const Err(BackupWriteFailed());
    }
  }

  /// Parse + version-gate + unseal an archive under [passphrase] → its contents
  /// (no DB write). A wrong passphrase / tampered payload → [WrongBackupPassphrase];
  /// a newer format → [SchemaVersionMismatch]; malformed → [CorruptArchive].
  Future<Result<BackupContents, ImportFailure>> readArchive(
    List<int> bytes,
    String passphrase,
  ) async {
    final parsed = parseArchive(bytes);
    if (parsed case Err(:final failure)) return Err(failure);
    final p = (parsed as Ok<ParsedArchive, ImportFailure>).value;

    final params = Argon2idParams(
      memory: p.header.kdf.memory,
      iterations: p.header.kdf.iterations,
      parallelism: p.header.kdf.parallelism,
    );
    final unsealed = await _cipher.unseal(
        p.sealedPayload, passphrase, p.header.kdf.salt, params);
    if (unsealed case Err(:final failure)) {
      return Err(failure is WrongSecret
          ? const WrongBackupPassphrase()
          : const CorruptArchive());
    }
    final plain = (unsealed as Ok<List<int>, SecurityFailure>).value;

    try {
      final payload = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      final doc = payload['canonical'] as Map<String, dynamic>;
      final att = payload['attachments'] as Map<String, dynamic>;
      final entries = [
        for (final e in (att['entries'] as List).cast<Map<String, dynamic>>())
          AttachmentManifestEntry.fromJson(e),
      ];
      final blobs = <String, Uint8List>{
        for (final e in (att['blobs'] as Map<String, dynamic>).entries)
          e.key: base64.decode(e.value as String),
      };
      final summary = ArchiveSummary(
        createdAtUtcMillis: payload['createdAtUtcMillis'] as int,
        entityCounts: (payload['entityCounts'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
        attachmentCount: entries.length,
        totalAttachmentBytes: (payload['totalAttachmentBytes'] as int?) ?? 0,
      );
      return Ok(BackupContents(
        doc: doc,
        bundle: AttachmentBundle(entries: entries, blobs: blobs),
        summary: summary,
      ));
    } on Object {
      return const Err(CorruptArchive());
    }
  }

  /// Restore contents into the DB (destructive replace) + materialise blobs +
  /// re-link + orphan-clean. Guarded by a pre-restore snapshot that is restored
  /// on any failure — a refusal never leaves partially-mutated data.
  Future<Result<void, ImportFailure>> restore(BackupContents contents) async {
    final snapshotPath = await db.snapshotGuard?.take();
    var restored = false;
    try {
      final imported = await CanonicalCodec(db).import(contents.doc);
      if (imported case Err(:final failure)) {
        restored = await _rollback(snapshotPath);
        return Err(failure);
      }
      final relinked = await AttachmentBundler(db: db, store: store)
          .restore(contents.bundle);
      if (relinked case Err(:final failure)) {
        restored = await _rollback(snapshotPath);
        return Err(failure);
      }
      await _discardSnapshot(snapshotPath);
      return const Ok(null);
    } on Object {
      if (!restored) await _rollback(snapshotPath);
      return const Err(CorruptArchive());
    }
  }

  Future<bool> _rollback(String? snapshotPath) async {
    if (snapshotPath != null) await db.snapshotGuard?.restore(snapshotPath);
    return true;
  }

  Future<void> _discardSnapshot(String? snapshotPath) async {
    if (snapshotPath == null) return;
    try {
      final f = File(snapshotPath);
      if (f.existsSync()) f.deleteSync();
    } on Object {
      // best-effort
    }
  }

  Future<void> _checkpoint() async {
    try {
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    } on Object {
      // best-effort; an in-memory DB has no WAL to checkpoint
    }
  }
}
