import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'base_repository.dart';

/// The month bucket key ('YYYY-MM', UTC) a timestamp rolls into.
String monthPeriodKey(int epochMillis) {
  final d = DateTime.fromMillisecondsSinceEpoch(epochMillis, isUtc: true);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}

/// Maintains the pre-aggregated, revision-stamped `Rollups` that dashboards read
/// instead of scanning years of source rows. Additive metrics (cost, volume,
/// distance) are bumped **inside the same transaction** as the source write;
/// [rebuild] recomputes deterministically from source and must match.
class RollupService {
  const RollupService(this.db);

  final AppDatabase db;

  /// Add [delta] to the (vehicle, period, metric) rollup — creating it if absent
  /// — and bump its revision. Call inside the source write's transaction.
  Future<void> bump({
    required String vehicleId,
    required String period,
    required String metric,
    required int delta,
    required int now,
  }) async {
    final existing = await (db.select(db.rollups)
          ..where(
            (t) =>
                t.vehicleId.equals(vehicleId) &
                t.periodKey.equals(period) &
                t.metric.equals(metric),
          ))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.rollups).insert(
            RollupsCompanion.insert(
              id: newId(),
              vehicleId: vehicleId,
              periodKey: period,
              metric: metric,
              createdAt: now,
              updatedAt: now,
              value: Value(delta),
              revision: const Value(1),
            ),
          );
    } else {
      await (db.update(db.rollups)..where((t) => t.id.equals(existing.id)))
          .write(
        RollupsCompanion(
          value: Value(existing.value + delta),
          revision: Value(existing.revision + 1),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Deterministically rebuild every rollup for a vehicle from source rows
  /// (excludes tombstoned rows). A rebuild must equal the incremental values.
  Future<void> rebuild(String vehicleId, {required int now}) async {
    await db.transaction(() async {
      await (db.delete(db.rollups)..where((t) => t.vehicleId.equals(vehicleId)))
          .go();

      final fuels = await (db.select(db.fuelEntries)
            ..where(
              (t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false),
            ))
          .get();
      for (final f in fuels) {
        final period = monthPeriodKey(f.filledAt);
        await bump(
            vehicleId: vehicleId,
            period: period,
            metric: 'costMinor',
            delta: f.totalCostMinor,
            now: now);
        await bump(
            vehicleId: vehicleId,
            period: period,
            metric: 'fuelMl',
            delta: f.volumeMl,
            now: now);
      }

      final expenses = await (db.select(db.expenses)
            ..where(
              (t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false),
            ))
          .get();
      for (final e in expenses) {
        await bump(
            vehicleId: vehicleId,
            period: monthPeriodKey(e.spentAt),
            metric: 'costMinor',
            delta: e.amountMinor,
            now: now);
      }

      final trips = await (db.select(db.trips)
            ..where(
              (t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false),
            ))
          .get();
      for (final t in trips) {
        await bump(
            vehicleId: vehicleId,
            period: monthPeriodKey(t.tripAt),
            metric: 'distanceMetres',
            delta: t.distanceMetres,
            now: now);
      }
    });
  }
}
