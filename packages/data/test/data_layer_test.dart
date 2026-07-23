import 'package:core/core.dart';
import 'package:data/data.dart';
// Hide `isNull` so the matcher (not drift's SQL helper) is used in expectations.
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Instant on(int dayN) => Instant.fromEpochMillis(
      1000000000000 + dayN * Duration.millisecondsPerDay);

  Future<int> rollupValue(String vehicleId, String metric) async {
    final rows = await (db.select(db.rollups)
          ..where(
              (t) => t.vehicleId.equals(vehicleId) & t.metric.equals(metric)))
        .get();
    return rows.fold<int>(0, (s, r) => s + r.value);
  }

  Future<int> rowRevisionOf(String id) async {
    final row = await (db.select(db.vehicles)..where((t) => t.id.equals(id)))
        .getSingle();
    return row.rowRevision;
  }

  group('VehiclesRepository', () {
    test('add / watch (tombstone-filtered) / soft-delete / restore', () async {
      final repo = VehiclesRepository(db);
      final added = await repo.add(nickname: 'Peugeot 208');
      expect(added.isOk, isTrue);
      final id = added.valueOrNull!.id;

      expect(await repo.watchAll().first, hasLength(1));

      expect((await repo.softDelete(id)).isOk, isTrue);
      expect(await repo.watchAll().first, isEmpty); // excluded from reads
      expect((await repo.getById(id)).valueOrNull, isNull);

      expect((await repo.restore(id)).isOk, isTrue);
      expect(await repo.watchAll().first, hasLength(1));
    });

    test('soft-delete of a missing row → Err(NotFound)', () async {
      final repo = VehiclesRepository(db);
      final r = await repo.softDelete('nope');
      expect(r.isErr, isTrue);
      expect(r.failureOrNull, isA<NotFound>());
    });
  });

  group('Transactional fuel write (parent + ledger + rollup)', () {
    test('one fuel write touches fuel, ledger, vehicle odometer & rollups',
        () async {
      final vehicles = VehiclesRepository(db);
      final v = (await vehicles.add(nickname: 'Golf')).valueOrNull!;

      final res = await FuelRepository(db).add(
        vehicleId: v.id,
        filledAt: on(0),
        odometerMetres: 10000000,
        volumeMl: 40000,
        totalCostMinor: 6000,
        currencyCode: 'EUR',
      );
      expect(res.isOk, isTrue);

      final readings = await LedgerRepository(db).watchByVehicle(v.id).first;
      expect(readings, hasLength(1));
      expect(readings.single.source, LedgerSource.fuel);
      expect(readings.single.value, 10000000);

      expect(await rollupValue(v.id, 'costMinor'), 6000);
      expect(await rollupValue(v.id, 'fuelMl'), 40000);

      // The cached vehicle odometer updated in the same transaction.
      final row = await (db.select(db.vehicles)
            ..where((t) => t.id.equals(v.id)))
          .getSingle();
      expect(row.currentOdometerMetres, 10000000);
    });

    test('rollup rebuild deterministically matches the incremental values',
        () async {
      final vehicles = VehiclesRepository(db);
      final v = (await vehicles.add(nickname: 'Corolla')).valueOrNull!;
      final fuel = FuelRepository(db);
      await fuel.add(
          vehicleId: v.id,
          filledAt: on(0),
          odometerMetres: 1000000,
          volumeMl: 30000,
          totalCostMinor: 4500,
          currencyCode: 'EUR');
      await fuel.add(
          vehicleId: v.id,
          filledAt: on(5),
          odometerMetres: 1400000,
          volumeMl: 35000,
          totalCostMinor: 5200,
          currencyCode: 'EUR');

      final expenses = ExpensesRepository(db);
      // A plain manual base-currency expense — counted.
      await expenses.add(
          vehicleId: v.id,
          spentAt: on(1),
          amountMinor: 1999,
          currencyCode: 'EUR');
      // A foreign-currency expense: the incremental path counts baseAmountMinor,
      // NOT the raw amountMinor — rebuild must do the same.
      await expenses.add(
          vehicleId: v.id,
          spentAt: on(2),
          amountMinor: 5000,
          currencyCode: 'USD',
          fxRateThousandths: 920,
          baseAmountMinor: 4600);
      // A projected cross-module row: counted by its own module, so the expense
      // rollup must skip it on BOTH the incremental and the rebuild paths.
      await expenses.add(
          vehicleId: v.id,
          spentAt: on(3),
          amountMinor: 9999,
          currencyCode: 'EUR',
          sourceEntityType: 'fuel',
          sourceEntityId: 'some-fuel-id');

      final incrementalCost = await rollupValue(v.id, 'costMinor');
      final incrementalFuel = await rollupValue(v.id, 'fuelMl');

      await RollupService(db).rebuild(v.id, now: on(10).epochMillis);
      expect(await rollupValue(v.id, 'costMinor'), incrementalCost);
      expect(await rollupValue(v.id, 'fuelMl'), incrementalFuel);
    });
  });

  group('LedgerRepository warn-with-override', () {
    test('regression yields a warning but still persists', () async {
      final v = (await VehiclesRepository(db).add(nickname: 'X')).valueOrNull!;
      final ledger = LedgerRepository(db);
      await ledger.appendManual(
          vehicleId: v.id, value: 10000000, takenAt: on(0));
      final warned = await ledger.appendManual(
        vehicleId: v.id,
        value: 9999000, // lower → regression
        takenAt: on(1),
      );
      expect(warned.isOk, isTrue);
      expect(warned.valueOrNull!.map((e) => e.code), contains('regression'));
      // The row still persisted despite the warning.
      expect(await ledger.watchByVehicle(v.id).first, hasLength(2));
    });
  });

  group('TrashRepository (cross-entity)', () {
    test('list / restore / purge across entities', () async {
      final t0 = DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true);
      final vehicles = VehiclesRepository(db, clock: FixedClock(t0));
      final v = (await vehicles.add(nickname: 'ToTrash')).valueOrNull!;
      await vehicles.softDelete(v.id, retention: const Duration(days: 1));

      final trash = TrashRepository(db);
      final listed = (await trash.list()).valueOrNull!;
      expect(listed.map((i) => i.entityType), contains('vehicles'));
      expect(listed.any((i) => i.id == v.id), isTrue);

      // Restore clears the tombstone.
      expect((await trash.restore('vehicles', v.id)).isOk, isTrue);
      expect(await vehicles.watchAll().first, hasLength(1));

      // Re-trash, then purge at a time well past the retention window.
      await vehicles.softDelete(v.id, retention: const Duration(days: 1));
      final latePurge = TrashRepository(
        db,
        clock: FixedClock(t0.add(const Duration(days: 2))),
      );
      final purged = await latePurge.purgeExpired();
      expect(purged.valueOrNull, greaterThanOrEqualTo(1));
      expect((await trash.list()).valueOrNull, isEmpty);
    });

    test('restore notifies a live .watch() stream and bumps row_revision',
        () async {
      final vehicles = VehiclesRepository(db);
      final v = (await vehicles.add(nickname: 'Live')).valueOrNull!;
      await vehicles.softDelete(v.id, retention: const Duration(days: 1));
      final revAfterDelete = await rowRevisionOf(v.id);

      // Subscribe BEFORE the restore: the already-open stream (empty now) must
      // re-emit with the row back. customStatement would leave it stale at 0.
      final counts = vehicles.watchAll().map((l) => l.length);
      final seesRestore = expectLater(counts, emitsInOrder(<int>[0, 1]));

      await pumpEventQueue();
      expect(
          (await TrashRepository(db).restore('vehicles', v.id)).isOk, isTrue);
      await seesRestore;

      expect(await rowRevisionOf(v.id), greaterThan(revAfterDelete));
    });

    test('purgeExpired notifies a live .watch() stream', () async {
      final t0 = DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true);
      final vehicles = VehiclesRepository(db, clock: FixedClock(t0));
      final v = (await vehicles.add(nickname: 'Purge')).valueOrNull!;
      await vehicles.softDelete(v.id, retention: const Duration(days: 1));

      // A live query over ALL rows (tombstoned included): 1 → 0 on hard purge.
      // The DELETE must pass `updates:` or this stream never re-emits.
      final totals = db
          .customSelect('SELECT COUNT(*) AS c FROM vehicles',
              readsFrom: {db.vehicles})
          .watch()
          .map((rows) => rows.first.read<int>('c'));
      final seesPurge = expectLater(totals, emitsInOrder(<int>[1, 0]));

      await pumpEventQueue();
      final latePurge = TrashRepository(
        db,
        clock: FixedClock(t0.add(const Duration(days: 2))),
      );
      expect((await latePurge.purgeExpired()).valueOrNull,
          greaterThanOrEqualTo(1));
      await seesPurge;
    });
  });

  group('TaxonomyRepository', () {
    test('seedDefaults is idempotent', () async {
      final repo = TaxonomyRepository(db);
      final first = await repo.seedDefaults();
      expect(first.valueOrNull, greaterThan(0));
      final second = await repo.seedDefaults();
      expect(second.valueOrNull, 0); // re-seed inserts nothing
      expect(await repo.watchByKind('expense').first, isNotEmpty);

      // Built-in service types ship with an interval default (M4-T6) so the
      // localized status cards compute a next-due out of the box.
      final services = await repo.watchByKind('service').first;
      final oil = services.firstWhere((c) => c.label == 'taxonomy.oil_change');
      expect(oil.defaultIntervalMetres, 15000000);
      expect(oil.defaultIntervalMonths, 12);
      expect(oil.defaultIntervalLogic, 'whicheverFirst');
    });
  });

  group('SettingsRepository (app-global key/value)', () {
    test('set / get / upsert / delete, and watchAll is reactive', () async {
      final settings = SettingsRepository(db);

      // A live watcher: {} → {locale: en} → {locale: fa} as writes land.
      final sizes = settings.watchAll().map((m) => m['locale']);
      final seen = expectLater(sizes, emitsInOrder([null, 'en', 'fa']));

      await pumpEventQueue();
      expect((await settings.set('locale', 'en')).isOk, isTrue);
      expect(await settings.get('locale'), 'en');
      expect((await settings.set('locale', 'fa')).isOk, isTrue); // upsert
      await seen;

      expect(await settings.readAll(), {'locale': 'fa'});

      // Passing null removes the key (revert to default).
      expect((await settings.set('locale', null)).isOk, isTrue);
      expect(await settings.get('locale'), isNull);
    });
  });

  group('IntegrityValidators', () {
    test('over-capacity, future-dated, collect', () {
      expect(
        IntegrityValidators.overCapacityFuel(
                volumeMl: 60000, tankCapacityMl: 50000)
            ?.code,
        'over_capacity',
      );
      expect(
        IntegrityValidators.overCapacityFuel(
            volumeMl: 40000, tankCapacityMl: 50000),
        isNull,
      );
      expect(
        IntegrityValidators.futureDated(atMillis: 100, nowMillis: 50)?.code,
        'future_dated',
      );
      final failure = IntegrityValidators.collect([
        IntegrityValidators.overCapacityFuel(
            volumeMl: 60000, tankCapacityMl: 50000),
        null,
        IntegrityValidators.economyOutlier(litresPer100Km: 99),
      ]);
      expect(failure, isA<ValidationFailure>());
      expect(failure!.fieldErrors, hasLength(2));
    });
  });
}
