/// Jalali (Solar Hijri) calendar via the Jalaali arithmetic algorithm
/// (Borkowski / Behrang Noruzi Niya), accurate across the supported range.
/// Leap years follow the 33-year-cycle break table rather than a fixed cycle.
library;

import 'julian_day.dart';

const _breaks = <int>[
  -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, //
  1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178,
];

class _JalCal {
  const _JalCal(this.leap, this.gy, this.march);

  /// 0..4 — years since the last leap year; the year is leap iff `leap == 0`.
  final int leap;

  /// Gregorian year in which this Jalali year begins.
  final int gy;

  /// Day in March (Gregorian) on which 1 Farvardin falls.
  final int march;
}

_JalCal _jalCal(int jy) {
  final gy = jy + 621;
  var leapJ = -14;
  var jp = _breaks[0];
  var jm = 0;
  var jump = 0;
  for (var i = 1; i < _breaks.length; i += 1) {
    jm = _breaks[i];
    jump = jm - jp;
    if (jy < jm) break;
    leapJ = leapJ + fdiv(jump, 33) * 8 + fdiv(fmod(jump, 33), 4);
    jp = jm;
  }
  var n = jy - jp;
  leapJ = leapJ + fdiv(n, 33) * 8 + fdiv(fmod(n, 33) + 3, 4);
  if (fmod(jump, 33) == 4 && jump - n == 4) leapJ += 1;
  final leapG = fdiv(gy, 4) - fdiv((fdiv(gy, 100) + 1) * 3, 4) - 150;
  final march = 20 + leapJ - leapG;
  if (jump - n < 6) n = n - jump + fdiv(jump + 4, 33) * 33;
  var leap = fmod(fmod(n + 1, 33) - 1, 4);
  if (leap == -1) leap = 4;
  return _JalCal(leap, gy, march);
}

/// Jalali `(year, month, day)` → JDN.
int jalaliToJdn(int jy, int jm, int jd) {
  final r = _jalCal(jy);
  return gregorianToJdn(r.gy, 3, r.march) +
      (jm - 1) * 31 -
      fdiv(jm, 7) * (jm - 7) +
      jd -
      1;
}

/// JDN → Jalali `(year, month, day)`.
(int, int, int) jalaliFromJdn(int jdn) {
  final (gy, _, _) = gregorianFromJdn(jdn);
  var jy = gy - 621;
  final r = _jalCal(jy);
  final jdn1f = gregorianToJdn(r.gy, 3, r.march);
  var k = jdn - jdn1f;
  if (k >= 0) {
    if (k <= 185) {
      return (jy, 1 + fdiv(k, 31), fmod(k, 31) + 1);
    }
    k -= 186;
  } else {
    jy -= 1;
    k += 179;
    if (r.leap == 1) k += 1;
  }
  return (jy, 7 + fdiv(k, 30), fmod(k, 30) + 1);
}

/// Whether [jy] is a Jalali leap year (Esfand has 30 days).
bool jalaliIsLeapYear(int jy) => _jalCal(jy).leap == 0;

/// Length of Jalali month [jm] in year [jy].
int jalaliMonthLength(int jy, int jm) {
  if (jm <= 6) return 31;
  if (jm <= 11) return 30;
  return jalaliIsLeapYear(jy) ? 30 : 29; // Esfand
}
