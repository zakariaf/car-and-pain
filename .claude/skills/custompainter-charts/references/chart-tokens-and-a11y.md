# Chart tokens & accessibility contract

Colour comes from PULSE tokens (`PulseTokens`, exposed via `ThemeExtension`, from the
`pulse-design-system` skill). This file records the **chart-specific** rules: which hues may carry
data, the redundant-encoding requirements, and the CI-gated a11y checklist. Never hard-code a hex in
a painter — read it from `PulseTokens.of(context)` and pass it in.

## Data ramp vs reserved status hues

| Role | Token | Hex (day+night, validated on ink) | May carry a data series? |
|------|-------|-----------------------------------|--------------------------|
| Data — firouzeh ramp light | `temp[0]` lighten / `#7FD4C8` | `#7FD4C8` | ✅ yes (lightest series step) |
| Data — firouzeh ramp mid | `accent` | `#2FB8A8` | ✅ yes |
| Data — firouzeh ramp dark | `accentInk` (day) | `#1F8F82` | ✅ yes (largest/darkest) |
| Reference band | `temp[0]` @ ~.12 alpha (`u0-soft`) | `#2FB8A8` @ .12 | band only, not a series |
| **Status — scheduled** | `temp[1]` pistachio | `#7FBF6A` | ❌ RESERVED — urgency only |
| **Status — due soon** | `temp[2]` saffron | `#E9A43B` | ❌ RESERVED — urgency only |
| **Status — pressing** | `temp[3]` ember | `#E8703A` | ❌ RESERVED — urgency only |
| **Status — overdue** | `temp[4]` pomegranate | `#D64533` | ❌ RESERVED — urgency only |

Sequential ramp order for ranked bars: **largest = darkest** (`#1F8F82`), smallest = lightest
(`#7FD4C8`). Night steps are hand-picked on ink (`#141A20`) and pass AA as graphical objects (≥3:1) —
never auto-flip a day hue for night.

## Redundant (non-colour) encoding — mandatory

A chart must be fully readable in **greyscale**. Every categorical mark carries, beyond hue:

| Channel | How, in a painter |
|---------|-------------------|
| **Direct label** | Draw the value/percent on or beside the mark (`Fuel €231 · 55%`). Load-bearing. |
| **Pattern** | Hatch the highlighted/largest mark: `repeating` 45° stripes, `white @ .35`, 3px on / 3px off. Paint as a clipped second `Paint` pass. |
| **Legend** | Any chart with 2+ series carries a legend that **names the cue** ("Hatched = largest slice"). |
| **Position / order** | Ranked bars sort largest→smallest; heatmap reads start→end in time. Order is a signal. |

Rules:
- **Status hues are never a data series** — plot data from the firouzeh ramp only.
- The **cadence heatmap encodes activity, never status** — no saffron/ember in it.
- The **hero pulse-line stays firouzeh in every state** — mood lives in the capped halo (max
  saffron/u2), acute ache on the Vital Card, never on the chart line.

## Hatch snippet (the redundant pattern)

```dart
// Clip to the fill rect, then stripe. white @ .35 over the firouzeh fill = greyscale-distinct.
canvas.save();
canvas.clipRect(fillRect);
final hatch = Paint()..color = const Color(0x59FFFFFF)..strokeWidth = 3; // .35 alpha
for (double x = fillRect.left - fillRect.height; x < fillRect.right; x += 6) {
  canvas.drawLine(Offset(x, fillRect.bottom), Offset(x + fillRect.height, fillRect.top), hatch);
}
canvas.restore();
```

## Semantics recipes

A `CustomPaint` is one opaque rectangle to TalkBack/VoiceOver. Always pair it:

```dart
// Trend / bars / heatmap — a chart is an image; speak the ANSWER, not the shape.
Semantics(
  image: true,
  label: 'Economy trending 6.9 to 6.4 L per 100km over 12 months', // display numerals, correct RTL
  child: ExcludeSemantics(child: RepaintBoundary(child: CustomPaint(painter: ...))),
);

// Hero vital — add liveRegion so the exhale (real change) is announced.
Semantics(
  container: true,
  label: 'Vehicle vitals',
  value: '$readiness percent. Status: ${status.label}. $acuteItem needs care.',
  liveRegion: true,
  child: ExcludeSemantics(child: PulseLineHero(...)),
);
```

- Expose the **final** value immediately; the count-up roll is `ExcludeSemantics` (never read
  digit-by-digit).
- `MergeSemantics` groups a tile's number + label + icon into one readable unit.
- Interactive tooltips must also be reachable by a labelled non-gesture path.

## No-skeleton / motion rules

- **No skeleton loaders / spinners / shimmer** in chart code — offline data is instant; paint it.
  The only non-default state is **empty** (axis frame + next-action text).
- **Count-up on real change only** — `key: ValueKey(value)`, tabular figures, `PulseMotion.countUp`
  (600ms ease-out). Never re-count from 0 on rebuild/visit. Reduced motion → print final string.
- **Breathing** from one shared `AnimationController(PulseMotion.breathe)`; reduced motion → static.

## CI-gated acceptance checklist (from docs/design/pulse/04-motion-rtl-accessibility.md §4)

- [ ] No chart package imported; every chart is a `CustomPainter`.
- [ ] Data uses the firouzeh ramp only; status hues never appear as a series.
- [ ] Every categorical mark has a direct label; highlighted mark hatched; 2+ series → legend naming the cue.
- [ ] **Greyscale golden** of each chart is readable — status/rank recoverable with hue stripped.
- [ ] Contrast: ramp steps and text meet AA in both themes; night steps validated on ink.
- [ ] Every chart/vital carries a complete `Semantics` node; hero uses `liveRegion`; painter `ExcludeSemantics`.
- [ ] No skeleton loader; empty state = axis frame + next-action text.
- [ ] Count-up animates on real change only; reduced-motion prints the final value.
- [ ] Waveform/data orientation not mirrored in RTL; only chrome (legend/tooltip/axis) mirrors.
- [ ] No hard-coded `left`/`right`/`Offset` sign; direction derived from `Directionality.of(context)`.
- [ ] `RepaintBoundary` around every painter; `shouldRepaint` compares fields (never `=> true`).
- [ ] Downsampling runs in `Isolate.run`, keyed on the rollup revision counter.
