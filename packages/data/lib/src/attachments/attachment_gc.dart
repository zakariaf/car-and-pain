import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'blob_store.dart';

/// What a garbage-collection pass removed (or would remove, on a dry run).
class GcReport {
  const GcReport({
    required this.purgedRowIds,
    required this.deletedBlobPaths,
    required this.reclaimedBytes,
  });

  const GcReport.empty()
      : purgedRowIds = const [],
        deletedBlobPaths = const [],
        reclaimedBytes = 0;

  /// Attachment rows hard-deleted (tombstones past trash retention).
  final List<String> purgedRowIds;

  /// Blob files deleted because no retained row referenced them.
  final List<String> deletedBlobPaths;

  /// Bytes reclaimed from disk by the deleted blobs.
  final int reclaimedBytes;

  bool get isEmpty => purgedRowIds.isEmpty && deletedBlobPaths.isEmpty;
}

/// Size accounting + orphan garbage collection for attachments (F8-T5).
///
/// Roll-ups are simple indexed SUMs over live rows. GC is an idempotent, safe
/// sweep: it first purges tombstoned rows past their trash-retention grace, then
/// deletes blob files that no *retained* row references (retained = live, or
/// tombstoned but still within its grace window). A dry run reports the same set
/// without touching anything. In-flight staging lives outside the store, so a
/// concurrent capture is never corrupted.
class AttachmentGc {
  AttachmentGc({
    required this.db,
    required this.store,
    Clock clock = const SystemClock(),
  }) : _clock = clock;

  final AppDatabase db;
  final AttachmentBlobStore store;
  final Clock _clock;

  int _now() => _clock.nowUtc().millisecondsSinceEpoch;

  // ── Size roll-up ──────────────────────────────────────────────────────────
  /// Total bytes of all live attachments.
  Future<int> totalBytes() => _sum(
        'SELECT COALESCE(SUM(size_bytes), 0) AS s '
        'FROM attachments WHERE is_deleted = 0',
      );

  /// Bytes of live attachments owned by one record.
  Future<int> bytesByOwner(String type, String id) => _sum(
        'SELECT COALESCE(SUM(size_bytes), 0) AS s FROM attachments '
        'WHERE is_deleted = 0 AND linked_entity_type = ? AND linked_entity_id = ?',
        [Variable<String>(type), Variable<String>(id)],
      );

  /// Bytes of live attachments grouped by owner type (for the Storage surface).
  Future<Map<String, int>> bytesByOwnerType() async {
    final rows = await db
        .customSelect(
          'SELECT linked_entity_type AS t, COALESCE(SUM(size_bytes), 0) AS s '
          'FROM attachments WHERE is_deleted = 0 GROUP BY linked_entity_type',
        )
        .get();
    return {
      for (final r in rows) r.read<String>('t'): r.read<int>('s'),
    };
  }

  Future<int> _sum(String sql, [List<Variable<Object>> vars = const []]) async {
    final r = await db.customSelect(sql, variables: vars).getSingle();
    return r.read<int>('s');
  }

  // ── Orphan cleanup ────────────────────────────────────────────────────────
  /// Hard-delete every attachment row for an owner record that was removed —
  /// the cascade an owning repository calls on hard-delete. Blob files are
  /// reclaimed by the next [sweep]. Returns the number of rows removed.
  Future<int> cascadeOwnerDeleted(String type, String id) => (db.delete(
        db.attachments,
      )..where((t) =>
              t.linkedEntityType.equals(type) & t.linkedEntityId.equals(id)))
          .go();

  /// Report what a [sweep] would remove, without deleting anything.
  Future<GcReport> dryRun() => _collect(apply: false);

  /// Purge expired tombstones + delete orphan blobs. Idempotent and safe to run
  /// repeatedly; a second immediate run reports nothing.
  Future<GcReport> sweep() => _collect(apply: true);

  Future<GcReport> _collect({required bool apply}) async {
    final now = _now();

    // 1. Rows whose trash-retention grace has expired → purgeable.
    final expired = await (db.select(db.attachments)
          ..where((t) =>
              t.isDeleted.equals(true) &
              t.trashExpiresAt.isNotNull() &
              t.trashExpiresAt.isSmallerOrEqualValue(now)))
        .get();
    final purgeIds = expired.map((r) => r.id).toList();
    if (apply && purgeIds.isNotEmpty) {
      await (db.delete(db.attachments)..where((t) => t.id.isIn(purgeIds))).go();
    }

    // 2. Retained rows = live, OR tombstoned but still within grace. After a
    //    real purge those are exactly the rows remaining; on a dry run we
    //    exclude the would-be-purged ids so the report matches a real sweep.
    final retained = await (db.select(db.attachments)
          ..where((t) =>
              t.isDeleted.equals(false) |
              (t.trashExpiresAt.isNotNull() &
                  t.trashExpiresAt.isBiggerThanValue(now))))
        .get();
    final referenced = <String>{
      for (final r in retained) ...[
        r.relativePath,
        if (r.thumbnailRelativePath != null) r.thumbnailRelativePath!,
      ],
    };

    // 3. Blobs on disk with no retained reference → orphans.
    final onDisk = await store.listAll();
    final orphans = onDisk.where((p) => !referenced.contains(p)).toList();

    var reclaimed = 0;
    final deleted = <String>[];
    for (final path in orphans) {
      reclaimed += await store.size(path);
      if (apply) await store.delete(path);
      deleted.add(path);
    }

    return GcReport(
      purgedRowIds: purgeIds,
      deletedBlobPaths: deleted,
      reclaimedBytes: reclaimed,
    );
  }
}
