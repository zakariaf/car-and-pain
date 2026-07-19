# ♿ Accessibility & Dynamic Type

> This document governs how Car and Pain stays usable for screen-reader, low-vision, motor, and cognitive-access users across six languages, both text directions, three calendars, and text scaled up to 2×.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · see also **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)** · **[Testing Strategy](./11-testing.md)** · **[Localization, RTL & Calendars (product)](../features/19-localization-rtl.md)**

## Decision

Accessibility and dynamic type are **first-class from module #1**, not a late QA pass. Every custom chart and stat tile carries an explicit `Semantics` node; TalkBack/VoiceOver read RTL text and Eastern-Arabic/Persian numerals correctly; focus and traversal order mirror in RTL; the biometric/PIN app-lock is fully operable by a screen reader; WCAG-AA contrast (4.5:1 body, 3:1 large text and non-text) is verified in both light and dark themes; and every dense RTL layout survives `MediaQuery.textScaler` from 1.0 to 2.0 without clipping tall Persian/Arabic glyphs. All of this is enforced by CI: `flutter_test`'s `meetsGuideline` accessibility guidelines plus **explicit large-text-scale (1.5×/2.0×) and RTL-overflow golden dimensions** in the trimmed Alchemist matrix. We add **no** accessibility-specific packages — the primitives (`Semantics`, `MergeSemantics`, `MediaQuery.textScalerOf`, `Focus`/`FocusTraversalGroup`) ship in the framework.

## Why

The RTL + tall-glyph + Eastern-numeral combination is exactly where screen readers and text scaling break, and **none of it is visible in the emulator's default `en-US` / LTR / textScaler 1.0 environment** — so it silently rots unless it is a compile-/CI-time gate rather than a human judgement call. Making text-scale and overflow *golden dimensions* turns a subjective "looks fine" into an enforced regression gate.

Alternatives considered and rejected (from the stack decision and critique):

- **Treat a11y as a late QA pass** — rejected: guarantees rework across all ~25 modules and store-review friction; retrofitting `Semantics` and Directional geometry after the fact is far more painful than doing it per-widget from the start.
- **Ignore text scaling** — rejected: dense RTL screens (fuel log rows, TCO tiles) overflow at 1.5–2×; the failure mode is a yellow-and-black overflow stripe or, worse, clipped digits that misreport an odometer value.
- **Fixed-height rows** — rejected: fixed heights clip scaled Persian/Arabic glyphs, whose ascenders/descenders (e.g. the tail on ج/چ, the dots on پ/ژ) are taller than Latin at the same point size.
- **Custom charts with no `Semantics`** — rejected: an `fl_chart` `CustomPaint` is a single opaque rectangle to a screen reader — the user's whole fuel-economy trend is invisible.
- **Third-party a11y helper packages** — rejected: unnecessary surface area for a buy-once/no-telemetry app; the framework primitives are sufficient and don't phone home.

## How we do it

### Where the code lives

Accessibility is a property of `design_system` widgets, not scattered per feature. Reusable a11y-correct primitives live in the design system package; features consume them and never hand-roll a chart or tile.

```text
packages/design_system/lib/src/
  a11y/
    semantic_chart.dart      # Semantics wrapper + RepaintBoundary for fl_chart
    stat_tile.dart           # MergeSemantics stat tile (label + value + unit)
    scalable_row.dart        # wrap/flex row that survives textScaler 2.0
    a11y_extensions.dart     # context.textScale, context.isRtl helpers
  theme/
    contrast.dart            # AA-verified light/dark color roles
apps/car_and_pain/test/a11y/
  contrast_test.dart         # meetsGuideline(textContrastGuideline)
  tap_target_test.dart       # meetsGuideline(androidTapTargetGuideline)
  semantics_labels_test.dart # labelled-tap-target + custom chart labels
```

### 1. Semantics on custom charts and stat tiles

A chart is meaningless to a screen reader unless you give it a value. Wrap `fl_chart` output in a `Semantics` node whose `label` is the **already-localized, already-numeral-formatted** summary, and mark the painted area as excluded so the reader announces the summary, not the pixels.

```dart
/// design_system: a chart that a screen reader can actually read.
class SemanticChart extends StatelessWidget {
  const SemanticChart({required this.summary, required this.chart, super.key});

  /// e.g. "میانگین مصرف ۷٫۸ لیتر در ۱۰۰ کیلومتر، رو به کاهش"
  final String summary;
  final Widget chart;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: summary,
      // The painted chart is decorative to a11y; the label carries the meaning.
      child: ExcludeSemantics(
        child: RepaintBoundary(child: chart),
      ),
    );
  }
}
```

