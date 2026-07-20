import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../domain/vehicle.dart';
import 'base_repository.dart';

/// The hub repository. Emits [Vehicle] domain models (never Drift rows), exposes
/// a soft-delete-filtered `.watch()` stream, and returns `Result<T, DbFailure>`.
class VehiclesRepository extends BaseRepository {
  VehiclesRepository(super.db, {super.clock});

  Vehicle _toDomain(VehicleRow r) => Vehicle(
        id: r.id,
        nickname: r.nickname,
        make: r.make,
        model: r.model,
        vehicleType: r.vehicleType,
        status: r.status,
        currencyCode: r.currencyCode,
        isDefault: r.isDefault,
      );

  /// Active (non-trashed) vehicles, oldest first — push-updated on every write.
  Stream<List<Vehicle>> watchAll() {
    final query = db.select(db.vehicles)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => rows.map<Vehicle>(_toDomain).toList());
  }

  Future<Result<Vehicle?, DbFailure>> getById(String id) async {
    try {
      final row = await (db.select(db.vehicles)
            ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
          .getSingleOrNull();
      return Ok(row == null ? null : _toDomain(row));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'vehicles'));
    }
  }

  Future<Result<Vehicle, DbFailure>> add({
    required String nickname,
    String? make,
    String? model,
    String vehicleType = 'car',
    String? currencyCode,
  }) async {
    try {
      final now = nowMillis();
      final id = newId();
      await db.into(db.vehicles).insert(
            VehiclesCompanion.insert(
              id: id,
              nickname: nickname,
              createdAt: now,
              updatedAt: now,
              make: Value(make),
              model: Value(model),
              vehicleType: Value(vehicleType),
              currencyCode: Value(currencyCode),
            ),
          );
      final row = await (db.select(db.vehicles)..where((t) => t.id.equals(id)))
          .getSingle();
      return Ok(_toDomain(row));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'vehicles'));
    }
  }

  Future<Result<void, DbFailure>> rename(String id, String nickname) async {
    try {
      final now = nowMillis();
      final n = await (db.update(db.vehicles)..where((t) => t.id.equals(id)))
          .write(VehiclesCompanion(
              nickname: Value(nickname), updatedAt: Value(now)));
      return n == 0 ? const Err(NotFound('vehicle')) : const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'vehicles'));
    }
  }

  /// Optimistic soft-delete: tombstone the row with a retention window; it is
  /// never hard-deleted here. Excluded from every read until purged/restored.
  Future<Result<void, DbFailure>> softDelete(
    String id, {
    Duration retention = const Duration(days: 30),
  }) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.vehicles)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null) return false;
        await (db.update(db.vehicles)..where((t) => t.id.equals(id))).write(
          VehiclesCompanion(
            isDeleted: const Value(true),
            deletedAt: Value(now),
            trashExpiresAt: Value(now + retention.inMilliseconds),
            updatedAt: Value(now),
            rowRevision: Value(cur.rowRevision + 1),
          ),
        );
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('vehicle'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'vehicles'));
    }
  }

  /// Restore a trashed vehicle (clears the tombstone).
  Future<Result<void, DbFailure>> restore(String id) async {
    try {
      final now = nowMillis();
      final n =
          await (db.update(db.vehicles)..where((t) => t.id.equals(id))).write(
        VehiclesCompanion(
          isDeleted: const Value(false),
          deletedAt: const Value(null),
          trashExpiresAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      return n == 0 ? const Err(NotFound('vehicle')) : const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'vehicles'));
    }
  }
}
