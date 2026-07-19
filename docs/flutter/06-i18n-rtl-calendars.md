# 🌐 Internationalization, RTL, Calendars & Numerals

> This document governs how Car and Pain localizes strings, mirrors layout for right-to-left scripts, renders and stores dates across three calendars, and formats/parses Eastern-Arabic and Persian numerals — all fully offline with zero runtime network dependency.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · See also [Architecture & Module Structure](./01-architecture-and-structure.md) · [Money, Currency, Units & FX](./14-money-currency-fx.md) · [Localization, RTL & Calendars (product)](../features/19-localization-rtl.md)

## Decision

Use Flutter's **built-in `gen-l10n` pipeline** (`flutter_localizations` from the SDK + `intl` + ARB files, `generate: true`, an `l10n.yaml`) — no third-party i18n runtime. The active **`Locale` is app-controlled and persisted in the encrypted DB**, fed to `MaterialApp.locale`; six locales ship: `fa`, `ar`, `ckb` (RTL) and `en`, `de`, `fr` (LTR). All dates are stored as **calendar-neutral UTC epoch millis** and projected only at display via `intl` (Gregorian), **`shamsi_date`** (Jalali) and **`hijri`** (Um Al-Qura + a user ±day offset). Eastern-Arabic/Persian numerals are a **presentation-only transform** via `NumberFormat(locale)`, with a "Western digits" toggle; **all numeric input — digits *and* the Persian/Arabic decimal (`٫`) and grouping (`٬`) separators — is normalized to ASCII before any math or storage.** Geometry is **Directional-only** from module #1. **Vazirmatn** is bundled as the primary font (with Noto Naskh Arabic + Noto Sans fallback); `google_fonts` is disqualified.

## Why

`gen-l10n` is the officially recommended workflow and the correct fit for a buy-once, no-telemetry app: it is compile-time key-checked, tree-shaken, has **zero runtime/network path**, and aligns natively with `GlobalMaterialLocalizations`/`GlobalWidgetsLocalizations`/`GlobalCupertinoLocalizations`, which give us RTL `Directionality` and localized pickers for free. Locale must be **app-controlled** because our users routinely run a Persian/Kurdish UI on an English-locale phone (and vice-versa), and — being account-free — there is no cloud profile; the preference travels inside the single-file backup instead.

Alternatives considered and rejected:

- **`easy_localization`** — runtime asset loading, no compile-time safety, heavier, poorly aligned with Flutter's own Material/Cupertino localization. Rejected.
- **`slang` / `intl_utils` (flutter_intl)** — reasonable but add another codegen surface / IDE tooling for little gain here. Not worth it.
- **`google_fonts` (runtime fetch)** — **disqualified**: fetches over the network, violating the 100%-offline and no-telemetry posture.
- **Hand-rolled Jalali/Hijri conversion** — leap-year/epoch bugs. Use the battle-tested `shamsi_date` (jalaali-js algorithm) and `hijri` (Um Al-Qura).
- **Normalizing digits only** — leaves the `٫`/`٬` separators unparsed, silently corrupting entered amounts. Rejected in favor of full separator + digit normalization.

## How we do it

### Package layout

All of this lives in the **`l10n` package** (a foundational internal package, see [Architecture & Module Structure](./01-architecture-and-structure.md)) with a narrow public barrel. Feature folders never re-implement formatting.

```text
packages/l10n/
  lib/
    l10n/                       # gen-l10n ARB inputs
      app_en.arb  app_de.arb  app_fr.arb
      app_fa.arb  app_ar.arb  app_ckb.arb
    src/
      calendars/                # Gregorian/Jalali/Hijri projection + formatting
        calendar_kind.dart
        calendar_formatter.dart
      numerals/                 # native-digit format + ASCII normalization
        numeral_formatter.dart
        numeral_normalizer.dart # digits + ٫ decimal + ٬ grouping -> ASCII
      bidi/
        bidi_isolate.dart       # isolateLtr / isolateAuto helpers
      locale/
        ckb_material_delegate.dart  # Sorani Material fallback (delegates to ar)
      fonts/                    # Vazirmatn + Noto (bundled TTF assets)
    l10n.dart                   # public barrel
  l10n.yaml
  pubspec.yaml
```

