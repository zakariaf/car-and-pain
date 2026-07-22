import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../domain/fuel_entry.dart';
import 'base_repository.dart';
import 'rollup_service.dart';

/// The flagship transactional write (F2-T9/T10, M3-T1): a fuel/charge entry, its
/// odometer ledger row, the cached vehicle odometer, and the affected rollups
/// are all written in ONE transaction so the spine never desyncs.
class FuelRepository extends BaseRepository {
  FuelRepository(super.db, {super.clock});

  RollupService get _rollups => RollupService(db);

  FuelEntry _toDomain(FuelEntryRow r) => FuelEntry(
        id: r.id,
        vehicleId: r.vehicleId,
        filledAt: Instant.fromEpochMillis(r.filledAt),
        odometerMetres: r.odometerMetres,
        volumeMl: r.volumeMl,
        energyJoules: r.energyJoules,
        totalCostMinor: r.totalCostMinor,
        currencyCode: r.currencyCode,
        isFullTank: r.isFullTank,
        isMissedPrevious: r.isMissedPrevious,
        excludeFromEconomy: r.excludeFromEconomy,
        isFree: r.isFree,
        fuelType: r.fuelType,
        pricePerUnitThousandths: r.pricePerUnitThousandths,
        startSocPct: r.startSocPct,
        endSocPct: r.endSocPct,
        isHomeCharge: r.isHomeCharge,
        stationName: r.stationName,
        notes: r.notes,
      );

  /// A vehicle's fill/charge history, newest first, tombstone-filtered.
  Stream<List<FuelEntry>> watchByVehicle(String vehicleId) {
    final query = db.select(db.fuelEntries)
      ..where((t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.filledAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<Result<String, DbFailure>> add({
    required String vehicleId,
    required Instant filledAt,
    required int odometerMetres,
    required int volumeMl,
    required int totalCostMinor,
    required String currencyCode,
    bool isFullTank = true,
    bool isMissedPrevious = false,
    bool excludeFromEconomy = false,
    bool isFree = false,
    String? fuelType,
    int? energyJoules,
    int? pricePerUnitThousandths,
    int? startSocPct,
    int? endSocPct,
    bool isHomeCharge = false,
    String? stationName,
    String? notes,
  }) async {
    try {
      final id = newId();
      final now = nowMillis();
      await db.transaction(() async {
        await db.into(db.fuelEntries).insert(
              FuelEntriesCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                filledAt: filledAt.epochMillis,
                odometerMetres: odometerMetres,
                volumeMl: volumeMl,
                totalCostMinor: totalCostMinor,
                currencyCode: currencyCode,
                createdAt: now,
                updatedAt: now,
                isFullTank: Value(isFullTank),
                isPartial: Value(!isFullTank),
                isMissedPrevious: Value(isMissedPrevious),
                excludeFromEconomy: Value(excludeFromEconomy),
                isFree: Value(isFree),
                fuelType: Value(fuelType),
                energyJoules: Value(energyJoules),
                pricePerUnitThousandths: Value(pricePerUnitThousandths),
                startSocPct: Value(startSocPct),
                endSocPct: Value(endSocPct),
                isHomeCharge: Value(isHomeCharge),
                stationName: Value(stationName),
                notes: Value(notes),
              ),
            );
        // The ledger row — same transaction, source-tagged, back-referenced.
        await db.into(db.odometerReadings).insert(
              OdometerReadingsCompanion.insert(
                id: newId(),
                vehicleId: vehicleId,
                value: odometerMetres,
                takenAt: filledAt.epochMillis,
                source: LedgerSource.fuel.name,
                createdAt: now,
                updatedAt: now,
                sourceRecordId: Value(id),
              ),
            );
        // Cache the vehicle's current odometer.
        await (db.update(db.vehicles)..where((t) => t.id.equals(vehicleId)))
            .write(
          VehiclesCompanion(
            currentOdometerMetres: Value(odometerMetres),
            currentOdometerAt: Value(filledAt.epochMillis),
            updatedAt: Value(now),
          ),
        );
        // Bump the affected rollups (additive metrics).
        final period = monthPeriodKey(filledAt.epochMillis);
        await _rollups.bump(
            vehicleId: vehicleId,
            period: period,
            metric: 'costMinor',
            delta: totalCostMinor,
            now: now);
        await _rollups.bump(
            vehicleId: vehicleId,
            period: period,
            metric: 'fuelMl',
            delta: volumeMl,
            now: now);
      });
      return Ok(id);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'fuel_entries'));
    }
  }

  /// The liquid/gas economy report for a vehicle (M3-T2), computed by the pure
  /// [EconomyEngine] over the non-charge fills. EV charges are a separate series
  /// (they carry no litre volume) and never blended into the liquid average.
  Future<EconomyReport> economyReport(String vehicleId) async {
    final rows = await (db.select(db.fuelEntries)
          ..where(
              (t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false)))
        .get();
    final liquidFills = rows
        .map(_toDomain)
        .where((e) => !e.isCharge)
        .map((e) => e.toEnergyFill())
        .toList();
    return const EconomyEngine().compute(liquidFills);
  }

  /// Soft-delete a fuel/charge entry to trash (never a hard delete). The ledger
  /// row it wrote remains — corrections there are audited, not erased.
  Future<Result<void, DbFailure>> softDelete(
    String id, {
    Duration retention = const Duration(days: 30),
  }) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.fuelEntries)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null) return false;
        await (db.update(db.fuelEntries)..where((t) => t.id.equals(id))).write(
          FuelEntriesCompanion(
            isDeleted: const Value(true),
            deletedAt: Value(now),
            trashExpiresAt: Value(now + retention.inMilliseconds),
            updatedAt: Value(now),
            rowRevision: Value(cur.rowRevision + 1),
          ),
        );
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('fuel_entry'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'fuel_entries'));
    }
  }
}
