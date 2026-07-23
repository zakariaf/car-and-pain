import 'package:car_and_pain/src/notifications/reminder_scheduler.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';

class _FakeCopy implements NotificationCopy {
  @override
  ({String body, String title}) forReminder(
    String vehicleName,
    ReminderScheduleDef def,
    NextDue due,
  ) =>
      (title: '$vehicleName: ${def.title}', body: 'due');

  @override
  ({String body, String title}) forDigest(
    List<(String, ReminderScheduleDef)> group,
  ) =>
      (title: '${group.length} due', body: 'digest');
}

int _ms(int y, int mo, int d) => DateTime.utc(y, mo, d).millisecondsSinceEpoch;

void main() {
  late AppDatabase db;
  late FakeNotificationGateway gateway;
  late ReminderScheduler scheduler;

  setUp(() async {
    db = AppDatabase.memory();
    gateway = FakeNotificationGateway();
    final vehicle =
        (await VehiclesRepository(db).add(nickname: 'Golf')).valueOrNull!;
    scheduler = ReminderScheduler(
      schedules: NotificationScheduleRepository(db),
      ledger: LedgerRepository(db),
      vehicles: VehiclesRepository(db),
      gateway: gateway,
      copy: _FakeCopy(),
    );

    Future<void> reminder(String id, String title, int dueMs, String sev) =>
        db.customStatement(
          'INSERT INTO reminders (id, created_at, updated_at, vehicle_id, '
          'title, trigger_type, due_date, severity) '
          "VALUES (?, 0, 0, ?, ?, 'date', ?, ?)",
          [id, vehicle.id, title, dueMs, sev],
        );

    // Two due the same day (→ one digest) + one on another day (→ single).
    await reminder('r1', 'Oil', _ms(2026, 6, 1), 'dueSoon');
    await reminder('r2', 'Tyres', _ms(2026, 6, 1), 'overdue');
    await reminder('r3', 'Inspection', _ms(2026, 7, 1), 'documents');
  });

  tearDown(() => db.close());

  test('reconcileAll: same-day items digest, lone item stays single', () async {
    final result = await scheduler.reconcileAll();
    expect(result.armed, 2); // one digest (Jun 1) + one single (Jul 1)

    final ids = await gateway.pendingIds();
    expect(ids, hasLength(2));

    // The Jun-1 pair collapsed into one grouped digest…
    final digest = gateway.scheduled.firstWhere((n) => n.groupKey != null);
    expect(digest.title, '2 due');
    // …and the lone Jul-1 item is ungrouped on its own severity channel.
    final single = gateway.scheduled.firstWhere((n) => n.groupKey == null);
    expect(single.channelId, 'documents');
    expect(single.title, 'Golf: Inspection');
  });

  test('the projection table mirrors what was armed', () async {
    await scheduler.reconcileAll();
    final projection =
        await NotificationScheduleRepository(db).loadProjection();
    expect(projection, hasLength(2));
  });

  test('a second reconcile is idempotent (no OS churn)', () async {
    await scheduler.reconcileAll();
    final again = await scheduler.reconcileAll();
    expect(again.mutations, 0);
    expect(again.unchanged, 2);
  });

  test('a paused reminder arms nothing', () async {
    await db.customStatement("UPDATE reminders SET status = 'paused'");
    final result = await scheduler.reconcileAll();
    expect(result.armed, 0);
    expect(await gateway.pendingIds(), isEmpty);
  });

  test('a new ledger reading re-projects a distance rule sooner (M5-T2)',
      () async {
    final fc = FixedClock(DateTime.utc(2026, 7));
    final s = ReminderScheduler(
      schedules: NotificationScheduleRepository(db),
      ledger: LedgerRepository(db),
      vehicles: VehiclesRepository(db),
      gateway: gateway,
      copy: _FakeCopy(),
      // Fully deterministic projection: fix both the engine and ledger clocks.
      engine: NextDueEngine(clock: fc, ledger: LedgerEngine(clock: fc)),
    );
    final v = (await VehiclesRepository(db).watchAll().first).single;
    // Only a distance rule (drop the seeded date reminders for isolation).
    await db.customStatement('DELETE FROM reminders');
    await db.customStatement(
      'INSERT INTO reminders (id, created_at, updated_at, vehicle_id, title, '
      "trigger_type, due_odometer_metres, severity) VALUES ('d1', 0, 0, ?, "
      "'Oil', 'distance', 105000000, 'info')",
      [v.id],
    );

    final ledger = LedgerRepository(db);
    Instant when(int y, int mo, int d) =>
        Instant.fromDateTime(DateTime.utc(y, mo, d));
    // Slow baseline usage (~6.6 km/day) → a far projection.
    await ledger.appendManual(
        vehicleId: v.id, value: 100000000, takenAt: when(2026, 1, 1));
    await ledger.appendManual(
        vehicleId: v.id, value: 101000000, takenAt: when(2026, 6, 1));
    await s.reconcileAll();
    final firstWhen =
        gateway.scheduled.lastWhere((n) => n.groupKey == null).when;

    // A fast recent reading (~22 km/day over the window) → sooner projection.
    await ledger.appendManual(
        vehicleId: v.id, value: 104000000, takenAt: when(2026, 7, 1));
    final r2 = await s.reconcileAll();
    final secondWhen =
        gateway.scheduled.lastWhere((n) => n.groupKey == null).when;

    // The due date self-corrected earlier, and the reconcile acted on it.
    expect(secondWhen.epochMillis, lessThan(firstWhen.epochMillis));
    expect(r2.mutations, greaterThanOrEqualTo(1));
  });
}
