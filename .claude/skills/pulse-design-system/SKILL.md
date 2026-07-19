---
name: pulse-design-system
description: >-
  Builds Car and Pain UI in PULSE, the chosen design system (dossier and pitwall
  are rejected alternatives), across packages/design_system and presentation.
  Covers the token bridge to Dart PulseTokens, PulseColors ThemeExtension, dual
  warm-paper/ink ColorScheme and tabular TextTheme; the scoped, capped
  emotional-temperature model (urgency u0..u4, halo capped at saffron u2,
  ache card to pomegranate u4) and its a11y guardrails (temperature is mood never
  signal; every status redundantly encoded as icon plus label plus shape plus
  position; WCAG AA both themes; colour-blind safe); the signature widgets
  (breathing vitals pulse-line hero, ache card, status pill, urgency stripe,
  keypad-first quick-add, Rooms nav); and the exhale, breathe and count-up motion
  with reduced-motion fallbacks. Use when editing PulseTokens,
  pulse_theme, VitalsHero, VitalCard, StatusPill, UrgencyStripe, AmbientHalo,
  QuickLogSheet, RoomsNav, the exhale, or any CustomPainter chart or screen under
  packages/design_system or a presentation folder.
metadata:
  project: car-and-pain
  area: design-system, presentation
  source-docs: docs/design/pulse/00-design-system.md, docs/design/pulse/01-tokens.md, docs/design/pulse/02-components.md, docs/design/pulse/03-screens.md, docs/design/pulse/04-motion-rtl-accessibility.md
---

# PULSE Design System

Build Car and Pain's UI in **PULSE** — *"a vitals chart for your car."*
PULSE is the **single chosen design system**; `dossier` and `pitwall` (under
`docs/design/`) are rejected alternatives — never mix their tokens or metaphors
in. Tokens and shared widgets live in the frozen `packages/design_system/`
barrel; screens compose them in each feature's `presentation/` layer. Facts here
scope to those two areas.

Assume general Flutter/Dart/Material 3/CustomPainter knowledge. What follows is
only PULSE's specific, non-negotiable decisions.

## The five commitments (non-negotiable)

1. **Compose from tokens, never literals.** UI reads `PulseTokens` /
   `PulseColorsExt` / `ColorScheme` / `TextTheme` — never a raw `Color(0xFF…)`,
   hex, dp, ms, or `Cubic` inline. The token class is the single source of truth
   (`references/tokens.md`).
2. **Temperature is MOOD, never signal.** Warmth (urgency `u0..u4`) is ambient
   decoration painted *behind* content. Every status is ALSO encoded four
   redundant ways — **icon + text label + shape/pattern + position** — and text
   and controls always meet **WCAG AA in both themes**. Status knowable by hue
   alone is a bug (`references/redundant-encoding-a11y.md`).
3. **Warmth is scoped AND capped.** The aggregate `AmbientHalo` clamps to
   **saffron `u2`** and eases at most one stop; only the one specific aching
   *card* may reach **pomegranate `u4`**. This structurally kills the
   "permanent pain" trap — never let the field go ember/pomegranate.
4. **Every relieving action fires THE EXHALE.** Log, mark-done, clear, close →
   card cools exactly one notch, halo eases ≤1 stop, a soft settle, and a
   weighted haptic. The status icon+label flip in the same frame the cool begins
   (`references/motion-exhale.md`).
5. **Motion, warmth and colour are decoration.** Every animation has a
   reduced-motion fallback that preserves meaning; **haptics survive reduced
   motion** as the accessible confirmation channel. State must be fully legible
   with all three switched off.

## Structural signatures (do not "improve" these)

- **Cockpit home leads with ONE vital and NO visible list.** The prioritized
  "needs you now" queue lives one pull/swipe away in Pit-lane. Do not add a
  telemetry dashboard or open on an index.
- **The hero is an ECG-like breathing VITALS PULSE-LINE, not a ring.** It is a
  `CustomPainter` seismograph, symmetric (needs **no RTL mirroring**), and its
  **trace never warms** — mood lives only in the halo, ache only on cards.
- **Rooms navigation** = three named emotional spaces: **Cockpit** ("Now") ·
  **Garage** ("Care & history") · **Pit-lane** ("What's due") — not a generic
  tab bar. A **persistent keypad-first quick-add** and the Rooms nav are chrome
  reachable from every room.
- **Quick-log is keypad-first** ("enter any two" + last-3-digits odometer
  shortcut). The diegetic nozzle/dipstick is a demoted empty-state flourish,
  **never** the input mechanism.
- Voice is a **calm physician / good race engineer** — no mascot, no streak, no
  confetti. **No skeleton loaders** (offline-first; instant local paint is the
  flex).

## The one canonical snippet: status derives colour LAST

The spine of the whole system. `urgency` is the canonical signal; colour is
computed last and is never the source of truth. The halo clamps; the card does
not.

```dart
// packages/design_system/lib/src/pulse_temperature.dart
enum Urgency { calm, watch, dueSoon, pressing, overdue } // u0..u4

extension UrgencyToken on Urgency {
  int get u => index;

  /// Decoration ONLY — never read status from this. temp[] lives in PulseTokens.
  Color color(BuildContext c) => PulseTokens.of(c).temp[index];

  /// Redundant channel 1 — a shape that is MONOTONIC with urgency.
  StripeStyle get stripe => index <= 1
      ? const StripeStyle.solid()
      : StripeStyle.dashed(dash: const [8, 5, 3][index - 2],
                           gap:  const [6, 4, 5][index - 2]); // tighter = hotter

  /// Redundant channel 2 — the word (routed through gen-l10n at the call site).
  String label(AppLocalizations l) =>
      [l.uCalm, l.uWatch, l.uDueSoon, l.uPressing, l.uOverdue][index];

  /// Redundant channel 3 — the glyph (shape differs per status → greyscale-safe).
  IconData get icon => const [Icons.favorite, Icons.visibility, Icons.schedule,
      Icons.warning_amber, Icons.priority_high][index];

  /// THE CAP: the aggregate halo may never exceed saffron (u2). Cards do not clamp.
  Urgency get haloClamped => index > 2 ? Urgency.dueSoon : this;
}
```