Stat tiles bundle three visual runs (caption, value, unit) that must be read as **one** utterance, in reading order, with the numerals spoken in the user's script. Use `MergeSemantics` and build the label from the same formatter the UI uses:

```dart
class StatTile extends StatelessWidget {
  const StatTile({required this.caption, required this.value, required this.unit, super.key});
  final String caption;   // localized, e.g. "کل هزینه"
  final String value;     // NumberFormat(locale)-formatted, e.g. "۱۲٬۳۴۵"
  final String unit;      // localized, e.g. "تومان"

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: '$caption: $value $unit', // one node, reading order preserved
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caption, style: Theme.of(context).textTheme.labelMedium),
            Text.rich(TextSpan(children: [
              TextSpan(text: value, style: Theme.of(context).textTheme.headlineSmall),
              const TextSpan(text: ' '),
              TextSpan(text: unit, style: Theme.of(context).textTheme.bodySmall),
            ])),
          ],
        ),
      ),
    );
  }
}
```

### 2. Eastern-Arabic/Persian numerals in the screen reader

TalkBack/VoiceOver read the **string you hand them**. If the visible label says `۱۲٬۳۴۵` but the semantics label says `12345`, the reader speaks Western digits while the eye sees Persian — a mismatch that fails review. Rule: **the `Semantics.label` is built from the same `NumberFormat(locale)` output as the visible text**, never from the raw ASCII value. Isolate technical strings (VIN, plate) with LTR bidi marks in *both* the visible text and the semantics label so the reader announces them in the right order (see [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)).

### 3. Mirrored focus and traversal order

`Directionality` flips visual layout, but you must confirm focus/traversal follows reading order in RTL. Because geometry is **Directional-only** (project-wide rule — see [Architecture & Module Structure](./01-architecture-and-structure.md)), the default `ReadingOrderTraversalPolicy` mirrors correctly. Where a screen has independent regions (a form column + an action bar), wrap each in a `FocusTraversalGroup` so focus doesn't jump across the screen:

```dart
FocusTraversalGroup(
  policy: ReadingOrderTraversalPolicy(), // honours Directionality; RTL = right→left
  child: Column(children: [ /* fields in logical order */ ]),
);
```

Never set explicit `left`/`right`-anchored focus order. Directional geometry gives correct traversal for free; a hardcoded order breaks the moment the user switches to fa/ar/ckb.

### 4. Dynamic type: survive textScaler 1.5–2×

Read the scale via `MediaQuery.textScalerOf(context)` and **never** cap or ignore it. Dense RTL screens use flexible/wrapping layouts so tall glyphs at 2× reflow instead of clipping:

```dart
// DON'T: fixed height clips scaled Persian/Arabic ascenders/descenders.
// SizedBox(height: 48, child: Row(...))

// DO: let the row grow; wrap label+value when they no longer fit side by side.
class ScalableStatRow extends StatelessWidget {
  const ScalableStatRow({required this.label, required this.value, super.key});
  final Widget label, value;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    // Above ~1.5×, stack vertically so long labels + tall glyphs never overflow.
    if (scale >= 1.5) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [label, value],
      );
    }
    return Row(children: [Expanded(child: label), value]);
  }
}
```

Guidelines: give text `Flexible`/`Expanded` room; allow `maxLines` growth or `softWrap`; reserve `Icon` sizes with `IconTheme` that also scales; and prefer intrinsic-height rows over fixed `SizedBox` heights. Test the whole thing at 2.0 (below).

### 5. Accessible biometric / PIN lock

The app-lock gate (`local_auth` biometric + PIN escape — see [Security, Privacy & At-Rest Encryption](./09-security-privacy.md)) is the first screen a user hits, so it must be fully operable by a screen reader:

- The PIN pad buttons carry `Semantics(label: '<localized digit>', button: true)` and meet the **48×48 dp minimum tap target**.
- The biometric prompt's fallback ("Enter PIN instead") is a focusable, labelled button — never an icon-only affordance.
- On lock failure, announce the error via `SemanticsService.announce(localizedError, textDirection)` so a blind user hears "wrong PIN, 2 attempts left" without sight of the field.
- The lock screen respects textScaler: the PIN dots and digits reflow, never clip.

### 6. WCAG-AA contrast in both themes

