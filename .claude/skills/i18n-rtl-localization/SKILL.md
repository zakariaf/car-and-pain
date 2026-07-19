---
name: i18n-rtl-localization
description: >-
  Localization, RTL and calendars for Car and Pain's offline gen-l10n pipeline.
  Covers routing every user-facing string through ARB files
  (app_en/de/fr/fa/ar/ckb.arb) with ICU plural/select and key + placeholder
  parity, Directional-only geometry (EdgeInsetsDirectional, PositionedDirectional,
  TextAlign.start, Icons.adaptive) that keeps RTL correct by construction, bidi
  isolation of VIN, plate, phone and IBAN, calendar
  projection (Gregorian via intl, Jalali via shamsi_date, Hijri via hijri) from
  canonical UTC epoch, and native numeral format AND parse distinguishing Persian
  versus Eastern-Arabic digits and the Persian decimal and grouping separators,
  plus Vazirmatn/Noto fonts. Runs check_arb_parity.sh and run_gen_l10n.sh. Use
  when adding or translating a string key, building an RTL screen,
  formatting or parsing dates, amounts, odometer or numerals, touching the l10n
  package, app_*.arb, l10n.yaml, AppLocalizations, numeral_normalizer.dart or
  calendar_formatter.dart, or pairing with scaffold-feature-module.
metadata:
  project: car-and-pain
  source-docs: docs/flutter/06-i18n-rtl-calendars.md, docs/features/19-localization-rtl.md
---

# i18n, RTL & Calendars

The localization contract for Car and Pain: **store canonical, localize at render.**
All conversion and formatting lives ONLY in the `packages/l10n` package (and `core`);
feature widgets receive value objects and already-localized strings, never raw
formatting logic. Six locales ship: `fa`, `ar`, `ckb` (RTL) and `en`, `de`, `fr` (LTR).

Assume general Flutter/Dart/intl/RTL knowledge. What follows is only what is
specific to this project's decisions.

## Non-negotiable rules

1. **Every user-facing string goes through gen-l10n.** Add a key to `app_en.arb`
   (the template) and read it via `AppLocalizations.of(context)`. Never hardcode
   user-facing text. `nullable-getter: false` — `AppLocalizations.of(context)` is
   non-null, so no `!`. Never call it above the `Localizations` scope (e.g. in
   `main()` before `runApp`).
2. **Build sentences and plurals with ICU, never concatenation.** Use `{count, plural, ...}`
   and `{x, select, ...}` in the ARB. Word order and plural categories differ across
   de/fa/ar/ckb (Arabic has six forms). Concatenation produces grammatically wrong output.
3. **Directional-only geometry from module #1.** Use `EdgeInsetsDirectional`,
   `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`,
   `MainAxisAlignment.start/end`, `Icons.adaptive.*`. NEVER `EdgeInsets.only(left/right)`,
   `Alignment.centerLeft/Right`, `Positioned(left/right:)`, `TextAlign.left/right`, or
   `Icons.arrow_back` in feature code. A CI grep + custom_lint rejects the PR.
4. **Store dates as UTC epoch millis, numbers as ASCII.** Never persist native
   numerals or calendar-specific fields. Calendars and numerals are display-only projections.
5. **Normalize every numeric input to ASCII before parse or storage** — digits AND
   the Persian/Arabic decimal `٫` (U+066B) and grouping `٬` (U+066C) separators.
   Use `double.parse(normalizeToAscii(text))`, never `int.parse(text)` on raw input.
6. **Schedule off epoch/`DateTime`, never off Jalali/Hijri arithmetic.** Calendars
   project for display only; reminder triggers are computed from canonical instants.
7. **Isolate strong-LTR technical strings** (VIN, plate, phone, IBAN, part numbers)
   at the view layer only. Never let isolate characters reach storage, search, or export.
8. **Never add `google_fonts`** (runtime fetch violates the offline/no-telemetry posture).
   Bundle Vazirmatn + Noto Naskh Arabic + Noto Sans; the CI lockfile scan flags it.

## The one canonical snippet: format at the edge, normalize before math

```dart
// packages/l10n — presentation transform, gated by the user's digit switch
String formatNumber(num value, String locale, {required bool westernDigits}) =>
    NumberFormat.decimalPattern(westernDigits ? 'en' : locale).format(value);

// Run on EVERY numeric input BEFORE parse/store. Handles Persian AND Eastern-Arabic
// digit ranges plus the ٫ decimal and ٬ grouping separators.
String normalizeToAscii(String input) {
  final sb = StringBuffer();
  for (final r in input.runes) {
    if (r >= 0x0660 && r <= 0x0669) {        // Eastern-Arabic ٠-٩
      sb.writeCharCode(0x30 + (r - 0x0660));
    } else if (r >= 0x06F0 && r <= 0x06F9) { // Persian ۰-۹
      sb.writeCharCode(0x30 + (r - 0x06F0));
    } else if (r == 0x066B) {                // ٫ Arabic decimal separator
      sb.write('.');
    } else if (r == 0x066C) {                // ٬ Arabic grouping separator -> drop
      sb.write('');
    } else {
      sb.writeCharCode(r);
    }
  }
  return sb.toString();
}
// Odometer / price / engine-hour: double.parse(normalizeToAscii(text))
```

Technical IDs (VIN/plate) always render in Western digits regardless of the toggle.

## Adding a string key (the ARB workflow)

1. Add the key + its `@key` metadata (with `placeholders` typed) to `app_en.arb` first.
2. Add the SAME key to all five other ARB files with a real translation (or a
   tracked TODO), preserving the exact placeholder names and ICU structure.
3. Run `scripts/check_arb_parity.sh` — fails if any locale is missing a key or a
   placeholder differs from the template.
4. Run `scripts/run_gen_l10n.sh` to regenerate `app_localizations.dart`, then
   `flutter analyze`.

Details, ICU examples, and placeholder-typing table: `references/arb-workflow.md`.

## RTL, calendars, numerals — deep references

- **Directional geometry, bidi isolation, icon-mirroring, RTL charts:**
  `references/rtl-directional-rules.md`
- **Calendar projection (Jalali/Hijri/Gregorian), Hijri day offset, numeral format
  AND parse, separator table, Persian-vs-Eastern-Arabic digit distinction:**
  `references/calendars-numerals.md`
- Correct illustrative Dart: `examples/directional_widget.dart`,
  `examples/calendar_projection.dart`
- New-key ARB entry template: `assets/arb_entry.tmpl`

## Font pairing & per-language voice

- Theme `fontFamily: 'Vazirmatn'` with `fontFamilyFallback: ['NotoNaskhArabic', 'NotoSans']`.
  Vazirmatn is primary (covers Latin + Arabic script incl. Persian/Sorani letters
  ڕ ڵ ۆ ێ ە ڤ); Noto Naskh Arabic and Noto Sans are tofu-prevention fallbacks.
- Weights bundled: Regular, Medium (500), Bold (700) — do not reference weights not
  in `pubspec.yaml`.
- **Per-language voice:** fa/ar/ckb are RTL and translated for natural reading order
  (vehicle name placed so the sentence reads naturally in RTL); ckb borrows Arabic
  Material widget strings via `CkbMaterialLocalizations` (Global* may not ship `ckb`).
  Keep microcopy — help, tutorials, insights, category labels — translated across all
  six, not just top-level chrome.

## Pairs with

`scaffold-feature-module` — when a new feature folder is created, its user-facing
strings are added through this ARB workflow, and its widgets follow the Directional-only
discipline from the first commit.
