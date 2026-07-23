import 'package:core/core.dart';
import 'package:test/test.dart';

/// M4-T9 — the pure interval / next-due projection engine. Exhaustive because the
/// diamond-topped pyramid puts its weight here: every branch of anchor
/// resolution, whichever-first, projection, and status grading is pinned.
void main() {
  Instant at(int y, int m, int d) =>
      Instant.fromDateTime(DateTime.utc(y, m, d));
  ServiceScheduleEngine engineAt(int y, int m, [int d = 1]) =>
      ServiceScheduleEngine(clock: FixedClock(DateTime.utc(y, m, d)));

  const km = 1000; // metres per km, for readability
  const tenThousandKm = 10000 * km; // 10_000_000 m

  group('anchor resolution', () {
    final engine = engineAt(2026, 7);

    test('no history → unknown, no governing dimension', () {
      final s = engine.status(
        const ServiceInterval(
          logic: ServiceIntervalLogic.distance,
          distanceMetres: tenThousandKm,
        ),
        const [],
        currentOdometerMetres: 5000 * km,
      );
      expect(s.level, ServiceDueLevel.unknown);
      expect(s.governing, isNull);
      expect(s.anchor, isNull);
    });

    test('anchors to the most recent RESETTING event, never a newer top-up',
        () {
      final s = engine.status(
        const ServiceInterval(
          logic: ServiceIntervalLogic.distance,
          distanceMetres: tenThousandKm,
        ),
        [
          ServiceEvent(doneAt: at(2026, 1, 1), odometerMetres: 10000 * km),
          // A newer top-up must NOT become the anchor (coolant top-up).
          ServiceEvent(
            doneAt: at(2026, 6, 1),
            odometerMetres: 15000 * km,
            resetsInterval: false,
          ),
        ],
        currentOdometerMetres: 16000 * km,
      );
      // Anchored to the Jan full change at 10_000 km → next due 20_000 km.
      expect(s.anchor!.doneAt, at(2026, 1, 1));
      expect(s.nextDueOdometerMetres, 20000 * km);
    });

    test('back-dated events anchor by true date regardless of list order', () {
      final s = engine.status(
        const ServiceInterval(
          logic: ServiceIntervalLogic.distance,
          distanceMetres: tenThousandKm,
        ),
        [
          // Entered later but happened earlier — order in the list is scrambled.
          ServiceEvent(doneAt: at(2026, 5, 1), odometerMetres: 14000 * km),
          ServiceEvent(doneAt: at(2026, 1, 1), odometerMetres: 10000 * km),
          ServiceEvent(doneAt: at(2026, 3, 1), odometerMetres: 12000 * km),
        ],
        currentOdometerMetres: 16000 * km,
      );
      expect(s.anchor!.doneAt, at(2026, 5, 1));
      expect(s.nextDueOdometerMetres, 24000 * km);
    });

    test('deleting the anchor re-anchors to the previous valid record', () {
      const interval = ServiceInterval(
        logic: ServiceIntervalLogic.distance,
        distanceMetres: tenThousandKm,
      );
      final full = [
        ServiceEvent(doneAt: at(2026, 1, 1), odometerMetres: 10000 * km),
        ServiceEvent(doneAt: at(2026, 5, 1), odometerMetres: 14000 * km),
      ];
      expect(engine.status(interval, full).nextDueOdometerMetres, 24000 * km);
      // Simulate deleting the May anchor → recompute from January.
      final afterDelete = [full.first];
      expect(
        engine.status(interval, afterDelete).nextDueOdometerMetres,
        20000 * km,
      );
    });
  });

  group('distance-only grading', () {
    final engine = engineAt(2026, 7);
    const interval = ServiceInterval(
      logic: ServiceIntervalLogic.distance,
      distanceMetres: tenThousandKm,
    );
    final anchor = [
      ServiceEvent(doneAt: at(2026, 1, 1), odometerMetres: 10000 * km),
    ];

    test('ok when far from the threshold', () {
      final s =
          engine.status(interval, anchor, currentOdometerMetres: 15000 * km);
      expect(s.level, ServiceDueLevel.ok);
      expect(s.governing, ServiceIntervalLogic.distance);
      expect(s.remainingMetres, 5000 * km);
    });

    test('due-soon inside the 500 km band', () {
      final s =
          engine.status(interval, anchor, currentOdometerMetres: 19800 * km);
      expect(s.level, ServiceDueLevel.dueSoon);
    });

    test('overdue past the threshold', () {
      final s =
          engine.status(interval, anchor, currentOdometerMetres: 21000 * km);
      expect(s.level, ServiceDueLevel.overdue);
      expect(s.remainingMetres, -1000 * km);
      expect(s.isOverdue, isTrue);
    });

    test('unknown historical odometer with no time dim → unknown', () {
      final s = engine.status(
        interval,
        [ServiceEvent(doneAt: at(2026, 1, 1))], // odometer unknown
        currentOdometerMetres: 21000 * km,
      );
      expect(s.level, ServiceDueLevel.unknown);
      expect(s.nextDueOdometerMetres, isNull);
    });
  });

  group('time-only grading (calendar-correct)', () {
    const interval = ServiceInterval(
      logic: ServiceIntervalLogic.time,
      time: Recurrence(6, RecurrenceUnit.months),
    );
    final anchor = [
      ServiceEvent(doneAt: at(2026, 1, 1), odometerMetres: 10000 * km),
    ];

    test('ok months ahead', () {
      final s = engineAt(2026, 3).status(interval, anchor);
      expect(s.level, ServiceDueLevel.ok);
      expect(s.governing, ServiceIntervalLogic.time);
      expect(s.nextDueDate, at(2026, 7, 1));
      expect(s.confidence, DueConfidence.exact);
    });

    test('due-soon inside the 14-day window', () {
      final s = engineAt(2026, 6, 20).status(interval, anchor);
      expect(s.level, ServiceDueLevel.dueSoon);
    });

    test('overdue after the due date', () {
      final s = engineAt(2026, 7, 15).status(interval, anchor);
      expect(s.level, ServiceDueLevel.overdue);
    });

    test('end-of-month clamps (Jan 31 + 1 month → Feb 28)', () {
      final s = engineAt(2026, 2).status(
        const ServiceInterval(
          logic: ServiceIntervalLogic.time,
          time: Recurrence(1, RecurrenceUnit.months),
        ),
        [ServiceEvent(doneAt: at(2026, 1, 31), odometerMetres: 0)],
      );
      expect(s.nextDueDate, at(2026, 2, 28));
    });
  });

  group('whichever-first', () {
    const interval = ServiceInterval(
      logic: ServiceIntervalLogic.whicheverFirst,
      distanceMetres: tenThousandKm,
      time: Recurrence(12, RecurrenceUnit.months),
    );

    test('distance governs when its projected date is nearer', () {
      // Time due 2027-01-01 (far); distance ~120 days out → distance governs.
      final odo = [
        LedgerReading(
          value: 10000 * km,
          takenAt: at(2026, 1, 1),
          source: LedgerSource.service,
        ),
        LedgerReading(
          value: 16000 * km,
          takenAt: at(2026, 7, 1),
          source: LedgerSource.manual,
        ),
      ];
      final s = engineAt(2026, 7).status(
        interval,
        [ServiceEvent(doneAt: at(2026, 1, 1), odometerMetres: 10000 * km)],
        currentOdometerMetres: 16000 * km,
        odometerHistory: odo,
      );
      expect(s.governing, ServiceIntervalLogic.distance);
      expect(s.level, ServiceDueLevel.ok);
      expect(s.projectedDueDate, isNotNull);
      expect(s.confidence, DueConfidence.projected);
    });

    test('either dimension overdue → overdue', () {
      // Time interval of 3 months from Jan → due Apr 1 (past on Jul 1) → overdue.
      final s = engineAt(2026, 7).status(
        const ServiceInterval(
          logic: ServiceIntervalLogic.whicheverFirst,
          distanceMetres: tenThousandKm,
          time: Recurrence(3, RecurrenceUnit.months),
        ),
        [ServiceEvent(doneAt: at(2026, 1, 1), odometerMetres: 10000 * km)],
        currentOdometerMetres: 12000 * km, // distance still fine
      );
      expect(s.level, ServiceDueLevel.overdue);
      expect(s.governing, ServiceIntervalLogic.time);
    });

    test('distance overdue by metres even with no ledger to project a date',
        () {
      final s = engineAt(2026, 7).status(
        interval,
        [ServiceEvent(doneAt: at(2026, 1, 1), odometerMetres: 10000 * km)],
        currentOdometerMetres: 21000 * km, // past 20_000 km threshold
        // no odometerHistory → cannot project a distance date
      );
      expect(s.level, ServiceDueLevel.overdue);
      expect(s.governing, ServiceIntervalLogic.distance);
    });

    test('whichever-first with only a usable time dim degrades to time', () {
      final s = engineAt(2026, 3).status(
        interval,
        // odometer unknown → distance dimension drops out
        [ServiceEvent(doneAt: at(2026, 1, 1))],
      );
      expect(s.governing, ServiceIntervalLogic.time);
      expect(s.nextDueOdometerMetres, isNull);
      expect(s.nextDueDate, at(2027, 1, 1));
    });
  });

  group('projection confidence', () {
    test('distance-governed with insufficient ledger → uncertain', () {
      final s = engineAt(2026, 7).status(
        const ServiceInterval(
          logic: ServiceIntervalLogic.distance,
          distanceMetres: tenThousandKm,
        ),
        [ServiceEvent(doneAt: at(2026, 1, 1), odometerMetres: 10000 * km)],
        currentOdometerMetres: 15000 * km,
        // no odometerHistory → no projection possible
      );
      expect(s.governing, ServiceIntervalLogic.distance);
      expect(s.level, ServiceDueLevel.ok);
      expect(s.projectedDueDate, isNull);
      expect(s.confidence, DueConfidence.uncertain);
    });
  });

  group('toScheduleRule (feeds the F5 NextDueEngine)', () {
    final engine = engineAt(2026, 7);
    final anchor = [
      ServiceEvent(doneAt: at(2026, 1, 1), odometerMetres: 10000 * km),
    ];

    test('distance-only → distance trigger with the odometer threshold', () {
      final rule = engine.toScheduleRule(
        const ServiceInterval(
          logic: ServiceIntervalLogic.distance,
          distanceMetres: tenThousandKm,
        ),
        anchor,
      )!;
      expect(rule.kind, TriggerKind.distance);
      expect(rule.dueOdometerMetres, 20000 * km);
      expect(rule.dueDate, isNull);
    });

    test('time-only → date trigger with the due date', () {
      final rule = engine.toScheduleRule(
        const ServiceInterval(
          logic: ServiceIntervalLogic.time,
          time: Recurrence(6, RecurrenceUnit.months),
        ),
        anchor,
      )!;
      expect(rule.kind, TriggerKind.date);
      expect(rule.dueDate, at(2026, 7, 1));
    });

    test('whichever-first with both dims → whicheverFirst trigger', () {
      final rule = engine.toScheduleRule(
        const ServiceInterval(
          logic: ServiceIntervalLogic.whicheverFirst,
          distanceMetres: tenThousandKm,
          time: Recurrence(12, RecurrenceUnit.months),
        ),
        anchor,
        leadDistanceMetres: 1000 * km,
      )!;
      expect(rule.kind, TriggerKind.whicheverFirst);
      expect(rule.dueOdometerMetres, 20000 * km);
      expect(rule.dueDate, at(2027, 1, 1));
      expect(rule.leadDistanceMetres, 1000 * km);
    });

    test('no anchor → null rule', () {
      expect(
        engine.toScheduleRule(
          const ServiceInterval(
            logic: ServiceIntervalLogic.time,
            time: Recurrence(6, RecurrenceUnit.months),
          ),
          const [],
        ),
        isNull,
      );
    });
  });

  group('logic pins one dimension even when both are present', () {
    final anchor = [
      ServiceEvent(doneAt: at(2026, 1, 1), odometerMetres: 10000 * km),
    ];

    test('logic=distance ignores the time dimension for grading', () {
      // Both dims present, but a distance-only logic → graded purely by metres.
      final s = engineAt(2026, 7).status(
        const ServiceInterval(
          logic: ServiceIntervalLogic.distance,
          distanceMetres: tenThousandKm,
          time: Recurrence(1, RecurrenceUnit.months), // overdue on time…
        ),
        anchor,
        currentOdometerMetres: 12000 * km, // …but fine on distance
      );
      expect(s.governing, ServiceIntervalLogic.distance);
      expect(s.level, ServiceDueLevel.ok); // time overdue is ignored
    });

    test('logic=time ignores the distance dimension for grading', () {
      final s = engineAt(2026, 3).status(
        const ServiceInterval(
          logic: ServiceIntervalLogic.time,
          distanceMetres: tenThousandKm, // would be overdue on distance…
          time: Recurrence(12, RecurrenceUnit.months),
        ),
        anchor,
        currentOdometerMetres: 99000 * km, // …but time governs and is fine
      );
      expect(s.governing, ServiceIntervalLogic.time);
      expect(s.level, ServiceDueLevel.ok);
    });
  });

  test('value objects construct at runtime (guards + getters)', () {
    // Defeat const-folding so the constructor/assert bodies actually run.
    final metres = int.parse('10000');
    final interval = ServiceInterval(
      logic: ServiceIntervalLogic.distance,
      distanceMetres: metres,
    );
    expect(interval.hasDistance, isTrue);
    expect(interval.hasTime, isFalse);
  });
}
