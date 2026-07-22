import 'package:core/core.dart';

/// The broad media class of an attachment, derived from its MIME type — drives
/// thumbnail generation, viewer selection, and the redundant type icon + label.
enum AttachmentKind { image, pdf, video, other }

/// Well-known polymorphic owner types for `linked_entity_type` (F8-T1).
/// Attachments can hang off virtually any record; these are the launch owners
/// and the set is extensible — the column stays a plain discriminator string.
abstract final class AttachmentOwner {
  static const vehicle = 'vehicle';
  static const fuelEntry = 'fuel_entry';
  static const serviceEntry = 'service_entry';
  static const expense = 'expense';
  static const document = 'document';
  static const incident = 'incident';
}

/// A Drift-free attachment domain model (F8-T1) — polymorphic media metadata.
/// The bytes live app-private on disk (optionally sealed); this row carries only
/// the pointer (`relativePath`), the content-address (`sha256`), the owner link,
/// and accounting/display fields.
final class Attachment {
  const Attachment({
    required this.id,
    required this.linkedEntityType,
    required this.linkedEntityId,
    required this.sha256,
    required this.relativePath,
    required this.mimeType,
    required this.size,
    required this.refCount,
    required this.isEncrypted,
    required this.createdAt,
    this.thumbnailRelativePath,
    this.originalFilename,
  });

  final String id;
  final String linkedEntityType;
  final String linkedEntityId;

  /// PLAINTEXT content hash — the de-dup key and restore re-link key.
  final String sha256;

  /// App-private path to the (optionally sealed) blob.
  final String relativePath;

  /// App-private path to the derived thumbnail, when one exists.
  final String? thumbnailRelativePath;

  final String mimeType;
  final String? originalFilename;

  /// Plaintext content size.
  final ByteSize size;

  /// Shared-blob refcount — how many owners reference this content.
  final int refCount;

  /// Whether the on-disk blob is AES-GCM sealed with the master key.
  final bool isEncrypted;

  /// UTC epoch millis.
  final int createdAt;

  AttachmentKind get kind => kindForMime(mimeType);
  bool get hasThumbnail => thumbnailRelativePath != null;

  static AttachmentKind kindForMime(String mime) {
    final m = mime.toLowerCase();
    if (m.startsWith('image/')) return AttachmentKind.image;
    if (m == 'application/pdf') return AttachmentKind.pdf;
    if (m.startsWith('video/')) return AttachmentKind.video;
    return AttachmentKind.other;
  }

  @override
  bool operator ==(Object other) =>
      other is Attachment &&
      other.id == id &&
      other.linkedEntityType == linkedEntityType &&
      other.linkedEntityId == linkedEntityId &&
      other.sha256 == sha256 &&
      other.relativePath == relativePath &&
      other.thumbnailRelativePath == thumbnailRelativePath &&
      other.mimeType == mimeType &&
      other.originalFilename == originalFilename &&
      other.size == size &&
      other.refCount == refCount &&
      other.isEncrypted == isEncrypted &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        linkedEntityType,
        linkedEntityId,
        sha256,
        relativePath,
        thumbnailRelativePath,
        mimeType,
        originalFilename,
        size,
        refCount,
        isEncrypted,
        createdAt,
      );
}
