import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../domain/vehicle.dart';
import 'base_repository.dart';

/// A pending edit to a vehicle's profile — every field is optional; absent means
/// "leave unchanged". Keeps the update surface explicit without leaking a Drift
/// companion to callers.
class VehicleEdit {
  const VehicleEdit({
    this.nickname,
    this.make,
    this.model,
    this.trim,
    this.modelYear,
    this.vehicleType,
    this.energyType,
    this.secondaryEnergyType,
    this.vin,
    this.vinScanned,
    this.vinChecksumValid,
    this.wmiDecoded,
    this.licensePlate,
    this.plateCountry,
    this.tankCapacityMl,
    this.secondaryTankMl,
    this.fuelGrade,
    this.batteryCapacityJoules,
    this.usableCapacityJoules,
    this.connectorTypes,
    this.distanceUnit,
    this.volumeUnit,
    this.consumptionUnit,
    this.currencyCode,
    this.distanceTrackingEnabled,
    this.groupId,
    this.tags,
    this.sortOrder,
    this.coverPhotoRef,
  });

  final String? nickname;
  final String? make;
  final String? model;
  final String? trim;
  final int? modelYear;
  final String? vehicleType;
  final String? energyType;
  final String? secondaryEnergyType;
  final String? vin;
  final bool? vinScanned;
  final bool? vinChecksumValid;
  final String? wmiDecoded;
  final String? licensePlate;
  final String? plateCountry;
  final int? tankCapacityMl;
  final int? secondaryTankMl;
  final String? fuelGrade;
  final int? batteryCapacityJoules;
  final int? usableCapacityJoules;
  final String? connectorTypes;
  final String? distanceUnit;
  final String? volumeUnit;
  final String? consumptionUnit;
  final String? currencyCode;
  final bool? distanceTrackingEnabled;
  final String? groupId;
  final List<String>? tags;
  final int? sortOrder;
  final String? coverPhotoRef;
}

/// The hub repository. Emits [Vehicle] domain models (never Drift rows), exposes
/// soft-delete-filtered `.watch()` streams, and returns `Result<T, DbFailure>`.
class VehiclesRepository extends BaseRepository {
  VehiclesRepository(super.db, {super.clock});

  static List<String> _splitTags(String? raw) =>
      (raw ?? '').split(',').where((s) => s.isNotEmpty).toList();

  static String? _joinTags(List<String>? tags) =>
      (tags == null || tags.isEmpty) ? null : tags.join(',');

  Vehicle _toDomain(VehicleRow r) => Vehicle(
        id: r.id,
        nickname: r.nickname,
        make: r.make,
        model: r.model,
        trim: r.trim,
        modelYear: r.modelYear,
        vehicleType: r.vehicleType,
        energyType: r.energyType,
        secondaryEnergyType: r.secondaryEnergyType,
        status: r.status,
        vin: r.vin,
        vinChecksumValid: r.vinChecksumValid,
        licensePlate: r.licensePlate,
        plateCountry: r.plateCountry,
        tankCapacityMl: r.tankCapacityMl,
        secondaryTankMl: r.secondaryTankMl,
        fuelGrade: r.fuelGrade,
        batteryCapacityJoules: r.batteryCapacityJoules,
        usableCapacityJoules: r.usableCapacityJoules,
        connectorTypes: r.connectorTypes,
        distanceUnit: r.distanceUnit,
        volumeUnit: r.volumeUnit,
        consumptionUnit: r.consumptionUnit,
        currencyCode: r.currencyCode,
        distanceTrackingEnabled: r.distanceTrackingEnabled,
        groupId: r.groupId,
        tags: _splitTags(r.tags),
        sortOrder: r.sortOrder,
        coverPhotoRef: r.coverPhotoRef,
        isDefault: r.isDefault,
      );

  /// The whole garage — every non-trashed vehicle (active and non-active alike),
  /// by manual sort order then age. Non-active vehicles stay visible here;
  /// active-scope filtering happens above the repository.
  Stream<List<Vehicle>> watchGarage() {
    final query = db.select(db.vehicles)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    return query.watch().map((rows) => rows.map<Vehicle>(_toDomain).toList());
  }

  /// A single vehicle's live stream (null once trashed/removed).
  Stream<Vehicle?> watchVehicle(String id) {
    final query = db.select(db.vehicles)
      ..where((t) => t.id.equals(id) & t.isDeleted.equals(false));
    return query
        .watchSingleOrNull()
        .map((r) => r == null ? null : _toDomain(r));
  }

