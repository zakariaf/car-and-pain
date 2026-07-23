import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// M2-T4: the audited manual-reading flow over the shared ledger — preview
/// surfaces the anomaly (warn), append with an explicit override persists and
/// keeps the sequence, and a monotonic advance is clean.
void main() {
  late AppDatabase db;
  late VehiclesRepository vehicles;
  late LedgerRepository ledger;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vehicles = VehiclesRepository(db);
    ledger = LedgerRepository(db);
  });
  tearDown(() => db.close());

  Future<String> seedVehicleWithReading() async {
    final id = (await vehicles.add(nickname: 'Rocinante')).valueOrNull!.id;
    await ledger.appendManual(
      vehicleId: id,
      value: 100000000, // 100,000 km
      takenAt: const Instant.fromEpochMillis(1000),
    );
    return id;
  }

  test('a monotonic advance previews clean and appends without warnings',
      () async {
    final id = await seedVehicleWithReading();
    final preview = await ledger.previewManual(
      vehicleId: id,
      value: 101000000, // +1,000 km
      takenAt: const Instant.fromEpochMillis(2000),
    );
    expect(preview.valueOrNull, isEmpty);

    final appended = await ledger.appendManual(
      vehicleId: id,
      value: 101000000,
      takenAt: const Instant.fromEpochMillis(2000),
    );
    expect(appended.valueOrNull, isEmpty);
    expect(await ledger.watchByVehicle(id).first, hasLength(2));
  });

  test(
      'a regression previews a warning; override persists + keeps the sequence',
      () async {
    final id = await seedVehicleWithReading();
    // A lower reading (50,000 km) → regression warning on preview.
    final preview = await ledger.previewManual(
      vehicleId: id,
      value: 50000000,
      takenAt: const Instant.fromEpochMillis(2000),
    );
    expect(preview.valueOrNull!.map((e) => e.code), contains('regression'));

    // Persisting WITH an explicit override keeps both rows (audit, no overwrite).
    final appended = await ledger.appendManual(
      vehicleId: id,
      value: 50000000,
      takenAt: const Instant.fromEpochMillis(2000),
      overrideRegression: true,
    );
    expect(appended.isOk, isTrue);
    final rows = await ledger.watchByVehicle(id).first;
    expect(rows, hasLength(2)); // original NOT mutated; new row appended
    expect(rows.where((r) => r.isRegressionOverride), hasLength(1));
  });

  test('a huge backward jump previews as a rollover, not a regression',
      () async {
    final id = (await vehicles.add(nickname: 'Hauler')).valueOrNull!.id;
    // Prior reading high enough that a drop to ~0 exceeds the 500,000 km
    // rollover threshold (→ cluster swap / rollover, not a data-entry slip).
    await ledger.appendManual(
      vehicleId: id,
      value: 600000000, // 600,000 km
      takenAt: const Instant.fromEpochMillis(1000),
    );
    final preview = await ledger.previewManual(
      vehicleId: id,
      value: 1000, // ~0 km
      takenAt: const Instant.fromEpochMillis(2000),
    );
    final codes = preview.valueOrNull!.map((e) => e.code);
    expect(codes, contains('rollover'));
    expect(codes, isNot(contains('regression')));
  });
}
