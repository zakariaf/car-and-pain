import 'dart:io';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

/// M4-T3 — the bundled schedule-template asset loads + parses fully offline, and
/// applying it to a vehicle creates recurring reminders anchored to its state.
void main() {
  const lib = ScheduleTemplateLibrary();

  // Read the SHIPPED asset directly from disk (no rootBundle) so the test pins
  // the real bundled content, not a fixture.
  String genericAssetJson() =>
      File('assets/schedules/generic.json').readAsStringSync();

  test('the bundled generic asset parses and is versioned', () {
    final result = lib.parse(genericAssetJson());
    expect(result.isOk, isTrue);
    final t = result.valueOrNull!;
    expect(t.version, ScheduleTemplate.currentVersion);
    expect(t.id, 'generic');
    expect(t.entries, isNotEmpty);
    // The oil change ships with a severe-duty override (shortened).
    final oil = t.entries.firstWhere((e) => e.serviceType == 'oil_change');
    expect(oil.severeDistanceMetres, isNotNull);
    expect(oil.severeDistanceMetres! < oil.distanceMetres!, isTrue);
  });

  test('a template authored for a newer schema version is refused', () {
    final r = lib.parse('{"version": 999, "id": "x", "name": "x", '
        '"entries": []}');
    expect(r.failureOrNull, isA<SchemaVersionMismatch>());
  });

  test('malformed template JSON is a typed CorruptArchive', () {
    expect(lib.parse('not json').failureOrNull, isA<CorruptArchive>());
  });

  test('applying the template creates recurring reminders anchored to state',
      () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final vehicles = VehiclesRepository(db);
    final v = (await vehicles.add(nickname: 'Golf')).valueOrNull!;
    // Give the vehicle a current odometer via a fuel fill.
    await FuelRepository(db).add(
      vehicleId: v.id,
      filledAt: const Instant.fromEpochMillis(1000),
      odometerMetres: 100000000, // 100_000 km
      volumeMl: 40000,
      totalCostMinor: 6000,
      currencyCode: 'EUR',
    );

    final template = lib.parse(genericAssetJson()).valueOrNull!;
    final ids = (await ServiceRepository(db).applyTemplate(
      v.id,
      template,
      profile: ScheduleProfile.generic,
      anchorDate: const Instant.fromEpochMillis(1000),
      resolveTitle: (key) => 'Service: $key',
    ))
        .valueOrNull!;
    expect(ids.length, template.entries.length);

    // The reminders landed with anchored thresholds and a resolved title.
    final rows = await db.customSelect(
      'SELECT title, trigger_type, due_odometer_metres FROM reminders '
      'WHERE vehicle_id = ?',
      variables: [Variable<String>(v.id)],
    ).get();
    expect(rows, hasLength(template.entries.length));
    final oil = rows
        .firstWhere((r) => r.read<String>('title') == 'Service: oil_change');
    expect(oil.read<String>('trigger_type'), 'whicheverFirst');
    // 100_000 km + 15_000 km generic interval = 115_000 km.
    expect(oil.read<int?>('due_odometer_metres'), 115000000);
  });
}
