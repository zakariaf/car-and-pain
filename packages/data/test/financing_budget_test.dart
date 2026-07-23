import 'dart:convert';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

/// M6-T4/T3/T8 — financing + budget persistence and their canonical round-trip.
void main() {
  Future<(AppDatabase, String)> fresh() async {
    final db = AppDatabase.memory();
    final v = (await VehiclesRepository(db).add(nickname: 'Golf')).valueOrNull!;
    return (db, v.id);
  }

  test('financing stores terms + feeds the amortization engine', () async {
    final (db, vehicleId) = await fresh();
    addTearDown(db.close);
    final repo = FinancingRepository(db);

    final id = (await repo.addFinancing(
      vehicleId: vehicleId,
      kind: 'loan',
      principalMinor: 2000000,
      currencyCode: 'EUR',
      aprBps: 600,
      termMonths: 48,
      startDate: const Instant.fromEpochMillis(0),
    ))
        .valueOrNull!;

    final f = await repo.financingById(id);
    expect(f, isNotNull);
    // The stored terms recompute the schedule via the pure engine (no lossy copy).
    final schedule = const AmortizationEngine().schedule(f!.toLoanTerms());
    expect(schedule.rows.last.balanceMinor, 0);
    expect(f.isClosed, isFalse);

    expect(
        (await repo.closeFinancing(id, const Instant.fromEpochMillis(100)))
            .isOk,
        isTrue);
    expect((await repo.financingById(id))!.isClosed, isTrue);
  });

  test('budget rejects a non-positive target and records alert de-dup state',
      () async {
    final (db, vehicleId) = await fresh();
    addTearDown(db.close);
    final repo = BudgetsRepository(db);

    expect(
      (await repo.add(period: 'monthly', targetMinor: 0, currencyCode: 'EUR'))
          .failureOrNull,
      isA<ConstraintViolation>(),
    );
    final id = (await repo.add(
      period: 'monthly',
      targetMinor: 30000,
      currencyCode: 'EUR',
      vehicleId: vehicleId,
    ))
        .valueOrNull!;

    final byVehicle = await repo.watchForVehicle(vehicleId).first;
    expect(byVehicle, hasLength(1));
    expect(byVehicle.single.budgetPeriod, BudgetPeriod.monthly);

    expect(
        (await repo.recordAlert(id, threshold: 80, periodKey: '2026-07')).isOk,
        isTrue);
    final after = await repo.byId(id);
    expect(after!.lastAlertThreshold, 80);
    expect(after.lastAlertPeriod, '2026-07');
  });

  test('financing + budget round-trip through the canonical backup', () async {
    final (db, vehicleId) = await fresh();
    addTearDown(db.close);
    await FinancingRepository(db).addFinancing(
      vehicleId: vehicleId,
      kind: 'lease',
      principalMinor: 3000000,
      currencyCode: 'EUR',
      aprBps: 900,
      termMonths: 36,
      startDate: const Instant.fromEpochMillis(0),
      residualMinor: 1200000,
    );
    await BudgetsRepository(db)
        .add(period: 'annual', targetMinor: 500000, currencyCode: 'EUR');

    final doc = await CanonicalCodec(db).export();
    final db2 = AppDatabase.memory();
    addTearDown(db2.close);
    expect((await CanonicalCodec(db2).import(doc)).isOk, isTrue);

    final doc2 = await CanonicalCodec(db2).export();
    for (final e in ['financings', 'budgets']) {
      expect(
        jsonEncode((doc2['entities'] as Map)[e]),
        jsonEncode((doc['entities'] as Map)[e]),
        reason: '$e must round-trip',
      );
    }
    final f = await FinancingRepository(db2).watchByVehicle(vehicleId).first;
    expect(f.single.residualMinor, 1200000);
  });
}
