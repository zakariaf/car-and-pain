---
name: custompainter-charts
description: Author the offline-only, hand-painted charts and dashboard vitals of Car and Pain using CustomPainter and CustomPaint instead of any charting dependency (no fl_chart, no Syncfusion, no chart library). Enforces the PULSE dataviz discipline — three-tier progressive disclosure (hero vital, interactive chart, opt-in raw table), the firouzeh sequential ramp for data with reserved saffron/ember/pomegranate status hues that never become a data series, redundant hatch and direct-label encoding for colour-blind safety, complete Semantics nodes on every chart and vital, RepaintBoundary with shared-controller breathing, and the no-skeleton-loader and count-up-on-real-change rules. Pairs with the pulse-design-system skill for tokens. Use when writing or reviewing a CustomPainter such as PulseLinePainter, SparklinePainter, CostBar, or a cadence heatmap; building the Cockpit vitals hero, economy trend, or spend-by-category chart; adding chart Semantics, legends, or reference bands; or choosing chart colours and patterns.
metadata:
  project: car-and-pain
  pairs-with: pulse-design-system
  sources: docs/design/pulse/02-components.md, docs/design/pulse/04-motion-rtl-accessibility.md, docs/features/17-dashboard-statistics-reports.md, docs/flutter/10-performance-rendering.md
---

# CustomPainter Charts (PULSE dataviz)

Paint every chart in Car and Pain by hand with `CustomPainter`/`CustomPaint`. This is a
deliberate product decision, not an omission — the design system specs all charts as
hand-painted primitives (`docs/design/pulse/02-components.md` §9). Read
`references/painter-patterns.md` for per-painter recipes and
`references/chart-tokens-and-a11y.md` for the token tables and the a11y acceptance checklist.
Get PULSE tokens (`PulseTokens`, `PulseMotion`) from the `pulse-design-system` skill.

## Non-negotiable rules