`AmbientHalo` paints `worst.haloClamped`; a `VitalCard` paints its own true `u`
(up to `u4`). Redundant channel 4 is **position** — aching items sort to the top
under an "Aching now" header. See `examples/urgency_value_object.dart` and
`examples/vital_card.dart`.

## The token bridge (Dart)

- `PulseTokens` — theme-agnostic raw values (the `temp` ramp `u0..u4`, radii
  card 20 / sheet 26 / pill 999, the 8px spacing grid, tap targets key 44/56×64
  · quick-add 56 · room-nav 48, motion durations/curves, grain opacity).
- `PulseColors` (light `.day` / dark `.night`) — per-theme neutrals + **AA-safe
  semantic text tones** (`okText`/`warnText`/`critText`), exposed to widgets via
  a `PulseColorsExt extends ThemeExtension`. Read with `PulseTokens.of(context)`.
- Dual `ColorScheme` (`pulseLightScheme`/`pulseDarkScheme`) + a `TextTheme` from
  `buildPulseTextTheme`; assembled in `pulseTheme(Brightness)`.
- **Night values are hand-tuned on the ink surface — never auto-flipped.** Set
  `splashFactory: NoSplash` (the exhale is the feedback, not ripples).

Full colour/type/space tables, the CSS-to-Dart map, semantic-vs-ramp split,
vehicle-accent palette, and font mapping: **`references/tokens.md`**.

## Type, RTL & i18n (defer to the l10n contract)

- **Numerals are tabular everywhere they change or align** via
  `FontFeature.tabularFigures()`. Hero numeral `84/88` **reflows to `60/64`** on
  German / long-Arabic expansion and at large text scale — never clips.
- Latin = **Hanken Grotesk**; Arabic/Persian/Sorani = **Vazirmatn** (+2
  line-height at body and below); Persian masthead = **Noto Nastaliq Urdu**
  (≥1.8 line-height, `ExcludeSemantics`, masthead/milestone only), Arabic
  masthead = **Aref Ruqaa** — never conflate the two, never letter-space or
  ALL-CAPS Arabic.
- The **pulse-line, checkmarks, sweep dot, logo glyph, and the exhale/haptics do
  NOT mirror**; only directional glyphs and layout flip. Use Directional geometry
  only. Numeral formatting, calendars, and bidi isolation belong to the
  **`i18n-rtl-localization`** skill — do not re-implement them here.

## Signature components

Widget anatomy, variants, all states, and Flutter mappings for the pulse-line
hero, `VitalCard` (scoped temperature + capped halo), `AmbientHalo`, `StatusPill`,
`UrgencyStripe`, `RoomsNav`, `QuickLogSheet` keypad, reminder tile, list row,
headers, empty/first-run, and the `PulseScaffold`: **`references/components.md`**.

CustomPainter charts (pulse-line, sparkline with "vs your history" band, ranked
cost bars with hatch, cadence heatmap) reserve status hues — **saffron/ember/
pomegranate are NEVER a data series**; magnitude uses the sequential firouzeh
ramp with a redundant pattern + direct label. Painter mechanics belong to the
**`custompainter-charts`** skill; PULSE only fixes the palette rules here.

## Motion & the exhale

The four authored motions + haptics, exact durations/curves, the full exhale
sequence, count-up (on real change only — never re-count from 0), the breath
loop, and the complete reduced-motion matrix: **`references/motion-exhale.md`**.
Canonical exhale wiring: `examples/exhale_interaction.dart`.

## Accessibility gate (CI-enforced)

Redundant-encoding table, the contrast matrix (5 stops × 2 themes × text/icon/
outline), colour-blind + greyscale acceptance test, screen-reader semantics for
the decorative pulse-line, dynamic type to 2×, and touch-target floors:
**`references/redundant-encoding-a11y.md`**.

## Verify

- `scripts/analyze-and-gen.sh` — `build_runner build --delete-conflicting-outputs`
  then `flutter analyze` on `packages/design_system`.
- `scripts/check-token-literals.sh` — flags raw `Color(0xFF…)` / hex / magic dp
  outside the token file (commitment 1).
- `scripts/check-halo-cap.sh` — flags an `AmbientHalo` / halo urgency used
  without `haloClamped` / `.clamp(0, 2)` (commitment 3), and `u3`/`u4` in a halo.
- `scripts/check-directional-geometry.sh` — flags non-directional geometry and
  a mirrored pulse-line / checkmark in the design system + presentation.
- `scripts/check-redundant-encoding.sh` — flags a status colour without an
  accompanying label + icon (heuristic for commitment 2).

## Templates & examples

- `assets/pulse_widget.dart.tmpl` — a token-driven, RTL-correct, a11y-complete
  design-system widget skeleton.
- `examples/pulse_theme.dart` — `PulseTokens`, `PulseColorsExt`, both
  `ColorScheme`s, `TextTheme`, and `pulseTheme(Brightness)` assembled.
- `examples/urgency_value_object.dart`, `examples/vital_card.dart`,
  `examples/exhale_interaction.dart` — the signature interactions.

## Pairs with

`custompainter-charts` (chart painters) · `i18n-rtl-localization` (numerals,
calendars, bidi, ARB strings) · `flutter-architecture` (Riverpod DI, feature
folders) · `local-notifications-scheduler` (the reminders the ache cards surface).
