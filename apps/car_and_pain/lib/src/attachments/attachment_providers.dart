import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:security/security.dart';

import '../settings/locale_controller.dart';
import 'attachment_service.dart';
import 'media_intake.dart';

/// The persisted app setting key for at-rest attachment encryption.
const attachmentEncryptKey = 'attachments.encrypt_at_rest';

/// The app-private blob store over the resolved attachments directory.
final attachmentBlobStoreProvider = Provider<AttachmentBlobStore>(
  (ref) =>
      DirectoryAttachmentBlobStore(ref.watch(appDirsProvider).attachmentsDir),
);

final attachmentGcProvider = Provider<AttachmentGc>(
  (ref) => AttachmentGc(
    db: ref.watch(appDatabaseProvider),
    store: ref.watch(attachmentBlobStoreProvider),
  ),
);

final attachmentBundlerProvider = Provider<AttachmentBundler>(
  (ref) => AttachmentBundler(
    db: ref.watch(appDatabaseProvider),
    store: ref.watch(attachmentBlobStoreProvider),
  ),
);

/// The raw master key, read once from the keystore and cached (never per-blob).
final _masterKeyProvider = FutureProvider<List<int>>(
  (ref) async =>
      (await ref.watch(secureKeyStoreProvider).readAndUnwrapDbKey()).toList(),
);

/// Whether new attachment blobs are sealed at rest (persisted setting).
final attachmentEncryptionEnabledProvider = Provider<bool>((ref) {
  final map = ref.watch(settingsMapProvider).asData?.value ?? const {};
  return map[attachmentEncryptKey] == 'true';
});

/// The capture/import intake (camera + gallery + file fallback).
final mediaIntakeProvider =
    Provider<MediaIntake>((ref) => PlatformMediaIntake());

/// The attachment pipeline — process, seal, store, record.
final attachmentServiceProvider = Provider<AttachmentService>(
  (ref) => AttachmentService(
    repo: ref.watch(attachmentsRepositoryProvider),
    store: ref.watch(attachmentBlobStoreProvider),
    sealer: BlobSealer(),
    keyProvider: () => ref.read(_masterKeyProvider.future),
    encryptionEnabled: () => ref.read(attachmentEncryptionEnabledProvider),
  ),
);

/// A record's live attachments, push-updated on every change.
final attachmentsForOwnerProvider =
    StreamProvider.family<List<Attachment>, ({String type, String id})>(
  (ref, owner) => ref
      .watch(attachmentsRepositoryProvider)
      .watchByOwner(owner.type, owner.id),
);
