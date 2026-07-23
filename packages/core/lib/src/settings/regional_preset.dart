/// M9-T2 · regional preset bundles + fiscal/week boundary derivation (pure).
///
/// A preset sets every i18n axis at once as a *starting point* — after which any
/// single axis can still be overridden (the precedence resolver `resolveUnit`
/// and the settings store own that). Presets are locale-neutral data, not
/// behaviour: language, calendar, numerals, grouping, the display units,
/// currency, first-day-of-week, and the fiscal-year start. Choosing a preset
/// never rewrites a stored canonical value — it only changes projections.
library;

import '../units/distance.dart';
import '../units/pressure.dart';
import '../units/temperature.dart';
import '../units/volume.dart';

/// The bundled regional starting points.
enum RegionalPreset {
  iran,
  germany,
  france,
  unitedStates,
  saudiArabia,
  kurdistan,
  turkey,
  india,
  israel,
  spain,
  brazil,
}

/// Every axis a preset sets. Calendar/numeral/grouping are stable string codes
/// the l10n engine understands; currency is an ISO-4217 code; the fiscal-year
/// start is a (month, day) in the Gregorian proleptic calendar; the week starts
/// on an ISO weekday (1 = Monday … 7 = Sunday).
final class RegionalDefaults {
  const RegionalDefaults({
    required this.localeCode,
    required this.calendar,
    required this.numeral,
    required this.grouping,
    required this.distance,
    required this.volume,
    required this.temperature,
    required this.pressure,
    required this.currencyCode,
    required this.firstDayOfWeek,
    required this.fiscalYearStartMonth,
    required this.fiscalYearStartDay,
  });

  final String localeCode;
  final String calendar; // gregorian | jalali | hijri | hebrew
  final String numeral; // western | persian | arabic | devanagari
  final String grouping; // thousands | indian
  final DistanceUnit distance;
  final VolumeUnit volume;
  final TemperatureUnit temperature;
  final PressureUnit pressure;
  final String currencyCode;
  final int firstDayOfWeek; // ISO 1..7
  final int fiscalYearStartMonth;
  final int fiscalYearStartDay;
}