Contrast is a property of the theme's color roles, verified by test — not eyeballed. The `contrast.dart` roles are chosen so body text ≥ 4.5:1 and large text / icons / focus rings ≥ 3:1 against their background in **both** light and dark. Never encode state by color alone (an overdue reminder needs an icon or text label, not just red) — that serves color-blind and low-vision users.

## Rules

**Do:**

- Wrap every `CustomPaint`/`fl_chart` in `SemanticChart` with a localized, numeral-formatted `summary`; `ExcludeSemantics` the painted area.
- Build every `Semantics.label` from the **same** `NumberFormat(locale)` / `DateFormat` output as the visible text (Persian eye ⇒ Persian ear).
- Read text scale via `MediaQuery.textScalerOf(context)`; give text `Flexible`/`Expanded`/`maxLines` room and wrap dense rows at high scale.
- Use `MergeSemantics` for label+value+unit tiles so they read as one utterance in reading order.
- Meet the 48 dp minimum tap target on every interactive element, including PIN keys and chart legend toggles.
- Use `SemanticsService.announce(text, Directionality.of(context))` for async state changes a sighted user would see (save succeeded, lock failed).
- Provide a non-color signal (icon/label) for every state (overdue, stale FX rate, missed fill).

**Don't:**

- Ship a fixed-height row that clips at textScaler 2.0 — CI golden fails.
- Set a hardcoded `Semantics.sortKey` with `left`/`right` assumptions — breaks RTL traversal.
- Put ASCII digits in a semantics label while showing Eastern digits on screen.
- Cap or override the OS text scale (`textScaler: TextScaler.noScaling`) anywhere in the tree.
- Rely on an icon-only button with no `Semantics` label (screen reader reads "button", nothing more).

**CI enforcement:**

```dart
// apps/car_and_pain/test/a11y/contrast_test.dart
testWidgets('meets WCAG AA contrast, light & dark', (tester) async {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    await tester.pumpWidget(app(themeMode: mode));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }
});

testWidgets('all tap targets ≥ 48dp and labelled', (tester) async {
  await tester.pumpWidget(app());
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
});
```

## For Car and Pain specifically

- **Offline / no-telemetry:** we add zero accessibility SDKs. Everything is framework-native `Semantics`/`MediaQuery`, so nothing phones home and the a11y layer doesn't threaten the omitted-INTERNET-permission claim. The CI lockfile scan (see [Store Compliance, Privacy Declarations & Licensing](./17-store-compliance-licensing.md)) stays green.
- **RTL / i18n:** a11y is where RTL correctness is *proven*, not just laid out — mirrored traversal, isolated VIN/plate reading order, and Persian-ear numerals all key off the same locale-controlled state the rest of the app uses. Sorani (ckb) rides the same path as fa/ar. Semantics labels are localized ARB strings, never concatenated (see [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)).
- **Notifications:** a reminder's screen-reader label reads the localized, numeral-correct due state ("Due in ۳ days" / "Overdue") — the same string the reconcile engine and the visible chip render, so ear and eye never disagree after a reboot re-arm.
- **Canonical storage:** accessibility is a **presentation-boundary** concern. Semantics labels are formatted from canonical value objects (Money minor units, Distance metres) exactly like the visible text — the DB never stores a display string or a native numeral.
- **App-lock durability:** the accessible PIN escape path is also the recovery path — a screen-reader user who can't use biometrics after re-enrollment still reaches their irreplaceable data.

## Testing

Accessibility is tested at three levels (see [Testing Strategy](./11-testing.md)):

1. **Widget / guideline tests** — `meetsGuideline` for `textContrastGuideline`, `androidTapTargetGuideline`, and `labeledTapTargetGuideline` on representative screens in both themes. Cheap, deterministic, run on every PR.

2. **Semantics-tree assertions** — pump a chart/tile and assert the merged node's label:

```dart
testWidgets('stat tile reads label+value+unit as one node in Persian', (tester) async {
  await tester.pumpWidget(pumpLocalized(
    const StatTile(caption: 'کل هزینه', value: '۱۲٬۳۴۵', unit: 'تومان'),
    locale: const Locale('fa'),
  ));
  expect(
    tester.getSemantics(find.byType(StatTile)),
    matchesSemantics(label: 'کل هزینه: ۱۲٬۳۴۵ تومان'),
  );
});
```