  /// Active (non-trashed) vehicles — retained for the M1 scope providers.
  Stream<List<Vehicle>> watchAll() => watchGarage();

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

  /// Apply a partial [VehicleEdit]. Absent fields are left unchanged (M2 never
  /// needs to clear a scalar to null through this path). Bumps `updated_at` +
  /// `row_revision` transactionally.
  Future<Result<void, DbFailure>> update(String id, VehicleEdit e) async {
    try {
      final now = nowMillis();
      final companion = VehiclesCompanion(
        updatedAt: Value(now),
        nickname:
            e.nickname == null ? const Value.absent() : Value(e.nickname!),
        make: e.make == null ? const Value.absent() : Value(e.make),
        model: e.model == null ? const Value.absent() : Value(e.model),
        trim: e.trim == null ? const Value.absent() : Value(e.trim),
        modelYear:
            e.modelYear == null ? const Value.absent() : Value(e.modelYear),
        vehicleType: e.vehicleType == null
            ? const Value.absent()
            : Value(e.vehicleType!),
        energyType:
            e.energyType == null ? const Value.absent() : Value(e.energyType),
        secondaryEnergyType: e.secondaryEnergyType == null
            ? const Value.absent()
            : Value(e.secondaryEnergyType),
        vin: e.vin == null ? const Value.absent() : Value(e.vin),
        vinScanned:
            e.vinScanned == null ? const Value.absent() : Value(e.vinScanned!),
        vinChecksumValid: e.vinChecksumValid == null
            ? const Value.absent()
            : Value(e.vinChecksumValid),
        wmiDecoded:
            e.wmiDecoded == null ? const Value.absent() : Value(e.wmiDecoded),
        licensePlate: e.licensePlate == null
            ? const Value.absent()
            : Value(e.licensePlate),
        plateCountry: e.plateCountry == null
            ? const Value.absent()
            : Value(e.plateCountry),
        tankCapacityMl: e.tankCapacityMl == null
            ? const Value.absent()
            : Value(e.tankCapacityMl),
        secondaryTankMl: e.secondaryTankMl == null
            ? const Value.absent()
            : Value(e.secondaryTankMl),
        fuelGrade:
            e.fuelGrade == null ? const Value.absent() : Value(e.fuelGrade),
        batteryCapacityJoules: e.batteryCapacityJoules == null
            ? const Value.absent()
            : Value(e.batteryCapacityJoules),
        usableCapacityJoules: e.usableCapacityJoules == null
            ? const Value.absent()
            : Value(e.usableCapacityJoules),
        connectorTypes: e.connectorTypes == null
            ? const Value.absent()
            : Value(e.connectorTypes),
        distanceUnit: e.distanceUnit == null
            ? const Value.absent()
            : Value(e.distanceUnit),
        volumeUnit:
            e.volumeUnit == null ? const Value.absent() : Value(e.volumeUnit),
        consumptionUnit: e.consumptionUnit == null
            ? const Value.absent()
            : Value(e.consumptionUnit),
        currencyCode: e.currencyCode == null
            ? const Value.absent()
            : Value(e.currencyCode),
        distanceTrackingEnabled: e.distanceTrackingEnabled == null
            ? const Value.absent()
            : Value(e.distanceTrackingEnabled!),
        groupId: e.groupId == null ? const Value.absent() : Value(e.groupId),
        tags: e.tags == null ? const Value.absent() : Value(_joinTags(e.tags)),
        sortOrder:
            e.sortOrder == null ? const Value.absent() : Value(e.sortOrder),
        coverPhotoRef: e.coverPhotoRef == null
            ? const Value.absent()
            : Value(e.coverPhotoRef),
      );
      final found = await db.transaction(() async {
        final cur = await (db.select(db.vehicles)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null) return false;
        await (db.update(db.vehicles)..where((t) => t.id.equals(id))).write(
          companion.copyWith(rowRevision: Value(cur.rowRevision + 1)),
        );
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('vehicle'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'vehicles'));
    }
  }

  /// Set the lifecycle [status] (active/archived/sold/scrapped/stolen/
  /// written_off), stamping `status_changed_at` and, for a disposal, the
  /// close-out fields.
  Future<Result<void, DbFailure>> setStatus(
    String id,
    String status, {
    int? soldDateMillis,
    int? soldPriceMinor,
    int? finalOdometerMetres,
  }) async {
    try {
      final now = nowMillis();
      final n =
          await (db.update(db.vehicles)..where((t) => t.id.equals(id))).write(
        VehiclesCompanion(
          status: Value(status),
          statusChangedAt: Value(now),
          soldDate: soldDateMillis == null
              ? const Value.absent()
              : Value(soldDateMillis),
          soldPriceMinor: soldPriceMinor == null
              ? const Value.absent()
              : Value(soldPriceMinor),
          finalOdometerMetres: finalOdometerMetres == null
              ? const Value.absent()
              : Value(finalOdometerMetres),
          updatedAt: Value(now),
        ),
      );
      return n == 0 ? const Err(NotFound('vehicle')) : const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'vehicles'));
    }
  }

  /// Pin exactly one default vehicle (clears any prior pin in the same write).
  Future<Result<void, DbFailure>> setDefault(String id) async {
    try {
      final now = nowMillis();
      await db.transaction(() async {
        await (db.update(db.vehicles)..where((t) => t.isDefault.equals(true)))
            .write(VehiclesCompanion(
                isDefault: const Value(false), updatedAt: Value(now)));
        await (db.update(db.vehicles)..where((t) => t.id.equals(id))).write(
            VehiclesCompanion(
                isDefault: const Value(true), updatedAt: Value(now)));
      });
      return const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'vehicles'));
    }
  }

  /// Permanently delete a vehicle and cascade its children (plate/valuation/SoH
  /// history + ledger) via the FK `onDelete: cascade`. Irreversible.
  Future<Result<void, DbFailure>> purge(String id) async {
    try {
      final n =
          await (db.delete(db.vehicles)..where((t) => t.id.equals(id))).go();
      return n == 0 ? const Err(NotFound('vehicle')) : const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'vehicles'));
    }
  }

  // ── Child tables (normalized, joined by vehicle_id) ─────────────────────────

  Stream<List<PlateHistoryRow>> watchPlateHistory(String vehicleId) =>
      (db.select(db.plateHistory)
            ..where((t) =>
                t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.fromDate)]))
          .watch();

  Future<Result<void, DbFailure>> addPlateHistory(
    String vehicleId, {
    required String plate,
    String? country,
    int? fromDate,
    int? toDate,
  }) =>
      _insertChild(() {
        final now = nowMillis();
        return db.into(db.plateHistory).insert(PlateHistoryCompanion.insert(
              id: newId(),
              vehicleId: vehicleId,
              plate: plate,
              createdAt: now,
              updatedAt: now,
              country: Value(country),
              fromDate: Value(fromDate),
              toDate: Value(toDate),
            ));
      });

  Stream<List<ValuationRow>> watchValuations(String vehicleId) =>
      (db.select(db.valuationHistory)
            ..where((t) =>
                t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.valuedAt)]))
          .watch();

  Future<Result<void, DbFailure>> addValuation(
    String vehicleId, {
    required int valuedAt,
    required int amountMinor,
    required String currencyCode,
    String? source,
  }) =>
      _insertChild(() {
        final now = nowMillis();
        return db
            .into(db.valuationHistory)
            .insert(ValuationHistoryCompanion.insert(
              id: newId(),
              vehicleId: vehicleId,
              valuedAt: valuedAt,
              amountMinor: amountMinor,
              currencyCode: currencyCode,
              createdAt: now,
              updatedAt: now,
              source: Value(source),
            ));
      });

  Stream<List<StateOfHealthRow>> watchStateOfHealth(String vehicleId) =>
      (db.select(db.stateOfHealthLog)
            ..where((t) =>
                t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.recordedAt)]))
          .watch();

  Future<Result<void, DbFailure>> addStateOfHealth(
    String vehicleId, {
    required int recordedAt,
    required int sohPermille,
    String? note,
  }) =>
      _insertChild(() {
        final now = nowMillis();
        return db
            .into(db.stateOfHealthLog)
            .insert(StateOfHealthLogCompanion.insert(
              id: newId(),
              vehicleId: vehicleId,
              recordedAt: recordedAt,
              sohPermille: sohPermille,
              createdAt: now,
              updatedAt: now,
              note: Value(note),
            ));
      });

  Future<Result<void, DbFailure>> _insertChild(
    Future<void> Function() insert,
  ) async {
    try {
      await insert();
      return const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'vehicle_child'));
    }
  }
}
