// Illustrative — parent row + shared-ledger row + rollup bump in ONE transaction.
// Every fuel/service/expense/trip write follows this shape: the parent, its
// odometer_readings ledger row, and the affected rollup are written atomically
// so the spine never desyncs. Pairs with the error-handling-never-lose-data
// skill (typed Result on failure). Canonical int columns only — Distance/Volume/
// Money are mapped to metres/millilitres/minor-units at the repository boundary.

import 'package:core/core.dart'; // Money, Distance, Volume, Currency
import 'package:drift/drift.dart';

class FuelRepository {
  FuelRepository(this.db);
  final AppDatabase db;

  /// Insert a fuel entry, its ledger row, and bump the period rollup atomically.
  /// [now] is injected (package:clock) for deterministic tests.
  Future<void> addFuelEntry(FuelEntry e, {required int now}) {
    return db.transaction(() async {
      // 1. Parent row. updatedAt / rowRevision stamped by the shared write wrapper.
      await db.into(db.fuelEntries).insert(
            FuelEntriesCompanion.insert(
              id: e.id, // UUIDv7
              vehicleId: e.vehicleId,
              filledAt: e.filledAt.millisecondsSinceEpoch,
              volumeMl: e.volume.ml, // canonical millilitres
              amountMinor: e.totalCost.minorUnits, // integer minor units
              currencyCode: e.totalCost.currency.code, // ISO-4217
              isFullTank: Value(e.isFullTank),
              isPartial: Value(e.isPartial),
              isMissedPrevious: Value(e.isMissedPrevious),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 2. Shared odometer_readings ledger row — same transaction, never separate.
      await db.into(db.odometerReadings).insert(
            OdometerReadingsCompanion.insert(
              id: e.ledgerRowId,
              vehicleId: e.vehicleId,
              readingMetres: e.odometer.metres, // canonical whole metres
              takenAt: e.filledAt.millisecondsSinceEpoch,
              sourceType: 'fuel',
              sourceRecordId: e.id,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 3. Bump the revision-keyed rollup for the affected (vehicle, period) slice.
      await _bumpRollup(e.vehicleId, e.periodKey, revision: e.rowRevision + 1);
    });
  }

  Future<void> _bumpRollup(String vehicleId, String periodKey,
          {required int revision}) =>
      db.customStatement(
        'UPDATE rollups SET revision = ? WHERE vehicle_id = ? AND period_key = ?',
        [revision, vehicleId, periodKey],
      );
}