- **No chart dependency, ever.** Never add or import `fl_chart`, `syncfusion_*`, `charts_flutter`,
  `graphic`, or any plotting package for these charts. Draw with `Canvas`/`Path`/`Paint` inside a
  `CustomPainter`. (The old perf note mentioning `fl_chart` is superseded by the PULSE "no chart
  library" spec — treat CustomPainter as the only path.)
- **Status hues are reserved — never a data series.** Saffron `#E9A43B`, ember `#E8703A`,
  pomegranate `#D64533` (and pistachio `#7FBF6A`) encode *urgency*, not data. Plot every data
  series from the **firouzeh sequential ramp** only: light→dark `#7FD4C8 · #2FB8A8 · #1F8F82`,
  reference band `--u0-soft`. Dark steps are hand-validated on ink — never auto-flip a light hue.
- **Every categorical encoding is redundant.** Colour alone is forbidden. Pair each category with a
  **direct text label** (`Fuel €231 · 55%`) and give the highlighted/largest slice a **hatch
  pattern** (`repeating` 45° white-alpha stripes). Any chart with 2+ series carries a **legend**
  that names its non-colour cue ("Hatched = largest slice").
- **Three-tier progressive disclosure.** Surface data as (1) a **hero vital** — the breathing
  pulse-line + one count-up number on the Cockpit; (2) an **interactive chart** — tap a bar/point
  for a tooltip with the exact figure and a "vs your history" line; (3) an **opt-in raw table** the
  user expands. Never dump the table first; never make the hero interactive.
- **No skeleton loaders.** Data is local and instant — offline-first is the flex. Paint the real
  chart immediately. The only non-default state is **empty**: draw the axis frame plus a
  next-action line ("Not enough data yet — log 2 fills to see your trend"). Never a shimmer, spinner,
  or placeholder box.
- **Count up on REAL change only.** Roll numerals on first reveal and when the *canonical* value
  actually changes — key the animation on the value (`key: ValueKey(value)`), never re-count from 0
  on every rebuild or screen visit. Under reduced motion, print the final formatted string instantly.
- **The painter is decorative; the Semantics node is the truth.** Wrap the `CustomPaint` in
  `ExcludeSemantics` and attach a sibling `Semantics(label:…, value:…)` that speaks the *answer* in
  display numerals ("Economy trending 6.9 to 6.4 L per 100km over 12 months"), not the shape. Hero
  vitals add `liveRegion: true` so the exhale is announced.
- **Isolate the animating layer.** Wrap each painter in a `RepaintBoundary`. Drive breathing from a
  **single app-wide `AnimationController`** (`PulseMotion.breathe`, 4000ms) via `AnimatedBuilder` —
  never one ticker per point. Gate it on `reduceMotion(context)`: when true, pass a fixed phase and
  do not `repeat()`.
- **Off-thread downsampling.** Bucket/downsample multi-year histories with `Isolate.run`, keyed off
  the rollup revision counter — never loop thousands of points synchronously in `paint()` or
  `build()`. `paint()` receives already-downsampled, already-projected data.
- **Waveform never mirrors; chrome does.** The pulse-line, sweep dot, checkmarks and plotted data
  orientation are direction-agnostic (an ECG has no handedness). Only chart chrome — legends,
  tooltips, axis placement, the time-axis direction — flips in RTL. Derive any sign from
  `Directionality.of(context)`; never hard-code an `Offset` sign or `left`/`right`.
- **Canonical in, display out.** `paint()` consumes canonical values (SI metres, UTC epoch millis,
  ISO-4217 minor units) already converted to display units and formatted with locale numerals /
  the active calendar upstream. Never format dates, convert units, or shape numerals inside a
  painter — memoize formatted axis labels (see `docs/flutter/10-performance-rendering.md`).
- **The hero line never warms.** The pulse-line is identity, not signal. Aggregate mood lives only
  in the capped edge halo (max saffron/u2); acute ache lives on the Vital Card. Keep the waveform
  firouzeh in every state.

## Canonical snippet — a shared-controller, a11y-complete painted chart

```dart
/// Sparkline: firouzeh 2dp line + "vs your history" reference band + end dot.
/// Data arrives already downsampled (Isolate.run) and unit-converted.
class Sparkline extends StatelessWidget {
  const Sparkline({required this.series, required this.lo, required this.hi,
    required this.semanticsLabel, super.key});
  final List<double> series;   // display units, canonical->display upstream
  final double lo, hi;         // typical-low/high reference band
  final String semanticsLabel; // "Economy trending 6.9 to 6.4 L per 100km over 12 months"

  @override
  Widget build(BuildContext context) {
    final t = PulseTokens.of(context);
    return Semantics(
      image: true,                              // a chart is an image to a screen reader
      label: semanticsLabel,                    // the ANSWER, in display numerals
      child: ExcludeSemantics(                  // the painter itself says nothing
        child: RepaintBoundary(                 // isolate repaints (perf guide)
          child: CustomPaint(
            size: const Size.fromHeight(56),
            painter: _SparklinePainter(
              series: series, lo: lo, hi: hi,
              line: t.accent,                   // firouzeh — data ramp, NOT a status hue
              band: t.temp[0].withValues(alpha: 0.12), // u0-soft reference band
            ),
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.series, required this.lo, required this.hi,
    required this.line, required this.band});
  final List<double> series;
  final double lo, hi;
  final Color line, band;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;             // empty-state handled by the widget, not here
    // 1. reference band (u0-soft) between typical-low/high — the "vs your history" cue
    // 2. firouzeh polyline: 2dp, StrokeCap.round, StrokeJoin.round
    // 3. end dot r=4.5 filled `line` — the current value, labelled directly by the caller
    // ...geometry omitted; see references/painter-patterns.md...
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      !identical(old.series, series) || old.lo != lo || old.hi != hi ||
      old.line != line || old.band != band;   // never `=> true`
}
```

## Do / Don't

- **Do** implement `shouldRepaint` by comparing every field; **never** `=> true` (repaints every frame).
- **Do** put status in the Vital Card / status pill (icon + label + shape), not on the chart line.
- **Do** paint the empty state as an axis frame + next-action text; **don't** ship a skeleton/spinner.
- **Do** label chart series and slices directly on-canvas or adjacent; **don't** rely on a colour key alone.
- **Do** route large-history bucketing through `Isolate.run` keyed on the rollup revision counter.
- **Don't** import any chart package, mirror the waveform in RTL, warm the hero line, or re-count from 0.
- **Don't** convert units / format dates / shape numerals inside `paint()` — do it upstream and memoize.

## Verify

- `bash scripts/check_no_chart_dep.sh` — fails if any chart package appears in a pubspec or import.
- `bash scripts/check_painter_hygiene.sh` — flags `shouldRepaint(...) => true`, missing
  `RepaintBoundary`/`ExcludeSemantics` near a `CustomPaint`, hard-coded `left`/`right`, and skeleton
  loaders in chart code.
- `bash scripts/analyze.sh` — `flutter analyze` (very_good_analysis: const + perf lints as errors).

## References

- `references/painter-patterns.md` — per-painter recipes: pulse-line, sparkline+band, ranked cost
  bars with hatch, cadence heatmap, tooltip/hit-testing, downsampling, empty/RTL states.
- `references/chart-tokens-and-a11y.md` — the firouzeh ramp, reserved status hues, hatch specs, the
  redundant-encoding table, Semantics recipes, and the CI-gated a11y acceptance checklist.
- `examples/pulse_line_painter.dart` — the full breathing hero painter with shared controller.
- `assets/chart_painter.dart.tmpl` — a starting template for a new a11y-complete painted chart.
