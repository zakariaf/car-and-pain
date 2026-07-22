import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security/security.dart';

// Fast Argon2 so the round-trip stays quick — the archive exercises the writer/
// reader, not the KDF (covered in the security suite).
const _fast = Argon2idParams.fast;

/// Seed a DB + store with a vehicle and one attachment; returns (vehicleId,
/// attachmentBlob, attachmentPath).
Future<({String vehicleId, Uint8List blob, String path})> _seed(
  AppDatabase db,
  AttachmentBlobStore store,
) async {
  final v = (await VehiclesRepository(db).add(nickname: 'Golf')).valueOrNull!;
  final blob = Uint8List.fromList(List.generate(64, (i) => (i * 5) % 256));
  final sha = contentSha256(blob);
  final path = await store.write(sha, blob);
  await AttachmentsRepository(db).add(
    linkedEntityType: AttachmentOwner.vehicle,
    linkedEntityId: v.id,
    sha256: sha,
    relativePath: path,
    mimeType: 'application/pdf',
    sizeBytes: blob.length,
  );
  return (vehicleId: v.id, blob: blob, path: path);
}

void main() {
  test('write → wipe → read → restore round-trips entities + attachments',
      () async {
    final db1 = AppDatabase.memory();
    addTearDown(db1.close);
    final store1 = InMemoryAttachmentBlobStore();
    final seed = await _seed(db1, store1);

    final engine1 = BackupEngine(db: db1, store: store1);
    final built = await engine1.writeArchive('correct horse', params: _fast);
    final bytes = (built as Ok<Uint8List, BackupFailure>).value;
    expect(bytes.length, greaterThan(8));

    // A fresh device: empty DB + empty store.
    final db2 = AppDatabase.memory();
    addTearDown(db2.close);
    final store2 = InMemoryAttachmentBlobStore();
    final engine2 = BackupEngine(db: db2, store: store2);

    final read = await engine2.readArchive(bytes, 'correct horse');
    final contents = (read as Ok<BackupContents, ImportFailure>).value;
    expect(contents.summary.entityCounts['vehicles'], 1);
    expect(contents.summary.attachmentCount, 1);

    expect((await engine2.restore(contents)).isOk, isTrue);

    // The vehicle is back…
    final vehicles = await VehiclesRepository(db2).watchAll().first;
    expect(vehicles.map((v) => v.nickname), ['Golf']);
    // …and the attachment row + blob re-link, byte-identical.
    final atts = (await AttachmentsRepository(db2)
            .listByOwner(AttachmentOwner.vehicle, seed.vehicleId))
        .valueOrNull!;
    expect(atts, hasLength(1));
    expect(await store2.read(atts.single.relativePath), seed.blob);
  });

  test('a failed restore (bad doc) leaves existing data intact', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final store = InMemoryAttachmentBlobStore();
    await _seed(db, store);
    final engine = BackupEngine(db: db, store: store);

    // A structurally-valid archive whose canonical doc is refused by import
    // (newer formatVersion) — restore must NOT wipe or mutate the live DB.
    final before =
        (await VehiclesRepository(db).watchAll().first).map((v) => v.nickname);
    final r = await engine.restore(const BackupContents(
      doc: {'formatVersion': 999, 'entities': <String, dynamic>{}},
      bundle: AttachmentBundle(entries: [], blobs: {}),
      summary: ArchiveSummary(
        createdAtUtcMillis: 0,
        entityCounts: {},
        attachmentCount: 0,
        totalAttachmentBytes: 0,
      ),
    ));
    expect((r as Err).failure, isA<SchemaVersionMismatch>());
    // Existing data is untouched — the refusal never mutated it.
    final after =
        (await VehiclesRepository(db).watchAll().first).map((v) => v.nickname);
    expect(after, before);
  });

  test('a wrong passphrase is refused as WrongBackupPassphrase', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final store = InMemoryAttachmentBlobStore();
    await _seed(db, store);
    final engine = BackupEngine(db: db, store: store);
    final bytes = (await engine.writeArchive('right', params: _fast) as Ok)
        .value as Uint8List;

    final r = await engine.readArchive(bytes, 'wrong');
    expect((r as Err).failure, isA<WrongBackupPassphrase>());
  });

  test('a tampered payload is caught by the digest before any crypto',
      () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final store = InMemoryAttachmentBlobStore();
    await _seed(db, store);
    final engine = BackupEngine(db: db, store: store);
    final bytes = (await engine.writeArchive('pw', params: _fast) as Ok).value
        as Uint8List;

    // Flip a byte in the sealed payload region (last byte).
    final tampered = Uint8List.fromList(bytes)..[bytes.length - 1] ^= 0xFF;
    final r = await engine.readArchive(tampered, 'pw');
    expect((r as Err).failure, isA<CorruptArchive>());
  });

  test('an archive from a newer format is refused, never applied', () {
    // Hand-build a v2 header over an arbitrary payload.
    final payload = Uint8List.fromList([1, 2, 3]);
    final header = ArchiveHeader(
      backupFormatVersion: 2, // newer than this build supports
      schemaVersion: 4,
      kdf: const ArchiveKdf(
          salt: [0], memory: 256, iterations: 1, parallelism: 1),
      payloadSha256: archiveSha256(payload),
    );
    final archive = assembleArchive(header, payload);
    final r = parseArchive(archive);
    expect((r as Err).failure, isA<SchemaVersionMismatch>());
  });

  test('garbage bytes are CorruptArchive, not a crash', () {
    expect((parseArchive(utf8.encode('not a backup')) as Err).failure,
        isA<CorruptArchive>());
    expect((parseArchive(const []) as Err).failure, isA<CorruptArchive>());
  });

  test('writeArchiveToFile writes atomically and verifies by re-open',
      () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final store = InMemoryAttachmentBlobStore();
    await _seed(db, store);
    final dir = Directory.systemTemp.createTempSync('cap_backup');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/backup.capb';

    final engine = BackupEngine(db: db, store: store);
    final r = await engine.writeArchiveToFile('pw', path, params: _fast);
    expect((r as Ok<String, BackupFailure>).value, path);
    expect(File(path).existsSync(), isTrue);
    expect(File('$path.tmp').existsSync(), isFalse); // temp cleaned by rename

    // The written file reads back and restores.
    final contents =
        (await engine.readArchive(await File(path).readAsBytes(), 'pw')
                as Ok<BackupContents, ImportFailure>)
            .value;
    expect(contents.summary.totalRecords, greaterThanOrEqualTo(1));
  });
}
