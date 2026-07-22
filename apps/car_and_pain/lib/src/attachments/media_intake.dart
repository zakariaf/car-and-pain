import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// A staged file handed from intake to the pipeline — bytes buffered in memory
/// with an inferred MIME type and the original filename for export readability.
class StagedMedia {
  const StagedMedia({
    required this.bytes,
    required this.mimeType,
    this.filename,
  });

  final Uint8List bytes;
  final String mimeType;
  final String? filename;
}

/// The capture/import port (F8-T2). Injected so the pipeline is testable with a
/// fake; the real implementation drives `image_picker` (camera + gallery) and
/// `file_picker` (arbitrary files, the manual fallback). Nothing leaves the
/// device. Each method returns an empty result / null on cancel, never throws.
abstract interface class MediaIntake {
  /// Capture a single photo with the camera (may be unavailable → null).
  Future<StagedMedia?> capturePhoto();

  /// Pick one or more images from the photo library.
  Future<List<StagedMedia>> pickImages();

  /// The manual fallback — pick any file (PDF, etc.). Always available.
  Future<List<StagedMedia>> pickFiles();
}

/// Infer a MIME type from a filename extension. Unknown → octet-stream (which
/// the pipeline rejects as an unsupported type with a localized message).
String mimeForName(String? name) {
  final ext = name == null || !name.contains('.')
      ? ''
      : name.substring(name.lastIndexOf('.') + 1).toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' || 'heif' => 'image/heic',
    'pdf' => 'application/pdf',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    _ => 'application/octet-stream',
  };
}

/// The production intake over `image_picker` + `file_picker`. Device-only — the
/// pickers require platform UI, so this path is exercised in on-device QA
/// (TODO(F8): verify camera/gallery/file flows + permission denial on a device).
class PlatformMediaIntake implements MediaIntake {
  PlatformMediaIntake([ImagePicker? picker])
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<StagedMedia?> capturePhoto() async {
    final shot = await _picker.pickImage(source: ImageSource.camera);
    if (shot == null) return null;
    return StagedMedia(
      bytes: await shot.readAsBytes(),
      mimeType: mimeForName(shot.name),
      filename: shot.name,
    );
  }

  @override
  Future<List<StagedMedia>> pickImages() async {
    final shots = await _picker.pickMultiImage();
    return [
      for (final x in shots)
        StagedMedia(
          bytes: await x.readAsBytes(),
          mimeType: mimeForName(x.name),
          filename: x.name,
        ),
    ];
  }

  @override
  Future<List<StagedMedia>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true, // buffer bytes; large files are streamed by the plugin
    );
    if (result == null) return const [];
    return [
      for (final f in result.files)
        if (f.bytes != null)
          StagedMedia(
            bytes: f.bytes!,
            mimeType: mimeForName(f.name),
            filename: f.name,
          ),
    ];
  }
}

/// An in-memory intake for tests — returns preset media, no plugins.
class FakeMediaIntake implements MediaIntake {
  FakeMediaIntake({
    this.photo,
    this.images = const [],
    this.files = const [],
  });

  StagedMedia? photo;
  List<StagedMedia> images;
  List<StagedMedia> files;

  @override
  Future<StagedMedia?> capturePhoto() async => photo;

  @override
  Future<List<StagedMedia>> pickImages() async => images;

  @override
  Future<List<StagedMedia>> pickFiles() async => files;
}
