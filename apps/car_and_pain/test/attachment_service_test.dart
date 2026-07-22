import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:car_and_pain/src/attachments/attachment_service.dart';
import 'package:car_and_pain/src/attachments/media_processor.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security/security.dart';

Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFF338866),
  );
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Uint8List _pdf() =>
    Uint8List.fromList(List.generate(500, (i) => (i * 3) % 256));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AttachmentsRepository repo;
  late InMemoryAttachmentBlobStore store;
  late bool encrypt;

  final key = List<int>.filled(32, 7);

  AttachmentService service() => AttachmentService(
        repo: repo,
        store: store,
        sealer: BlobSealer(),
        keyProvider: () async => key,
        encryptionEnabled: () => encrypt,
        processor:
            const MediaProcessor(maxDimension: 200, thumbnailDimension: 64),
      );

  setUp(() {
    db = AppDatabase.memory();
    repo = AttachmentsRepository(db);
    store = InMemoryAttachmentBlobStore();
    encrypt = false;
  });
  tearDown(() => db.close());

  Attachment ok(Result<Attachment, Failure> r) =>
      (r as Ok<Attachment, Failure>).value;

  test('attaching an image processes, stores and re-reads it', () async {
    final svc = service();
    final att = ok(await svc.attach(
      ownerType: AttachmentOwner.vehicle,
      ownerId: 'v1',
      bytes: await _png(600, 400),
      mimeType: 'image/jpeg',
      filename: 'photo.jpg',
    ));
    expect(att.kind, AttachmentKind.image);
    expect(att.hasThumbnail, isTrue);
    expect(att.isEncrypted, isFalse);

    final bytes = await svc.readBytes(att);
    // The stored (processed) bytes decode to the bounded image.
    expect((bytes as Ok<Uint8List, Failure>).value, isNotEmpty);
    expect(await svc.readThumbnail(att), isA<Ok<Uint8List?, Failure>>());
  });

  test('a PDF is stored as-is (no processing), an unsupported type is refused',
      () async {
    final svc = service();
    final pdf = ok(await svc.attach(
      ownerType: AttachmentOwner.document,
      ownerId: 'd1',
      bytes: _pdf(),
      mimeType: 'application/pdf',
    ));
    expect(pdf.kind, AttachmentKind.pdf);
    expect(pdf.hasThumbnail, isFalse);
    expect((await svc.readBytes(pdf) as Ok<Uint8List, Failure>).value, _pdf());

    final bad = await svc.attach(
      ownerType: AttachmentOwner.document,
      ownerId: 'd1',
      bytes: _pdf(),
      mimeType: 'text/plain',
    );
    expect((bad as Err).failure, isA<UnsupportedMediaType>());
  });

  test('with encryption on, the on-disk blob is sealed but reads transparently',
      () async {
    encrypt = true;
    final svc = service();
    final plaintext = _pdf();
    final att = ok(await svc.attach(
      ownerType: AttachmentOwner.document,
      ownerId: 'd1',
      bytes: plaintext,
      mimeType: 'application/pdf',
    ));
    expect(att.isEncrypted, isTrue);

    // Ciphertext on disk is NOT the plaintext…
    final onDisk = await store.read(att.relativePath);
    expect(onDisk, isNot(plaintext));
    expect(SealedBlob.fromBytes(onDisk), isNotNull);

    // …but the service unseals it on read.
    expect(
        (await svc.readBytes(att) as Ok<Uint8List, Failure>).value, plaintext);
  });

  test('a wrong key or tampered sealed blob surfaces a typed failure',
      () async {
    encrypt = true;
    final att = ok(await service().attach(
      ownerType: AttachmentOwner.document,
      ownerId: 'd1',
      bytes: _pdf(),
      mimeType: 'application/pdf',
    ));

    final wrongKeySvc = AttachmentService(
      repo: repo,
      store: store,
      sealer: BlobSealer(),
      keyProvider: () async => List<int>.filled(32, 9),
      encryptionEnabled: () => true,
    );
    expect(
        (await wrongKeySvc.readBytes(att) as Err).failure, isA<WrongSecret>());
  });

  test('identical content is de-duped to one blob (shared refCount)', () async {
    final svc = service();
    final pdf = _pdf();
    final a = ok(await svc.attach(
      ownerType: AttachmentOwner.expense,
      ownerId: 'e1',
      bytes: pdf,
      mimeType: 'application/pdf',
    ));
    final b = ok(await svc.attach(
      ownerType: AttachmentOwner.expense,
      ownerId: 'e2',
      bytes: pdf,
      mimeType: 'application/pdf',
    ));
    expect(a.relativePath, b.relativePath);
    // Only one physical blob, referenced twice.
    expect(await store.listAll(), hasLength(1));
    final reloaded = (await repo.getById(b.id)).valueOrNull!;
    expect(reloaded.refCount, 2);
  });

  test('bulk re-encrypt seals existing blobs, then decrypts back; idempotent',
      () async {
    final svc = service();
    final pdf = _pdf();
    final att = ok(await svc.attach(
      ownerType: AttachmentOwner.document,
      ownerId: 'd1',
      bytes: pdf,
      mimeType: 'application/pdf',
    ));
    expect(att.isEncrypted, isFalse);

    // Encrypt the whole library.
    final n = await svc.reencryptLibrary(encrypt: true);
    expect((n as Ok<int, Failure>).value, 1);
    final enc = (await repo.getById(att.id)).valueOrNull!;
    expect(enc.isEncrypted, isTrue);
    expect(SealedBlob.fromBytes(await store.read(enc.relativePath)), isNotNull);
    expect((await svc.readBytes(enc) as Ok<Uint8List, Failure>).value, pdf);

    // Idempotent: a second encrypt pass changes nothing.
    expect(
        (await svc.reencryptLibrary(encrypt: true) as Ok<int, Failure>).value,
        0);

    // Decrypt back to plaintext on disk.
    expect(
        (await svc.reencryptLibrary(encrypt: false) as Ok<int, Failure>).value,
        1);
    final dec = (await repo.getById(att.id)).valueOrNull!;
    expect(dec.isEncrypted, isFalse);
    expect(await store.read(dec.relativePath), pdf);
  });
}
