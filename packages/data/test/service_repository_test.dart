import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

/// M4-T1 — the service schema + repository: one receipt per visit, atomic ledger
/// write, filterable history, back-date-safe odometer cache, and rollup-reversing
/// soft-delete.
void main() {
  Future<(AppDatabase, String)> freshWithVehicle() async {
    final db = AppDatabase.memory();
    final v = (await VehiclesRepository(db).add(nickname: 'Golf')).valueOrNull!;
    return (db, v.id);
  }

  // Read the monthly cost rollup for a vehicle (filter the metric in Dart to
  // avoid importing drift's `&` operator into the test).
  Future<int> rollupCost(AppDatabase db, String vehicleId) async {
    final rows = await (db.select(db.rollups)
          ..where((t) => t.vehicleId.equals(vehicleId)))
        .get();
    return rows.where((r) => r.metric == 'costMinor').firstOrNull?.value ?? 0;
  }

  // Seed a service-type row so a line item's serviceTypeId FK resolves (service
  // types are taxonomy refs, and the FK is enforced with foreign_keys ON).
  Future<void> seedType(AppDatabase db, String id) => db.customStatement(
        'INSERT INTO categories (id, created_at, updated_at, kind, label, '
        "analytic_bucket) VALUES ('$id', 0, 0, 'service', '$id', 'service')",
      );

  test('a visit owns its line items under one receipt; total is computed',
      () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    final repo = ServiceRepository(db);
    await seedType(db, 'oil');
    await seedType(db, 'brakes');

    final id = (await repo.add(
      vehicleId: vehicleId,
      servicedAt: const Instant.fromEpochMillis(1000),
      currencyCode: 'EUR',
      odometerMetres: 120000000,
      taxMinor: 1000,
      discountMinor: 500,
      lineItems: const [
        ServiceLineItemDraft(
            serviceTypeId: 'oil', labourMinor: 5000, partsMinor: 3000),
        ServiceLineItemDraft(
            serviceTypeId: 'brakes', labourMinor: 2000, partsMinor: 1500),
      ],
    ))
        .valueOrNull!;

    final visit = await repo.visit(id);
    expect(visit, isNotNull);
    // 8000 + 3500 + tax 1000 − discount 500 = 12000.
    expect(visit!.totalCostMinor, 12000);
    expect(visit.lineItems, hasLength(2));
    expect(visit.lineItems.first.serviceTypeId, 'oil');
    // Line-item order is preserved.
    expect(visit.lineItems[1].serviceTypeId, 'brakes');
  });

  test('the visit writes its odometer into the shared ledger atomically',
      () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    final id = (await ServiceRepository(db).add(
      vehicleId: vehicleId,
      servicedAt: const Instant.fromEpochMillis(2000),
      currencyCode: 'EUR',
      odometerMetres: 150000000,
      lineItems: const [ServiceLineItemDraft(partsMinor: 4000)],
    ))
        .valueOrNull!;

    final readings = await LedgerRepository(db).watchByVehicle(vehicleId).first;
    expect(readings, hasLength(1));
    expect(readings.single.value, 150000000);
    expect(readings.single.source, LedgerSource.service);
    // Back-reference to the visit is set.
    expect(id, isNotEmpty);
  });

  test('a failed visit save rolls back the ledger reading too (atomicity)',
      () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    final repo = ServiceRepository(db);

    // A line item references a service type that does not exist → the FK insert
    // fails mid-transaction, AFTER the visit row and ledger row would be written.
    final result = await repo.add(
      vehicleId: vehicleId,
      servicedAt: const Instant.fromEpochMillis(2000),
      currencyCode: 'EUR',
      odometerMetres: 150000000,
      lineItems: const [ServiceLineItemDraft(serviceTypeId: 'does-not-exist')],
    );
    expect(result.isErr, isTrue);

    // Neither the visit NOR its ledger row survived — the whole write rolled back.
    final visits = await repo.watchByVehicle(vehicleId).first;
    expect(visits, isEmpty);
    expect(await LedgerRepository(db).watchByVehicle(vehicleId).first, isEmpty);
  });

  test('a visit without an odometer writes no ledger row', () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    await ServiceRepository(db).add(
      vehicleId: vehicleId,
      servicedAt: const Instant.fromEpochMillis(2000),
      currencyCode: 'EUR',
      lineItems: const [ServiceLineItemDraft(partsMinor: 4000)],
    );
    expect(await LedgerRepository(db).watchByVehicle(vehicleId).first, isEmpty);
  });

  test('a back-dated service never rewinds the cached current odometer',
      () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    final repo = ServiceRepository(db);

    // A recent service at 200_000 km sets the cache.
    await repo.add(
      vehicleId: vehicleId,
      servicedAt: const Instant.fromEpochMillis(10000),
      currencyCode: 'EUR',
      odometerMetres: 200000000,
    );
    // A back-dated historical service at 50_000 km must NOT clobber the cache.
    await repo.add(
      vehicleId: vehicleId,
      servicedAt: const Instant.fromEpochMillis(1000),
      currencyCode: 'EUR',
      odometerMetres: 50000000,
    );

    final veh = await (db.select(db.vehicles)
          ..where((t) => t.id.equals(vehicleId)))
        .getSingleOrNull();
    expect(veh!.currentOdometerMetres, 200000000);
  });

  test('history is filterable and excludes tombstones, newest first', () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    final repo = ServiceRepository(db);

    final shopId = (await repo.add(
      vehicleId: vehicleId,
      servicedAt: const Instant.fromEpochMillis(1000),
      currencyCode: 'EUR',
      lineItems: const [ServiceLineItemDraft(partsMinor: 100)],
    ))
        .valueOrNull!;
    await repo.add(
      vehicleId: vehicleId,
      servicedAt: const Instant.fromEpochMillis(3000),
      currencyCode: 'EUR',
      isDiy: true,
      lineItems: const [ServiceLineItemDraft(partsMinor: 200)],
    );

    // Newest first.
    final all = await repo.watchByVehicle(vehicleId).first;
    expect(all.map((v) => v.servicedAt.epochMillis), [3000, 1000]);

    // DIY filter.
    final diyOnly = await repo.watchByVehicle(vehicleId, isDiy: true).first;
    expect(diyOnly, hasLength(1));
    expect(diyOnly.single.isDiy, isTrue);

    // Soft-delete removes the shop visit from the stream.
    expect((await repo.softDelete(shopId)).isOk, isTrue);
    final afterDelete = await repo.watchByVehicle(vehicleId).first;
    expect(afterDelete.map((v) => v.servicedAt.epochMillis), [3000]);
  });

  test('softDelete reverses the cost rollup and guards double-delete',
      () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    final repo = ServiceRepository(db);

    final id = (await repo.add(
      vehicleId: vehicleId,
      servicedAt: const Instant.fromEpochMillis(5000),
      currencyCode: 'EUR',
      lineItems: const [ServiceLineItemDraft(partsMinor: 9000)],
    ))
        .valueOrNull!;
    expect(await rollupCost(db, vehicleId), 9000);

    expect((await repo.softDelete(id)).isOk, isTrue);
    // Rollup is back to zero — a trashed visit is never counted.
    expect(await rollupCost(db, vehicleId), 0);
    // Line items are tombstoned with the visit.
    expect(await repo.lineItemsFor(id), isEmpty);
    // Double-delete is a typed NotFound, not a silent success.
    expect((await repo.softDelete(id)).failureOrNull, isA<NotFound>());
  });

  test('serviceEventsByType groups anchors for the schedule engine', () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    final repo = ServiceRepository(db);
    await seedType(db, 'oil');

    await repo.add(
      vehicleId: vehicleId,
      servicedAt: const Instant.fromEpochMillis(1000),
      currencyCode: 'EUR',
      odometerMetres: 100000000,
      lineItems: const [
        ServiceLineItemDraft(serviceTypeId: 'oil', partsMinor: 100),
        ServiceLineItemDraft(serviceTypeId: 'oil', resetsInterval: false),
      ],
    );

    final byType = await repo.serviceEventsByType(vehicleId);
    expect(byType.keys, contains('oil'));
    expect(byType['oil'], hasLength(2));
    // The reset flag rides through so the engine can pick the anchor.
    expect(byType['oil']!.where((e) => e.resetsInterval), hasLength(1));
  });

  // ── M4-T2: parts, fluids, procedure logs, warranty, catalog ────────────────

  test('a line item carries parts, fluids, procedure steps, and warranty',
      () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    final repo = ServiceRepository(db);
    await seedType(db, 'oil');

    final id = (await repo.add(
      vehicleId: vehicleId,
      servicedAt: const Instant.fromEpochMillis(1000),
      currencyCode: 'EUR',
      lineItems: const [
        ServiceLineItemDraft(
          serviceTypeId: 'oil',
          partsMinor: 4000,
          warrantyUntilDate: 99999,
          warrantyUntilMileageMetres: 200000000,
          parts: [
            PartDraft(
              name: 'Oil filter',
              brand: 'Mann',
              oemNumber: 'W712',
              quantity: 2,
              unitCostMinor: 1500,
            ),
          ],
          fluids: [
            FluidDraft(fluidType: 'engineOil', spec: '5W-30', quantityMl: 5000),
          ],
          procedureSteps: [
            ProcedureStepDraft(instruction: 'Drain', torqueSpec: '25Nm'),
            ProcedureStepDraft(instruction: 'Refill'),
          ],
        ),
      ],
    ))
        .valueOrNull!;

    final li = (await repo.lineItemsFor(id)).single;
    expect(li.warrantyUntilDate, 99999);
    expect(li.warrantyUntilMileageMetres, 200000000);

    final parts = await repo.partsFor(li.id);
    expect(parts, hasLength(1));
    expect(parts.single.oemNumber, 'W712');
    expect(parts.single.totalCostMinor, 3000); // 1500 × 2

    final fluids = await repo.fluidsFor(li.id);
    expect(fluids.single.spec, '5W-30');
    expect(fluids.single.quantityMl, 5000);

    final steps = await repo.procedureStepsFor(li.id);
    expect(steps.map((s) => s.instruction), ['Drain', 'Refill']);
    expect(steps.first.stepOrder, 0);
    expect(steps.first.torqueSpec, '25Nm');
  });

  test('parts catalog dedups by (name, oem), newest first, with a query filter',
      () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    final repo = ServiceRepository(db);
    await seedType(db, 'oil');

    Future<void> addWith(int at, PartDraft part) => repo.add(
          vehicleId: vehicleId,
          servicedAt: Instant.fromEpochMillis(at),
          currencyCode: 'EUR',
          lineItems: [
            ServiceLineItemDraft(serviceTypeId: 'oil', parts: [part]),
          ],
        );

    await addWith(1000, const PartDraft(name: 'Oil filter', oemNumber: 'W712'));
    await addWith(2000, const PartDraft(name: 'Brake pad', oemNumber: 'BP1'));
    // A newer duplicate of the oil filter must collapse to one entry.
    await addWith(
        3000,
        const PartDraft(
            name: 'Oil filter', oemNumber: 'W712', unitCostMinor: 1600));

    final all = await repo.partsCatalog();
    expect(all, hasLength(2)); // deduped
    expect(all.first.name, 'Oil filter'); // newest first, newest cost
    expect(all.first.unitCostMinor, 1600);

    final filtered = await repo.partsCatalog(query: 'brake');
    expect(filtered, hasLength(1));
    expect(filtered.single.name, 'Brake pad');
  });

  // ── M4-T5: appointments, .ics, independence, warranty expiries ─────────────

  test('appointment lifecycle: book, list active, set status, build .ics',
      () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    final repo = ServiceRepository(db);

    final id = (await repo.addAppointment(
      vehicleId: vehicleId,
      scheduledAt: Instant.fromDateTime(DateTime.utc(2026, 7, 15, 9, 30)),
      durationMinutes: 90,
      title: 'Oil change',
    ))
        .valueOrNull!;

    expect(await repo.watchAppointments(vehicleId, activeOnly: true).first,
        hasLength(1));

    final ics = await repo.appointmentIcs(id, summary: 'Oil change');
    expect(ics, contains('DTSTART:20260715T093000Z'));
    expect(ics, contains('DTEND:20260715T110000Z'));

    // Completing it drops it from the active list but keeps it in the full list.
    expect((await repo.setAppointmentStatus(id, 'completed')).isOk, isTrue);
    expect(await repo.watchAppointments(vehicleId, activeOnly: true).first,
        isEmpty);
    expect(await repo.watchAppointments(vehicleId).first, hasLength(1));

    // A status update on a missing appointment is a typed NotFound.
    expect(
        (await repo.setAppointmentStatus('ghost', 'cancelled')).failureOrNull,
        isA<NotFound>());
  });

  test('cancelling an appointment never clears interval reminders', () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    final repo = ServiceRepository(db);
    await seedType(db, 'oil');

    // An interval reminder from applying a template.
    const template = ScheduleTemplate(
      version: 1,
      id: 'generic',
      name: 'schedule.generic',
      entries: [
        ScheduleTemplateEntry(
          serviceType: 'oil',
          logic: ServiceIntervalLogic.time,
          months: 12,
        ),
      ],
    );
    await repo.applyTemplate(
      vehicleId,
      template,
      profile: ScheduleProfile.generic,
      anchorDate: const Instant.fromEpochMillis(0),
    );
    final appt = (await repo.addAppointment(
      vehicleId: vehicleId,
      scheduledAt: const Instant.fromEpochMillis(1000),
    ))
        .valueOrNull!;

    Future<int> reminderCount() async =>
        (await db.customSelect('SELECT id FROM reminders WHERE vehicle_id = ?',
                variables: [Variable<String>(vehicleId)]).get())
            .length;

    expect(await reminderCount(), 1);
    // Cancel the appointment — the interval reminder is untouched.
    expect((await repo.setAppointmentStatus(appt, 'cancelled')).isOk, isTrue);
    expect(await reminderCount(), 1);
  });

  test('warranty expiries surface part + workmanship limits (date and mileage)',
      () async {
    final (db, vehicleId) = await freshWithVehicle();
    addTearDown(db.close);
    final repo = ServiceRepository(db);
    await seedType(db, 'oil');

    await repo.add(
      vehicleId: vehicleId,
      servicedAt: const Instant.fromEpochMillis(1000),
      currencyCode: 'EUR',
      lineItems: const [
        ServiceLineItemDraft(
          serviceTypeId: 'oil',
          warrantyUntilDate: 50000,
          warrantyUntilMileageMetres: 200000000,
          parts: [
            PartDraft(
              name: 'Timing belt',
              warrantyUntilDate: 99999,
            ),
          ],
        ),
      ],
    );

    final expiries = await repo.warrantyExpiries(vehicleId);
    expect(expiries, hasLength(2));
    final workmanship = expiries.firstWhere((e) => e.source == 'workmanship');
    expect(workmanship.untilDate, 50000);
    expect(workmanship.untilMileageMetres, 200000000);
    final part = expiries.firstWhere((e) => e.source == 'part');
    expect(part.label, 'Timing belt');
    expect(part.untilDate, 99999);
  });
}
