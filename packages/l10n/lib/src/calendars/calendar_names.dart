import 'calendar.dart';

/// Month names for the three script calendars (F4-T3). Latin transliterations
/// serve en/de/fr; the native-script names serve fa/ar/ckb. Gregorian month and
/// all weekday names are localized through `intl` in the formatter layer (T9);
/// the Gregorian entries here are an English fallback.
///
/// String literals below are visible RTL script — safe in Dart source.

const _gregorianLatin = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _jalaliLatin = [
  'Farvardin', 'Ordibehesht', 'Khordad', 'Tir', 'Mordad', 'Shahrivar', //
  'Mehr', 'Aban', 'Azar', 'Dey', 'Bahman', 'Esfand',
];
const _jalaliNative = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', //
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];

const _hijriLatin = [
  'Muharram', 'Safar', 'Rabi al-awwal', 'Rabi al-thani', //
  'Jumada al-awwal', 'Jumada al-thani', 'Rajab', "Sha'ban", //
  'Ramadan', 'Shawwal', 'Dhu al-Qadah', 'Dhu al-Hijjah',
];
const _hijriNative = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', //
  'جمادى الآخرة', 'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];

// Tishrei-first display order; the leap variants insert Adar I / Adar II.
const _hebrewCommonLatin = [
  'Tishrei', 'Cheshvan', 'Kislev', 'Tevet', 'Shevat', 'Adar', //
  'Nisan', 'Iyar', 'Sivan', 'Tammuz', 'Av', 'Elul',
];
const _hebrewLeapLatin = [
  'Tishrei', 'Cheshvan', 'Kislev', 'Tevet', 'Shevat', 'Adar I', 'Adar II', //
  'Nisan', 'Iyar', 'Sivan', 'Tammuz', 'Av', 'Elul',
];
const _hebrewCommonNative = [
  'תשרי', 'חשוון', 'כסלו', 'טבת', 'שבט', 'אדר', //
  'ניסן', 'אייר', 'סיוון', 'תמוז', 'אב', 'אלול',
];
const _hebrewLeapNative = [
  'תשרי', 'חשוון', 'כסלו', 'טבת', 'שבט', 'אדר א׳', 'אדר ב׳', //
  'ניסן', 'אייר', 'סיוון', 'תמוז', 'אב', 'אלול',
];

/// The name of [month] (1-based, display numbering) in [year] for [system].
/// When [native] is true, returns the calendar's own-script name; otherwise a
/// Latin transliteration.
String monthName(
  CalendarSystem system,
  int year,
  int month, {
  bool native = false,
}) {
  final list = switch (system) {
    CalendarSystem.gregorian => _gregorianLatin,
    CalendarSystem.jalali => native ? _jalaliNative : _jalaliLatin,
    CalendarSystem.hijri => native ? _hijriNative : _hijriLatin,
    CalendarSystem.hebrew => isLeapYear(system, year)
        ? (native ? _hebrewLeapNative : _hebrewLeapLatin)
        : (native ? _hebrewCommonNative : _hebrewCommonLatin),
  };
  return list[month - 1];
}
