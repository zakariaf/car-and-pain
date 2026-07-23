import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// M3-T1/T2: the unified fuel/charge repository writes to the shared ledger,
/// streams the history, and computes the liquid economy via the pure engine
/// (EV charges never blend into the liquid average).
void main() {
  late AppDatabase db;
  late FuelRepository fuel;
  late String vehicleId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fuel = FuelRepository(db);
    vehicleId =
        (await VehiclesRepository(db).add(nickname: 'Rig')).valueOrNull!.id;
  });
  tearDown(() => db.close());

  Future<String> fill(
    int ms,
    int odo,
    int volMl, {
    int cost = 6000,
    bool full = true,
    String? fuelType,
  }) async =>
      (await fuel.add(
        vehicleId: vehicleId,
        filledAt: Instant.fromEpochMillis(ms),
        odometerMetres: odo,
        volumeMl: volMl,
        totalCostMinor: cost,
        currencyCode: 'EUR',
        isFullTank: full,
        fuelType: fuelType,
      ))
          .valueOrNull!;

  test('a fill writes a ledger row tagged source=fuel', () async {
    await fill(1000, 500000, 40000);
    final ledger = await LedgerRepository(db).watchByVehicle(vehicleId).first;
    expect(ledger, hasLength(1));
    expect(ledger.single.source, LedgerSource.fuel);
    expect(ledger.single.value, 500000);
  });

  test('watchByVehicle streams the history newest-first', () async {
    await fill(1000, 0, 40000);
    await fill(2000, 500000, 40000);
    final entries = await fuel.watchByVehicle(vehicleId).first;
    expect(entries.map((e) => e.odometerMetres), [500000, 0]); // desc by time
  });

  test('economyReport computes full-to-full via the pure engine', () async {
    await fill(1000, 0, 40000); // baseline
    await fill(2000, 500000, 40000); // 500 km on 40 L
    final report = await fuel.economyReport(vehicleId);
    expect(report.intervals, hasLength(1));
    expect(report.latest!.mlPerMetre, closeTo(0.08, 1e-9)); // 8 L/100km
  });

  test('an EV charge is excluded from the liquid economy series', () async {
    await fill(1000, 0, 40000);
    await fill(2000, 500000, 40000);
    // A charge session between fills must not distort the litre-based economy.
    await fill(2500, 700000, 0, cost: 1200, fuelType: 'electric');
    final report = await fuel.economyReport(vehicleId);
    expect(report.intervals, hasLength(1)); // charge ignored
    expect(report.latest!.volumeMl, 40000);
    // The liquid report's spend is liquid-only; the charge is a separate series.
    expect(report.totalSpendMinor, 12000); // 6000 + 6000
  });

  test('soft-delete removes the entry from the stream + economy', () async {
    await fill(1000, 0, 40000);
    final id = await fill(2000, 500000, 40000);
    expect((await fuel.softDelete(id)).isOk, isTrue);
    expect(await fuel.watchByVehicle(vehicleId).first, hasLength(1));
    expect((await fuel.economyReport(vehicleId)).pending, isTrue);
  });

  test('soft-delete reverses the rollups it bumped (incremental == rebuild)',
      () async {
    final id = await fill(1000, 500000, 40000); // default cost 6000
    Future<int> costRollup() async {
      final rows = await (db.select(db.rollups)
            ..where((t) => t.vehicleId.equals(vehicleId)))
          .get();
      return rows.where((r) => r.metric == 'costMinor').firstOrNull?.value ?? 0;
    }

    expect(await costRollup(), 6000); // bumped on add
    await fuel.softDelete(id);
    expect(await costRollup(), 0); // reversed on soft-delete
  });
}