/// The defaults for a preset. Pure lookup — no I/O.
RegionalDefaults presetDefaults(RegionalPreset preset) => switch (preset) {
      RegionalPreset.iran => const RegionalDefaults(
          localeCode: 'fa',
          calendar: 'jalali',
          numeral: 'persian',
          grouping: 'thousands',
          distance: DistanceUnit.kilometre,
          volume: VolumeUnit.litre,
          temperature: TemperatureUnit.celsius,
          pressure: PressureUnit.bar,
          currencyCode: 'IRR',
          firstDayOfWeek: 6, // Saturday
          fiscalYearStartMonth: 3,
          fiscalYearStartDay: 21, // Nowruz ≈ 21 March
        ),
      RegionalPreset.germany => const RegionalDefaults(
          localeCode: 'de',
          calendar: 'gregorian',
          numeral: 'western',
          grouping: 'thousands',
          distance: DistanceUnit.kilometre,
          volume: VolumeUnit.litre,
          temperature: TemperatureUnit.celsius,
          pressure: PressureUnit.bar,
          currencyCode: 'EUR',
          firstDayOfWeek: 1, // Monday
          fiscalYearStartMonth: 1,
          fiscalYearStartDay: 1,
        ),
      RegionalPreset.france => const RegionalDefaults(
          localeCode: 'fr',
          calendar: 'gregorian',
          numeral: 'western',
          grouping: 'thousands',
          distance: DistanceUnit.kilometre,
          volume: VolumeUnit.litre,
          temperature: TemperatureUnit.celsius,
          pressure: PressureUnit.bar,
          currencyCode: 'EUR',
          firstDayOfWeek: 1,
          fiscalYearStartMonth: 1,
          fiscalYearStartDay: 1,
        ),
      RegionalPreset.unitedStates => const RegionalDefaults(
          localeCode: 'en',
          calendar: 'gregorian',
          numeral: 'western',
          grouping: 'thousands',
          distance: DistanceUnit.mile,
          volume: VolumeUnit.usGallon,
          temperature: TemperatureUnit.fahrenheit,
          pressure: PressureUnit.psi,
          currencyCode: 'USD',
          firstDayOfWeek: 7, // Sunday
          fiscalYearStartMonth: 1,
          fiscalYearStartDay: 1,
        ),
      RegionalPreset.saudiArabia => const RegionalDefaults(
          localeCode: 'ar',
          calendar: 'hijri',
          numeral: 'arabic',
          grouping: 'thousands',
          distance: DistanceUnit.kilometre,
          volume: VolumeUnit.litre,
          temperature: TemperatureUnit.celsius,
          pressure: PressureUnit.bar,
          currencyCode: 'SAR',
          firstDayOfWeek: 7,
          fiscalYearStartMonth: 1,
          fiscalYearStartDay: 1,
        ),
      RegionalPreset.kurdistan => const RegionalDefaults(
          localeCode: 'ckb',
          calendar: 'gregorian',
          numeral: 'arabic',
          grouping: 'thousands',
          distance: DistanceUnit.kilometre,
          volume: VolumeUnit.litre,
          temperature: TemperatureUnit.celsius,
          pressure: PressureUnit.bar,
          currencyCode: 'IQD',
          firstDayOfWeek: 6,
          fiscalYearStartMonth: 1,
          fiscalYearStartDay: 1,
        ),
      RegionalPreset.turkey => const RegionalDefaults(
          localeCode: 'en',
          calendar: 'gregorian',
          numeral: 'western',
          grouping: 'thousands',
          distance: DistanceUnit.kilometre,
          volume: VolumeUnit.litre,
          temperature: TemperatureUnit.celsius,
          pressure: PressureUnit.bar,
          currencyCode: 'TRY',
          firstDayOfWeek: 1,
          fiscalYearStartMonth: 1,
          fiscalYearStartDay: 1,
        ),
      RegionalPreset.india => const RegionalDefaults(
          localeCode: 'en',
          calendar: 'gregorian',
          numeral: 'devanagari',
          grouping: 'indian',
          distance: DistanceUnit.kilometre,
          volume: VolumeUnit.litre,
          temperature: TemperatureUnit.celsius,
          pressure: PressureUnit.bar,
          currencyCode: 'INR',
          firstDayOfWeek: 1,
          fiscalYearStartMonth: 4, // 1 April
          fiscalYearStartDay: 1,
        ),
      RegionalPreset.israel => const RegionalDefaults(
          localeCode: 'en',
          calendar: 'hebrew',
          numeral: 'western',
          grouping: 'thousands',
          distance: DistanceUnit.kilometre,
          volume: VolumeUnit.litre,
          temperature: TemperatureUnit.celsius,
          pressure: PressureUnit.bar,
          currencyCode: 'ILS',
          firstDayOfWeek: 7,
          fiscalYearStartMonth: 1,
          fiscalYearStartDay: 1,
        ),
      RegionalPreset.spain => const RegionalDefaults(
          localeCode: 'en',
          calendar: 'gregorian',
          numeral: 'western',
          grouping: 'thousands',
          distance: DistanceUnit.kilometre,
          volume: VolumeUnit.litre,
          temperature: TemperatureUnit.celsius,
          pressure: PressureUnit.bar,
          currencyCode: 'EUR',
          firstDayOfWeek: 1,
          fiscalYearStartMonth: 1,
          fiscalYearStartDay: 1,
        ),
      RegionalPreset.brazil => const RegionalDefaults(
          localeCode: 'en',
          calendar: 'gregorian',
          numeral: 'western',
          grouping: 'thousands',
          distance: DistanceUnit.kilometre,
          volume: VolumeUnit.litre,
          temperature: TemperatureUnit.celsius,
          pressure: PressureUnit.bar,
          currencyCode: 'BRL',
          firstDayOfWeek: 7,
          fiscalYearStartMonth: 1,
          fiscalYearStartDay: 1,
        ),
    };

/// The Gregorian fiscal year `[start, end)` containing [date] for a fiscal-year
/// start of ([startMonth], [startDay]). Pure date math (UTC midnight), used for
/// budgets and fiscal-boundary derivation. A date before this year's start falls
/// in the prior fiscal year (mirrors the tax-year logic in the mileage engine).
(DateTime, DateTime) fiscalYearOf(
  DateTime date, {
  required int startMonth,
  required int startDay,
}) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final thisYearStart = DateTime.utc(d.year, startMonth, startDay);
  if (d.isBefore(thisYearStart)) {
    return (
      DateTime.utc(d.year - 1, startMonth, startDay),
      thisYearStart,
    );
  }
  return (thisYearStart, DateTime.utc(d.year + 1, startMonth, startDay));
}

/// The number of days from [firstDayOfWeek] (ISO 1..7) back to the ISO weekday
/// of [date] — i.e. how far into the week [date] sits given a custom week start.
/// Drives weekly summaries and work-hours rules across calendars.
int dayOfWeekIndex(DateTime date, {required int firstDayOfWeek}) {
  final iso = DateTime.utc(date.year, date.month, date.day).weekday; // 1..7
  return (iso - firstDayOfWeek + 7) % 7;
}
