import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'trash_notifier.g.dart';

/// The current trash contents across every entity (re-fetched on demand).
@riverpod
Future<List<TrashItem>> trashItems(Ref ref) async {
  final result = await ref.watch(trashRepositoryProvider).list();
  return result.fold((items) => items, (_) => const <TrashItem>[]);
}

/// Commands for the Trash screen: restore an item and empty (purge) the trash.
@riverpod
class TrashController extends _$TrashController {
  @override
  FutureOr<void> build() {}

  Future<void> restore(String entityType, String id) async {
    await ref.read(trashRepositoryProvider).restore(entityType, id);
    ref.invalidate(trashItemsProvider);
  }

  Future<void> emptyTrash() async {
    await ref.read(trashRepositoryProvider).purgeExpired();
    ref.invalidate(trashItemsProvider);
  }
}
