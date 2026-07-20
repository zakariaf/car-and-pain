import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../repositories/base_repository.dart';

/// One trashed row surfaced by the shared Trash across all entity types.
class TrashItem {
  const TrashItem({
    required this.entityType,
    required this.id,
    this.deletedAt,
    this.trashExpiresAt,
  });

  final String entityType;
  final String id;
  final int? deletedAt;
  final int? trashExpiresAt;

  @override
  bool operator ==(Object other) =>
      other is TrashItem &&
      other.entityType == entityType &&
      other.id == id &&
      other.deletedAt == deletedAt &&
      other.trashExpiresAt == trashExpiresAt;

  @override
  int get hashCode => Object.hash(entityType, id, deletedAt, trashExpiresAt);
}

/// The shared Trash across every soft-deleting entity: list, restore, and the
/// scheduled purge of expired tombstones. Table names are a fixed allowlist
/// (never user input), so the interpolated SQL is safe.
class TrashRepository extends BaseRepository {
  TrashRepository(super.db, {super.clock});

  static const List<String> trashedTables = [
    'vehicles',
    'fuel_entries',
    'service_entries',
    'expenses',
    'trips',
    'reminders',
  ];

  /// Every trashed row across entities, most-recently-deleted first.
  Future<Result<List<TrashItem>, DbFailure>> list() async {
    try {
      final items = <TrashItem>[];
      for (final table in trashedTables) {
        final rows = await db
            .customSelect(
              'SELECT id, deleted_at, trash_expires_at FROM $table '
              'WHERE is_deleted = 1',
            )
            .get();
        for (final r in rows) {
          items.add(
            TrashItem(
              entityType: table,
              id: r.read<String>('id'),
              deletedAt: r.read<int?>('deleted_at'),
              trashExpiresAt: r.read<int?>('trash_expires_at'),
            ),
          );
        }
      }
      items.sort((a, b) => (b.deletedAt ?? 0).compareTo(a.deletedAt ?? 0));
      return Ok(items);
    } on Object catch (e) {
      return Err(mapDbError(e));
    }
  }

  /// Restore a trashed row (clears the tombstone).
  Future<Result<void, DbFailure>> restore(String entityType, String id) async {
    if (!trashedTables.contains(entityType)) {
      return const Err(NotFound('entity'));
    }
    try {
      final now = nowMillis();
      final table =
          db.allTables.firstWhere((t) => t.actualTableName == entityType);
      // customUpdate (not customStatement) so Drift notifies the table's live
      // .watch() streams — an Undo/restore must refresh the UI. Bump
      // row_revision like every other write (documented invariant on
      // AuditColumns) so sync/merge metadata stays consistent.
      await db.customUpdate(
        'UPDATE $entityType SET is_deleted = 0, deleted_at = NULL, '
        'trash_expires_at = NULL, updated_at = ?, '
        'row_revision = row_revision + 1 WHERE id = ?',
        variables: [Variable.withInt(now), Variable.withString(id)],
        updates: {table},
      );
      return const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: entityType));
    }
  }

  /// Hard-delete tombstones past their retention window. Returns purged count.
  Future<Result<int, DbFailure>> purgeExpired() async {
    try {
      final now = nowMillis();
      var count = 0;
      await db.transaction(() async {
        for (final table in trashedTables) {
          final tableInfo =
              db.allTables.firstWhere((t) => t.actualTableName == table);
          count += await db.customUpdate(
            'DELETE FROM $table WHERE is_deleted = 1 '
            'AND trash_expires_at IS NOT NULL AND trash_expires_at < ?',
            variables: [Variable.withInt(now)],
            updates: {tableInfo},
            updateKind: UpdateKind.delete,
          );
        }
      });
      return Ok(count);
    } on Object catch (e) {
      return Err(mapDbError(e));
    }
  }
}
