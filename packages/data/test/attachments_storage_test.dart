import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(int n, int fill) => Uint8List.fromList(List.filled(n, fill));

/// Seed a live attachment: write the blob to [store] and a matching row.
Future<Attachment> _seed(
  AttachmentsRepository repo,
  AttachmentBlobStore store, {
  required String owner,
  required Uint8List bytes,
  String type = AttachmentOwner.vehicle,
  String mime = 'image/jpeg',
  String? thumb,
}) async {
  final sha = contentSha256(bytes);
  final path = await store.write(sha, bytes);
  String? thumbPath;
  if (thumb != null) {
    thumbPath = await store.write(sha, _bytes(64, 9), suffix: '.thumb');
  }
  final r = await repo.add(
    linkedEntityType: type,
    linkedEntityId: owner,
    sha256: sha,
    relativePath: path,
    mimeType: mime,
    sizeBytes: bytes.length,
    thumbnailRelativePath: thumbPath,
  );
  return (r as Ok<Attachment, DbFailure>).value;
}

void main() {
  group('blob store', () {
    test('is content-addressed: same content → same sharded path', () async {
      final store = InMemoryAttachmentBlobStore();
      final bytes = _bytes(100, 7);
      final sha = contentSha256(bytes);
      final p1 = await store.write(sha, bytes);
      final p2 = await store.write(sha, bytes);
      expect(p1, p2);
      expect(p1, startsWith('${sha.substring(0, 2)}/${sha.substring(2, 4)}/'));
      expect(await store.read(p1), bytes);
      expect(await store.size(p1), 100);
    });

    test('DirectoryAttachmentBlobStore round-trips on a real temp dir',
        () async {
      final dir = Directory.systemTemp.createTempSync('cap_blob');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = DirectoryAttachmentBlobStore(dir.path);
      final bytes = _bytes(2048, 3);
      final path = await store.write(contentSha256(bytes), bytes);
      expect(await store.exists(path), isTrue);
      expect(await store.read(path), bytes);
      expect(await store.listAll(), contains(path));
      await store.delete(path);
      expect(await store.exists(path), isFalse);
    });
  });

  group('size roll-up + GC', () {
    late AppDatabase db;
    late AttachmentsRepository repo;
    late InMemoryAttachmentBlobStore store;
    late AttachmentGc gc;

    setUp(() {
      db = AppDatabase.memory();
      repo = AttachmentsRepository(db);
      store = InMemoryAttachmentBlobStore();
      gc = AttachmentGc(db: db, store: store);
    });
    tearDown(() => db.close());

    test('roll-ups total, per-owner and per-type over live rows', () async {
      await _seed(repo, store, owner: 'v1', bytes: _bytes(1000, 1));
      await _seed(repo, store, owner: 'v1', bytes: _bytes(500, 2));
      await _seed(
        repo,
        store,
        owner: 'f1',
        type: AttachmentOwner.fuelEntry,
        bytes: _bytes(300, 3),
      );

      expect(await gc.totalBytes(), 1800);
      expect(await gc.bytesByOwner(AttachmentOwner.vehicle, 'v1'), 1500);
      expect(await gc.bytesByOwnerType(), {
        AttachmentOwner.vehicle: 1500,
        AttachmentOwner.fuelEntry: 300,
      });
    });

    test('total counts a de-duped shared blob once, not per row', () async {
      // Two owners reference the SAME content (one physical blob, 1000 bytes).
      final bytes = _bytes(1000, 5);
      final sha = contentSha256(bytes);
      final path = await store.write(sha, bytes);
      for (final owner in ['v1', 'v2']) {
        await repo.add(
          linkedEntityType: AttachmentOwner.vehicle,
          linkedEntityId: owner,
          sha256: sha,
          relativePath: path,
          mimeType: 'application/pdf',
          sizeBytes: 1000,
        );
      }
      // Headline total reconciles with disk (one blob), not 2×.
      expect(await gc.totalBytes(), 1000);
      // Per-owner attribution stays logical (per row).
      expect(await gc.bytesByOwner(AttachmentOwner.vehicle, 'v1'), 1000);
    });

    test('orphan blobs (no row) are found and swept; totals reconcile',
        () async {
      final live = await _seed(repo, store, owner: 'v1', bytes: _bytes(200, 5));
      // A stray blob with no row.
      final orphanPath =
          await store.write(contentSha256(_bytes(50, 8)), _bytes(50, 8));

      final dry = await gc.dryRun();
      expect(dry.deletedBlobPaths, [orphanPath]);
      expect(dry.reclaimedBytes, 50);
      // Dry run touched nothing.
      expect(await store.exists(orphanPath), isTrue);

      final swept = await gc.sweep();
      expect(swept.deletedBlobPaths, [orphanPath]);
      expect(await store.exists(orphanPath), isFalse);
      // The live blob is untouched.
      expect(await store.exists(live.relativePath), isTrue);

      // Idempotent: a second sweep finds nothing.
      expect((await gc.sweep()).isEmpty, isTrue);
    });

    test('expired tombstones purge, then their blobs become collectable',
        () async {
      final t0 = DateTime.utc(2026);
      final seedRepo = AttachmentsRepository(db, clock: FixedClock(t0));
      final att =
          await _seed(seedRepo, store, owner: 'v1', bytes: _bytes(400, 4));
      await seedRepo.softDelete(att.id); // trash_expires_at = t0 + 30d

      // GC 31 days later: the tombstone is past grace.
      final laterGc = AttachmentGc(
        db: db,
        store: store,
        clock: FixedClock(t0.add(const Duration(days: 31))),
      );
      final report = await laterGc.sweep();
      expect(report.purgedRowIds, [att.id]);
      expect(report.deletedBlobPaths, [att.relativePath]);
      expect(await store.exists(att.relativePath), isFalse);
    });

    test('a within-grace tombstone keeps its blob', () async {
      final t0 = DateTime.utc(2026);
      final seedRepo = AttachmentsRepository(db, clock: FixedClock(t0));
      final att =
          await _seed(seedRepo, store, owner: 'v1', bytes: _bytes(400, 4));
      await seedRepo.softDelete(att.id);

      // Only 1 day later — still within the 30-day grace.
      final soonGc = AttachmentGc(
        db: db,
        store: store,
        clock: FixedClock(t0.add(const Duration(days: 1))),
      );
      expect((await soonGc.sweep()).isEmpty, isTrue);
      expect(await store.exists(att.relativePath), isTrue);
    });

    test("cascadeOwnerDeleted removes an owner's rows; sweep reclaims blobs",
        () async {
      final att = await _seed(repo, store, owner: 'v1', bytes: _bytes(600, 6));
      final removed =
          await gc.cascadeOwnerDeleted(AttachmentOwner.vehicle, 'v1');
      expect(removed, 1);
      expect((await repo.getById(att.id)).valueOrNull, isNull);

      final swept = await gc.sweep();
      expect(swept.deletedBlobPaths, [att.relativePath]);
    });
  });

  group('backup bundle round-trip (F8-T7)', () {
    late AppDatabase db;
    late AttachmentsRepository repo;

    setUp(() {
      db = AppDatabase.memory();
      repo = AttachmentsRepository(db);
    });
    tearDown(() => db.close());

    test('collect → restore is byte-identical, re-linked and orphan-free',
        () async {
      final source = InMemoryAttachmentBlobStore();
      final image = _bytes(1500, 1);
      final pdf = _bytes(3000, 2);
      final video = _bytes(9000, 3);
      final a =
          await _seed(repo, source, owner: 'v1', bytes: image, thumb: 't');
      final b = await _seed(repo, source,
          owner: 'v1', bytes: pdf, mime: 'application/pdf');
      final c = await _seed(repo, source,
          owner: 'f1',
          type: AttachmentOwner.fuelEntry,
          bytes: video,
          mime: 'video/mp4');

      final bundle = await AttachmentBundler(db: db, store: source).collect();
      expect(bundle.entries, hasLength(3));

      // Restore into a FRESH (empty) store = simulate a new device.
      final target = InMemoryAttachmentBlobStore();
      final result =
          await AttachmentBundler(db: db, store: target).restore(bundle);
      expect((result as Ok<int, ImportFailure>).value, 3);

      // Every blob is byte-identical and re-linked to its owner by UUID.
      for (final (att, bytes) in [(a, image), (b, pdf), (c, video)]) {
        final row = (await repo.getById(att.id)).valueOrNull!;
        expect(await target.read(row.relativePath), bytes);
      }
      // The video's owner link survived.
      final fuel = await repo.listByOwner(AttachmentOwner.fuelEntry, 'f1');
      expect(fuel.valueOrNull, hasLength(1));

      // Re-running GC on the restored store finds no orphans.
      final gc = AttachmentGc(db: db, store: target);
      expect((await gc.sweep()).isEmpty, isTrue);
    });

    test('an ENCRYPTED blob round-trips (verified by on-disk digest)',
        () async {
      // Simulate a sealed attachment: on-disk bytes (ciphertext) differ from the
      // plaintext, and the row is content-addressed by the PLAINTEXT sha.
      final source = InMemoryAttachmentBlobStore();
      final plaintext = _bytes(2000, 4);
      final ciphertext = _bytes(2040, 9); // stands in for SealedBlob.toBytes()
      final sha = contentSha256(plaintext);
      final path = await source.write(sha, ciphertext);
      final att = (await repo.add(
        linkedEntityType: AttachmentOwner.document,
        linkedEntityId: 'd1',
        sha256: sha,
        relativePath: path,
        mimeType: 'application/pdf',
        sizeBytes: plaintext.length,
        isEncrypted: true,
      ) as Ok<Attachment, DbFailure>)
          .value;

      final bundle = await AttachmentBundler(db: db, store: source).collect();
      final target = InMemoryAttachmentBlobStore();
      final result =
          await AttachmentBundler(db: db, store: target).restore(bundle);
      expect((result as Ok<int, ImportFailure>).value, 1);

      // The sealed bytes survive byte-identically and the row re-links.
      final row = (await repo.getById(att.id)).valueOrNull!;
      expect(await target.read(row.relativePath), ciphertext);
      expect(row.isEncrypted, isTrue);
    });

    test('a checksum mismatch is refused and writes nothing', () async {
      final source = InMemoryAttachmentBlobStore();
      final att =
          await _seed(repo, source, owner: 'v1', bytes: _bytes(1000, 7));
      final bundle = await AttachmentBundler(db: db, store: source).collect();

      // Corrupt the blob bytes in the bundle (checksum will no longer match).
      bundle.blobs[att.relativePath]![0] ^= 0xFF;

      final target = InMemoryAttachmentBlobStore();
      final result =
          await AttachmentBundler(db: db, store: target).restore(bundle);
      final failure = (result as Err<int, ImportFailure>).failure;
      expect(failure, isA<AttachmentChecksumMismatch>());
      expect((failure as AttachmentChecksumMismatch).attachmentId, att.id);
      // Nothing was materialised — corrupt media is never silently attached.
      expect(await target.listAll(), isEmpty);
    });
  });
}