3. **Golden dimensions — large text scale + RTL overflow (the enforced gate).** The trimmed Alchemist matrix adds `textScaler 1.5` and `2.0` as explicit scenario dimensions on dense screens, in both LTR and every RTL locale, with **real fonts loaded** (`loadAppFonts`) so Persian/Arabic shaping is exercised — Ahem squares can't catch clipped tall glyphs:

```dart
goldenTest('fuel log row — scale × direction', fileName: 'fuel_row_scale', builder: () =>
  GoldenTestGroup(children: [
    for (final locale in const [Locale('en'), Locale('fa'), Locale('ar'), Locale('ckb')])
      for (final scale in const [1.0, 1.5, 2.0])
        GoldenTestScenario(
          name: '${locale.languageCode}@$scale',
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: pumpLocalized(const FuelLogRow(sample), locale: locale),
          ),
        ),
  ]),
);
```

An overflow at 2.0 renders the yellow-black stripe into the golden and fails the diff — a subjective "looks fine" becomes a byte-stable regression gate.

4. **Manual device pass (documented, not automated):** VoiceOver on iOS and TalkBack on Android for each RTL locale — confirm chart summaries are spoken, numerals are read in-script, focus mirrors, the PIN pad is operable, and the biometric fallback is announced. This rides the same real-device QA matrix as OEM notification survival (see [Permissions, Onboarding & OEM Survival](./16-permissions-onboarding-oem.md)).

## Pitfalls

- **Ahem-font goldens can't catch clipped glyphs or wrong numerals** — the large-text-scale and RTL-overflow goldens **must** run in the real-font lane (`loadAppFonts` + pinned OS), or a 2× Persian overflow ships green.
- **Widget-test defaults hide everything** — the harness is 800×600, textScaler 1.0, `en_US`, LTR. Set locale, `TextDirection`, and `textScaler` explicitly per test or RTL/dynamic-type bugs stay invisible.
- **ASCII digits leaking into semantics labels** — the commonest a11y/i18n mismatch: eye sees `۱۲۳`, ear hears "one two three". Always format the label with `NumberFormat(locale)`.
- **Fixed-height rows** — tall Persian/Arabic ascenders/descenders exceed Latin at the same point size; a `SizedBox(height:)` that fits English clips fa/ar at 1.5×.
- **Icon-only affordances** — a bare `IconButton` announces "button" with no meaning; add a localized `Semantics.label` or `tooltip`.
- **Color-only state** — overdue/stale/missed encoded purely by color fails color-blind users and low-contrast environments; pair every color with an icon or text.
- **Charts as opaque rectangles** — forgetting `SemanticChart` leaves the entire analytics surface invisible; `ExcludeSemantics` on the paint plus a summary label is mandatory.
- **Capping text scale to "protect" layout** — never `TextScaler.noScaling`; fix the layout to flex instead. Overriding the OS scale is an accessibility regression, not a fix.
- **Mirrored traversal assumed, not verified** — Directional geometry gives it for free, but a stray hardcoded `sortKey` or `Positioned(left:)` silently breaks focus order in RTL; the Directional-only CI grep guards this.

## Decisions to confirm

- **Key-recovery / app-lock UX** ([Security, Privacy & At-Rest Encryption](./09-security-privacy.md)): the accessible PIN-escape path must be finalized alongside the default recovery mechanism (passphrase vs one-time recovery code vs both) so the lock screen's screen-reader flow is designed once, not retrofitted.
- **Font subsetting vs glyph coverage** (asset/size-budget open question): subsetting Vazirmatn/Noto to shrink the buy-once binary must not drop Sorani (ckb) diacritics or rarely-used glyphs, or screen-reader-visible text renders as tofu at high scale. Confirm the subset covers all six languages before locking the size budget.

## Related

- **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)** — the locale/direction/numeral machinery every semantics label depends on.
- **[Testing Strategy](./11-testing.md)** — the trimmed golden matrix, real-font lane, and `meetsGuideline` gates.
- **[Security, Privacy & At-Rest Encryption](./09-security-privacy.md)** — the biometric/PIN lock this doc makes accessible.
- **[Architecture & Module Structure](./01-architecture-and-structure.md)** — the Directional-only geometry rule that makes RTL traversal correct by default.
- **[Store Compliance, Privacy Declarations & Licensing](./17-store-compliance-licensing.md)** — accessibility as a launch-blocking, review-friction deliverable.
- **[Localization, RTL & Calendars (product)](../features/19-localization-rtl.md)** — product-side requirements for the six languages and three calendars.
