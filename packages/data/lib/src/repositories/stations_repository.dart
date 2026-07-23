import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'base_repository.dart';

/// The saved-stations library (M3-T9): a personal, fully-offline set of fuel/
/// charge stations the user can re-select. Emits the Drift row (a flat value
/// object with no child relations); returns a sealed `Result` at the boundary.
class StationsRepository extends BaseRepository {
  StationsRepository(super.db, {super.clock});

  /// All saved stations, name-ordered, tombstone-filtered — push-updated.
  Stream<List<SavedStationRow>> watchAll() {
    final query = db.select(db.savedStations)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch();
  }

  Future<Result<String, DbFailure>> add({
    required String name,
    String? brand,
    int? latMicro,
    int? lngMicro,
  }) async {
    try {
      final id = newId();
      final now = nowMillis();
      await db.into(db.savedStations).insert(SavedStationsCompanion.insert(
            id: id,
            name: name,
            createdAt: now,
            updatedAt: now,
            brand: Value(brand),
            latMicro: Value(latMicro),
            lngMicro: Value(lngMicro),
          ));
      return Ok(id);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'saved_stations'));
    }
  }

  /// Soft-delete a saved station (tombstone; never a hard delete).
  Future<Result<void, DbFailure>> softDelete(
    String id, {
    Duration retention = const Duration(days: 30),
  }) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.savedStations)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null || cur.isDeleted) return false;
        await (db.update(db.savedStations)..where((t) => t.id.equals(id)))
            .write(SavedStationsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          trashExpiresAt: Value(now + retention.inMilliseconds),
          updatedAt: Value(now),
          rowRevision: Value(cur.rowRevision + 1),
        ));
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('saved_station'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'saved_stations'));
    }
  }
}
