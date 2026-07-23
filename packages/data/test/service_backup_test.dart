import 'dart:convert';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

/// M4-T7 — every service entity round-trips losslessly through the canonical
/// backup, exports to per-entity CSV, and competitor service history maps in.
void main() {
  Future<void> seedType(AppDatabase db, String id) => db.customStatement(
        'INSERT INTO categories (id, created_at, updated_at, kind, label, '
        "analytic_bucket) VALUES ('$id', 0, 0, 'service', '$id', 'service')",
      );

  Future<AppDatabase> seededDb() async {
    final db = AppDatabase.memory();
    final v = (await VehiclesRepository(db).add(nickname: 'Golf')).valueOrNull!;
    await seedType(db, 'oil');
    final repo = ServiceRepository(db);
    await repo.add(
      vehicleId: v.id,
      servicedAt: const Instant.fromEpochMillis(1000),
      currencyCode: 'EUR',
      odometerMetres: 120000000,
      taxMinor: 1000,
      lineItems: const [
        ServiceLineItemDraft(
          serviceTypeId: 'oil',
          labourMinor: 5000,
          partsMinor: 3000,
          warrantyUntilDate: 99999,
          parts: [
            PartDraft(name: 'Oil filter', oemNumber: 'W712', quantity: 2)
          ],
          fluids: [FluidDraft(fluidType: 'engineOil', spec: '5W-30')],
          procedureSteps: [ProcedureStepDraft(instruction: 'Drain')],
        ),
      ],
    );
    await repo.addAppointment(
      vehicleId: v.id,
      scheduledAt: const Instant.fromEpochMillis(500000),
      title: 'Next oil change',
    );
    return db;
  }

  test('the full service graph round-trips losslessly through canonical JSON',
      () async {
    final db = await seededDb();
    addTearDown(db.close);
    final doc = await CanonicalCodec(db).export();

    final db2 = AppDatabase.memory();
    addTearDown(db2.close);
    expect((await CanonicalCodec(db2).import(doc)).isOk, isTrue);

    // Re-export from the fresh DB and compare the service entities deeply.
    final doc2 = await CanonicalCodec(db2).export();
    final ent1 = (doc['entities'] as Map).cast<String, dynamic>();
    final ent2 = (doc2['entities'] as Map).cast<String, dynamic>();
    for (final e in [
      'service_entries',
      'service_line_items',
      'parts_used',
      'fluids_used',
      'service_procedure_steps',
      'service_appointments',
      'service_providers',
    ]) {
      expect(
        jsonEncode(ent2[e]),
        jsonEncode(ent1[e]),
        reason: '$e must round-trip',
      );
    }

    // Spot-check the rebuilt graph is queryable.
    final v = (await VehiclesRepository(db2).watchAll().first).single;
    final visit =
        (await ServiceRepository(db2).watchByVehicle(v.id).first).single;
    expect(visit.totalCostMinor, 9000); // 5000+3000+1000 tax
    final parts = await ServiceRepository(db2).partsFor(
      (await ServiceRepository(db2).lineItemsFor(visit.id)).single.id,
    );
    expect(parts.single.oemNumber, 'W712');
    expect(await ServiceRepository(db2).watchAppointments(v.id).first,
        hasLength(1));
  });

  test('every service entity exports to its own flat CSV', () async {
    final db = await seededDb();
    addTearDown(db.close);
    final doc = await CanonicalCodec(db).export();
    final csvs = exportEntitiesToCsv(doc);

    for (final name in [
      'service_entries',
      'service_line_items',
      'parts_used',
      'fluids_used',
      'service_procedure_steps',
      'service_appointments',
    ]) {
      expect(csvs.containsKey(name), isTrue, reason: '$name.csv must exist');
    }
    // The part CSV carries the LTR-safe OEM number.
    expect(csvs['parts_used'], contains('W712'));
  });

  group('competitor service-history import presets (M4-T7)', () {
    test('Drivvo maps date/odometer(km)/cost/type/notes to canonical', () {
      final row = drivvoServicePreset.mapRow({
        'Date': '2026-07-15',
        'Odometer (km)': '100000',
        'Total cost': r'$120.50',
        'Type of service': 'Oil change',
        'Observation': 'synthetic',
      });
      expect(row['servicedAtUtcMillis'],
          DateTime.utc(2026, 7, 15).millisecondsSinceEpoch);
      expect(row['odometerMetres'], 100000000); // 100_000 km → metres
      expect(row['totalCostMinorUnits'], 12050);
      expect(row['serviceType'], 'Oil change');
      expect(row['note'], 'synthetic');
    });

    test('aCar and Fuelio presets are offered by the wizard', () {
      expect(
          competitorPresets.map((p) => p.name),
          containsAll(
              ['Drivvo (service)', 'aCar (service)', 'Fuelio (costs)']));
      // km coercion is exact.
      expect(kmToMetres('12.5'), 12500);
    });
  });
}
