import '../result/failures.dart';
import '../result/result.dart';
import '../result/validation.dart';

/// A **true instant** on the timeline — e.g. the moment a fuel fill happened.
///
/// Stored canonically as UTC epoch milliseconds. This is deliberately a
/// *different type* from [WallClockDateTime]: instants are absolute and never
/// shift, whereas civil/recurring schedules are wall-clock and must be resolved
/// to a zoned time only at (re)schedule time so DST/timezone changes can never
/// silently move a reminder.
final class Instant implements Comparable<Instant> {
  /// Construct from UTC epoch milliseconds.
  const Instant.fromEpochMillis(this.epochMillis);

  /// Construct from any [DateTime], normalizing to UTC.
  Instant.fromDateTime(DateTime dateTime)
      : epochMillis = dateTime.toUtc().millisecondsSinceEpoch;

  /// Canonical storage form: milliseconds since the Unix epoch, UTC.
  final int epochMillis;

  /// The instant as a UTC [DateTime]. Local/calendar rendering lives in l10n.
  DateTime get utc =>
      DateTime.fromMillisecondsSinceEpoch(epochMillis, isUtc: true);

  @override
  int compareTo(Instant other) => epochMillis.compareTo(other.epochMillis);

  @override
  bool operator ==(Object other) =>
      other is Instant && other.epochMillis == epochMillis;

  @override
  int get hashCode => epochMillis.hashCode;

  @override
  String toString() => 'Instant(${utc.toIso8601String()})';
}

/// A **wall-clock date-time** with no timezone attached — the anchor for civil
/// and recurring schedules ("remind at 09:00").
///
/// It is stored as calendar-agnostic components plus (later) a recurrence rule
/// and calendar, and is resolved to a concrete zoned time only when a reminder
/// is (re)scheduled. Keeping this a distinct type from [Instant] at the
/// type level is what prevents a schedule from ever being treated as an
/// absolute instant (and vice-versa).
final class WallClockDateTime {
  const WallClockDateTime._({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
  });

  /// Validated constructor. Rejects out-of-range civil components with a typed
  /// [ValidationFailure] rather than throwing on valid-looking input.
  static Result<WallClockDateTime, ValidationFailure> of({
    required int year,
    required int month,
    required int day,
    int hour = 0,
    int minute = 0,
  }) {
    final v = Validation();
    if (month < 1 || month > 12) v.add('month', 'out_of_range');
    if (day < 1 || day > 31) v.add('day', 'out_of_range');
    if (hour < 0 || hour > 23) v.add('hour', 'out_of_range');
    if (minute < 0 || minute > 59) v.add('minute', 'out_of_range');
    return v.build(
      WallClockDateTime._(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute,
      ),
    );
  }

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is WallClockDateTime &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(year, month, day, hour, minute);

  @override
  String toString() =>
      'WallClockDateTime($year-$month-$day $hour:$minute, no tz)';
}
