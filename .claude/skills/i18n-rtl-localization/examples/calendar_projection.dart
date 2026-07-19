// Calendar projection + numeral normalization for Car and Pain.
// Storage is ALWAYS canonical UTC epoch millis + ASCII digits;
// calendars and native numerals are display/input-only transforms.

import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

enum CalendarKind { gregorian, jalali, hijri }

/// Project a stored UTC instant into the user's chosen calendar for DISPLAY only.
/// Never schedule notifications off this — schedule off the epoch/DateTime.
String formatDate(
  DateTime utc,
  CalendarKind kind,
  String locale, {
  int hijriDayOffset = 0, // user-settable ±day offset, persisted + in backup
}) {
  final local = utc.toLocal();
  switch (kind) {
    case CalendarKind.gregorian:
      return DateFormat.yMMMMd(locale).format(local);
    case CalendarKind.jalali:
      final j = Jalali.fromDateTime(local); // shamsi_date (astronomical Nowruz)
      return '${j.formatter.yyyy}/${j.formatter.mm}/${j.formatter.dd}';
    case CalendarKind.hijri:
      final h = HijriCalendar.fromDate(
        local.add(Duration(days: hijriDayOffset)), // Um Al-Qura + offset
      );
      return h.toFormat('dd MMMM yyyy');
  }
}

/// Display: shape a number to the user's numeral preference (presentation only).
String formatNumber(num value, String locale, {required bool westernDigits}) =>
    NumberFormat.decimalPattern(westernDigits ? 'en' : locale).format(value);

/// Input: fold native digits AND native separators to canonical ASCII BEFORE parse.
/// Handles Persian (U+06F0..) and Eastern-Arabic (U+0660..) digit ranges SEPARATELY,
/// plus the ٫ decimal (U+066B) and ٬ grouping (U+066C) separators.
String normalizeToAscii(String input) {
  final sb = StringBuffer();
  for (final r in input.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      sb.writeCharCode(0x30 + (r - 0x0660)); // Eastern-Arabic ٠-٩
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      sb.writeCharCode(0x30 + (r - 0x06F0)); // Persian ۰-۹
    } else if (r == 0x066B) {
      sb.write('.'); // ٫ decimal -> ASCII dot
    } else if (r == 0x066C) {
      sb.write(''); // ٬ grouping -> drop
    } else {
      sb.writeCharCode(r);
    }
  }
  return sb.toString();
}

/// Parse a user-entered odometer/price/engine-hour value safely.
double parseNumeric(String raw) => double.parse(normalizeToAscii(raw));
// NEVER int.parse(raw): a Persian/Arabic soft keyboard yields ۱۲۳ / ١٢٣ and '1٫5'.
