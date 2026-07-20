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
}
