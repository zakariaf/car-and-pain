import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

/// M5-T1 — the user-facing reminder repository: CRUD returning Drift-free domain
/// models, derived live state over the F5 next-due engine + ledger, and
/// completion that re-anchors recurrence.
void main() {
  final t0 = DateTime.utc(2026, 7);
  Instant at(DateTime d) => Instant.fromDateTime(d);

  Future<(AppDatabase, RemindersRepository, String)> fresh() async {
    final db = AppDatabase.memory();
    final v = (await VehiclesRepository(db).add(nickname: 'Golf')).valueOrNull!;
    return (db, RemindersRepository(db, clock: FixedClock(t0)), v.id);
  }

  test('add returns a domain Reminder via watchByVehicle, tombstone-filtered',
      () async {
    final (db, repo, vehicleId) = await fresh();
    addTearDown(db.close);

    final id = (await repo.add(
      vehicleId: vehicleId,
      title: 'Inspection',
      kind: TriggerKind.date,
      dueDate: at(DateTime.utc(2026, 12)),
      severity: 'documents',
      notes: 'TÜV',
    ))
        .valueOrNull!;

    final list = await repo.watchByVehicle(vehicleId).first;
    expect(list, hasLength(1));
    expect(list.single, isA<Reminder>());
    expect(list.single.title, 'Inspection');
    expect(list.single.notes, 'TÜV');
    expect(list.single.triggerType, 'date');

    expect((await repo.softDelete(id)).isOk, isTrue);
    expect(await repo.watchByVehicle(vehicleId).first, isEmpty);
    expect((await repo.softDelete(id)).failureOrNull, isA<NotFound>());
  });

  test('live state grades a date rule overdue / due-soon / upcoming', () async {
    final (db, repo, vehicleId) = await fresh();
    addTearDown(db.close);

    await repo.add(
      vehicleId: vehicleId,
      title: 'Overdue',
      kind: TriggerKind.date,
      dueDate: at(t0.subtract(const Duration(days: 1))),
    );
    await repo.add(
      vehicleId: vehicleId,
      title: 'Soon',
      kind: TriggerKind.date,
      dueDate: at(t0.add(const Duration(days: 1))),
    );
    await repo.add(
      vehicleId: vehicleId,
      title: 'Later',
      kind: TriggerKind.date,
      dueDate: at(t0.add(const Duration(days: 60))),
    );

    final states = {
      for (final s in await repo.liveStatesFor(vehicleId))
        s.reminder.title: s.state,
    };
    expect(states['Overdue'], ReminderLiveState.overdue);
    expect(states['Soon'], ReminderLiveState.dueSoon);
    expect(states['Later'], ReminderLiveState.upcoming);
  });

  test('snooze masks an overdue rule; unsnooze restores it', () async {
    final (db, repo, vehicleId) = await fresh();
    addTearDown(db.close);
    final id = (await repo.add(
      vehicleId: vehicleId,
      title: 'X',
      kind: TriggerKind.date,
      dueDate: at(t0.subtract(const Duration(days: 1))),
    ))
        .valueOrNull!;

    await repo.snooze(id, at(t0.add(const Duration(days: 7))));
    expect((await repo.liveStatesFor(vehicleId)).single.state,
        ReminderLiveState.snoozed);

    await repo.unsnooze(id);
    expect((await repo.liveStatesFor(vehicleId)).single.state,
        ReminderLiveState.overdue);
  });

  test(
      'completing a one-off marks it done; recurring re-anchors and stays live',
      () async {
    final (db, repo, vehicleId) = await fresh();
    addTearDown(db.close);

    final oneOff = (await repo.add(
      vehicleId: vehicleId,
      title: 'One-off',
      kind: TriggerKind.date,
      dueDate: at(t0),
    ))
        .valueOrNull!;
    final recurring = (await repo.add(
      vehicleId: vehicleId,
      title: 'Recurring',
      kind: TriggerKind.date,
      dueDate: at(t0),
      recurrenceEvery: 6,
      recurrenceUnit: RecurrenceUnit.months,
    ))
        .valueOrNull!;

    expect((await repo.complete(oneOff, at: at(t0))).isOk, isTrue);
    expect((await repo.complete(recurring, at: at(t0))).isOk, isTrue);

    final done = await repo.byId(oneOff);
    expect(done!.status, 'done');

    final rec = await repo.byId(recurring);
    expect(rec!.status, 'active'); // recurring stays live
    expect(rec.completedAt, at(t0)); // re-anchored to the actual completion
    // Next occurrence is 6 months after completion (via the F5 engine).
    final recState = (await repo.liveStatesFor(vehicleId))
        .firstWhere((s) => s.reminder.id == recurring);
    expect(recState.next?.dueAt, at(DateTime.utc(2027)));
  });

  test('a distance rule projects a due date from the ledger', () async {
    final (db, repo, vehicleId) = await fresh();
    addTearDown(db.close);
    // Two readings a month apart → ~a known daily rate for projection.
    await LedgerRepository(db).appendManual(
      vehicleId: vehicleId,
      value: 100000000, // 100_000 km
      takenAt: at(t0.subtract(const Duration(days: 30))),
    );
    await LedgerRepository(db).appendManual(
      vehicleId: vehicleId,
      value: 101000000, // +1_000 km in 30 days
      takenAt: at(t0),
    );

    await repo.add(
      vehicleId: vehicleId,
      title: 'Oil',
      kind: TriggerKind.distance,
      dueOdometerMetres: 105000000, // 4_000 km away at ~33 km/day → ~120 days
    );

    final s = (await repo.liveStatesFor(vehicleId)).single;
    expect(s.next, isNotNull);
    expect(s.state, ReminderLiveState.upcoming);
    expect(s.next!.dueAt.epochMillis, greaterThan(t0.millisecondsSinceEpoch));
  });
}
