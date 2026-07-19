# Painter patterns — per-chart recipes

Every chart is a `CustomPainter`. Data arrives already **downsampled** (via `Isolate.run`, keyed
on the rollup revision counter) and already **converted to display units + formatted numerals /
calendar labels** upstream. A painter only maps numbers to pixels and draws — it never converts,
formats, or loops over raw history. Wrap each in `RepaintBoundary` + `ExcludeSemantics` with a
sibling `Semantics` node. See `chart-tokens-and-a11y.md` for the exact colours and hatch specs.

## The three tiers (progressive disclosure)

| Tier | What | Interaction | Component |
|------|------|-------------|-----------|
| 1 · Hero vital | Breathing pulse-line + one count-up number | none (glance only) | Vitals hero (§1) |
| 2 · Interactive chart | Painted sparkline / bars / heatmap | tap → tooltip with exact figure + "vs your history" | Chart primitives (§9) |
| 3 · Raw table | Opt-in expandable data table | user-triggered disclosure | List rows (§8) |

Never invert this order (table first) and never make tier 1 interactive.

## 1. Pulse-line hero (`PulseLinePainter`)

- Seismograph polyline, `stroke 2.4dp`, `--accent #2FB8A8` (firouzeh), `StrokeCap.round`,
  `StrokeJoin.round`, plus a soft glow pass (`MaskFilter.blur`, accent @ .4 alpha) drawn first.
- **Breathing:** amplitude scaled ±6% by `1 + 0.06 * sin(phase*2π) * (0.6 + urgency*0.1)`. The
  **baseline never moves** (keeps the hero numeral stable). Amplitude widens slightly with aggregate
  urgency — a redundant, non-colour urgency cue — but the **line colour stays firouzeh in every
  state** (the hero line is identity, never signal).
- **Sweep dot** travels L→R over 4s (`PulseMotion.breathe`). Direction-agnostic — does **not**
  mirror in RTL.
- Drive `phase` from **one app-wide** `AnimationController(duration: PulseMotion.breathe)` shared by
  every hero, via `AnimatedBuilder` — never a ticker per point. Reduced motion → fixed `phase=0.5`,
  no sweep, controller not started.
- Full working version: `examples/pulse_line_painter.dart`.

```dart
@override
bool shouldRepaint(PulseLinePainter old) =>
    old.phase != phase || old.urgency != urgency || old.color != color;
```

## 2. Sparkline / economy trend (`SparklinePainter`)

Draw order matters (band under line under dot):

1. **Reference band** — `u0-soft` rect between typical-low/high with dashed top/bottom edges. This
   is the "vs your history" cue; it makes a single trend readable without a second series.
2. **Polyline** — firouzeh `2dp`, round joins.
3. **End dot** — `r=4.5`, filled accent = the current value. Label it directly (`6.4`, accent) and
   label the axis endpoints as plain text next to the canvas.
4. Optional **moving-average overlay** — a second, lighter step of the firouzeh ramp (`#7FD4C8`),
   never a status hue. If drawn, add a legend.

Semantics: `Semantics(image: true, label: 'Economy trending 6.9 to 6.4 L per 100km over 12 months')`.

## 3. Ranked cost breakdown — PRIMARY form (`CostBar`)

Spend-by-category is **ranked horizontal bars**, not a pie. A donut is an *optional secondary* only.

- Track: `12dp` tall, `radius 6dp`, `surface-2`, hairline border.
- Fill: **sequential firouzeh ramp**, largest category darkest (`#1F8F82`) → smallest lightest.
- **Direct label** on every bar: `Fuel €231 · 55%` (money via ISO-4217 minor units, formatted
  upstream). The label is load-bearing; colour is decoration.
- **Hatch** the highlighted/largest bar: `repeating-linear-gradient(45°, white@.35 3px, transparent
  3px)` — the redundant non-colour cue. Paint it as a second `Paint` pass clipped to the fill rect.
- Legend row states the cue: "Hatched = largest slice".
- RTL: bars grow from the **end** edge; labels lead from `end`. Derive the grow direction from
  `Directionality.of(context)` — never a hard-coded sign.

## 4. Cost / distance-over-time (bars + cumulative line)

- Per-period bars (firouzeh ramp) for the primary series; optional cumulative odometer line overlaid
  as a lighter ramp step with its own legend entry.
- X buckets are **calendar-aware** (Gregorian/Jalali/Hijri/Hebrew) and computed upstream; the painter
  receives labelled buckets. The **time axis direction flips in RTL** (chrome), the **bar heights do
  not** (data orientation is preserved — a rising trend stays rising).

## 5. Cadence heatmap

- Sequential firouzeh ramp over a month grid; month names and first-day-of-week come from the active
  calendar (`MaterialLocalizations.firstDayOfWeekIndex` upstream — never hard-coded).
- Encodes **activity only, never status** — do not reach for saffron/ember here.
- Each cell exposes an exact count as text (tooltip on tap) for redundancy.

## 6. Interactivity & hit-testing (tier 2)

- Implement `hitTest(Offset)` or wrap the `CustomPaint` in a `GestureDetector` and hit-test against
  the cached bar/point rects computed in `paint()` (store them in a field the gesture handler reads).
- On tap: show a tooltip with the **exact figure** + a **"vs your history"** line ("6.4 — your best
  this year"). Mirror tooltip placement in RTL.
- Provide a labelled non-gesture path too (a detail row / expand) — no figure is reachable by gesture
  alone (motor-accessibility rule).

## 7. Downsampling (off-thread, revision-keyed)

```dart
// In the Notifier/repository, NOT in paint():
final points = await Isolate.run(() => downsampleBuckets(rawRows, bucket)); // plain in, plain out
```

Bucket into `aggregationBucket` (day/week/month/quarter/year) above `downsampleThreshold`. Recompute
only when the ledger's rollup revision counter changes; the painter gets the finished list.

## 8. States (no skeleton, ever)

| State | Painter behaviour |
|-------|-------------------|
| default | instant paint of real data — no loading placeholder |
| active | tap a bar/point → tooltip with exact figure + "vs your history" |
| empty | draw the **axis frame** + next-action text ("Log 2 fills to see your trend") |
| loading | **none** — local data is instant; a spinner/shimmer is a bug here |
| disabled | n/a for charts |

Guard the empty case in the **widget** (branch before `CustomPaint`), so `paint()` can assume
`series.length >= 2`.

## 9. RTL cheat-sheet

| Element | Flips? |
|---------|--------|
| Pulse-line waveform, sweep dot, checkmarks | ❌ never (direction-agnostic) |
| Plotted data orientation (bar heights, line slope) | ❌ never (a rising line stays rising) |
| Legend, tooltip, axis placement, time-axis direction | ✅ chrome mirrors |
| Bar grow direction, label lead edge | ✅ from `Directionality.of(context)` |

Never write `Offset(-x, y)`, `.left`, `.right`, `Alignment.centerRight`, or a hard-coded sign — use
`Directionality.of(context)` and `*Directional` geometry. A raw sign is an RTL-golden failure.

## 10. Performance hooks (see docs/flutter/10-performance-rendering.md)

- `RepaintBoundary` around every painter — but never blanket-wrap; each costs GPU memory.
- One shared `AnimationController` for breathing app-wide; `AnimatedBuilder` with the static chart
  passed through the `child:` slot so it is built once and reused across ticks.
- Memoize formatted axis labels keyed by (epochMillis, locale, calendar) — RTL/calendar/numeral
  formatting is per-frame expensive.
- `shouldRepaint` compares fields; `identical(...)` for the series list is cheap and correct when the
  Notifier hands out a new list only on real change.
