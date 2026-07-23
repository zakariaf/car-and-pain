import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

/// M6-T1 — the expense ledger: CRUD returning domain models, filterable streams,
/// dated-FX + source links, and rollup that never double-counts projected rows.
void main() {
  Future<(AppDatabase, String)> fresh() async {
    final db = AppDatabase.memory();
    final v = (await VehiclesRepository(db).add(nickname: 'Golf')).valueOrNull!;
    return (db, v.id);
  }

  Future<int> rollupCost(AppDatabase db, String vehicleId) async {
    final rows = await (db.select(db.rollups)
          ..where((t) => t.vehicleId.equals(vehicleId)))
        .get();
    return rows.where((r) => r.metric == 'costMinor').firstOrNull?.value ?? 0;
  }

  // Seed a category so an expense's categoryId FK resolves (foreign_keys ON).
  Future<void> seedCategory(AppDatabase db, String id) => db.customStatement(
        'INSERT INTO categories (id, created_at, updated_at, kind, label, '
        "analytic_bucket) VALUES ('$id', 0, 0, 'expense', '$id', '$id')",
      );

  test('add stores a domain Expense with dated FX; watchByVehicle filters',
      () async {
    final (db, vehicleId) = await fresh();
    addTearDown(db.close);
    final repo = ExpensesRepository(db);
    await seedCategory(db, 'insurance');

    await repo.add(
      vehicleId: vehicleId,
      spentAt: const Instant.fromEpochMillis(1000),
      amountMinor: 5000, // 50.00 USD
      currencyCode: 'USD',
      categoryId: 'insurance',
      fxRateThousandths: 920, // 0.920 base per USD
      fxAsOf: 1000,
      baseAmountMinor: 4600, // 46.00 EUR base
      tags: const ['annual'],
    );
    await repo.add(
      vehicleId: vehicleId,
      spentAt: const Instant.fromEpochMillis(3000),
      amountMinor: -1000, // a refund (signed)
      currencyCode: 'EUR',
    );

    final all = await repo.watchByVehicle(vehicleId).first;
    expect(all.map((e) => e.amountMinor), [-1000, 5000]); // newest first
    final fx = all.firstWhere((e) => e.currencyCode == 'USD');
    expect(fx.baseAmountOrSelf, 4600); // base amount honoured
    expect(fx.tags, ['annual']);

    // Category filter.
    final ins =
        await repo.watchByVehicle(vehicleId, categoryId: 'insurance').first;
    expect(ins, hasLength(1));
  });

  test('manual rows bump the rollup; a projected source row does NOT',
      () async {
    final (db, vehicleId) = await fresh();
    addTearDown(db.close);
    final repo = ExpensesRepository(db);

    // A manual expense → counts toward the monthly cost rollup.
    await repo.add(
      vehicleId: vehicleId,
      spentAt: const Instant.fromEpochMillis(1000),
      amountMinor: 8000,
      currencyCode: 'EUR',
    );
    expect(await rollupCost(db, vehicleId), 8000);

    // A projected fuel row (source link set) → already counted by fuel; skip it.
    final projected = (await repo.add(
      vehicleId: vehicleId,
      spentAt: const Instant.fromEpochMillis(2000),
      amountMinor: 6000,
      currencyCode: 'EUR',
      sourceEntityType: 'fuel',
      sourceEntityId: 'f1',
    ))
        .valueOrNull!;
    expect(
        await rollupCost(db, vehicleId), 8000); // unchanged — no double count

    // Deleting the manual one reverses its bump; deleting the projected one is a
    // no-op on the rollup.
    final manual = (await repo.watchByVehicle(vehicleId).first)
        .firstWhere((e) => !e.isProjected);
    expect((await repo.softDelete(manual.id)).isOk, isTrue);
    expect(await rollupCost(db, vehicleId), 0);
    expect((await repo.softDelete(projected)).isOk, isTrue);
    expect(await rollupCost(db, vehicleId), 0);
    expect((await repo.softDelete('ghost')).failureOrNull, isA<NotFound>());
  });
}
