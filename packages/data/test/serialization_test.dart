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
