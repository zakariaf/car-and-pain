import 'package:core/core.dart';

import 'hebrew.dart';
import 'hijri.dart';
import 'jalali.dart';
import 'julian_day.dart';

/// The four calendar systems Car and Pain renders (F4-T3). Storage is always a
/// canonical UTC [Instant]; these are display projections.
enum CalendarSystem { gregorian, jalali, hijri, hebrew }

/// The calendar a locale resolves to before any user override (F4-T2): Persian
/// → Jalali, Arabic → Hijri, everything else → Gregorian. Sorani (ckb) defaults
/// to Gregorian (its speakers span Jalali and Gregorian regions); users pick in
/// settings.
CalendarSystem defaultCalendarFor(String languageCode) =>
    switch (languageCode) {
      'fa' => CalendarSystem.jalali,
      'ar' => CalendarSystem.hijri,
      _ => CalendarSystem.gregorian,
    };

// ── Gregorian helpers (the other three live in their own files) ─────────────
bool _gregLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

int _gregMonthLength(int y, int m) {
  const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (m == 2 && _gregLeap(y)) return 29;
  return lengths[m - 1];
}

/// Number of months in [year] for [system] (13 in a Hebrew leap year).
int monthsInYear(CalendarSystem system, int year) => switch (system) {
      CalendarSystem.hebrew => hebrewMonthsInYear(year),
      _ => 12,
    };

/// Length of [month] in [year] for [system].
int monthLength(CalendarSystem system, int year, int month) => switch (system) {
      CalendarSystem.gregorian => _gregMonthLength(year, month),
      CalendarSystem.jalali => jalaliMonthLength(year, month),
      CalendarSystem.hijri => hijriMonthLength(year, month),
      CalendarSystem.hebrew => hebrewMonthLength(year, month),
    };

/// Whether [year] is a leap year in [system].
bool isLeapYear(CalendarSystem system, int year) => switch (system) {
      CalendarSystem.gregorian => _gregLeap(year),
      CalendarSystem.jalali => jalaliIsLeapYear(year),
      CalendarSystem.hijri => hijriIsLeapYear(year),
      CalendarSystem.hebrew => hebrewIsLeapYear(year),
    };

int _toJdn(CalendarSystem s, int y, int m, int d) => switch (s) {
      CalendarSystem.gregorian => gregorianToJdn(y, m, d),
      CalendarSystem.jalali => jalaliToJdn(y, m, d),
      CalendarSystem.hijri => hijriToJdn(y, m, d),
      CalendarSystem.hebrew => hebrewToJdn(y, m, d),
    };

(int, int, int) _fromJdn(CalendarSystem s, int jdn) => switch (s) {
      CalendarSystem.gregorian => gregorianFromJdn(jdn),
      CalendarSystem.jalali => jalaliFromJdn(jdn),
      CalendarSystem.hijri => hijriFromJdn(jdn),
      CalendarSystem.hebrew => hebrewFromJdn(jdn),
    };

/// A wall-clock calendar date in a specific [system] — a pure value object with
/// no time zone. Convert between systems losslessly via the Julian Day Number.
class CalendarDate {
  const CalendarDate(this.system, this.year, this.month, this.day);

  /// Build a date from a Julian Day Number in the given [system].
  factory CalendarDate.fromJdn(CalendarSystem system, int jdn) {
    final (y, m, d) = _fromJdn(system, jdn);
    return CalendarDate(system, y, m, d);
  }

  /// Project a canonical UTC [instant] into [system] at the display time zone
  /// ([utcOffsetMinutes]). The wall-clock day never shifts under a DST/zone
  /// change because the offset is applied explicitly, not read from the host.
  factory CalendarDate.fromInstant(
    Instant instant,
    CalendarSystem system, {
    int utcOffsetMinutes = 0,
  }) {
    final local = DateTime.fromMillisecondsSinceEpoch(
      instant.epochMillis + utcOffsetMinutes * 60000,
      isUtc: true,
    );
    return CalendarDate(
            CalendarSystem.gregorian, local.year, local.month, local.day)
        .toSystem(system);
  }

  final CalendarSystem system;
  final int year;
  final int month;
  final int day;

  /// Julian Day Number for this date.
  int get jdn => _toJdn(system, year, month, day);

  /// ISO weekday: 1 = Monday … 7 = Sunday (calendar-independent).
  int get isoWeekday => isoWeekdayFromJdn(jdn);

  /// The same instant-in-time expressed in another calendar [target].
  CalendarDate toSystem(CalendarSystem target) =>
      target == system ? this : CalendarDate.fromJdn(target, jdn);

  /// The UTC [Instant] of local midnight for this date at [utcOffsetMinutes].
  Instant startOfDay({int utcOffsetMinutes = 0}) {
    final (gy, gm, gd) = _fromJdn(CalendarSystem.gregorian, jdn);
    final localMidnight = DateTime.utc(gy, gm, gd).millisecondsSinceEpoch;
    return Instant.fromEpochMillis(localMidnight - utcOffsetMinutes * 60000);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.system == system &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(system, year, month, day);

  @override
  String toString() => 'CalendarDate(${system.name} $year-$month-$day)';
}

/// Validate and build a [CalendarDate], rejecting impossible dates (e.g. Esfand
/// 30 in a common Jalali year) with a typed [ValidationFailure] — never an
/// exception or a silent wraparound.
Result<CalendarDate, ValidationFailure> tryCalendarDate(
  CalendarSystem system,
  int year,
  int month,
  int day,
) {
  final errors = <FieldError>[];
  if (month < 1 || month > monthsInYear(system, year)) {
    errors.add(const FieldError('month', 'out_of_range'));
  } else if (day < 1 || day > monthLength(system, year, month)) {
    errors.add(const FieldError('day', 'out_of_range'));
  }
  if (errors.isNotEmpty) return Err(ValidationFailure(errors));
  return Ok(CalendarDate(system, year, month, day));
}