### `pubspec.yaml` + `l10n.yaml`

```yaml
# packages/l10n/pubspec.yaml
flutter:
  generate: true
  fonts:
    - family: Vazirmatn
      fonts:
        - asset: lib/src/fonts/Vazirmatn-Regular.ttf
        - asset: lib/src/fonts/Vazirmatn-Medium.ttf
          weight: 500
        - asset: lib/src/fonts/Vazirmatn-Bold.ttf
          weight: 700
    - family: NotoNaskhArabic
      fonts: [{ asset: lib/src/fonts/NotoNaskhArabic-Regular.ttf }]
    - family: NotoSans
      fonts: [{ asset: lib/src/fonts/NotoSans-Regular.ttf }]
dependencies:
  flutter_localizations: { sdk: flutter }
  intl: any            # version resolved to the SDK-pinned intl
  shamsi_date: ^1.1.0  # Jalali <-> Gregorian (jalaali-js)
  hijri: ^3.0.0        # Hijri (Um Al-Qura)
```

```yaml
# packages/l10n/l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false      # AppLocalizations.of(context) is non-null — no ! everywhere
```

### ARB with ICU plurals/select — never string concatenation

```json
// app_en.arb
{
  "reminderDueDays": "{count, plural, =0{Due today} =1{Due in 1 day} other{Due in {count} days}}",
  "@reminderDueDays": { "placeholders": { "count": { "type": "num" } } },

  "attachmentCount": "{n, plural, =0{No photos} =1{1 photo} other{{n} photos}}",
  "@attachmentCount": { "placeholders": { "n": { "type": "int" } } }
}
```

Word order and plural rules differ across `de`/`fa`/`ar`/`ckb`; building these by concatenation produces grammatically wrong output. Always use ICU placeholders. `select`/gender keys are case-sensitive — pass canonical lowercase keys.

### MaterialApp wiring — app-controlled, DB-persisted locale

```dart
class CarAndPainApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);         // null = follow device seed
    return MaterialApp.router(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,    // Global* + gen-l10n
        CkbMaterialLocalizations.delegate,             // Sorani -> 'ar' Material strings
      ],
      localeResolutionCallback: (device, supported) {
        if (locale != null) return locale;             // explicit user choice wins
        return basicLocaleListResolution([device ?? const Locale('en')], supported);
      },
      theme: ThemeData(
        fontFamily: 'Vazirmatn',
        fontFamilyFallback: const ['NotoNaskhArabic', 'NotoSans'],
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
```

The locale (plus preferred calendar, digit preference, and Hijri day-offset) is a settings row in the encrypted DB. Changing it rebuilds `MaterialApp`, which re-flips `Directionality` and re-runs every `AppLocalizations` lookup — **live, no restart**. These preferences are part of the backup export so a restore reproduces the exact UI (see [Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)).

### Sorani (ckb) Material fallback delegate

`GlobalMaterialLocalizations`/`GlobalCupertinoLocalizations` may not ship `ckb`. Our own ARB supplies app strings; for the framework's widget strings (picker labels, "Cancel", etc.) we delegate to the closest covered locale.

```dart
class CkbMaterialLocalizations extends DefaultMaterialLocalizations {
  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _CkbMaterialDelegate();
}

class _CkbMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _CkbMaterialDelegate();
  @override
  bool isSupported(Locale l) => l.languageCode == 'ckb';
  @override
  Future<MaterialLocalizations> load(Locale l) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('ar')); // borrow Arabic
  @override
  bool shouldReload(_) => false;
}
```

### Directional-only geometry (the RTL discipline)

RTL is a **layout discipline**, not a translation task — ~90% of RTL bugs are hardcoded left/right geometry that compiles fine and silently breaks. From module #1, feature code uses **only**:

```dart
// GOOD — resolves to the correct side per Directionality
Padding(padding: const EdgeInsetsDirectional.only(start: 16, end: 8), child: ...);
Align(alignment: AlignmentDirectional.centerStart, child: ...);
PositionedDirectional(start: 0, child: ...);
Text(label, textAlign: TextAlign.start);
Row(mainAxisAlignment: MainAxisAlignment.start, children: [...]);
Icon(Icons.adaptive.arrow_back);   // auto-mirrors

// BAD — banned in feature code (CI grep rejects)
EdgeInsets.only(left: 16);  Alignment.centerLeft;  Positioned(left: 0);
TextAlign.left;  Icons.arrow_back;
```

