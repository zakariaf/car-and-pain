import 'package:core/core.dart';
import 'package:test/test.dart';

Instant _utc(int y, int mo, int d, [int h = 0, int mi = 0]) =>
    Instant.fromEpochMillis(
        DateTime.utc(y, mo, d, h, mi).millisecondsSinceEpoch);

LedgerReading _r(Instant at, int value) =>
    LedgerReading(value: value, takenAt: at, source: LedgerSource.manual);

void main() {
  group('Recurrence.nextAfter (Gregorian, end-of-month clamped)', () {
    test('days / weeks', () {
      expect(
          const Recurrence(30, RecurrenceUnit.days).nextAfter(_utc(2026, 1, 1)),
          _utc(2026, 1, 31));
      expect(
          const Recurrence(2, RecurrenceUnit.weeks).nextAfter(_utc(2026, 1, 1)),
          _utc(2026, 1, 15));
    });

    test('months clamp to end-of-month', () {
      expect(
        const Recurrence(1, RecurrenceUnit.months).nextAfter(_utc(2026, 1, 31)),
        _utc(2026, 2, 28), // Jan 31 + 1mo → Feb 28 (2026 common)
      );
      expect(
        const Recurrence(6, RecurrenceUnit.months).nextAfter(_utc(2026, 1, 15)),
        _utc(2026, 7, 15),
      );
      // Crossing the year boundary.
      expect(
        const Recurrence(2, RecurrenceUnit.months)
            .nextAfter(_utc(2026, 11, 30)),
        _utc(2027, 1, 30),
      );
    });

    test('years clamp a leap day', () {
      expect(
        const Recurrence(1, RecurrenceUnit.years).nextAfter(_utc(2024, 2, 29)),
        _utc(2025, 2, 28),
      );
    });
  });

  group('date trigger', () {
    final engine = NextDueEngine(clock: FixedClock(_utc(2026, 1, 1).utc));

    test('one-off fires once, then a completed one-off is done', () {
      const rule = TriggerKind.date;
      final due = engine.evaluate(
        ScheduleRule(kind: rule, dueDate: _utc(2026, 6, 1)),
      );
      expect(due, isA<Due>());
      expect((due as Due).next.dueAt, _utc(2026, 6, 1));
      expect(due.next.confidence, DueConfidence.exact);

      final done = engine.evaluate(
        ScheduleRule(
            kind: rule,
            dueDate: _utc(2026, 6, 1),
            completedAt: _utc(2026, 6, 2)),
      );
      expect(done, isA<NoDue>());
    });

    test('recurring re-anchors to the completion date, not the schedule', () {
      final due = engine.evaluate(
        ScheduleRule(
          kind: TriggerKind.date,
          dueDate: _utc(2026, 1, 1),
          completedAt: _utc(2026, 3, 10), // completed late
          recurrence: const Recurrence(6, RecurrenceUnit.months),
        ),
      );
      // Next = completion + 6 months, NOT original + 6 months.
      expect((due as Due).next.dueAt, _utc(2026, 9, 10));
    });
  });

  group('distance projection', () {
    // 100 km/day: 0 m on Jan 1, 1,000,000 m on Jan 11; clock at Jan 11.
    final clock = FixedClock(DateTime.utc(2026, 1, 11));
    final engine = NextDueEngine(
      clock: clock,
      ledger: LedgerEngine(clock: clock),
    );
    final history = [_r(_utc(2026, 1, 1), 0), _r(_utc(2026, 1, 11), 1000000)];

    test('projects a threshold to a due date', () {
      final due = engine.evaluate(
        const ScheduleRule(
            kind: TriggerKind.distance, dueOdometerMetres: 2000000),
        odometer: history,
      );
      // (2,000,000 − 1,000,000) / 100,000 per day = 10 days → Jan 21.
      expect((due as Due).next.dueAt, _utc(2026, 1, 21));
      expect(due.next.confidence, DueConfidence.projected);
    });

    test('already-crossed threshold is due now', () {
      final due = engine.evaluate(
        const ScheduleRule(
            kind: TriggerKind.distance, dueOdometerMetres: 500000),
        odometer: history,
      );
      expect((due as Due).next.dueAt, _utc(2026, 1, 11)); // now
    });

    test('fewer than two readings → insufficient data', () {
      final due = engine.evaluate(
        const ScheduleRule(
            kind: TriggerKind.distance, dueOdometerMetres: 2000000),
        odometer: [_r(_utc(2026, 1, 1), 0)],
      );
      expect(due, isA<InsufficientData>());
    });

    test('stale data widens the lead and flags uncertain', () {
      final staleClock = FixedClock(_utc(2026, 6, 1).utc); // long after
      final e = NextDueEngine(
          clock: staleClock, ledger: LedgerEngine(clock: staleClock));
      final due = e.evaluate(
        const ScheduleRule(
          kind: TriggerKind.distance,
          dueOdometerMetres: 100000000,
          leadTime: Duration(days: 5),
          staleAfter: Duration(days: 30),
        ),
        odometer: history,
      );
      expect((due as Due).next.confidence, DueConfidence.uncertain);
      // Lead is doubled: fireAt is 10 days (not 5) before dueAt.
      final gapDays =
          (due.next.dueAt.epochMillis - due.next.fireAt.epochMillis) /
              Duration.millisecondsPerDay;
      expect(gapDays, closeTo(10, 0.001));
    });
  });

  group('engine-hours projection', () {
    final clock = FixedClock(DateTime.utc(2026, 1, 11));
    final engine =
        NextDueEngine(clock: clock, ledger: LedgerEngine(clock: clock));
    // 60 min/day: 0 on Jan 1, 600 min on Jan 11.
    final hours = [_r(_utc(2026, 1, 1), 0), _r(_utc(2026, 1, 11), 600)];

    test('projects an hours threshold to a due date', () {
      final due = engine.evaluate(
        const ScheduleRule(
            kind: TriggerKind.engineHours, dueEngineMinutes: 1200),
        hours: hours,
      );
      // (1200 − 600) / 60 per day = 10 days → Jan 21.
      expect((due as Due).next.dueAt, _utc(2026, 1, 21));
    });
  });

  group('whichever-first', () {
    final clock = FixedClock(DateTime.utc(2026, 1, 11));
    final engine =
        NextDueEngine(clock: clock, ledger: LedgerEngine(clock: clock));
    final odo = [_r(_utc(2026, 1, 1), 0), _r(_utc(2026, 1, 11), 1000000)];

    test('returns the earliest across present dimensions', () {
      final due = engine.evaluate(
        ScheduleRule(
          kind: TriggerKind.whicheverFirst,
          dueDate: _utc(2026, 2, 1), // date: Feb 1
          dueOdometerMetres: 2000000, // distance: Jan 21 (earlier)
        ),
        odometer: odo,
      );
      expect((due as Due).next.dueAt, _utc(2026, 1, 21)); // distance wins
    });

    test('a single present dimension is used; null ones are ignored', () {
      final due = engine.evaluate(
        ScheduleRule(
          kind: TriggerKind.whicheverFirst,
          dueDate: _utc(2026, 2, 1),
        ),
        odometer: odo,
      );
      expect(
          (due as Due).next.dueAt, _utc(2026, 2, 1)); // only the date applies
    });
  });

  group('lead-time and quiet-hours', () {
    final engine = NextDueEngine(clock: FixedClock(_utc(2026, 1, 1).utc));

    test('time lead-time fires before the due instant', () {
      final due = engine.evaluate(
        ScheduleRule(
          kind: TriggerKind.date,
          dueDate: _utc(2026, 1, 10, 12),
          leadTime: const Duration(days: 2),
        ),
      );
      expect((due as Due).next.fireAt, _utc(2026, 1, 8, 12));
    });

    test('a firing inside quiet hours shifts to the delivery time', () {
      // Due 03:00 local; quiet 22:00→07:00, deliver 07:00.
      final due = engine.evaluate(
        ScheduleRule(
          kind: TriggerKind.date,
          dueDate: _utc(2026, 1, 1, 3),
          quietHours: const QuietHours(
            startMinute: 22 * 60,
            endMinute: 7 * 60,
            deliverAtMinute: 7 * 60,
          ),
        ),
      );
      expect((due as Due).next.fireAt, _utc(2026, 1, 1, 7));
    });

    test('a late-night firing shifts to the next morning (never earlier)', () {
      final due = engine.evaluate(
        ScheduleRule(
          kind: TriggerKind.date,
          dueDate: _utc(2026, 1, 1, 23),
          quietHours: const QuietHours(
            startMinute: 22 * 60,
            endMinute: 7 * 60,
            deliverAtMinute: 7 * 60,
          ),
        ),
      );
      expect((due as Due).next.fireAt, _utc(2026, 1, 2, 7));
    });
  });
}
