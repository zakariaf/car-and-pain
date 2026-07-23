import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'base_repository.dart';
import 'expenses_repository.dart';
import 'fuel_repository.dart';
import 'vehicles_repository.dart';

/// M10-T3 · seeds and tears down a sample/demo vehicle with realistic history so
/// a brand-new user sees the dashboard, economy math, and TCO populated. The
/// demo vehicle is flagged `is_demo`; teardown removes it and every linked
/// record in one transaction (FK cascade → no orphans). Seed/teardown/re-seed
/// are idempotent. All writes go through the real repositories, so the demo
/// exercises the same canonical paths as real data.
class DemoSeeder extends BaseRepository {
  DemoSeeder(super.db, {super.clock});

  /// Whether a demo vehicle currently exists.
  Future<bool> isActive() async {
    final rows = await (db.select(db.vehicles)
          ..where((t) => t.isDemo.equals(true) & t.isDeleted.equals(false)))
        .get();
    return rows.isNotEmpty;
  }

  /// Seed the demo vehicle + history. Idempotent: if one already exists its id
  /// is returned without re-seeding.
  Future<Result<String, DbFailure>> seed(
      {String nickname = 'Sample car'}) async {
    try {
      final existing = await (db.select(db.vehicles)
            ..where((t) => t.isDemo.equals(true) & t.isDeleted.equals(false)))
          .get();
      if (existing.isNotEmpty) return Ok(existing.first.id);

      final vehicles = VehiclesRepository(db, clock: clock);
      final added = await vehicles.add(nickname: nickname);
      if (added.isErr) return Err(added.failureOrNull!);
      final id = added.valueOrNull!.id;

      // Flag it as demo.
      await (db.update(db.vehicles)..where((t) => t.id.equals(id)))
          .write(const VehiclesCompanion(isDemo: Value(true)));

      final now = _clockNow();
      final fuel = FuelRepository(db, clock: clock);
      // A spread of fills: full → partial → full, so the full-to-full economy
      // engine has a valid interval to compute.
      await fuel.add(
        vehicleId: id,
        filledAt: Instant.fromEpochMillis(now - _days(40)),
        odometerMetres: 20000000,
        volumeMl: 45000,
        totalCostMinor: 6500,
        currencyCode: 'EUR',
      );
      await fuel.add(
        vehicleId: id,
        filledAt: Instant.fromEpochMillis(now - _days(25)),
        odometerMetres: 20450000,
        volumeMl: 20000,
        totalCostMinor: 2900,
        currencyCode: 'EUR',
        isFullTank: false,
      );
      await fuel.add(
        vehicleId: id,
        filledAt: Instant.fromEpochMillis(now - _days(10)),
        odometerMetres: 20850000,
        volumeMl: 42000,
        totalCostMinor: 6100,
        currencyCode: 'EUR',
      );

      final expenses = ExpensesRepository(db, clock: clock);
      await expenses.add(
        vehicleId: id,
        spentAt: Instant.fromEpochMillis(now - _days(15)),
        amountMinor: 8500,
        currencyCode: 'EUR',
        notes: 'Sample expense',
      );

      return Ok(id);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'vehicles'));
    }
  }

  /// Tear down every demo vehicle and all its linked records in one transaction.
  /// FK `onDelete: cascade` removes fuel/service/expense/odometer/trip children,
  /// so no orphan rows remain. Returns the number of demo vehicles removed.
  Future<Result<int, DbFailure>> teardown() async {
    try {
      final count = await db.transaction(() async {
        final demos = await (db.select(db.vehicles)
              ..where((t) => t.isDemo.equals(true)))
            .get();
        for (final v in demos) {
          await (db.delete(db.vehicles)..where((t) => t.id.equals(v.id))).go();
        }
        return demos.length;
      });
      return Ok(count);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'vehicles'));
    }
  }

  int _clockNow() => nowMillis();
  int _days(int n) => n * Duration.millisecondsPerDay;
}
