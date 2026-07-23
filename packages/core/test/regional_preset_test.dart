import 'package:core/core.dart';
import 'package:test/test.dart';

/// M9-T2/T7 · regional preset bundles + fiscal/week boundary derivation.
void main() {
  group('presetDefaults', () {
    test('every preset resolves and covers all axes', () {
      for (final p in RegionalPreset.values) {
        final d = presetDefaults(p);
        expect(d.localeCode, isNotEmpty);
        expect(d.currencyCode.length, 3);
        expect(d.firstDayOfWeek, inInclusiveRange(1, 7));
        expect(d.fiscalYearStartMonth, inInclusiveRange(1, 12));
      }
    });

    test('the US preset is imperial, USD, Sunday-start', () {
      final us = presetDefaults(RegionalPreset.unitedStates);
      expect(us.distance, DistanceUnit.mile);
      expect(us.volume, VolumeUnit.usGallon);
      expect(us.temperature, TemperatureUnit.fahrenheit);
      expect(us.currencyCode, 'USD');
      expect(us.firstDayOfWeek, 7);
    });

    test('Iran is Jalali/Persian/Saturday with a Nowruz fiscal start', () {
      final ir = presetDefaults(RegionalPreset.iran);
      expect(ir.calendar, 'jalali');
      expect(ir.numeral, 'persian');
      expect(ir.firstDayOfWeek, 6);
      expect(ir.fiscalYearStartMonth, 3);
      expect(ir.fiscalYearStartDay, 21);
    });

    test('India uses Indian digit grouping and a 1-April fiscal year', () {
      final india = presetDefaults(RegionalPreset.india);
      expect(india.grouping, 'indian');
      expect(india.fiscalYearStartMonth, 4);
    });
  });

  group('fiscalYearOf', () {
    test('a 1-April fiscal year splits the calendar year correctly', () {
      // 5 April 2026 is in FY starting 1 April 2026.
      final (start, end) =
          fiscalYearOf(DateTime.utc(2026, 4, 5), startMonth: 4, startDay: 1);
      expect(start, DateTime.utc(2026, 4));
      expect(end, DateTime.utc(2027, 4));
      // 31 March 2026 is still in the PRIOR fiscal year.
      final (start2, _) =
          fiscalYearOf(DateTime.utc(2026, 3, 31), startMonth: 4, startDay: 1);
      expect(start2, DateTime.utc(2025, 4));
    });

    test('a calendar fiscal year (Jan 1) is the plain year', () {
      final (start, end) =
          fiscalYearOf(DateTime.utc(2026, 7), startMonth: 1, startDay: 1);
      expect(start, DateTime.utc(2026));
      expect(end, DateTime.utc(2027));
    });
  });

  group('dayOfWeekIndex', () {
    test('a Monday-start week places Monday at 0, Sunday at 6', () {
      // 2026-01-05 is a Monday.
      expect(dayOfWeekIndex(DateTime.utc(2026, 1, 5), firstDayOfWeek: 1), 0);
      // 2026-01-11 is a Sunday.
      expect(dayOfWeekIndex(DateTime.utc(2026, 1, 11), firstDayOfWeek: 1), 6);
    });

    test('a Saturday-start week places Saturday at 0', () {
      // 2026-01-03 is a Saturday.
      expect(dayOfWeekIndex(DateTime.utc(2026, 1, 3), firstDayOfWeek: 6), 0);
    });
  });
}
