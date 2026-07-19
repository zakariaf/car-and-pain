# Calendars & numerals — projection, format AND parse

All timestamps are stored canonically as `dateTime.toUtc().millisecondsSinceEpoch`.
Calendars and numeral systems are **pure display projections** chosen from the user's
DB-persisted preferences (`CalendarKind`, digit preference, Hijri day-offset). Never
persist a calendar-specific field or native numerals. **Never schedule notifications off
Jalali/Hijri arithmetic** — trigger off epoch/`DateTime` so leap/month-length quirks and
the iOS 64-pending cap logic stay calendar-independent.

## Calendars

| Kind | Library | Projection notes |
| --- | --- | --- |
| Gregorian | `intl` (`DateFormat`) | Canonical storage calendar; baseline, no conversion |
| Jalali / Shamsi | `shamsi_date` (jalaali-js) | Astronomical Nowruz leap rule; short-month clamp (Esfand 30). Valid ~560–3798 AD. Persian digits typical |
| Hijri | `hijri` (Um Al-Qura) | ~354-day year, variable months; add the user ±day offset before projecting. Eastern-Arabic digits typical |

```dart
String formatDate(DateTime utc, CalendarKind kind, String locale, {int hijriDayOffset = 0}) {
  final local = utc.toLocal();
  switch (kind) {
    case CalendarKind.gregorian:
      return DateFormat.yMMMMd(locale).format(local);
    case CalendarKind.jalali:
      final j = Jalali.fromDateTime(local);            // shamsi_date
      return '${j.formatter.yyyy}/${j.formatter.mm}/${j.formatter.dd}';
    case CalendarKind.hijri:
      final h = HijriCalendar.fromDate(
          local.add(Duration(days: hijriDayOffset)));  // hijri + user offset
      return h.toFormat('dd MMMM yyyy');
  }
}
```

- **Hijri offset:** Um Al-Qura vs moon-sighting can differ ±1 day; expose a persisted,
  user-settable ±day offset (included in backup) or users report "wrong date."
- **Never hand-roll** Jalali/Gregorian conversion (leap-year/epoch bugs) — use the libraries.
- **First day of week / weekend** are locale-aware: Saturday start for fa/ar; affects
  weekly bucketing in stats/reports (compute on canonical dates, label per locale).
- **Recurrence** ("every 6 months", Jalali-anchored due date) resolves in the user's
  calendar with short-month clamping, then re-anchors from actual completion — but the
  fired trigger is still an absolute epoch instant.

## Numerals — format at the edge, normalize before math

Digits are a **display and input** concern only. On input, native digits AND native
separators are folded to canonical ASCII before parse/store/search. On display they are
shaped to the user's preference (with a "Western digits" toggle).

### The four digit systems

| System | 0–9 | Unicode range | Locale(s) |
| --- | --- | --- | --- |
| Western Arabic (Latin) | 0123456789 | U+0030–0039 | Canonical storage/export form |
| Eastern Arabic | ٠١٢٣٤٥٦٧٨٩ | U+0660–0669 | ar, ckb |
| Persian | ۰۱۲۳۴۵۶۷۸۹ | U+06F0–06F9 | fa |
| Devanagari | ०१२३४५६७८९ | U+0966–096F | expansion tier (hi) |

> **Persian vs Eastern-Arabic are distinct code points AND distinct glyphs for 4, 5, 6**
> (Persian ۴۵۶ vs Eastern-Arabic ٤٥٦). `normalizeToAscii` MUST handle both ranges
> separately — mapping only one range silently drops the other.

### Separators — the trap

| Style | Decimal | Grouping | Example (1234567.5) |
| --- | --- | --- | --- |
| English (US/UK) | `.` | `,` every 3 | `1,234,567.5` |
| German/French | `,` | `.` / thin space every 3 | `1.234.567,5` |
| Persian/Arabic | `٫` U+066B | `٬` U+066C every 3 | `۱٬۲۳۴٬۵۶۷٫۵` |
| Indian (lakh/crore) | `.` | `2-2-3` | `12,34,567.5` |

> **`1٫5` means 1.5, not 15.** The Persian decimal `٫` (U+066B) and grouping `٬` (U+066C)
> must never be confused. Normalizing digits but NOT separators silently corrupts entered
> amounts — `double.parse` throws or yields the wrong number.

### Format

```dart
String formatNumber(num value, String locale, {required bool westernDigits}) =>
    NumberFormat.decimalPattern(westernDigits ? 'en' : locale).format(value);
```

### Parse — normalize FIRST, always

```dart
String normalizeToAscii(String input) {
  final sb = StringBuffer();
  for (final r in input.runes) {
    if (r >= 0x0660 && r <= 0x0669) {        // Eastern-Arabic ٠-٩
      sb.writeCharCode(0x30 + (r - 0x0660));
    } else if (r >= 0x06F0 && r <= 0x06F9) { // Persian ۰-۹
      sb.writeCharCode(0x30 + (r - 0x06F0));
    } else if (r == 0x066B) {                // ٫ decimal -> '.'
      sb.write('.');
    } else if (r == 0x066C) {                // ٬ grouping -> drop
      sb.write('');
    } else {
      sb.writeCharCode(r);
    }
  }
  return sb.toString();
}
// Odometer/price/engine-hour: double.parse(normalizeToAscii(text)) — NEVER int.parse(raw).
// A Persian/Arabic soft keyboard yields ۱۲۳ / ١٢٣, which fail int.parse.
```

- **Technical IDs (VIN/plate) always render Western digits** regardless of the toggle.
- **Fuel prices carry 3 decimals** of precision throughout.
- **Round-trip test:** `NumberFormat.decimalPattern('fa').format(12345)` →
  `normalizeToAscii` → `.parse` → `12345`. Table-test both digit ranges and both separators.

## Export

CSV/JSON writes an unambiguous ISO-8601/epoch canonical value (optionally plus a
localized display string), and the importer round-trips Persian/Arabic text, native
digits, and localized separators back to canonical. CSV gets a UTF-8 BOM so Excel does
not mojibake non-Latin scripts.
