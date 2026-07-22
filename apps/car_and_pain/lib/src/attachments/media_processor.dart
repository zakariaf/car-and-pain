import 'dart:typed_data';
import 'dart:ui' as ui;

/// A pure resize decision (F8-T3): the target dimensions that bound an image's
/// longest side to `maxDimension` while preserving aspect ratio. No decode — so
/// it's unit-tested directly.
class ImageResizePlan {
  const ImageResizePlan({
    required this.targetWidth,
    required this.targetHeight,
    required this.resized,
  });

  final int targetWidth;
  final int targetHeight;

  /// Whether any downscale was applied (false when already within bounds).
  final bool resized;

  static ImageResizePlan forSource({
    required int width,
    required int height,
    required int maxDimension,
  }) {
    final longest = width >= height ? width : height;
    if (longest <= maxDimension || longest == 0) {
      return ImageResizePlan(
        targetWidth: width,
        targetHeight: height,
        resized: false,
      );
    }
    final scale = maxDimension / longest;
    return ImageResizePlan(
      targetWidth: (width * scale).round().clamp(1, width),
      targetHeight: (height * scale).round().clamp(1, height),
      resized: true,
    );
  }
}

/// The processed image: a re-encoded, down-scaled, **EXIF-stripped** blob plus a
/// small thumbnail, with the final dimensions.
class ProcessedImage {
  const ProcessedImage({
    required this.bytes,
    required this.thumbnail,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final Uint8List thumbnail;
  final int width;
  final int height;
}

/// Turns staged image bytes into a bounded, thumbnailed, privacy-safe blob
/// (F8-T3). Decoding + scaling run on the engine's own IO/raster threads via
/// `dart:ui` (target-size codec), never on the Dart UI thread, so no manual
/// isolate is needed and the UI never janks. Re-encoding to PNG **drops all EXIF
/// metadata** — the privacy-conscious default (no silent location leakage).
///
/// Zero runtime dependency (built-in `dart:ui`). PNG is lossless, so for very
/// large photographic sources a native JPEG/WebP re-encode
/// (`flutter_image_compress`, conditionally sanctioned) would compress harder;
/// the dimension bound here is the primary size win. Video transcode + PDF
/// raster are out of scope (deferred, no ffmpeg) — see the epic notes.
class MediaProcessor {
  const MediaProcessor({
    this.maxDimension = 2048,
    this.thumbnailDimension = 320,
  });

  /// The longest-side bound for the stored image.
  final int maxDimension;

  /// The longest-side bound for the derived thumbnail.
  final int thumbnailDimension;

  Future<ProcessedImage> processImage(Uint8List input) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(input);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final srcW = descriptor.width;
    final srcH = descriptor.height;

    final full = ImageResizePlan.forSource(
      width: srcW,
      height: srcH,
      maxDimension: maxDimension,
    );
    final thumb = ImageResizePlan.forSource(
      width: srcW,
      height: srcH,
      maxDimension: thumbnailDimension,
    );

    final fullBytes = await _decodeToPng(descriptor, full);
    final thumbBytes = await _decodeToPng(descriptor, thumb);
    descriptor.dispose();

    return ProcessedImage(
      bytes: fullBytes,
      thumbnail: thumbBytes,
      width: full.targetWidth,
      height: full.targetHeight,
    );
  }

  Future<Uint8List> _decodeToPng(
    ui.ImageDescriptor descriptor,
    ImageResizePlan plan,
  ) async {
    // Target-size decode: the engine scales during decode on its IO thread.
    final codec = await descriptor.instantiateCodec(
      targetWidth: plan.targetWidth,
      targetHeight: plan.targetHeight,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    return data!.buffer.asUint8List();
  }
}
