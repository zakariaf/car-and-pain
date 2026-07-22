import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'attachment_providers.dart';

part 'storage_controller.g.dart';

/// A snapshot of attachment storage usage + the at-rest encryption setting.
class StorageSnapshot {
  const StorageSnapshot({
    required this.total,
    required this.byType,
    required this.encrypt,
  });

  final ByteSize total;

  /// Bytes per owner type (`vehicle`, `fuel_entry`, …), largest first.
  final List<MapEntry<String, ByteSize>> byType;

  final bool encrypt;
}

/// Drives the Storage settings surface (F8-T8): the size roll-up, the at-rest
/// encryption toggle (which bulk-(un)seals the library), and the reclaim-space
/// GC action. Mutations refresh the snapshot live.
@riverpod
class StorageController extends _$StorageController {
  @override
  Future<StorageSnapshot> build() => _snapshot();

  Future<StorageSnapshot> _snapshot() async {
    final gc = ref.read(attachmentGcProvider);
    final total = await gc.totalBytes();
    final byType = await gc.bytesByOwnerType();
    final sorted = byType.entries
        .map((e) => MapEntry(e.key, ByteSize(e.value)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return StorageSnapshot(
      total: ByteSize(total),
      byType: sorted,
      encrypt: ref.read(attachmentEncryptionEnabledProvider),
    );
  }

  /// Toggle at-rest encryption: persist the setting and bulk-(un)seal existing
  /// blobs to match. Heavy on a large library (device QA); errors surface typed.
  Future<Result<void, Failure>> setEncrypt({required bool value}) async {
    final saved = await ref
        .read(settingsRepositoryProvider)
        .set(attachmentEncryptKey, value ? 'true' : null);
    if (saved case Err(:final failure)) return Err(failure);

    final reenc = await ref
        .read(attachmentServiceProvider)
        .reencryptLibrary(encrypt: value);
    if (reenc case Err(:final failure)) return Err(failure);

    state = AsyncData(await _snapshot());
    return const Ok(null);
  }

  /// What a reclaim sweep would remove, without deleting anything.
  Future<GcReport> previewReclaim() => ref.read(attachmentGcProvider).dryRun();

  /// Delete orphaned blobs past the trash window; refresh the roll-up.
  Future<GcReport> reclaim() async {
    final report = await ref.read(attachmentGcProvider).sweep();
    state = AsyncData(await _snapshot());
    return report;
  }
}
