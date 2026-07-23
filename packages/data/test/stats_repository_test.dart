import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

/// M8-T1 · the dashboard read layer aggregates over rollups (not raw scans),
/// scope-aware, and never sums across currencies.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Instant on(int day) => Instant.fromEpochMillis(
      1000000000000 + day * Duration.millisecondsPerDay);

  Future<String> vehicle(String name) async =>
      (await VehiclesRepository(db).add(nickname: name)).valueOrNull!.id;

  test('per-vehicle KPIs come from the rollups a fuel + trip write maintain',
      () async {
    final v = await vehicle('Golf');
    await FuelRepository(db).add(
      vehicleId: v,
      filledAt: on(0),
      odometerMetres: 1000000,
      volumeMl: 40000,
      totalCostMinor: 6000,
      currencyCode: 'EUR',
    );
    await TripsRepository(db)
        .add(vehicleId: v, tripAt: on(1), directDistanceMetres: 200000);

    final kpis = await StatsRepository(db).watchVehicleKpis(v, 'EUR').first;
    expect(kpis.spendMinor, 6000);
    expect(kpis.fuelMl, 40000);
    expect(kpis.distanceMetres, 200000);
    expect(kpis.mixedCurrency, isFalse);
    expect(kpis.currencyCode, 'EUR');
    // Derived: 6000 minor × 1000 / 200000 m = 30 minor per km.
    expect(kpis.costPerKmMinor, 30);
  });

  test('an all-vehicles scope with two currencies is flagged, never summed',
      () async {
    final eur = await vehicle('EurCar');
    final usd = await vehicle('UsdCar');
    await FuelRepository(db).add(
        vehicleId: eur,
        filledAt: on(0),
        odometerMetres: 1000000,
        volumeMl: 30000,
        totalCostMinor: 5000,
        currencyCode: 'EUR');
    await FuelRepository(db).add(
        vehicleId: usd,
        filledAt: on(0),
        odometerMetres: 1000000,
        volumeMl: 30000,
        totalCostMinor: 7000,
        currencyCode: 'USD');

    final scope = await StatsRepository(db)
        .watchScopeKpis({eur: 'EUR', usd: 'USD'}).first;
    expect(scope.mixedCurrency, isTrue);
    expect(scope.spendMinor, 0); // not summable across currencies
    // Non-money metrics still aggregate across the scope.
    expect(scope.fuelMl, 60000);
  });

  test('period-key range filters the rollups (this-month vs all-time)',
      () async {
    final v = await vehicle('Corolla');
    // Two fills in different months (rollups keyed YYYY-MM).
    await FuelRepository(db).add(
        vehicleId: v,
        filledAt: Instant.fromDateTime(DateTime.utc(2026, 6, 10)),
        odometerMetres: 1000000,
        volumeMl: 30000,
        totalCostMinor: 5000,
        currencyCode: 'EUR');
    await FuelRepository(db).add(
        vehicleId: v,
        filledAt: Instant.fromDateTime(DateTime.utc(2026, 7, 10)),
        odometerMetres: 1400000,
        volumeMl: 35000,
        totalCostMinor: 6000,
        currencyCode: 'EUR');

    final repo = StatsRepository(db);
    final all = await repo.watchVehicleKpis(v, 'EUR').first;
    expect(all.spendMinor, 11000);
    final july = await repo
        .watchVehicleKpis(v, 'EUR',
            sincePeriod: '2026-07', untilPeriod: '2026-07')
        .first;
    expect(july.spendMinor, 6000);
    expect(await repo.fillCount(v), 2);
  });
}
