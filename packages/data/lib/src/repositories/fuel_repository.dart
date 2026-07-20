import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'base_repository.dart';
import 'rollup_service.dart';

/// The flagship transactional write (F2-T9/T10): a fuel entry, its odometer
/// ledger row, the cached vehicle odometer, and the affected rollups are all
/// written in ONE transaction so the spine never desyncs.
class FuelRepository extends BaseRepository {
  FuelRepository(super.db, {super.clock});

  RollupService get _rollups => RollupService(db);

  Future<Result<String, DbFailure>> add({
    required String vehicleId,
    required Instant filledAt,
    required int odometerMetres,
    required int volumeMl,
    required int totalCostMinor,
    required String currencyCode,
    bool isFullTank = true,
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
}
