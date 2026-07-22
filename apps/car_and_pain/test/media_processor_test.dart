import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:car_and_pain/src/attachments/media_processor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _makePng(int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // A two-tone image so downscaling has real content to filter.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFF2266AA),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w / 2, h / 2),
    Paint()..color = const Color(0xFFEE8844),
  );
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageResizePlan', () {
    test('leaves an already-small image unresized', () {
      final p = ImageResizePlan.forSource(
          width: 800, height: 600, maxDimension: 2048);
      expect(p.resized, isFalse);
      expect(p.targetWidth, 800);
      expect(p.targetHeight, 600);
    });

    test('bounds the longest side of a landscape image, keeping aspect', () {
      final p = ImageResizePlan.forSource(
          width: 4000, height: 3000, maxDimension: 2000);
      expect(p.resized, isTrue);
      expect(p.targetWidth, 2000);
      expect(p.targetHeight, 1500);
    });

    test('bounds a portrait image by its height', () {
      final p = ImageResizePlan.forSource(
          width: 1500, height: 3000, maxDimension: 1000);
      expect(p.targetHeight, 1000);
      expect(p.targetWidth, 500);
    });

    test('never produces a zero dimension', () {
      final p =
          ImageResizePlan.forSource(width: 4000, height: 4, maxDimension: 100);
      expect(p.targetWidth, 100);
      expect(p.targetHeight, greaterThanOrEqualTo(1));
    });
  });

  group('MediaProcessor', () {
    test('downscales to the bound and derives a smaller thumbnail', () async {
      final source = await _makePng(1000, 800);
      const processor =
          MediaProcessor(maxDimension: 400, thumbnailDimension: 200);
      final result = await processor.processImage(source);

      // Stored image is bounded to 400 on its longest side, aspect preserved.
      expect(result.width, 400);
      expect(result.height, 320);

      // The thumbnail decodes to a smaller image than the stored blob.
      final thumb = await _decodedSize(result.thumbnail);
      expect(thumb.$1, lessThanOrEqualTo(200));
      expect(result.thumbnail.length, lessThan(result.bytes.length));

      // Output is valid PNG (decodes back to the target dimensions).
      final full = await _decodedSize(result.bytes);
      expect(full, (400, 320));
    });

    test('re-encodes even an in-bounds image (EXIF strip)', () async {
      final source = await _makePng(300, 300);
      const processor = MediaProcessor();
      final result = await processor.processImage(source);
      expect(result.width, 300);
      expect(await _decodedSize(result.bytes), (300, 300));
    });
  });
}

Future<(int, int)> _decodedSize(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  return (frame.image.width, frame.image.height);
}
