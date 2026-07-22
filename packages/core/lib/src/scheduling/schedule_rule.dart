import '../time/temporal.dart';

/// The four trigger kinds a schedule can fire on (F5-T3).
enum TriggerKind { date, distance, engineHours, whicheverFirst }

/// How confident the engine is in a computed due date.
enum DueConfidence {
  /// A concrete calendar date — no estimation.
  exact,

  /// Projected from the usage rate (distance / engine-hours).
  projected,

  /// Projected, but the underlying data is stale — treat as a soft estimate.
  uncertain,
}

/// The unit of a recurring interval.
enum RecurrenceUnit { days, weeks, months, years }

/// A recurring interval, re-anchored to the actual completion date. Months/years
/// advance Gregorian-correctly with end-of-month clamping (Jan 31 + 1 month →
/// Feb 28/29). Non-Gregorian-calendar recurrence is layered above (l10n).
final class Recurrence {
  const Recurrence(this.every, this.unit)
      : assert(every > 0, 'every must be > 0');

  final int every;
  final RecurrenceUnit unit;

  /// The next occurrence, one interval after [anchor] (UTC).
  Instant nextAfter(Instant anchor) {
    final d = anchor.utc;
    final next = switch (unit) {
      RecurrenceUnit.days => d.add(Duration(days: every)),
      RecurrenceUnit.weeks => d.add(Duration(days: 7 * every)),
      RecurrenceUnit.months => _addMonths(d, every),
      RecurrenceUnit.years => _addMonths(d, 12 * every),
    };
    return Instant.fromEpochMillis(next.millisecondsSinceEpoch);
  }

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    final year = d.year + _floorDiv(total, 12);
    final month = _mod(total, 12) + 1;
    final maxDay = _daysInMonth(year, month);
    final day = d.day <= maxDay ? d.day : maxDay; // clamp end-of-month
    return DateTime.utc(
      year,
      month,
      day,
      d.hour,
      d.minute,
      d.second,
      d.millisecond,
    );
  }

  static int _daysInMonth(int y, int m) {
    const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    final leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
    return m == 2 && leap ? 29 : lengths[m - 1];
  }

  static int _floorDiv(int a, int b) => (a - (a % b + b) % b) ~/ b;
  static int _mod(int a, int b) => (a % b + b) % b;
}

/// A local-time quiet window during which no notification fires; a firing that
/// lands inside is shifted to [deliverAtMinute] (default: the window end).
/// Minutes are measured from local midnight; a window may wrap midnight
/// (e.g. 22:00→07:00 is `startMinute: 1320, endMinute: 420`).
final class QuietHours {
  const QuietHours({
    required this.startMinute,
    required this.endMinute,
    this.deliverAtMinute,
  });

  final int startMinute;
  final int endMinute;
  final int? deliverAtMinute;

  /// Whether [minuteOfDay] (0..1439) falls inside the quiet window.
  bool contains(int minuteOfDay) => startMinute <= endMinute
      ? minuteOfDay >= startMinute && minuteOfDay < endMinute
      : minuteOfDay >= startMinute || minuteOfDay < endMinute;
}

/// A schedule definition — the canonical, calendar-agnostic inputs to the
/// next-due engine. Distance is metres, engine time whole minutes, instants UTC
/// epoch millis. Any dimension may be null so a rule can be purely one kind.
final class ScheduleRule {
  const ScheduleRule({
    required this.kind,
    this.dueDate,
    this.completedAt,
    this.recurrence,
    this.dueOdometerMetres,
    this.dueEngineMinutes,
    this.leadTime = Duration.zero,
    this.leadDistanceMetres,
    this.quietHours,
    this.utcOffsetMinutes = 0,
    this.staleAfter = const Duration(days: 45),
  });

  final TriggerKind kind;

  /// The absolute due instant for a one-off / the first occurrence of a date rule.
  final Instant? dueDate;

  /// When the rule was last completed — recurrence re-anchors from here, and a
  /// one-off with a completion is done.
  final Instant? completedAt;
  final Recurrence? recurrence;

  /// Lifetime-odometer threshold (metres) for a distance rule.
  final int? dueOdometerMetres;

  /// Engine-hour threshold (whole minutes) for an engine-hour rule.
  final int? dueEngineMinutes;

  /// Fire this long before the due instant.
  final Duration leadTime;

  /// Additional distance-expressed lead (metres), converted to time via the
  /// usage rate.
  final int? leadDistanceMetres;
  final QuietHours? quietHours;

  /// The display time zone offset used for quiet-hours math.
  final int utcOffsetMinutes;

  /// A projection is flagged uncertain (and its lead widened) when the newest
  /// reading is older than this.
  final Duration staleAfter;
}

/// A computed firing: [fireAt] (lead- and quiet-hours-adjusted) for the OS, and
/// [dueAt] (the raw threshold instant) for the body copy.
final class NextDue {
  const NextDue({
    required this.fireAt,
    required this.dueAt,
    required this.confidence,
  });

  final Instant fireAt;
  final Instant dueAt;
  final DueConfidence confidence;

  @override
  bool operator ==(Object other) =>
      other is NextDue &&
      other.fireAt == fireAt &&
      other.dueAt == dueAt &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(fireAt, dueAt, confidence);

  @override
  String toString() =>
      'NextDue(fireAt: $fireAt, dueAt: $dueAt, ${confidence.name})';
}

/// The typed outcome of evaluating a rule.
sealed class DueResult {
  const DueResult();
}

/// The rule is due — schedule [next].
final class Due extends DueResult {
  const Due(this.next);
  final NextDue next;
}

/// A distance/engine-hour rule without enough readings to project — surface
/// "estimate pending" rather than guessing.
final class InsufficientData extends DueResult {
  const InsufficientData();
}

/// Nothing to schedule (a completed one-off, or no applicable dimension).
final class NoDue extends DueResult {
  const NoDue();
}
