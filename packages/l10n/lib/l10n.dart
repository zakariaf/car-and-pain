/// Car and Pain — `l10n`.
///
/// The single public entry point for internationalization: the generated
/// `AppLocalizations` (gen-l10n), the localization delegates (including the ckb
/// Material/Cupertino fallback), the supported-locale list, and the RTL check.
/// Later: calendar (Gregorian/Jalali/Hijri) projection, numeral shaping, bidi
/// helpers, and bundled fonts.
///
/// `src/generated/` is produced by `flutter gen-l10n` (gitignored). Run the
/// `melos l10n` script if imports of `AppLocalizations` fail to resolve.
library;

export 'src/calendars/calendar.dart'
    show
        CalendarDate,
        CalendarSystem,
        defaultCalendarFor,
        isLeapYear,
        monthLength,
        monthsInYear,
        tryCalendarDate;
export 'src/calendars/calendar_names.dart' show monthName;
export 'src/generated/app_localizations.dart';
export 'src/localization.dart'
    show
        carAndPainLocalizationsDelegates,
        carAndPainSupportedLocales,
        isRtlLocale;
export 'src/numerals/numeral_format.dart' show NumeralFormat, NumeralParser;
export 'src/numerals/numeral_presets.dart'
    show
        NumeralPreset,
        defaultNumeralSystemFor,
        numeralPresetFor,
        resolveNumeralFormat,
        resolveNumeralParser;
export 'src/numerals/numeral_system.dart'
    show GroupingStyle, NumeralSystem, foldDigitsToAscii, groupInteger;
export 'src/pulse_labels.dart' show pulseLabel;
