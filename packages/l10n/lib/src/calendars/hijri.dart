/// Tabular **civil** Islamic (Hijri) calendar (F4-T3): a deterministic 30-year
/// arithmetic cycle with leap years {2,5,7,10,13,16,18,21,24,26,29} and the
/// civil epoch Friday 16 July 622 CE Julian (JDN 1948440).
///
/// This is the arithmetic variant, chosen for reproducibility offline. It is
/// NOT the sighting-based calendar and can differ from an observed/Umm al-Qura
/// Hijri date by ±1–2 days — documented, not a bug.
library;

import 'julian_day.dart';

const int _islamicEpoch = 1948440;

/// Whether [year] is a leap year (Dhu al-Hijja has 30 days).
bool hijriIsLeapYear(int year) => fmod(11 * year + 14, 30) < 11;

/// Length of Hijri month [month] in [year].
int hijriMonthLength(int year, int month) {
  if (month.isOdd) return 30;
  if (month == 12 && hijriIsLeapYear(year)) return 30;
  return 29;
}

/// Hijri `(year, month, day)` → JDN.
int hijriToJdn(int year, int month, int day) =>
    day +
    29 * (month - 1) +
    fdiv(month, 2) +
    (year - 1) * 354 +
    fdiv(3 + 11 * year, 30) +
    _islamicEpoch -
    1;

int _firstOfYear(int year) =>
    (year - 1) * 354 + fdiv(3 + 11 * year, 30) + _islamicEpoch;

/// JDN → Hijri `(year, month, day)`.
(int, int, int) hijriFromJdn(int jdn) {
  var year = fdiv(30 * (jdn - _islamicEpoch) + 10646, 10631);
  while (_firstOfYear(year) > jdn) {
    year -= 1;
  }
  while (_firstOfYear(year + 1) <= jdn) {
    year += 1;
  }
  final dayOfYear = jdn - _firstOfYear(year) + 1; // 1-based
  var month = 1;
  var prior = 0;
  while (month < 12 && prior + hijriMonthLength(year, month) < dayOfYear) {
    prior += hijriMonthLength(year, month);
    month += 1;
  }
  return (year, month, dayOfYear - prior);
}
