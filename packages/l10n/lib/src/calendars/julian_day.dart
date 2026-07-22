/// Julian Day Number (JDN) — the integer pivot every calendar converts through
/// (F4-T3). JDN is the count of days since the Julian-period epoch; converting
/// A→B is always A→JDN→B, so each calendar only needs a bidirectional JDN pair.
library;

/// Floor division (rounds toward negative infinity) — correct for the negative
/// intermediates some calendar formulas produce, unlike Dart's `~/` which
/// truncates toward zero.
int fdiv(int a, int b) => (a - (a % b + b) % b) ~/ b;

/// Euclidean modulo: always in `[0, b)` for `b > 0`.
int fmod(int a, int b) => (a % b + b) % b;

/// Proleptic-Gregorian date → JDN (Fliegel–Van Flandern). Valid for any year,
/// including negative (proleptic) ones.
int gregorianToJdn(int year, int month, int day) {
  final a = fdiv(14 - month, 12);
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  return day +
      fdiv(153 * m + 2, 5) +
      365 * y +
      fdiv(y, 4) -
      fdiv(y, 100) +
      fdiv(y, 400) -
      32045;
}

/// JDN → proleptic-Gregorian `(year, month, day)`.
(int, int, int) gregorianFromJdn(int jdn) {
  final a = jdn + 32044;
  final b = fdiv(4 * a + 3, 146097);
  final c = a - fdiv(146097 * b, 4);
  final d = fdiv(4 * c + 3, 1461);
  final e = c - fdiv(1461 * d, 4);
  final m = fdiv(5 * e + 2, 153);
  final day = e - fdiv(153 * m + 2, 5) + 1;
  final month = m + 3 - 12 * fdiv(m, 10);
  final year = 100 * b + d - 4800 + fdiv(m, 10);
  return (year, month, day);
}

/// Day of week for a JDN as an ISO index: 1 = Monday … 7 = Sunday.
int isoWeekdayFromJdn(int jdn) => fmod(jdn, 7) + 1;
