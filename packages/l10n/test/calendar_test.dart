import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

CalendarDate _g(int y, int m, int d) =>
    CalendarDate(CalendarSystem.gregorian, y, m, d);

/// Assert that a date in [sys] and a Gregorian date name the same day, and that
/// conversion both ways is exact.
void _anchor(CalendarSystem sys, int y, int m, int d, int gy, int gm, int gd) {
  final greg = _g(gy, gm, gd);
  final other = CalendarDate(sys, y, m, d);
  expect(other.jdn, greg.jdn, reason: '$sys $y-$m-$d should be $gy-$gm-$gd');
  expect(greg.toSystem(sys), other, reason: 'gregorian -> $sys');
  expect(other.toSystem(CalendarSystem.gregorian), greg,
      reason: '$sys -> greg');
}

void main() {
  group('Gregorian ⇄ JDN', () {
    test('canonical anchors', () {
      expect(_g(2000, 1, 1).jdn, 2451545); // J2000 epoch day
      expect(_g(1, 1, 1).jdn, 1721426);
      // 2000-01-01 was a Saturday (ISO 6).
      expect(_g(2000, 1, 1).isoWeekday, 6);
      // Round-trips through JDN.
      expect(CalendarDate.fromJdn(CalendarSystem.gregorian, 2451545),
          _g(2000, 1, 1));
    });
  });

  group('known cross-calendar anchors', () {
    test('Jalali (Nowruz)', () {
      _anchor(CalendarSystem.jalali, 1399, 1, 1, 2020, 3, 20);
      _anchor(CalendarSystem.jalali, 1400, 1, 1, 2021, 3, 21);
      // 1399 is a leap year: Esfand 30 is the day before Nowruz 1400.
      _anchor(CalendarSystem.jalali, 1399, 12, 30, 2021, 3, 20);
    });

    test('Hijri (tabular civil)', () {
      _anchor(CalendarSystem.hijri, 1443, 1, 1, 2021, 8, 10);
      // Epoch: 16 Jul 622 (Julian) == 19 Jul 622 proleptic Gregorian.
      _anchor(CalendarSystem.hijri, 1, 1, 1, 622, 7, 19);
    });

    test('Hebrew (Rosh Hashanah)', () {
      _anchor(CalendarSystem.hebrew, 5784, 1, 1, 2023, 9, 16);
      _anchor(CalendarSystem.hebrew, 5760, 1, 1, 1999, 9, 11);
    });
  });

  group('inverse round-trips over a dense JDN range', () {
    // ~1668 CE .. ~2216 CE, every day, for all four calendars.
    for (final sys in CalendarSystem.values) {
      test('fromJdn(jdn).jdn == jdn for $sys', () {
        for (var jdn = 2300000; jdn <= 2500000; jdn += 1) {
          final back = CalendarDate.fromJdn(sys, jdn).jdn;
          expect(back, jdn, reason: '$sys lost JDN $jdn');
        }
      });
    }
  });

  group('cross-system consistency (sampled days)', () {
    test('greg -> X -> greg is identity', () {
      for (var jdn = 2400000; jdn <= 2470000; jdn += 137) {
        final greg = CalendarDate.fromJdn(CalendarSystem.gregorian, jdn);
        for (final sys in CalendarSystem.values) {
          expect(greg.toSystem(sys).toSystem(CalendarSystem.gregorian), greg);
        }
      }
    });
  });

  group('month lengths sum to the year length', () {
    test('each system: sum of month lengths == days in year', () {
      const cases = <(CalendarSystem, List<int>)>[
        (CalendarSystem.gregorian, [2000, 2001, 2100]),
        (CalendarSystem.jalali, [1399, 1400, 1403]),
        (CalendarSystem.hijri, [1442, 1443, 1444]),
        (CalendarSystem.hebrew, [5782, 5783, 5784]),
      ];
      for (final (sys, ys) in cases) {
        for (final y in ys) {
          var sum = 0;
          for (var m = 1; m <= monthsInYear(sys, y); m++) {
            sum += monthLength(sys, y, m);
          }
          final start = CalendarDate(sys, y, 1, 1).jdn;
          final nextStart = CalendarDate(sys, y + 1, 1, 1).jdn;
          expect(sum, nextStart - start, reason: '$sys $y');
        }
      }
    });
  });

  group('tryCalendarDate rejects impossible dates', () {
    test('typed ValidationFailure, never an exception', () {
      // Gregorian Feb 29 in a common year.
      expect(
          tryCalendarDate(CalendarSystem.gregorian, 2001, 2, 29).isErr, isTrue);
      expect(
          tryCalendarDate(CalendarSystem.gregorian, 2000, 2, 29).isOk, isTrue);

      // Jalali Esfand 30 in a common year (1400) vs a leap year (1399).
      expect(
          tryCalendarDate(CalendarSystem.jalali, 1400, 12, 30).isErr, isTrue);
      expect(tryCalendarDate(CalendarSystem.jalali, 1399, 12, 30).isOk, isTrue);

      // Hijri day 31 never exists.
      expect(tryCalendarDate(CalendarSystem.hijri, 1443, 1, 31).isErr, isTrue);

      // Hebrew month 13 only exists in a leap year (5784 leap, 5783 common).
      expect(tryCalendarDate(CalendarSystem.hebrew, 5783, 13, 1).isErr, isTrue);
      expect(tryCalendarDate(CalendarSystem.hebrew, 5784, 13, 1).isOk, isTrue);

      final err = tryCalendarDate(CalendarSystem.jalali, 1400, 12, 30);
      expect(err.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('instant projection is offset-explicit', () {
    test('fromInstant + startOfDay round-trip at a +3:30 offset', () {
      // 2020-03-20 12:00Z, Iran offset +210 min → Jalali 1399-01-01.
      final noon = Instant.fromEpochMillis(
        DateTime.utc(2020, 3, 20, 12).millisecondsSinceEpoch,
      );
      final jalali = CalendarDate.fromInstant(noon, CalendarSystem.jalali,
          utcOffsetMinutes: 210);
      expect(jalali, const CalendarDate(CalendarSystem.jalali, 1399, 1, 1));

      final back = CalendarDate.fromInstant(
        jalali.startOfDay(utcOffsetMinutes: 210),
        CalendarSystem.jalali,
        utcOffsetMinutes: 210,
      );
      expect(back, jalali);
    });

    test('the wall-clock day does not shift with the offset near midnight', () {
      // 2020-03-20 22:30Z is already 2020-03-21 02:00 local at +210.
      final late = Instant.fromEpochMillis(
        DateTime.utc(2020, 3, 20, 22, 30).millisecondsSinceEpoch,
      );
      final d = CalendarDate.fromInstant(late, CalendarSystem.gregorian,
          utcOffsetMinutes: 210);
      expect(d, _g(2020, 3, 21));
    });
  });

  group('month names', () {
    test('Latin + native for each script calendar', () {
      expect(monthName(CalendarSystem.jalali, 1399, 1), 'Farvardin');
      expect(monthName(CalendarSystem.hijri, 1443, 9), 'Ramadan');
      // Hebrew leap year exposes Adar I / Adar II; common year has plain Adar.
      expect(monthName(CalendarSystem.hebrew, 5784, 6), 'Adar I');
      expect(monthName(CalendarSystem.hebrew, 5784, 7), 'Adar II');
      expect(monthName(CalendarSystem.hebrew, 5783, 6), 'Adar');
      // Native script is non-empty and differs from the Latin form.
      final faNative = monthName(CalendarSystem.jalali, 1399, 1, native: true);
      expect(faNative, isNotEmpty);
      expect(faNative, isNot('Farvardin'));
    });
  });
}
