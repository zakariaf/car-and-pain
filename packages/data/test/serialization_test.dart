import 'dart:convert';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical export → import round-trips losslessly (incl. tombstones)',
      () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final vehicles = VehiclesRepository(db);
    final active = (await vehicles.add(nickname: 'Active')).valueOrNull!;
    final trashed = (await vehicles.add(nickname: 'Trashed')).valueOrNull!;
    await vehicles.softDelete(trashed.id); // tombstone must survive the trip
    await FuelRepository(db).add(
      vehicleId: active.id,
      filledAt: const Instant.fromEpochMillis(1000),
      odometerMetres: 10000000,
      volumeMl: 40000,
      totalCostMinor: 6000,
      currencyCode: 'EUR',
    );

    final doc = await CanonicalCodec(db).export();

    // Import into a fresh DB, then re-export → deep-equal.
    final db2 = AppDatabase.memory();
    addTearDown(db2.close);
    final result = await CanonicalCodec(db2).import(doc);
    expect(result.isOk, isTrue);

    final doc2 = await CanonicalCodec(db2).export();
    expect(jsonEncode(doc2['entities']), jsonEncode(doc['entities']));

    // The tombstoned vehicle is NOT resurrected; only the active one is live.
    expect(await VehiclesRepository(db2).watchAll().first, hasLength(1));
    // The ledger row written by the fuel entry round-tripped.
    expect(await LedgerRepository(db2).watchByVehicle(active.id).first,
        hasLength(1));
  });

  test('M2 vehicle child tables round-trip through the backup (T8)', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final vehicles = VehiclesRepository(db);
    final v = (await vehicles.add(nickname: 'EV')).valueOrNull!;
    await vehicles.update(
      v.id,
      const VehicleEdit(energyType: 'electric', licensePlate: 'EV-1'),
    );
    await vehicles.addPlateHistory(v.id, plate: 'OLD-9', country: 'DE');
    await vehicles.addValuation(v.id,
        valuedAt: 1000, amountMinor: 2500000, currencyCode: 'EUR');
    await vehicles.addStateOfHealth(v.id, recordedAt: 2000, sohPermille: 934);

    final doc = await CanonicalCodec(db).export();
    final db2 = AppDatabase.memory();
    addTearDown(db2.close);
    expect((await CanonicalCodec(db2).import(doc)).isOk, isTrue);

    // Re-export is byte-identical (child tables included) and children survived.
    final doc2 = await CanonicalCodec(db2).export();
    expect(jsonEncode(doc2['entities']), jsonEncode(doc['entities']));
    final v2 = VehiclesRepository(db2);
    expect((await v2.watchPlateHistory(v.id).first).single.plate, 'OLD-9');
    expect((await v2.watchValuations(v.id).first).single.amountMinor, 2500000);
    expect((await v2.watchStateOfHealth(v.id).first).single.sohPermille, 934);
    expect((await v2.getById(v.id)).valueOrNull!.energyType, 'electric');
  });

  test('M3 fuel/charge entries round-trip through the backup (T7)', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final v = (await VehiclesRepository(db).add(nickname: 'Rig')).valueOrNull!;
    final fuel = FuelRepository(db);
    // A liquid fill with M3 flags…
    await fuel.add(
      vehicleId: v.id,
      filledAt: const Instant.fromEpochMillis(1000),
      odometerMetres: 500000,
      volumeMl: 40000,
      totalCostMinor: 7036,
      currencyCode: 'EUR',
      fuelType: 'gasoline',
      pricePerUnitThousandths: 1759,
      stationName: 'Aral',
    );
    // …and an EV charge session.
    await fuel.add(
      vehicleId: v.id,
      filledAt: const Instant.fromEpochMillis(2000),
      odometerMetres: 700000,
      volumeMl: 0,
      totalCostMinor: 1200,
      currencyCode: 'EUR',
      fuelType: 'electric',
      startSocPct: 20,
      endSocPct: 80,
      isHomeCharge: true,
    );

    final doc = await CanonicalCodec(db).export();
    final db2 = AppDatabase.memory();
    addTearDown(db2.close);
    expect((await CanonicalCodec(db2).import(doc)).isOk, isTrue);

    // Re-export is byte-identical and every M3 field survived.
    final doc2 = await CanonicalCodec(db2).export();
    expect(jsonEncode(doc2['entities']), jsonEncode(doc['entities']));
    final entries = await FuelRepository(db2).watchByVehicle(v.id).first;
    expect(entries, hasLength(2));
    final charge = entries.firstWhere((e) => e.isCharge);
    expect(charge.startSocPct, 20);
    expect(charge.isHomeCharge, isTrue);
    final liquid = entries.firstWhere((e) => !e.isCharge);
    expect(liquid.pricePerUnitThousandths, 1759);
    expect(liquid.stationName, 'Aral');
  });

  test('a newer archive is refused with a typed failure', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final r = await CanonicalCodec(db).import({
      'formatVersion': 999,
      'entities': <String, dynamic>{},
    });
    expect(r.isErr, isTrue);
    expect(r.failureOrNull, isA<SchemaVersionMismatch>());
  });

  test('a malformed archive is a typed CorruptArchive', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final r = await CanonicalCodec(db).import({'formatVersion': 'nope'});
    expect(r.failureOrNull, isA<CorruptArchive>());
  });

  test('localization preferences round-trip through export/import (F4-T10)',
      () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final settings = SettingsRepository(db);
    await settings.set('locale', 'fa');
    await settings.set('calendar', 'jalali');
    await settings.set('numeral', 'persian');

    final doc = await CanonicalCodec(db).export();

    final db2 = AppDatabase.memory();
    addTearDown(db2.close);
    expect((await CanonicalCodec(db2).import(doc)).isOk, isTrue);

    final restored = await SettingsRepository(db2).readAll();
    expect(restored['locale'], 'fa');
    expect(restored['calendar'], 'jalali');
    expect(restored['numeral'], 'persian');
  });

  test('reminders round-trip including the F5 schedule fields (F5-T7)',
      () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final v = (await VehiclesRepository(db).add(nickname: 'X')).valueOrNull!;
    await db.customStatement(
      'INSERT INTO reminders (id, created_at, updated_at, vehicle_id, title, '
      'trigger_type, severity, recurrence_every, recurrence_unit, lead_minutes) '
      "VALUES ('rem', 0, 0, ?, 'Oil', 'date', 'overdue', 6, 'months', 120)",
      [v.id],
    );

    final doc = await CanonicalCodec(db).export();
    final db2 = AppDatabase.memory();
    addTearDown(db2.close);
    expect((await CanonicalCodec(db2).import(doc)).isOk, isTrue);

    final r = (await db2
            .customSelect(
              'SELECT severity, recurrence_every, recurrence_unit, '
              "lead_minutes FROM reminders WHERE id = 'rem'",
            )
            .get())
        .single;
    expect(r.read<String>('severity'), 'overdue');
    expect(r.read<int>('recurrence_every'), 6);
    expect(r.read<String>('recurrence_unit'), 'months');
    expect(r.read<int>('lead_minutes'), 120);
    // The projection is rebuildable, so a restore re-arms it via reconcileAll
    // (proven by the ReminderScheduler orchestration tests) rather than shipping
    // stale OS entries in the archive.
  });

  test('an older archive without settings imports to first-run defaults',
      () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    // Seed a preference, then import an archive that predates the settings
    // entity — a full replace-restore must clear it (no leftover, no crash).
    await SettingsRepository(db).set('locale', 'ar');
    final legacy = {
      'formatVersion': CanonicalCodec.formatVersion,
      'entities': <String, dynamic>{}, // no 'settings' key
    };
    expect((await CanonicalCodec(db).import(legacy)).isOk, isTrue);
    expect(await SettingsRepository(db).get('locale'), isNull);
  });
}
