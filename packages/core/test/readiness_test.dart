import 'package:core/core.dart';
import 'package:test/test.dart';

Instant _at(int millis) => Instant.fromEpochMillis(millis);

ReminderDue _due(String id, {required int fireAt, required int dueAt}) =>
    ReminderDue(
      reminderId: id,
      title: 'r-$id',
      due: Due(NextDue(
        fireAt: _at(fireAt),
        dueAt: _at(dueAt),
        confidence: DueConfidence.exact,
      )),
    );

void main() {
  final now = _at(1000);

  group('urgencyForDue', () {
    test('overdue past dueAt, soon in the lead window, scheduled before it',
        () {
      expect(urgencyForDue(_due('a', fireAt: 0, dueAt: 500).due, now), 4);
      expect(urgencyForDue(_due('b', fireAt: 500, dueAt: 2000).due, now), 2);
      expect(urgencyForDue(_due('c', fireAt: 2000, dueAt: 3000).due, now), 1);
    });

    test('NoDue and InsufficientData are calm (0)', () {
      expect(urgencyForDue(const NoDue(), now), 0);
      expect(urgencyForDue(const InsufficientData(), now), 0);
    });
  });

  group('aggregateReadiness', () {
    test('no reminders reads perfectly calm', () {
      final s = aggregateReadiness(now: now, reminders: const []);
      expect(s, ReadinessSummary.calm);
      expect(s.isCalm, isTrue);
      expect(s.ache, isNull);
    });

    test('one healthy (future) reminder stays calm, full readiness', () {
      final s = aggregateReadiness(
          now: now, reminders: [_due('a', fireAt: 5000, dueAt: 9000)]);
      expect(s.urgency, 1);
      expect(s.score, 95); // one scheduled item, small penalty
      expect(s.ache!.reminderId, 'a');
    });

    test('one overdue reminder surfaces an acute ache at urgency 4', () {
      final s = aggregateReadiness(
          now: now, reminders: [_due('a', fireAt: 0, dueAt: 500)]);
      expect(s.urgency, 4);
      expect(s.score, 60); // 100 - 40
      expect(s.ache!.urgency, 4);
      expect(s.ache!.dueAt, _at(500));
    });

    test('the halo is clamped to 2 even when the worst is overdue', () {
      final s = aggregateReadiness(
          now: now, reminders: [_due('a', fireAt: 0, dueAt: 500)]);
      expect(s.urgency, 4);
      expect(s.haloUrgency, 2); // day-halo never exceeds saffron
    });

    test('worst-of selection across mixed urgencies; penalties accumulate', () {
      final s = aggregateReadiness(now: now, reminders: [
        _due('sched', fireAt: 5000, dueAt: 9000), // 1
        _due('soon', fireAt: 500, dueAt: 2000), // 2
        _due('over', fireAt: 0, dueAt: 400), // 4
      ]);
      expect(s.urgency, 4);
      expect(s.ache!.reminderId, 'over');
      expect(s.score, 100 - (5 + 15 + 40)); // 40
    });

    test('ties in urgency break to the earliest dueAt', () {
      final s = aggregateReadiness(now: now, reminders: [
        _due('later', fireAt: 0, dueAt: 800),
        _due('earlier', fireAt: 0, dueAt: 300),
      ]);
      expect(s.ache!.reminderId, 'earlier');
    });

    test('insufficient-data reminders never fabricate an ache', () {
      final s = aggregateReadiness(now: now, reminders: const [
        ReminderDue(reminderId: 'x', title: 't', due: InsufficientData()),
      ]);
      expect(s, ReadinessSummary.calm);
    });
  });
}
