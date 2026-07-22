import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../attachments/attachment_providers.dart';

/// The backup engine over the live DB + attachment store.
final backupEngineProvider = Provider<BackupEngine>(
  (ref) => BackupEngine(
    db: ref.watch(appDatabaseProvider),
    store: ref.watch(attachmentBlobStoreProvider),
  ),
);

/// Which backup files a retention policy would prune (F6-T8): keep the newest
/// [keepLast] by name (timestamped filenames sort chronologically), delete the
/// rest — and NEVER the most recent, even if keepLast is 0. Pure + testable.
List<String> backupsToPrune(List<String> filenames, int keepLast) {
  if (filenames.length <= 1) return const [];
  final sorted = [...filenames]..sort((a, b) => b.compareTo(a)); // newest first
  final keep = keepLast < 1 ? 1 : keepLast;
  return sorted.skip(keep).toList();
}
