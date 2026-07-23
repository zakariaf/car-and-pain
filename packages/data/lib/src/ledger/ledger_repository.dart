import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../repositories/base_repository.dart';

/// The shared ledger read/append contract. Features append here; they never
/// store their own odometer. Reads are vehicle-scoped and tombstone-filtered.
class LedgerRepository extends BaseRepository {
  LedgerRepository(super.db,
      {super.clock, LedgerEngine engine = const LedgerEngine()})
      : _engine = engine;

  final LedgerEngine _engine;

  LedgerReading _toReading(OdometerReading r) => LedgerReading(
        value: r.value,
        takenAt: Instant.fromEpochMillis(r.takenAt),
        source: LedgerSource.values.byName(r.source),
        cumulativeOffset: r.cumulativeOffset,
        isRegressionOverride: r.isRegressionOverride,
      );

  /// A lightweight change signal (M5-T2): emits the live count of odometer
  /// readings, re-emitting whenever ANY reading is written across all vehicles.
  /// Drives reactive re-projection of distance/engine-hour reminders (the F5
  /// reconcile) without polling — a phone can't watch the odometer roll, so the
  /// engine re-projects on each new reading instead.
  Stream<int> watchReadingCount() {
    final count = db.odometerReadings.id.count();
    final query = db.selectOnly(db.odometerReadings)
      ..addColumns([count])
      // Exclude tombstones so a soft-deleted reading (a correction) also
      // changes the count and triggers a re-projection.
      ..where(db.odometerReadings.isDeleted.equals(false));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// The vehicle's reading timeline, oldest first — push-updated.
  Stream<List<LedgerReading>> watchByVehicle(String vehicleId) {
    final query = db.select(db.odometerReadings)
      ..where((t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.takenAt)]);
    return query
        .watch()
        .map((rows) => rows.map<LedgerReading>(_toReading).toList());
  }

  Future<List<LedgerReading>> _historyFor(String vehicleId) async {
    final rows = await (db.select(db.odometerReadings)
          ..where(
            (t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false),
          ))
        .get();
    return rows.map<LedgerReading>(_toReading).toList();
  }

  /// Check a prospective manual reading WITHOUT writing (M2-T4): returns the
  /// anomaly warnings (regression / implausible jump / rollback) so the UI can
  /// require an explicit override before it persists. Pure read + engine.
  Future<Result<List<FieldError>, DbFailure>> previewManual({
    required String vehicleId,
    required int value,
    required Instant takenAt,
    int cumulativeOffset = 0,
  }) async {
    try {
      final history = await _historyFor(vehicleId);
      final candidate = LedgerReading(
        value: value,
        takenAt: takenAt,
        source: LedgerSource.manual,
        cumulativeOffset: cumulativeOffset,
      );
      return Ok(_engine.check(history, candidate));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'odometer_readings'));
    }
  }

  /// Append a manual reading. Returns the non-blocking validation warnings
  /// (warn-with-override) — the row still persists.
  Future<Result<List<FieldError>, DbFailure>> appendManual({
    required String vehicleId,
    required int value,
    required Instant takenAt,
    int cumulativeOffset = 0,
    bool overrideRegression = false,
  }) async {
    try {
      final history = await _historyFor(vehicleId);
      final candidate = LedgerReading(
        value: value,
        takenAt: takenAt,
        source: LedgerSource.manual,
        cumulativeOffset: cumulativeOffset,
        isRegressionOverride: overrideRegression,
      );
      final warnings = _engine.check(history, candidate);

      final now = nowMillis();
      await db.transaction(() async {
        await db.into(db.odometerReadings).insert(
              OdometerReadingsCompanion.insert(
                id: newId(),
                vehicleId: vehicleId,
                value: value,
                takenAt: takenAt.epochMillis,
                source: LedgerSource.manual.name,
                createdAt: now,
                updatedAt: now,
                cumulativeOffset: Value(cumulativeOffset),
                isRegressionOverride: Value(overrideRegression),
              ),
            );
        await (db.update(db.vehicles)..where((t) => t.id.equals(vehicleId)))
            .write(
          VehiclesCompanion(
            currentOdometerMetres: Value(value + cumulativeOffset),
            currentOdometerAt: Value(takenAt.epochMillis),
            updatedAt: Value(now),
          ),
        );
      });
      return Ok(warnings);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'odometer_readings'));
    }
  }
}
