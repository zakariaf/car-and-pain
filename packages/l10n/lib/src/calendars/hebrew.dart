/// Hebrew (Jewish) calendar (F4-T3) via the Dershowitz–Reingold algorithm — the
/// molad of Tishrei plus the four postponement rules (dechiyot). Internally it
/// uses D&R month numbering (1 = Nisan … 7 = Tishrei … 13 = Adar II) over RD
/// "fixed" days; the public API converts to/from JDN and to the **Tishrei-first
/// display numbering** (1 = Tishrei … 12/13 = Elul) users expect.
library;

import 'julian_day.dart';

const int _hebrewEpochRd = -1373427; // 1 Tishrei 1 (RD fixed)
const int _jdnFromRd = 1721425; // JDN = RD + this

/// Whether [year] is a Hebrew leap year (13 months, with Adar I inserted).
bool hebrewIsLeapYear(int year) => fmod(7 * year + 1, 19) < 7;

/// Number of months in [year] — 13 in a leap year, else 12.
int hebrewMonthsInYear(int year) => hebrewIsLeapYear(year) ? 13 : 12;

int _hebrewCalendarElapsedDays(int year) {
  final monthsElapsed = fdiv(235 * year - 234, 19);
  final partsElapsed = 12084 + 13753 * monthsElapsed;
  final day = monthsElapsed * 29 + fdiv(partsElapsed, 25920);
  return fmod(3 * (day + 1), 7) < 3
      ? day + 1
      : day; // Gatarad / Lo ADU dechiyah
}

int _yearLengthCorrection(int year) {
  final ny0 = _hebrewCalendarElapsedDays(year - 1);
  final ny1 = _hebrewCalendarElapsedDays(year);
  final ny2 = _hebrewCalendarElapsedDays(year + 1);
  if (ny2 - ny1 == 356) return 2;
  if (ny1 - ny0 == 382) return 1;
  return 0;
}

// RD "fixed" day of 1 Tishrei of [year].
int _newYear(int year) =>
    _hebrewEpochRd +
    _hebrewCalendarElapsedDays(year) +
    _yearLengthCorrection(year);

int _daysInYear(int year) => _newYear(year + 1) - _newYear(year);

bool _longMarheshvan(int year) {
  final n = _daysInYear(year);
  return n == 355 || n == 385;
}

bool _shortKislev(int year) {
  final n = _daysInYear(year);
  return n == 353 || n == 383;
}

// Length of D&R month [drMonth] (1 = Nisan) in [year].
int _lastDayOfMonth(int year, int drMonth) {
  const alwaysShort = {2, 4, 6, 10, 13}; // Iyar, Tammuz, Elul, Tevet, Adar II
  if (alwaysShort.contains(drMonth)) return 29;
  if (drMonth == 12 && !hebrewIsLeapYear(year)) return 29; // Adar (common year)
  if (drMonth == 8 && !_longMarheshvan(year)) return 29; // Marheshvan
  if (drMonth == 9 && _shortKislev(year)) return 29; // Kislev
  return 30;
}

int _fixedFromHebrew(int year, int drMonth, int day) {
  var f = _newYear(year) + day - 1;
  if (drMonth < 7) {
    // Tishrei (7) → year end, then Nisan (1) → drMonth-1.
    for (var m = 7; m <= hebrewMonthsInYear(year); m += 1) {
      f += _lastDayOfMonth(year, m);
    }
    for (var m = 1; m < drMonth; m += 1) {
      f += _lastDayOfMonth(year, m);
    }
  } else {
    for (var m = 7; m < drMonth; m += 1) {
      f += _lastDayOfMonth(year, m);
    }
  }
  return f;
}

(int, int, int) _hebrewFromFixed(int date) {
  var year = fdiv((date - _hebrewEpochRd) * 98496, 35975351);
  while (_newYear(year + 1) <= date) {
    year += 1;
  }
  while (_newYear(year) > date) {
    year -= 1;
  }
  final start = date < _fixedFromHebrew(year, 1, 1) ? 7 : 1;
  var m = start;
  while (date > _fixedFromHebrew(year, m, _lastDayOfMonth(year, m))) {
    m += 1;
  }
  final day = date - _fixedFromHebrew(year, m, 1) + 1;
  return (year, m, day);
}

// ── Display numbering (1 = Tishrei) ⇄ D&R numbering (1 = Nisan) ─────────────
int _displayToDr(int year, int displayMonth) {
  if (displayMonth <= 5) return displayMonth + 6; // Tishrei..Shevat → 7..11
  if (hebrewIsLeapYear(year)) {
    if (displayMonth == 6) return 12; // Adar I
    if (displayMonth == 7) return 13; // Adar II
    return displayMonth - 7; // Nisan(8)→1 … Elul(13)→6
  }
  if (displayMonth == 6) return 12; // Adar
  return displayMonth - 6; // Nisan(7)→1 … Elul(12)→6
}

int _drToDisplay(int year, int drMonth) {
  if (drMonth >= 7) return drMonth - 6; // Tishrei(7)→1 … Adar II(13)→7
  return hebrewIsLeapYear(year)
      ? drMonth + 7
      : drMonth + 6; // Nisan.. → 8../7..
}

/// Length of Hebrew month [displayMonth] (1 = Tishrei) in [year].
int hebrewMonthLength(int year, int displayMonth) =>
    _lastDayOfMonth(year, _displayToDr(year, displayMonth));

/// Hebrew `(year, displayMonth, day)` → JDN (display month is Tishrei-first).
int hebrewToJdn(int year, int displayMonth, int day) =>
    _fixedFromHebrew(year, _displayToDr(year, displayMonth), day) + _jdnFromRd;

/// JDN → Hebrew `(year, displayMonth, day)` (display month is Tishrei-first).
(int, int, int) hebrewFromJdn(int jdn) {
  final (year, drMonth, day) = _hebrewFromFixed(jdn - _jdnFromRd);
  return (year, _drToDisplay(year, drMonth), day);
}
