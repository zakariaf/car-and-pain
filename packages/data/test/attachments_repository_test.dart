import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AttachmentsRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = AttachmentsRepository(db);
  });
  tearDown(() => db.close());

  Future<Attachment> addFor(
    String ownerId, {
    String sha = 'sha-a',
    String mime = 'image/jpeg',
    int size = 1000,
    String? thumb,
    bool encrypted = false,
  }) async {
    final r = await repo.add(
      linkedEntityType: AttachmentOwner.vehicle,
      linkedEntityId: ownerId,
      sha256: sha,
      relativePath: 'blobs/$sha.bin',
      mimeType: mime,
      sizeBytes: size,
      thumbnailRelativePath: thumb,
      isEncrypted: encrypted,
    );
    return (r as Ok<Attachment, DbFailure>).value;
  }

  test('add stores content-address, size and kind; watch emits by owner',
      () async {
    final att = await addFor('v1', size: 4096, thumb: 'thumbs/x.jpg');
    expect(att.size, const ByteSize(4096));
    expect(att.kind, AttachmentKind.image);
    expect(att.hasThumbnail, isTrue);

    final live = await repo.watchByOwner(AttachmentOwner.vehicle, 'v1').first;
    expect(live, [att]);
    // A different owner sees nothing.
    expect(
        await repo.watchByOwner(AttachmentOwner.vehicle, 'v2').first, isEmpty);
  });

  test('mime type drives the media kind', () async {
    expect((await addFor('v1', sha: 's1', mime: 'application/pdf')).kind,
        AttachmentKind.pdf);
    expect((await addFor('v1', sha: 's2', mime: 'video/mp4')).kind,
        AttachmentKind.video);
    expect((await addFor('v1', sha: 's3', mime: 'text/plain')).kind,
        AttachmentKind.other);
  });

  test('findBySha returns a live match for dedup, null otherwise', () async {
    await addFor('v1', sha: 'shared');
    expect((await repo.findBySha('shared')).valueOrNull, isNotNull);
    expect((await repo.findBySha('missing')).valueOrNull, isNull);
  });

  test('refCount tracks how many live rows share a blob', () async {
    // Two records reference the SAME content (same sha) → refCount 2 on both.
    await addFor('v1', sha: 'shared');
    await addFor('v2', sha: 'shared');
    final v1 = await repo.watchByOwner(AttachmentOwner.vehicle, 'v1').first;
    final v2 = await repo.watchByOwner(AttachmentOwner.vehicle, 'v2').first;
    expect(v1.single.refCount, 2);
    expect(v2.single.refCount, 2);

    // Soft-deleting one drops the shared refCount to 1 for the survivor.
    await repo.softDelete(v1.single.id);
    final v2After =
        await repo.watchByOwner(AttachmentOwner.vehicle, 'v2').first;
    expect(v2After.single.refCount, 1);
  });

  test('soft-delete hides the row and is restorable', () async {
    final att = await addFor('v1');
    expect((await repo.softDelete(att.id)).isOk, isTrue);
    expect(
        await repo.watchByOwner(AttachmentOwner.vehicle, 'v1').first, isEmpty);
    expect((await repo.getById(att.id)).valueOrNull, isNull);

    expect((await repo.restore(att.id)).isOk, isTrue);
    expect((await repo.getById(att.id)).valueOrNull, isNotNull);
  });

  test('hard-delete removes the row entirely', () async {
    final att = await addFor('v1');
    expect((await repo.hardDelete(att.id)).isOk, isTrue);
    expect((await repo.getById(att.id)).valueOrNull, isNull);
    // Deleting again is NotFound.
    expect((await repo.hardDelete(att.id)).failureOrNull, isA<NotFound>());
  });

  test('soft-deleting a missing id is NotFound', () async {
    expect((await repo.softDelete('nope')).failureOrNull, isA<NotFound>());
  });

  test('listByOwner returns live rows oldest-first', () async {
    final a = await addFor('v1', sha: 's1');
    final b = await addFor('v1', sha: 's2');
    final list =
        (await repo.listByOwner(AttachmentOwner.vehicle, 'v1')).valueOrNull!;
    expect(list.map((x) => x.id), [a.id, b.id]);
  });
}
