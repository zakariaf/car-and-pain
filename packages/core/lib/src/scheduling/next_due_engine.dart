import '../ledger/ledger.dart';
import '../time/clock.dart';
import '../time/temporal.dart';
import 'schedule_rule.dart';

const int _msPerDay = Duration.millisecondsPerDay;
const int _msPerMinute = Duration.millisecondsPerMinute;

/// The pure-Dart next-due engine (F5-T3): from a [ScheduleRule] plus the shared
/// odometer / engine-hour ledger, compute the next firing. No Flutter, no
/// plugins, `Clock`-injected — fully unit-testable. The OS queue is a projection
/// of what this returns (F5-T2 reconcile).
final class NextDueEngine {
  const NextDueEngine({
    Clock clock = const SystemClock(),
    LedgerEngine ledger = const LedgerEngine(),
  })  : _clock = clock,
        _ledger = ledger;

  final Clock _clock;
  final LedgerEngine _ledger;

  /// Evaluate [rule] against the odometer / engine-hour [odometer] / [hours]
  /// histories (either may be empty for rules that don't use it).
  DueResult evaluate(
    ScheduleRule rule, {
    List<LedgerReading> odometer = const [],
    List<LedgerReading> hours = const [],
  }) {
    return switch (rule.kind) {
      TriggerKind.date => _dateDue(rule),
      TriggerKind.distance => _project(rule, rule.dueOdometerMetres, odometer),
      TriggerKind.engineHours => _project(rule, rule.dueEngineMinutes, hours),
      TriggerKind.whicheverFirst => _earliest(rule, odometer, hours),
    };
  }

  // ── Date ───────────────────────────────────────────────────────────────
  DueResult _dateDue(ScheduleRule rule) {
    final rec = rule.recurrence;
    if (rec != null) {
      // Recurring: re-anchor to the completion date, else the first occurrence.
      final dueAt = rule.completedAt != null
          ? rec.nextAfter(rule.completedAt!)
          : rule.dueDate;
      if (dueAt == null) return const NoDue();
      return Due(_finalize(rule, dueAt, DueConfidence.exact, null));
    }
    // One-off: a completed one-off has no next firing.
    if (rule.completedAt != null || rule.dueDate == null) return const NoDue();
    return Due(_finalize(rule, rule.dueDate!, DueConfidence.exact, null));
  }

  // ── Distance / engine-hours projection ─────────────────────────────────
  DueResult _project(
    ScheduleRule rule,
    int? threshold,
    List<LedgerReading> history,
  ) {
    if (threshold == null) return const NoDue();
    final rate = _ledger.avgDailyValue(history); // units/day
    final estNow = _ledger.estimatedValueNow(history);
    if (rate == null || estNow == null || rate <= 0) {
      return const InsufficientData();
    }

    final nowMs = _clock.nowUtc().millisecondsSinceEpoch;
    final newestMs = history
        .map((r) => r.takenAt.epochMillis)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final stale = nowMs - newestMs > rule.staleAfter.inMilliseconds;
    final confidence =
        stale ? DueConfidence.uncertain : DueConfidence.projected;

    final Instant dueAt;
    if (estNow >= threshold) {
      dueAt = Instant.fromEpochMillis(nowMs); // already crossed → due now
    } else {
      final days = (threshold - estNow) / rate;
      dueAt = Instant.fromEpochMillis(nowMs + (days * _msPerDay).round());
    }
    return Due(_finalize(rule, dueAt, confidence, rate));
  }

  // ── Whichever-comes-first ──────────────────────────────────────────────
  DueResult _earliest(
    ScheduleRule rule,
    List<LedgerReading> odometer,
    List<LedgerReading> hours,
  ) {
    final results = <DueResult>[
      if (rule.dueDate != null || rule.recurrence != null) _dateDue(rule),
      if (rule.dueOdometerMetres != null)
        _project(rule, rule.dueOdometerMetres, odometer),
      if (rule.dueEngineMinutes != null)
        _project(rule, rule.dueEngineMinutes, hours),
    ];
    final dues = results.whereType<Due>().toList()
      ..sort((a, b) =>
          a.next.fireAt.epochMillis.compareTo(b.next.fireAt.epochMillis));
    if (dues.isNotEmpty) return dues.first;
    // No concrete date: prefer to surface "estimate pending" over "nothing".
    return results.any((r) => r is InsufficientData)
        ? const InsufficientData()
        : const NoDue();
  }

  // ── Lead-time, distance-lead, stale-widening, quiet-hours ───────────────
  NextDue _finalize(
    ScheduleRule rule,
    Instant dueAt,
    DueConfidence confidence,
    double? ratePerDay,
  ) {
    var leadMs = rule.leadTime.inMilliseconds;
    final leadDist = rule.leadDistanceMetres;
    if (leadDist != null && ratePerDay != null && ratePerDay > 0) {
      leadMs += ((leadDist / ratePerDay) * _msPerDay).round();
    }
    if (confidence == DueConfidence.uncertain) {
      leadMs *= 2; // widen the lead when the estimate is shaky
    }
    final fireMs = _shiftOutOfQuietHours(rule, dueAt.epochMillis - leadMs);
    return NextDue(
      fireAt: Instant.fromEpochMillis(fireMs),
      dueAt: dueAt,
      confidence: confidence,
    );
  }

  int _shiftOutOfQuietHours(ScheduleRule rule, int fireMs) {
    final q = rule.quietHours;
    if (q == null) return fireMs;
    final offsetMs = rule.utcOffsetMinutes * _msPerMinute;
    final localMs = fireMs + offsetMs;
    final dayStartMs = (localMs ~/ _msPerDay) * _msPerDay;
    final minuteOfDay = (localMs - dayStartMs) ~/ _msPerMinute;
    if (!q.contains(minuteOfDay)) return fireMs;
    final deliverMinute = q.deliverAtMinute ?? q.endMinute;
    var newLocalMs = dayStartMs + deliverMinute * _msPerMinute;
    if (newLocalMs < localMs) newLocalMs += _msPerDay; // never fire earlier
    return newLocalMs - offsetMs;
  }
}