For custom directional glyphs that aren't in `Icons.adaptive`, mirror explicitly:

```dart
Transform(
  alignment: Alignment.center,
  transform: Matrix4.rotationY(
    Directionality.of(context) == TextDirection.rtl ? math.pi : 0),
  child: const Icon(Icons.trending_up), // e.g. a chevron/trend glyph
);
```

### Bidi isolation for VIN / plate / phone / part numbers

Strong-LTR technical strings visually scramble inside RTL paragraphs (a plate's letters and digits swap ends) unless isolated. Use Unicode isolates for **inline** use and explicit `textDirection` for **standalone** fields. Isolate characters live **only at the view layer** — store, search and export the raw ASCII string.

```dart
// bidi_isolate.dart
String isolateLtr(String s)  => '⁦$s⁩';  // LRI … PDI
String isolateAuto(String s) => '⁨$s⁩';  // FSI … PDI (unknown direction)

// Standalone field:
Text(vin, textDirection: TextDirection.ltr, textAlign: TextAlign.end);
TextField(controller: plateCtrl, textDirection: TextDirection.ltr);
```

### Calendar-neutral dates, projected at display

Every timestamp is persisted as `dateTime.toUtc().millisecondsSinceEpoch`. Jalali/Hijri/Gregorian are pure display projections chosen by the user's `CalendarKind` preference. (Note the instant-vs-wall-clock distinction from [Local Notifications & Background Reliability](./07-notifications.md): true instants are UTC epoch; *recurring reminder schedules* are stored as wall-clock + recurrence + calendar and are a different code path.)

```dart
String formatDate(DateTime utc, CalendarKind kind, String locale) {
  final local = utc.toLocal();
  switch (kind) {
    case CalendarKind.gregorian:
      return DateFormat.yMMMMd(locale).format(local);
    case CalendarKind.jalali:
      final j = Jalali.fromDateTime(local);              // shamsi_date
      return j.formatter.yyyy + '/' + j.formatter.mm + '/' + j.formatter.dd;
    case CalendarKind.hijri:
      final h = HijriCalendar.fromDate(local             // hijri
          .add(Duration(days: hijriDayOffset)));         // user ±day offset
      return h.toFormat('dd MMMM yyyy');
  }
}
```

**Never schedule notifications off Jalali/Hijri arithmetic** — schedule off epoch/`DateTime`, so leap/month-length quirks and the iOS 64-pending-cap logic stay calendar-independent.

### Native numerals — format at the edge, normalize before math

```dart
// numeral_formatter.dart — presentation only, gated by the user's digit switch
String formatNumber(num value, String locale, {required bool westernDigits}) =>
    NumberFormat.decimalPattern(westernDigits ? 'en' : locale).format(value);
```

```dart
// numeral_normalizer.dart — run on EVERY numeric input BEFORE parse/store
String normalizeToAscii(String input) {
  final sb = StringBuffer();
  for (final r in input.runes) {
    if (r >= 0x0660 && r <= 0x0669) { sb.writeCharCode(0x30 + (r - 0x0660)); } // ٠-٩
    else if (r >= 0x06F0 && r <= 0x06F9) { sb.writeCharCode(0x30 + (r - 0x06F0)); } // ۰-۹
    else if (r == 0x066B) { sb.write('.'); }   // ٫ Arabic decimal separator
    else if (r == 0x066C) { sb.write(''); }    // ٬ Arabic grouping separator -> drop
    else { sb.writeCharCode(r); }
  }
  return sb.toString();
}
// Odometer/price/engine-hour fields: double.parse(normalizeToAscii(text)) — never int.parse(text)
```

Technical IDs (VIN/plate) always render in Western digits regardless of the toggle.

## Rules

- **Do** put every string in ARB and read via `AppLocalizations.of(context)`. **Don't** hardcode user-facing text or build sentences/plurals by concatenation — use ICU `plural`/`select`.
- **Do** use only `*Directional` geometry, `TextAlign.start/end`, `MainAxisAlignment.start/end`, `Icons.adaptive.*`. **Don't** use `EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`, `Positioned(left/right:)`, or `TextAlign.left/right` in feature code. A **CI grep + custom_lint rejects the PR** (see [Build, Tooling, Release & CI/CD](./12-build-ci-release.md)).
- **Do** store dates as UTC epoch millis and numbers as ASCII. **Don't** ever persist native numerals or calendar-specific fields.
- **Do** `normalizeToAscii(...)` (digits **and** `٫`/`٬` separators) on every numeric input before parse or storage.
- **Do** isolate VIN/plate/phone with `isolateLtr`/`textDirection: ltr`. **Don't** let isolate characters reach storage, search, or export — strip at the boundary.
- **Do** drive locale from the DB-persisted setting and `MaterialApp.locale`. **Don't** read `Platform.localeName` as the source of truth.
- **Do** add all six languages to iOS `CFBundleLocalizations`. **Don't** rely on Android working as proof iOS surfaces the locale.
- **Do** bundle Vazirmatn + Noto. **Don't** add `google_fonts` — a CI lockfile scan should flag it alongside the analytics/crash SDK ban.
- **Do** expose a user-settable Hijri ±day offset and a "Western digits" toggle, both persisted and included in backup.
- **Don't** call `AppLocalizations.of(context)` above the `Localizations` scope (e.g. in `main()` before `runApp`).

## For Car and Pain specifically

- **Offline / no-telemetry:** `gen-l10n`, `intl`, `shamsi_date`, `hijri`, and bundled fonts are all fully offline and dependency-light — nothing phones home. `google_fonts` and any remote translation SDK are banned by the lockfile scan.
- **Encrypted DB is the source of truth:** locale, calendar, digit preference, and Hijri offset are settings rows in the encrypted SQLite DB (see [Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)); they are read at bootstrap and reproduced by a backup restore.
- **Canonical storage boundary:** the `l10n` and `core` packages are the *only* place conversion/formatting happens; feature widgets receive value objects and localized strings, never raw formatting logic. Money formatting composes with the ISO-4217 minor-unit model in [Money, Currency, Units & FX](./14-money-currency-fx.md) — render number and unit/symbol as separate isolated runs (or via `NumberFormat`'s currency pattern), never hand-concatenated.
- **Notifications:** reminder bodies use ARB/ICU plural strings and native numerals at render, but every trigger is computed off epoch/`DateTime` — see [Reminders & Notifications (product)](../features/04-reminders-notifications.md) and [Local Notifications & Background Reliability](./07-notifications.md).
- **Export portability:** CSV/JSON writes an unambiguous ISO-8601/epoch canonical value (optionally plus a localized display string), and round-trips Persian/Arabic text, Eastern digits, and localized separators through the importer — see [Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md).

## Testing

Golden tests are the RTL/i18n safety net, but **scoped to stay maintainable** (see [Testing Strategy](./11-testing.md)):

- **Golden — real fonts required.** Load Vazirmatn/Noto with `loadAppFonts()`/`FontLoader` first; the default test host renders **no** Arabic/Persian glyphs, making goldens blank/non-deterministic. Use **`alchemist`** (CI-stable) over `golden_toolkit` (winding down — borrow only `loadAppFonts`). Golden the **i18n primitives** (numerals, calendars, bidi, mirroring) and a few representative screens **exhaustively across locale × direction × calendar × numeral**; sample the rest. **Large text-scale (`textScaler` 1.5–2×) and RTL overflow are explicit golden dimensions** — tall Persian/Arabic glyphs overflow fixed-height rows. Pin one CI OS/Flutter version so glyph rendering is byte-stable; a CI **Ahem lane** catches mirroring cheaply, a **narrow real-font lane** catches shaping.

```dart
testGoldens('fuel row — fa/RTL/Jalali/native digits', (tester) async {
  await loadAppFonts();
  await tester.pumpWidgetBuilder(
    const FuelRow(...),
    wrapper: (child) => MaterialApp(
      locale: const Locale('fa'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child, // Directionality flips to RTL automatically
    ),
  );
  await screenMatchesGolden(tester, 'fuel_row_fa_rtl');
});
```

- **Unit — pure, deterministic, table-driven** (in the `l10n`/`core` packages):
  - **Digit + separator round-trip:** `NumberFormat.decimalPattern('fa').format(12345)` → `.parse` → `12345`; feed `U+06F0`/`U+0660` digit strings and `٫`/`٬` separators into `normalizeToAscii` and assert exact ASCII output.
  - **Calendar conversions:** table tests of known Gregorian↔Jalali (`shamsi_date`) and Gregorian↔Hijri (`hijri`) reference dates, including leap years, month boundaries, and the Hijri ±day offset.
  - **Bidi isolation:** assert `isolateLtr`/`isolateAuto` wrap with `U+2066`/`U+2068 … U+2069` and that stored values are stripped of isolate chars.
  - **Missing-key / pseudo-loc:** instantiate every `supportedLocale` and assert all ARB keys resolve (no `MissingResource`) before release.
- **Manual device QA (Impeller, per RTL locale):** letter joining/diacritics render; VIN/plate/phone read LTR inside RTL cards; nav/back icons mirror; native-digit keypad input saves correct values; charts mirror and show correct digits on axes/tooltips; Jalali/Hijri pickers show correct names; live locale switch re-mirrors without restart; a backup made under a Persian+Jalali+native-digits profile restores identically.

## Pitfalls

- **Hardcoded left/right geometry** is the #1 RTL bug source — it compiles and silently breaks. Enforce Directional-only from day one; retrofitting 25 modules later is far more painful.
- **Non-mirrored nav icons** (`Icons.arrow_back`, custom chevrons) point the wrong way in RTL — use `Icons.adaptive.*` or flip manually.
- **Normalizing digits but not separators** — `٫`/`٬` slip through and `double.parse` throws or corrupts the amount. Normalize both.
- **`int.parse`/`double.parse` on raw keyboard input** — a Persian/Arabic soft keyboard yields `۱۲۳`/`١٢٣`, which fail to parse. Always normalize first.
- **VIN/plate/phone reordering** inside RTL text unless isolated.
- **Assuming Material/Cupertino localizations cover `ckb`** — they may not. Provide the fallback delegate and test date/number pickers in `ckb`.
- **Forgetting iOS `CFBundleLocalizations`/Xcode localizations** — non-English locales may not be offered on iOS even though Android works.
- **`AppLocalizations.of(context)` used above the `Localizations` scope** (e.g. in `main()`).
- **Hijri Um Al-Qura vs moon-sighting** can differ ±1 day — without the user offset, users report "wrong date". Never schedule off Hijri math.
- **Hand-rolled Jalali/Gregorian conversion** — leap-year/epoch bugs; rely on `shamsi_date` (valid ~560–3798 AD).
- **Goldens with no real fonts** — blank/non-deterministic. Load fonts and pin the host.
- **Chart libraries don't auto-mirror** — set axis side, label alignment, and reversed X for RTL explicitly, and apply the digit formatter to axis/tooltip labels (see [Performance & Rendering](./10-performance-rendering.md) and [Accessibility & Dynamic Type](./15-accessibility-dynamic-type.md)).
- **Impeller complex-script shaping** — validate Arabic/Persian joining/diacritics on a real device (not simulator) on current stable.

## Decisions to confirm

- **Font asset-bundling & size budget** (open question): subsetting Vazirmatn/Noto and limiting weights has real binary-size implications for a buy-once app; the asset-bundling and size-budget strategy needs to be settled with the build tooling owner (see [Build, Tooling, Release & CI/CD](./12-build-ci-release.md)), including whether a `persian_datetime_picker` widget is bundled or a picker is built on top of `shamsi_date`.

## Related

- [Architecture & Module Structure](./01-architecture-and-structure.md) — where the `l10n` package sits and its barrel API.
- [Money, Currency, Units & FX](./14-money-currency-fx.md) — ISO-4217 minor units and currency formatting that composes with numeral rendering.
- [Local Notifications & Background Reliability](./07-notifications.md) — epoch-based scheduling and wall-clock recurrence; why calendars stay display-only.
- [Accessibility & Dynamic Type](./15-accessibility-dynamic-type.md) — RTL focus order, text-scale overflow, and Semantics for native numerals.
- [Testing Strategy](./11-testing.md) — the trimmed golden matrix and real-font lanes.
- [Localization, RTL & Calendars (product)](../features/19-localization-rtl.md) — the product-side spec this engineering doc implements.
