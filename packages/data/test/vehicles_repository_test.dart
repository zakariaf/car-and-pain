import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// M2-T1 repository integration tests over an in-memory Drift DB: CRUD +
/// per-vehicle overrides, the normalized child tables, lifecycle transitions,
/// soft-delete/tombstone + restore, and permanent-delete cascade.
void main() {
  late AppDatabase db;
  late VehiclesRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = VehiclesRepository(db);
  });
  tearDown(() => db.close());

  Future<String> seed({String nickname = 'Rocinante'}) async =>
      (await repo.add(nickname: nickname)).valueOrNull!.id;

  test('update applies the adaptive profile + per-vehicle overrides', () async {
    final id = await seed();
    final r = await repo.update(
      id,
      const VehicleEdit(
        make: 'Toyota',
        model: 'Corolla',
        trim: 'GR',
        modelYear: 2021,
        energyType: 'gasoline',
        vin: '1HGCM82633A004352',
        vinChecksumValid: true,
        licensePlate: 'ABC-123',
        distanceUnit: 'mile',
        currencyCode: 'USD',
        tags: ['daily', 'insured'],
        distanceTrackingEnabled: false,
      ),
    );
    expect(r.isOk, isTrue);

    final v = (await repo.getById(id)).valueOrNull!;
    expect(v.displayModel, 'Toyota Corolla GR');
    expect(v.energyType, 'gasoline');
    expect(v.vin, '1HGCM82633A004352');
    expect(v.vinChecksumValid, isTrue);
    expect(v.distanceUnit, 'mile'); // per-vehicle override persists
    expect(v.currencyCode, 'USD');
    expect(v.tags, ['daily', 'insured']);
    expect(v.distanceTrackingEnabled, isFalse);
  });

  test('an absent VehicleEdit field leaves the stored value unchanged',
      () async {
    final id = await seed();
    await repo.update(id, const VehicleEdit(make: 'Honda'));
    await repo.update(id, const VehicleEdit(model: 'Civic')); // make omitted
    final v = (await repo.getById(id)).valueOrNull!;
    expect(v.make, 'Honda'); // not clobbered by the second edit
    expect(v.model, 'Civic');
  });

  test('plate / valuation / SoH child tables persist joined by vehicle_id',
      () async {
    final id = await seed();
    expect((await repo.addPlateHistory(id, plate: 'OLD-1')).isOk, isTrue);
    expect(
        (await repo.addValuation(id,
                valuedAt: 100, amountMinor: 1500000, currencyCode: 'EUR'))
            .isOk,
        isTrue);
    expect(
        (await repo.addStateOfHealth(id, recordedAt: 200, sohPermille: 912))
            .isOk,
        isTrue);

    expect((await repo.watchPlateHistory(id).first).single.plate, 'OLD-1');
    expect((await repo.watchValuations(id).first).single.amountMinor, 1500000);
    expect((await repo.watchStateOfHealth(id).first).single.sohPermille, 912);
  });

  test('lifecycle: setStatus stamps status + disposal close-out', () async {
    final id = await seed();
    final r = await repo.setStatus(
      id,
      'sold',
      soldDateMillis: 5000,
      soldPriceMinor: 800000,
      finalOdometerMetres: 210000000,
    );
    expect(r.isOk, isTrue);
    final v = (await repo.getById(id)).valueOrNull!;
    expect(v.status, 'sold');
  });

  test('setDefault pins exactly one vehicle', () async {
    final a = await seed(nickname: 'A');
    final b = await seed(nickname: 'B');
    await repo.setDefault(a);
    await repo.setDefault(b);
    final all = await repo.watchGarage().first;
    expect(all.where((v) => v.isDefault).map((v) => v.id), [b]);
  });

  test('soft-delete tombstones + hides; restore brings it back', () async {
    final id = await seed();
    await repo.softDelete(id);
    expect((await repo.getById(id)).valueOrNull, isNull);
    expect(await repo.watchGarage().first, isEmpty);
    await repo.restore(id);
    expect((await repo.getById(id)).valueOrNull, isNotNull);
  });

  test('purge permanently deletes and cascades children', () async {
    final id = await seed();
    await repo.addPlateHistory(id, plate: 'X');
    await repo.addValuation(id,
        valuedAt: 1, amountMinor: 1, currencyCode: 'EUR');

    expect((await repo.purge(id)).isOk, isTrue);

    // Vehicle gone AND its child rows cascaded away (FK onDelete: cascade).
    final plates = await db.select(db.plateHistory).get();
    final vals = await db.select(db.valuationHistory).get();
    expect(plates, isEmpty);
    expect(vals, isEmpty);
    expect((await repo.purge(id)).isErr, isTrue); // already gone → NotFound
  });

  test('a tag containing a comma round-trips intact (no corruption)', () async {
    final id = await seed();
    await repo.update(
        id, const VehicleEdit(tags: ['winter, studded', 'daily']));
    final v = (await repo.getById(id)).valueOrNull!;
    expect(v.tags, ['winter, studded', 'daily']); // not split on the comma
  });

  test(
      'an energy switch clears the now-irrelevant capacity (VehicleEdit.clear)',
      () async {
    final id = await seed();
    await repo.update(id, const VehicleEdit(batteryCapacityJoules: 216000000));
    expect(
        (await repo.getById(id)).valueOrNull!.batteryCapacityJoules, 216000000);
    // Switching to a fuel powertrain clears the battery capacity.
    await repo.update(
      id,
      const VehicleEdit(
          energyType: 'gasoline', clear: {'batteryCapacityJoules'}),
    );
    final v = (await repo.getById(id)).valueOrNull!;
    expect(v.batteryCapacityJoules, isNull);
    expect(v.energyType, 'gasoline');
  });

  test('setDefault on a missing/trashed id is NotFound and keeps the default',
      () async {
    final a = await seed(nickname: 'A');
    await repo.setDefault(a);
    // A stale/nonexistent id must NOT clear the existing default.
    expect((await repo.setDefault('ghost')).isErr, isTrue);
    expect((await repo.getById(a)).valueOrNull!.isDefault, isTrue);
    // A trashed vehicle cannot be pinned.
    final b = await seed(nickname: 'B');
    await repo.softDelete(b);
    expect((await repo.setDefault(b)).isErr, isTrue);
    expect((await repo.getById(a)).valueOrNull!.isDefault, isTrue);
  });

  test('lifecycle/rename writes bump row_revision (audit invariant)', () async {
    final id = await seed();
    final r0 = (await db.select(db.vehicles).get()).single.rowRevision;
    await repo.rename(id, 'Renamed');
    await repo.setStatus(id, 'archived');
    final r1 = (await db.select(db.vehicles).get()).single.rowRevision;
    expect(r1, greaterThanOrEqualTo(r0 + 2));
  });

  test('watchGarage orders by manual sortOrder then age', () async {
    final a = await seed(nickname: 'A');
    final b = await seed(nickname: 'B');
    await repo.update(a, const VehicleEdit(sortOrder: 20));
    await repo.update(b, const VehicleEdit(sortOrder: 10));
    final ordered = await repo.watchGarage().first;
    expect(ordered.map((v) => v.id), [b, a]); // b's lower sortOrder wins
  });
}
