# Golden and RTL matrix

How Car and Pain snapshots its RTL/i18n surface without flaking. Goldens are the
RTL safety net — they catch mirroring, bidi isolation, calendar projection, and
Eastern-Arabic/Persian numeral regressions that unit tests cannot see.

## The six locales

`en`, `de`, `fr` (LTR) and `fa`, `ar`, `ckb` (RTL). Sorani Kurdish (`ckb`) is
RTL and uses Eastern-Arabic numerals — do not drop it.

## Two lanes (both call `loadAppFonts`)

| Lane | Fonts | Runs on | Catches | CI job |
| --- | --- | --- | --- | --- |
| Ahem CI | Ahem squares (byte-stable cross-OS) | one pinned Linux box | geometry, mirroring, overflow, layout | `goldens_ci` on every PR |
| Real-font | bundled Vazirmatn + Noto | one pinned OS | Persian/Arabic glyph joining, numeral glyphs | `goldens_font` PR-label or nightly |

Ahem squares validate geometry but **not** glyph shaping — broken Persian/Arabic
joining or a wrong numeral glyph slips through the CI lane and is caught only by
the real-font lane. Forgetting `loadAppFonts` renders text as tofu/fallback
boxes that differ per machine.

## Matrix dimensions

Golden the **i18n primitives exhaustively**; **sample** representative screens.

| Dimension | Values |
| --- | --- |
| Locale | en, de, fr, fa, ar, ckb |
| Direction | LTR, RTL (derived from locale, asserted explicitly) |
| Calendar | Gregorian, Jalali, Hijri |
| Numeral | Latin, Eastern-Arabic, Persian |
| Text scale | 1.0, 1.5, 2.0 (`TextScaler.linear`) — `large-text-scale` is explicit |
| Overflow | RTL-overflow is an explicit scenario |

| Target | Coverage |
| --- | --- |
| Numerals + separators (`٫` decimal, `٬` grouping) | Exhaustive: all locales x numeral systems |
| Calendar projection (Gregorian/Jalali/Hijri) | Exhaustive across locales |
| Bidi isolation (FSI/PDI marks around VIN, plate, phone) | Exhaustive; assert isolation marks present |
| Mirroring (directional icons, leading/trailing) | Exhaustive |
| Representative screens (ServiceDueCard, dashboard, fuel log) | **Sampled** locale x direction, not full cross-product |
| Chart wrappers (`CustomPainter`) | Assert `Semantics` label/value, sample locales |

## `GoldenTestGroup` shape

```dart
GoldenTestGroup(
  children: [
    for (final locale in const [Locale('en'), Locale('de'), Locale('fr'),
                                Locale('fa'), Locale('ar'), Locale('ckb')])
      GoldenTestScenario(
        name: '$locale',
        child: pumpLocalized(const ServiceDueCard(), locale: locale,
            textScaler: const TextScaler.linear(1.5)),
      ),
  ],
);
```

`pumpLocalized` (from `app_test_utils`) wires gen-l10n delegates, the derived
`TextDirection`, and the `textScaler` — never rely on the 800x600 / `1.0` /
`en_US` / LTR defaults.

## `flutter_test_config.dart`

Place one at each golden test root. It loads app fonts and wraps the suite in
the Alchemist config so text renders real glyphs instead of tofu.

```dart
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts(); // Vazirmatn + Noto + Ahem
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(/* ci + platform lanes */),
    run: testMain,
  );
}
```

## Discipline

- Tag every golden test `@Tags(['golden'])` so the unit and golden lanes stay
  separate (`flutter test --exclude-tags golden` vs `--tags golden`).
- Pin the Flutter version (FVM). Generate and commit goldens in that ONE
  environment — never regenerate on a dev Mac while CI runs Linux.
- Block accidental `--update-goldens` in the pipeline.
- Never `pumpAndSettle()` a shimmer/splash/spinner golden — timed `pump` only.
