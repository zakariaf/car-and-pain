# 🧩 Component Library

> **PULSE — "a vitals chart for your car."** Implementation-ready spec for every core
> component. Each entry gives **purpose · anatomy · variants · states · RTL · accessibility ·
> Flutter mapping** with concrete values (hex / dp / ms / cubic-bezier) and short Dart sketches.
>
> Related: [`./01-foundations.md`](./01-tokens.md) (tokens, colour, type) ·
> [`./03-motion-haptics.md`](./04-motion-rtl-accessibility.md) (the exhale, breathing, count-up) ·
> [`./prototype.html`](./prototype.html) (living reference) ·
> Engineering: [i18n / RTL / calendars](../../flutter/06-i18n-rtl-calendars.md) ·
> [performance & rendering](../../flutter/10-performance-rendering.md) ·
> [accessibility & dynamic type](../../flutter/15-accessibility-dynamic-type.md) ·
> Product: [overview](../../overview.md).

---

## 0. Principles every component obeys

1. **Status is never colour-only.** PULSE encodes urgency in *emotional temperature*
   (warm = ache). That colour is **decoration**. Every status is *also* carried by an
   **icon + text label + shape/position** (a hatched/dashed left stripe, a pill with a glyph,
   a section it lives under). This is the CRITICAL ACCESSIBILITY RULE and it is
   non-negotiable — see [§14 Accessibility contract](#14-accessibility-contract-redundant-encoding).
2. **Warmth is scoped and capped.** The *aggregate* ambient halo maxes at **stop-2 saffron**
   and never fills the whole field with ember/pomegranate. The *acute* ache concentrates on
   the one card that needs care (may reach stop-4).
3. **Every relieving action pays off with "the exhale":** soft settle + one-notch cooling +
   weighted haptic. See [§3](#3-the-exhale-completion-interaction).
4. **RTL is first-class by construction.** The symmetric pulse-line, halo, checkmarks and
   logo do **not** mirror; only directional glyphs and layout flip. Numerals are locale-driven.
5. **Text & controls always meet WCAG AA** in both themes; tints never degrade contrast.
6. **No skeleton loaders** — offline-first, instant paint is the flex.

### 0.1 The urgency scale (shared vocabulary)

| `u` | Name | Hex (day+night) | Meaning | Redundant shape | Text label |
|----|------|-----------------|---------|-----------------|------------|
| 0 | firouzeh | `#2FB8A8` | Calm / healthy | solid stripe | "OK" / "Healthy" |
| 1 | pistachio | `#7FBF6A` | Scheduled | solid stripe | "Scheduled" |
| 2 | saffron | `#E9A43B` | Due soon (**halo cap**) | dashed stripe (5/8) | "Soon" / "Due soon" |
| 3 | ember | `#E8703A` | Pressing | dashed stripe (4/7) | "Pressing" |
| 4 | pomegranate | `#D64533` | Overdue / aching | dashed stripe (3/5) | "Overdue" |

```dart
// lib/design/pulse_temperature.dart
enum Urgency { calm, scheduled, soon, pressing, overdue } // u0..u4

extension UrgencyToken on Urgency {
  int get u => index;
  Color get color => const [
    Color(0xFF2FB8A8), Color(0xFF7FBF6A), Color(0xFFE9A43B),
    Color(0xFFE8703A), Color(0xFFD64533),
  ][index];
  /// Redundant, colour-blind-safe shape: solid for calm states, tighter dashes as it warms.
  StripeStyle get stripe => index <= 1
      ? const StripeStyle.solid()
      : StripeStyle.dashed(dash: [8, 6, 5][index - 2], gap: [3, 3, 2][index - 2]);
  /// Halo NEVER exceeds saffron (u2) — the capped-aggregate guardrail.
  Urgency get haloClamped => index > 2 ? Urgency.soon : this;
}
```

The **acute** temperature = the single worst open item on the vehicle. The **halo** =
`worst.haloClamped`.

---

## 1. Breathing Vitals Pulse-line hero

**Purpose.** The daily "is my car OK?" answer in one glance: a clinical ECG-like
seismograph with one number = the car's current readiness. Deliberately **not a ring** — this
is the anti-Oura/Whoop signature.

### Anatomy

```
┌─────────────────────────────────────┐
│  READINESS · BLAU        ‹eyebrow›   │
│  ╭╮   ╭╮      ╭╮                      │  ← pulse-line (CustomPainter, breathing, sweep dot)
│ ─╯╰──╯ ╰─────╯ ╰──────────           │
│           92 / 100       ‹hero-num›  │  ← 84/88 tabular, count-up on real change
│  Healthy — one thing wants attention │  ← hero-label (word + plain sentence)
│  ┌──────┬──────┬──────┐              │
│  │84,320│ 6.4  │€0.31 │  ‹vrow›      │  ← 3 secondary vitals, tabular
│  │  km  │L/100 │per km│              │
│  └──────┴──────┴──────┘              │
│         ▁▁▁  Pull up · 3 in Pit-lane │  ← pull hint (list is one swipe away)
└─────────────────────────────────────┘
```

- **Pulse-line:** `stroke 2.4dp`, `--accent #2FB8A8`, round caps/joins, soft glow
  `blur 6 rgba(47,184,168,.4)`. Height `120dp` (`80dp` compact / first-run).
- **Breathing:** `scaleY 0.94 → 1.06`, `4s ease-in-out infinite`, origin center.
- **Sweep dot:** travels L→R `4s linear` (a monitor's cursor). *Direction-agnostic* — does
  **not** mirror in RTL.
- **Hero number:** `84/88`, weight 600, tabular, `letter-spacing -.04em`; reflows to `60/64`
  on German / long-Arabic expansion. **Count-up 600 ms ease-out on real change only** — never
  re-counts from 0 on every visit.

### Variants
- **Full** (Cockpit home, 120dp) · **Compact** (first-run / empty, 80dp, static line) ·
  **Inline mini** (sparkline in cards — see [§9](#9-chart-primitives-custompainter)).

### States

| State | Line | Number | Label | Halo |
|-------|------|--------|-------|------|
| default (calm) | firouzeh, breathing | steady, tabular | "Healthy — all clear" | u0 |
| active (count-up) | breathing | rolling to new value | live sentence | unchanged |
| ache (something due) | firouzeh (line stays cool) | e.g. `92` | "…one thing wants attention" | ≤ u2 (capped) |
| overdue | firouzeh (line **still cool**) | lower value | "…overdue" + count-down of days | u2 (halo capped; the *card* goes u4) |
| done (post-exhale) | breathing | count-up ↑ | "all clear, nothing aching" | eases one stop |
| disabled | n/a | n/a | n/a | n/a (hero is never disabled) |
| empty / first-run | static flat-ish line | "—" / no score | "Let's take your first reading" | u0 |

> Note the hero **line never warms** — the pulse-line is identity, not signal. Aggregate mood
> lives only in the capped edge halo; acute warmth lives on the card. This is the "permanent
> pain" guardrail.

### RTL behaviour
The waveform, sweep dot and number are **symmetric / non-mirrored**. Only the eyebrow, label
sentence and vrow reflow to RTL. Number renders with locale digits (`۹۲` / `٩٢`) via `intl`.

### Accessibility
- Reduced-motion: `MediaQuery.disableAnimations` (or `prefers-reduced-motion`) → **static line,
  no sweep, no count-up** (number set instantly). Haptics remain the accessible feedback channel.
- The pulse-line is decorative → `ExcludeSemantics`. The number+label form the semantic node:
  `Semantics(label: 'Readiness 92 of 100, Healthy, one item due soon', liveRegion: true)`.
- Contrast: firouzeh on paper `#F4EFE7` and on ink `#0E1317` both pass AA for the 2.4dp stroke
  as a graphical object (≥3:1); the *number* uses `--text`, not accent.

### Flutter mapping

```dart
class VitalsHero extends StatelessWidget {
  final int score;           // 0..100
  final String readiness;    // "Healthy"
  final String subline;
  final Urgency acute;       // worst open item (for context only; line stays cool)
  @override
  Widget build(BuildContext context) => Column(children: [
    const _Eyebrow('READINESS · BLAU'),
    SizedBox(height: 120, child: RepaintBoundary(       // isolate the animating layer
      child: ExcludeSemantics(child: PulseLine(breathing: !reduceMotion(context))),
    )),
    Semantics(liveRegion: true,
      label: '$readiness. $score of 100. $subline',
      child: CountUpText(value: score, style: t.heroNumeral, unit: ' / 100'),
    ),
    Text(subline, style: t.heroLabel),
    const VitalsRow(),        // 3-cell tabular strip
    const PullHint(),         // "Pull up · N in Pit-lane"
  ]);
}
```

`PulseLine` is a `CustomPainter`; see [§9.1](#91-pulse-line-painter). Wrap the animating
subtree in a `RepaintBoundary` per
[performance guide](../../flutter/10-performance-rendering.md).

---

## 2. Vital Card (scoped temperature + capped halo)

**Purpose.** The one aching card surfaced on home, and the atoms of the Pit-lane list. Carries
**concentrated warmth** (the ache visibly sitting here) without ever bleeding into the whole
screen.

### Anatomy

```
│▓ ┌───────────────────────────────────┐   ▓ = left ustripe (4dp), encodes u in SHAPE
│▓ │ THE ONE ACHE            [⚠ Soon]  │   [pill] = icon+label status (redundant)
│▓ │ 🛢  Oil & filter                   │   corner radial tint (u-soft), never on text
│▓ │     Due in 850 km or 40 days      │
│▓ │  [Mark done — exhale] [Snooze]    │
│▓ └───────────────────────────────────┘
```

- Card: `--surface #FFFFFF` (day) / `#141A20` (night), `border 1dp --hairline`,
  `radius 20dp`, `shadow 0 6 24 rgba(20,30,40,.07)` (day) / hairline-only (night).
- **`ustripe`** (left, `4dp`, inset 14dp top/bottom): the redundant urgency shape —
  solid (u0/1), then repeating dashes tightening 5/8 → 4/7 → 3/5 as it warms.
- **Corner tint** (`::before` radial from top-corner): `u-soft` alpha
  `.12 → .16` (day) / `.16 → .22` (night). Purely ambient, sits **under** content
  (`ache-inner` is `z-index:2`), never behind text runs that need contrast.

### Variants
- **Hero ache** (home, with action buttons) · **List ache** (Pit-lane row, pill only) ·
  **Calm card** (no stripe/tint — plain surface for healthy/scheduled items).

### States

| State | ustripe | corner tint | border | pill | actions |
|-------|---------|-------------|--------|------|---------|
| default (calm u0) | solid firouzeh | `.12` firouzeh | hairline | `OK` ✓ | — |
| active (pressed) | — | — | `--accent` | — | `scale .98`, `--u0-soft` bg |
| ache (soon u2) | dashed 5/8 saffron | `.14` saffron | `rgba(233,164,59,.5)` | `Soon` ⚠ | Mark done · Snooze |
| overdue (u4) | dashed 3/5 pomegranate | `.16` pomegranate | `rgba(214,69,51,.6)` | `Overdue` | Mark done · Snooze · Skip |
| done | animates u→u0 over 700ms | fades to firouzeh | firouzeh | `Done` ✓ | disabled/collapsed |
| disabled | 40% opacity, no tint | none | hairline | greyed | non-interactive |
| empty | — | — | dashed hairline | — | "Nothing aching" [§13] |

**Cooling animation (done):** `border-color` + tint cross-fade,
`700ms cubic-bezier(.2,.7,.2,1)`, `data-u` steps 4→…→0.

### RTL behaviour
The **ustripe moves to the right edge** (`right:0; border-radius:4 0 0 4`) and the corner tint
mirrors to the top-**left** corner. Row content flips (icon trails). Handled automatically by
`Directionality`/`EdgeInsetsDirectional` — see [§14](#14-accessibility-contract-redundant-encoding).

### Accessibility
Three redundant channels beyond colour: **(1)** the stripe's dash *pattern* (shape), **(2)** the
pill's *icon + text*, **(3)** *position* (aching items sort to the top, under an "Aching now"
header). Colour-blind users get full information with zero hue perception.

### Flutter mapping

```dart
class VitalCard extends StatelessWidget {
  final Urgency u; final IconData icon; final String title, detail;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final t = PulseTokens.of(context);
    return Semantics(
      container: true,
      label: '$title, ${u.label}. $detail',      // status spoken, not shown by colour
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        curve: PulseCurves.exhale,               // cubic-bezier(.2,.7,.2,1)
        decoration: BoxDecoration(
          color: t.surface, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: u.borderTint(t)),
          boxShadow: t.cardShadow,
        ),
        child: Stack(children: [
          Positioned.directional(textDirection: Directionality.of(context),
            start: 0, top: 14, bottom: 14,
            child: UStripe(u: u, width: 4)),       // dashed CustomPaint = redundant shape
          Positioned.fill(child: IgnorePointer(child: CornerTint(u: u))),
          Padding(padding: const EdgeInsetsDirectional.fromSTEB(18,16,18,16),
            child: _CardBody(icon, title, detail, actions, pill: StatusPill.forUrgency(u))),
        ]),
      ),
    );
  }
}
```

---

## 3. "The Exhale" completion interaction

**Purpose.** The emotional payoff — pain → relief — fired on **every** pain-relieving action
(log a fill, mark reminder done, clear/close). This is the concept's core micro-interaction.

### Anatomy of the sequence (fired together)
1. **Scoped cooling.** The resolved card animates `data-u` down to `u0`
   (`700ms cubic-bezier(.2,.7,.2,1)`): border, corner tint and stripe all cross-fade to firouzeh;
   stripe reverts to *solid*.
2. **Capped halo eases** at most **one stop** (e.g. `u2 → u1`), `800ms` same curve.
3. **Soft settle.** The card does a `translateY 0 → 3dp → 0`, `520ms` exhale curve (a body
   letting go of a held breath).
4. **Count-up.** Readiness number rolls **up** to the new score, `600ms ease-out`, tabular.
5. **Weighted haptic.** A single medium impact — the accessible feedback channel, **identical
   byte-for-byte LTR/RTL**, preserved under reduced-motion.
6. **Copy + pill swap.** Pill → `Done ✓ (pill--ok)`; detail → "Recovered · next in 15,000 km";
   hero label → "Healthy — all clear, nothing aching".

### States it moves between
`ache/overdue → (exhale) → done`. If reduced-motion: skip 1's animation curve timing but still
cross-fade instantly, **skip settle & count-up** (set values), **keep the haptic**.

### RTL behaviour
Visually identical mechanics; the settle is vertical (direction-agnostic). Haptic pattern is
identical. Copy is authored per language ("Exhaled ✓" / "بازدم ✓").

### Accessibility
- Haptic is the primary non-visual confirmation. Also fire a
  `SemanticsService.announce('Oil & filter marked done. Readiness now 97.', dir)`.
- Never rely on the green flash alone; the pill text/icon change is the durable signal.

### Flutter mapping

```dart
Future<void> exhale(BuildContext context, ReminderController c, String id) async {
  await HapticFeedback.mediumImpact();                 // native-only; the accessible channel
  c.markDone(id);                                       // DB write → ValueNotifier emits
  // AnimatedContainer in VitalCard cools 4→0; halo notifier eases one stop:
  context.read<HaloNotifier>().easeOneStop();
  // Hero CountUpText rebinds to new score → rolls up 600ms (unless reduceMotion).
  SemanticsService.announce(
    '${c.titleOf(id)} marked done. Readiness now ${c.score}.',
    Directionality.of(context));
}
```

```dart
// The reusable settle wrapper (points 3):
class ExhaleSettle extends StatefulWidget { /* runs a 0→3→0 dp TranslateY, 520ms exhale */ }
final exhaleCurve = const Cubic(0.2, 0.7, 0.2, 1.0); // PulseCurves.exhale
```

See [`./03-motion-haptics.md`](./04-motion-rtl-accessibility.md) for full timing tables and the
reduced-motion matrix.

---

## 4. Rooms navigation bar

**Purpose.** Three named *emotional spaces*, not a generic tab bar: **Cockpit** ("Now"),
**Garage** ("Care & history"), **Pit-lane** ("What's due"). Each carries a plain-language
secondary label for first-run legibility.

### Anatomy

```
┌───────────────┬───────────────┬───────────────┐
│    〰 icon     │    🏠 icon     │    ⏱ icon     │  22dp glyph
│    Cockpit    │    Garage     │   Pit-lane    │  r-name 11dp/600
│      Now      │ Care & history│   What's due  │  r-sub 9.5dp/500 (.7 opacity)
└───────────────┴───────────────┴───────────────┘
   ↑ selected = --accent-ink + icon drop-shadow glow
```

- Container: `linear-gradient(top, surface → surface@82%)`, `border-top 1dp hairline`,
  `backdrop blur 8`, `padding 10dp + safe-area-inset-bottom`.
- Each item: `min-height 48dp` (tap-target token), column layout, `radius 14dp`.
- **Persistent quick-add** floats above center at `bottom: 74dp + safe-area`
  (see [§5](#5-quick-log-keypad)).

### Variants
LTR order Cockpit·Garage·Pit-lane; RTL order **reverses** (Cockpit on the right). Icons hold.

### States

| State | Colour | Icon | Extra |
|-------|--------|------|-------|
| default | `--text-3 #8A949B` | outline | — |
| active (`aria-current`) | `--accent-ink #1F8F82` (day) / `#3ED6C4` (night) | filled tint + `drop-shadow(0 2 6 rgba(47,184,168,.35))` | position/label unchanged |
| pressed | ripple within 14dp radius | — | — |
| disabled | n/a — all rooms always reachable | | |
| ache indicator | Pit-lane gains a **dot badge** + count when items ache | badge | count is text, not colour-only |

### RTL behaviour
`Row` under `Directionality.rtl` reverses automatically. The selection glow and icons are
symmetric. Persian labels: کابین / گاراژ / پیت‌لِین with subs اکنون / نگهداری / سررسیدها.

### Accessibility
- Use `NavigationBar` semantics: each destination `Semantics(button:true, selected:isCurrent,
  label:'Pit-lane, What's due, 3 items due')`. Selection is announced ("selected"), not
  colour-only.
- `min-height 48dp` meets the touch-target minimum; badge count is spoken.

### Flutter mapping

```dart
NavigationBar(
  selectedIndex: room.index,
  onDestinationSelected: (i) => room.go(Room.values[i]),
  destinations: const [
    NavigationDestination(icon: PulseIcon.cockpit, label: 'Cockpit',  // + tooltip 'Now'
      selectedIcon: PulseIcon.cockpitFilled),
    NavigationDestination(icon: PulseIcon.garage,  label: 'Garage'),
    NavigationDestination(icon: PulseIcon.pitlane, label: 'Pit-lane',
      icon: Badge(isLabelVisible: dueCount>0, label: Text('$dueCount'), child: PulseIcon.pitlane)),
  ],
);
// Quick-add is a separate FloatingActionButton(location: centerDocked) so it is reachable
// from EVERY room (findability fix), not a nav destination.
```

---

## 5. Quick-log keypad ("enter any two" + last-3 odometer)

**Purpose.** 1–2-tap fuel/charge capture, reachable from every room. Default is a **numeric
keypad**, not a form. The diegetic nozzle/dipstick is demoted to an optional flourish and never
blocks entry.

### Anatomy (bottom sheet)

```
        ▁▁▁                         grab handle
   Log a fill                 ✕     sheet-head
        42.3 L                      entry-big (52dp tabular)
   Enter any two — Pulse computes the rest
  ┌ Volume ┐┌ Total € ┐            enter-two cards (active = accent border + u0-soft)
  │ 42.3 L ││  75.72  │
  └────────┘└─────────┘
   Odometer …320  [tap to fill last 3]   odo-shortcut
  ┌───┬───┬───┐
  │ 1 │ 2 │ 3 │   keys min 56dp (target 56×64)
  │ 4 │ 5 │ 6 │
  │ 7 │ 8 │ 9 │
  │ . │ 0 │ ⌫ │   fn keys tinted
  │  Save · Shell A2 Nord   │   save spans 3, accent gradient
  └─────────────────────────┘
```

- Sheet: `radius 26dp` top, `translateY 102% → 0` in `380ms cubic-bezier(.2,.7,.2,1)`.
- **Enter-any-two:** user fills any two of {volume, price/L, total, odometer}; PULSE computes
  the rest. Active field = `--accent` border + `--u0-soft` fill.
- **Odometer shortcut:** tapping `…320` fills the last 3 digits onto the remembered prefix
  (`84,320`) → most fills are literally last-3 + volume.
- Keys: `min 56dp`, `radius 16dp`, `24dp` tabular digit. Save key = accent gradient
  `160deg #3ED6C4→#1F8F82`, ink text `#04241f`, spans all 3 columns.
- **Decimal vs grouping (critical):** in Persian/Arabic the keypad's decimal is `٫`
  (U+066B) and grouping is `٬` (U+066C) — `1٫5 = 1.5`. Never confuse them; parse via `intl`
  `NumberFormat`. See [i18n guide](../../flutter/06-i18n-rtl-calendars.md).

### Variants
- **Fuel** (litres · L/100km) · **Charge** (kWh · Wh/km) — segmented toggle in the header.
- **Full-screen entry** (screen 03) vs **bottom-sheet** (from home) — same keypad widget.

### States

| State | Entry display | Keys | Save |
|-------|---------------|------|------|
| default (empty) | `0` dim | enabled | disabled until 1 value |
| active (typing) | live tabular value | pressed `scale .97` | enabled once 2 derivable |
| valid | shows computed economy preview ("6.4 L/100km") | — | accent, enabled |
| error (bad parse) | value in `--crit`, helper text + ⚠ icon | — | disabled |
| done (saved) | sheet dismiss → **exhale** on the vehicle | — | — |
| disabled | — | greyed 40% | greyed |
| empty (no prior fill) | no odo shortcut, no "remembered station" | — | "Save fill" |

### RTL behaviour
Keypad **digit order stays 1-2-3 / 4-5-6 …** (numeric keypads are not mirrored), but the sheet
chrome, labels and enter-two cards flip. Digits render as locale numerals. `⌫` backspace glyph
mirrors direction.

### Accessibility
- Keys are `Semantics(button:true, label:'7')`; the save button announces the computed result.
- Entry has a live region; parse errors are announced with text, not colour.
- `56×64` target exceeds the 44dp minimum for motor accessibility.

### Flutter mapping

```dart
showModalBottomSheet(
  context: context, isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
  builder: (_) => QuickLogSheet(vehicle: current),
);

class QuickLogSheet extends StatefulWidget { /* ValueNotifier<FillDraft> */ }
// Keypad tap → draft.push(digit) → draft.deriveMissing() (any-two solver) → live preview.
// Save → repo.insertFill(draft) → DB stream emits → home hero recomputes → exhale().
```

---

## 6. Reminder item (whichever-first: time + distance)

**Purpose.** A maintenance item that fires on **whichever trigger arrives first** — time *or*
distance — surfaced by a calm-engineer triage list.

### Anatomy (row inside a Vital Card)

```
│▓ 🛢  Oil & filter                    [⚠ Soon]
│▓     In 850 km or 40 days · whichever first
```

- Icon (part glyph) · title · **dual-trigger subline** ("In `850 km` or `40 days`") ·
  status pill. The winning trigger is computed and phrased ("distance wins first").
- In the **add/edit** view: two trigger cards (distance switch + time switch) and a synthesis
  card — "Pulse will ache in 850 km — distance wins first" — plus a lead-time segmented control
  (`3 days / 1 week / 1,000 km / 2 weeks`).

### Variants
- **List item** (Pit-lane, grouped by section) · **Add/edit** (dual trigger + synthesis) ·
  **Home hero ache** (the single surfaced one, with actions).

### States

| State | Section | ustripe | pill | Card |
|-------|---------|---------|------|------|
| default (scheduled u1) | "Healthy · scheduled" | solid pistachio | `OK`/`Scheduled` ✓ | calm |
| active (open sheet) | — | — | — | pressed |
| ache (soon u2) | "Wanting attention" | dashed 5/8 saffron | `Soon` ⚠ | warm |
| overdue (u4) | "Aching now" | dashed 3/5 pomegranate | `Overdue` | hot |
| done | leaves list with exhale → moves to Recovery timeline | cools | `Done` ✓ | — |
| snoozed | back to scheduled with new date | solid | `Snoozed` 💤 | calm |
| disabled (trigger off) | hidden from list | — | — | — |
| empty | "Nothing due — your car is calm" | — | — | [§13] |

**Triage motion:** swipe → done / snooze / skip with a satisfying card motion (done = exhale;
snooze = slide right + settle; skip = fade).

### RTL behaviour
Row flips (icon trails, pill leads); ustripe to right edge. Dates render Jalali-primary in RTL
("`تا ۸۵۰ کیلومتر یا ۴۰ روز`"). Distance/time numerals localized.

### Accessibility
- The winning trigger is stated in **text**, never implied by colour.
- Swipe actions have equivalent buttons (done/snooze/skip) for switch-control users; each
  `Semantics(button:true, label:'Mark oil & filter done')`.
- Section header ("Aching now") gives position-based redundancy for the pill colour.

### Flutter mapping

```dart
class ReminderTile extends StatelessWidget {
  final Reminder r;
  @override
  Widget build(BuildContext context) {
    final soonest = r.nextTrigger();               // min(byDistance, byTime)
    return Dismissible(
      key: ValueKey(r.id),
      background: const _SwipeAction(icon: Icons.check, label: 'Done'),      // → exhale()
      secondaryBackground: const _SwipeAction(icon: Icons.snooze, label: 'Snooze'),
      child: VitalCard(u: r.urgency, icon: r.partIcon, title: r.title,
        detail: soonest.phrase(context),           // "In 850 km or 40 days · whichever first"
        actions: r.isAche ? [DoneButton(r), SnoozeButton(r)] : const []),
    );
  }
}
```

---

## 7. Status chip / pill

**Purpose.** The compact, redundant status token — the workhorse that makes colour *optional*.
Always **icon + text**, never a bare colour dot for status.

### Anatomy
`pill`: `radius 999`, `padding 4/10/4/8`, `font 11.5dp/600`, `1dp` border, tinted bg, leading
icon `~11dp`.

### Variants & states (variant *is* the state)

| Variant | Fg (day) | Fg (night) | Border | Bg | Icon | Text |
|---------|----------|------------|--------|----|----|------|
| `--ok` | `#1F8F82` | `#3ED6C4` | `rgba(47,184,168,.35)` | `u0-soft` | ✓ check | "OK" / "Done" / "Recovered" |
| `--warn` | `#9a6b12` | `#f0bd6a` | `rgba(233,164,59,.45)` | `u2-soft` | ⚠ triangle | "Soon" / "Due soon" |
| `--crit` | `#a5352a` | `#f08a7c` | `rgba(214,69,51,.5)` | `u4-soft` | ! or clock | "Overdue" |
| neutral | `--text-2` | `--text-2` | hairline | `surface-2` | — | "Auto" / "Scheduled" |
| disabled | `--text-3` @60% | — | hairline | surface | — | greyed |

> **Contrast note:** the night foregrounds (`#3ED6C4`, `#f0bd6a`, `#f08a7c`) are *hand-selected
> on the ink surface*, not auto-flipped — each passes AA against `#141A20`.

### RTL behaviour
Icon leads in reading direction (flips to the right in RTL). Text localized.

### Accessibility
The **icon shape differs per status** (check / triangle / clock-bang), so the pill is
distinguishable in greyscale. Never ship a status pill as colour-only. `Semantics(label:'Due
soon')`.

### Flutter mapping

```dart
class StatusPill extends StatelessWidget {
  final PillKind kind;      // ok | warn | crit | neutral
  factory StatusPill.forUrgency(Urgency u) => StatusPill(kind: u.pillKind);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(8,4,10,4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: kind.bg(context), border: Border.all(color: kind.border(context))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(kind.icon, size: 12, color: kind.fg(context)),   // shape = redundant channel
      const SizedBox(width: 6),
      Text(kind.label(context), style: t.label.copyWith(color: kind.fg(context), fontWeight: FontWeight.w600)),
    ]),
  );
}
```

---

## 8. List row

**Purpose.** The generic dense-but-touchable row for history, expenses, trips, documents —
"vs your own history" framing turns rows into stories.

### Anatomy

```
[icon 38dp] Title                     value (tabular)
            Subtitle · meta · date
```

- `ricon`: `38dp` square, `radius 12dp`, `surface-2` bg, hairline border, `--text-2` glyph.
- `rmain`: title `14dp/600`, subtitle `12dp --text-2`.
- `rv` (trailing value): tabular, right-aligned (leading-aligned mirror in RTL).

### Variants
- **In-card** (single, padded) · **grouped list** (`gap 10dp`, each its own card) ·
  **timeline row** (Recovery log — dot on a rail, `recover` variant uses pistachio dot).

### States

| State | Row | Value | Notes |
|-------|-----|-------|-------|
| default | surface | tabular | — |
| active (tap) | `surface-2`, `scale .99` | — | opens detail |
| ache | wrapped in Vital Card (u≥2) | — | see [§2] |
| overdue | Vital Card u4 | count-down | — |
| done / recovered | timeline `recover` dot (pistachio) + `Recovered` pill | — | past tense copy |
| disabled | 40% opacity | — | non-tappable |
| empty | single "No entries yet" row | — | [§13] |

### RTL behaviour
Icon and value swap sides; `Row` reverses under `Directionality`. Dates/amounts localized
(currency via `intl` — see [money & currency](../../flutter/14-money-currency-fx.md)).

### Accessibility
`Semantics(button: onTap != null, label: '$title, $subtitle, $value')`. Trailing value is part
of the label so screen readers don't lose it. Row height ≥ 48dp effective tap target.

### Flutter mapping

```dart
class PulseRow extends StatelessWidget {
  final IconData icon; final String title, subtitle, value; final VoidCallback? onTap;
  @override
  Widget build(BuildContext c) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(children: [
        _RIcon(icon),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: t.rowTitle), Text(subtitle, style: t.rowSub)])),
        Text(value, style: t.tabular),          // fontFeatures: [FontFeature.tabularFigures()]
      ])));
}
```

---

## 9. Chart primitives (CustomPainter — **no chart library**)

All charts are hand-painted. **Status hues (saffron/ember/pomegranate) are reserved and never a
data series**; data uses the sequential **firouzeh ramp**. Every categorical encoding carries a
**redundant pattern + direct label**. Legend required for ≥2 series. **No skeleton loaders.**

Firouzeh sequential ramp (light→dark): `#7FD4C8 · #2FB8A8 · #1F8F82`. Reference band =
`--u0-soft`. Dark steps are validated on ink, not auto-flipped.

### 9.1 Pulse-line painter

```dart
class PulseLinePainter extends CustomPainter {
  final List<Offset> pts; final double breath;   // 0.94..1.06 from an AnimationController
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) { path.lineTo(p.dx, p.dy * breath); }
    final glow = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4
      ..color = accent.withOpacity(.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = accent;
    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
  }
  @override bool shouldRepaint(o) => o.breath != breath || o.pts != pts;
}
// Reduced motion: pass a fixed breath = 1.0 and no sweep dot.
```
The waveform is **not mirrored** in RTL. Wrap in `RepaintBoundary`; drive `breath` from a single
`AnimationController(4s)` shared app-wide to avoid N tickers
([perf](../../flutter/10-performance-rendering.md)).

### 9.2 Sparkline / economy trend

- `2dp` firouzeh line, **`4.5dp` rounded data-end dot**, plus a **"vs your history" reference
  band** (`u0-soft` rect between typical-low/high with dashed edges).
- End value labelled directly (`6.4`, accent); axis endpoints labelled as text.
- `Semantics(image, label:'Economy trending 6.9 to 6.4 L/100km over 12 months')`.

```dart
class SparklinePainter extends CustomPainter {
  final List<double> series; final double lo, hi;      // reference band
  // 1. draw band rect (u0-soft) + dashed top/bottom lines
  // 2. draw polyline (firouzeh 2dp, round joins)
  // 3. draw end dot r=4.5, fill accent
}
```

### 9.3 Cost breakdown (**primary = ranked horizontal bars**)

- Ranked bars, **sequential firouzeh ramp** (largest darkest), **direct labels**
  (`Fuel €231 · 55%`), and a **hatch pattern on the highlighted/largest category** — the
  redundant non-colour cue. Donut is *optional secondary* only.
- Track: `12dp`, `radius 6dp`, `surface-2`, hairline. Fill: ramp colour; highlight adds
  `repeating-linear-gradient(45deg, white@.35 3px, transparent 3px)`.

```dart
class CostBar extends StatelessWidget {
  final String label; final double pct; final Color rampColor; final bool highlighted;
  @override
  Widget build(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Text(label, style: t.label), const Spacer(),
      Text('${money(v)} · ${(pct*100).round()}%', style: t.tabular)]),   // direct label
    LayoutBuilder(builder: (_, box) => Stack(children: [
      _Track(width: box.maxWidth),
      _Fill(width: box.maxWidth * pct, color: rampColor, hatch: highlighted),  // hatch = redundant
    ])),
  ]);
}
```
Legend row states "Hatched = largest slice". RTL: bars grow from the right; labels lead right.

### 9.4 Cadence heatmap
Sequential firouzeh ramp over a Jalali/Gregorian month grid (calendar-aware month names). Each
cell has a tooltip with the exact count (text redundancy). Never encodes *status* — activity only.

### Chart states

| State | Behaviour |
|-------|-----------|
| default | instant paint (no skeleton) |
| active | tap a bar/point → tooltip with exact figure + "vs your history" line |
| empty | axis frame + "Not enough data yet — log 2 fills to see your trend" |
| loading | **none** — offline data is instant |
| disabled | n/a |

---

## 10. App / section header

**Purpose.** Orient within a room. Two registers: a **masthead** (brand, incl. the Nastaliq
identity in RTL) and a **section header** (eyebrow + title inside a room).

### Anatomy
- **Masthead:** logo mark (ECG-in-rounded-square) + wordmark `PULSE`; RTL adds the **Nastaliq
  masthead** (`نبضِ خودرو`, `Noto Nastaliq Urdu`, `line-height 1.9`) + Jalali date line.
- **Section header:** `eyebrow` (11dp/700, `.16em` tracking, uppercase, `--text-3`) + `h-title`
  (20/28) or `h-display` (30/38) + optional caption.

### Variants
- Cockpit masthead · Garage/Pit-lane section header · Sheet header (title + close ✕) ·
  RTL Nastaliq masthead (milestones/masthead only — never letter-spaced, never all-caps).

### States

| State | Note |
|-------|------|
| default | static |
| active (scroll) | title may shrink `h-display → h-title` on collapse |
| ache | header text **never** warms — only an inline count badge may appear |
| done / empty / disabled | copy swaps; no colour-only signalling |

### RTL behaviour
Eyebrow tracking is **removed** for Arabic scripts (never letter-space Arabic); Arabic/Persian
body gets **+2 line-height** so diacritics/dots survive. Masthead uses script-correct display:
**Persian → Nastaliq** (`Noto Nastaliq Urdu`/`Gulzar`), **Arabic → Aref Ruqaa** — explicitly not
conflated. See [i18n/RTL guide](../../flutter/06-i18n-rtl-calendars.md).

### Accessibility
- One `Semantics(header: true)` per section; the masthead logo is `ExcludeSemantics` (decorative)
  with the wordmark as text.
- Title contrast uses `--text` (`#1B242E` / `#ECF1F3`) — always AA+, independent of any tint.

### Flutter mapping

```dart
class SectionHeader extends StatelessWidget {
  final String eyebrow, title; final bool display;
  @override
  Widget build(BuildContext c) => Semantics(header: true, child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(eyebrow.toUpperCase(), style: t.eyebrow.copyWith(
        letterSpacing: isArabicScript(c) ? 0 : 1.6)),        // no tracking on Arabic
      Text(title, style: display ? t.display : t.title,
        strutStyle: StrutStyle(height: isArabicScript(c) ? 1.5 : 1.4)),  // +line-height for RTL
    ]));
}
```

---

## 11. Empty / first-run state

**Purpose.** The warm on-ramp and the calm "nothing to do" — where the demoted **nozzle/dipstick
flourish** and empty-state animation are allowed to appear.

### Anatomy (first-run)
Eyebrow "Welcome to Pulse" → display headline "Let's take your car's first reading." → a
**compact static-ish pulse-line** → power-source toggle (Petrol/Diesel · Electric) → vehicle /
plate / odometer fields → per-car accent picker (firouzeh/lapis/saffron/plum/pistachio) →
`Take first reading` CTA → "Offline-first · your data stays on this device".

### Variants
- **First-run onboarding** (add first vehicle) · **empty list** ("Nothing aching — your car is
  calm") · **empty chart** ("Log 2 fills to see your trend") · **empty room** (Garage with no
  history yet).

### States

| State | Content |
|-------|---------|
| default (first-run) | full onboarding flow, CTA enabled once required fields set |
| active | fields validate inline; accent preview updates hero tint live |
| ache | n/a (empty is by definition calm, u0 halo) |
| done | transitions to Cockpit with a first count-up reveal |
| disabled | CTA greyed until vehicle + odometer present |
| empty (nothing due) | reassurance line + optional nozzle flourish (decorative) |

### RTL behaviour
Whole flow flips; the Nastaliq masthead can debut here in Persian. Numerals localized in the
odometer field; `٫`/`٬` handling active in the fuel toggle preview.

### Accessibility
- The flourish/nozzle animation is decorative → `ExcludeSemantics`, honours reduced-motion.
- Empty states carry a **text explanation + next action**, never just an illustration.
- Accent swatches: `Semantics(button:true, selected:isPicked, label:'Firouzeh turquoise')` —
  selection is spoken, and the picked swatch also shows a **ring** (shape), not colour alone.

### Flutter mapping

```dart
class EmptyState extends StatelessWidget {
  final IconData glyph; final String title, body; final Widget? action;
  @override
  Widget build(BuildContext c) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    ExcludeSemantics(child: NozzleFlourish(animate: !reduceMotion(c))),   // decorative only
    Text(title, style: t.display, textAlign: TextAlign.center),
    Text(body, style: t.body.copyWith(color: t.text2), textAlign: TextAlign.center),
    if (action != null) Padding(padding: const EdgeInsets.only(top: 20), child: action!),
  ]));
}
```

---

## 12. Supporting controls (segmented, switch, toggle-card, CTA)

Small shared atoms used across the above.

| Control | Spec | States | RTL / a11y |
|---------|------|--------|------------|
| **Segmented** (`seg`) | pill container `surface-2` + hairline; selected item `surface` + shadow (day) / accent (night); `12.5dp/600` | default / `aria-pressed` selected / disabled | order flips; `Semantics(inMutuallyExclusiveGroup:true, selected:)` |
| **Switch** | `44×26`, thumb `20dp`, on = `--accent` | off / on / disabled | `Semantics(toggled:)`; label states meaning, not colour |
| **Toggle-card** (`ft`, `fuel-toggle`) | `radius 16dp` card, selected = accent border + `u0-soft` + tinted glyph | default / selected / disabled | icon holds; selection spoken + border (shape) |
| **CTA** | `radius 16dp`, accent gradient `160deg #3ED6C4→#1F8F82`, ink text `#04241f`; `.ghost` = hairline outline | default / pressed / disabled (opacity .7) / loading | full-width; `Semantics(button:true)`; gradient decorative, label load-bearing |
| **Vehicle switcher** (`vtab`) | pill with colour dot + name; selected = accent border + `u0-soft` | default / current | the dot is **paired with the vehicle name** (text), never colour-only ID |

```dart
final ctaGradient = const LinearGradient(
  begin: Alignment.topLeft, end: Alignment.bottomRight,
  colors: [Color(0xFF3ED6C4), Color(0xFF1F8F82)]);   // ink text #04241f on top
```

---

## 13. Theming, tokens & the two surfaces

Bind every component to a single `PulseTokens` object exposed via `ThemeExtension`, plus a
matching `ColorScheme` for Material widgets. Full token table lives in
[`./01-foundations.md`](./01-tokens.md); the essentials:

```dart
@immutable
class PulseTokens extends ThemeExtension<PulseTokens> {
  final Color base, surface, surface2, hairline, hairlineStrong, text, text2, text3;
  final List<Color> temp;                     // [u0..u4]
  final Color accent, accentInk, secondary;
  const PulseTokens._(...);

  static const day = PulseTokens._(
    base: Color(0xFFF4EFE7), surface: Color(0xFFFFFFFF), surface2: Color(0xFFFBF8F2),
    hairline: Color(0xFFE4DCD0), hairlineStrong: Color(0xFFD6CBBB),
    text: Color(0xFF1B242E), text2: Color(0xFF5E6B74), text3: Color(0xFF8A949B),
    temp: [Color(0xFF2FB8A8),Color(0xFF7FBF6A),Color(0xFFE9A43B),Color(0xFFE8703A),Color(0xFFD64533)],
    accent: Color(0xFF2FB8A8), accentInk: Color(0xFF1F8F82), secondary: Color(0xFFE9A43B));

  static const night = PulseTokens._(
    base: Color(0xFF0E1317), surface: Color(0xFF141A20), surface2: Color(0xFF182027),
    hairline: Color(0xFF222A32), hairlineStrong: Color(0xFF2E3841),
    text: Color(0xFFECF1F3), text2: Color(0xFF98A4AD), text3: Color(0xFF6E7A83),
    temp: [Color(0xFF2FB8A8),Color(0xFF7FBF6A),Color(0xFFE9A43B),Color(0xFFE8703A),Color(0xFFD64533)],
    accent: Color(0xFF2FB8A8), accentInk: Color(0xFF3ED6C4), secondary: Color(0xFFE9A43B));
}

ThemeData pulseTheme(Brightness b) {
  final tok = b == Brightness.light ? PulseTokens.day : PulseTokens.night;
  return ThemeData(
    useMaterial3: true, brightness: b,
    scaffoldBackgroundColor: tok.base,
    colorScheme: ColorScheme.fromSeed(seedColor: tok.accent, brightness: b).copyWith(
      surface: tok.surface, onSurface: tok.text, primary: tok.accentInk),
    textTheme: pulseTextTheme(b),               // Hanken Grotesk + Vazirmatn, tabular numerals
    extensions: [tok],
  );
}
```

**Radii:** cards 20 · sheets 26 · pill 999. **Shadow:** day `0 6 24 rgba(20,30,40,.07)`; night
= hairline + optional glow (no drop shadow). **Grain:** a baked fractal-noise overlay at
`opacity .05` (day) / `.06` (night), `blend overlay` — kills OLED banding on tints
([perf](../../flutter/10-performance-rendering.md)).

**Type scale** (px / line-height): hero-numeral `84/88` (→`60/64` on expansion) · display
`30/38` · title `20/28` · body `16/26` (**Arabic/Persian +2**) · label `13/20` · caption
`12/18`. All numerals `FontFeature.tabularFigures()`. See
[accessibility & dynamic type](../../flutter/15-accessibility-dynamic-type.md) for scaling caps.

---

## 14. Accessibility contract (redundant, non-colour encoding)

The single most important rule in PULSE: **because status is encoded in emotional colour,
every status MUST also be encoded redundantly.** This table is the acceptance checklist —
no component ships without all three non-colour channels.

| Status | Colour (decoration) | Channel 1 — **icon** | Channel 2 — **text label** | Channel 3 — **shape / position** |
|--------|--------------------|----------------------|----------------------------|----------------------------------|
| Calm / OK (u0) | firouzeh | ✓ check | "OK" / "Healthy" | solid stripe · bottom of list |
| Scheduled (u1) | pistachio | calendar | "Scheduled" | solid stripe |
| Due soon (u2) | saffron | ⚠ triangle | "Soon" / "Due soon" | dashed stripe 5/8 · "Wanting attention" section |
| Pressing (u3) | ember | ⚠ | "Pressing" | dashed stripe 4/7 |
| Overdue (u4) | pomegranate | ! / clock | "Overdue" | dashed stripe 3/5 · **top** "Aching now" section |
| Done / Recovered | firouzeh | ✓ | "Done" / "Recovered" | moved to Recovery timeline (pistachio dot) |

Additional guarantees:
- **Contrast.** Emotional tints are ambient and sit *behind* content; text/controls always use
  `--text`/`--text-2` and meet **WCAG AA** in both themes. Night status foregrounds are
  hand-picked on ink, not auto-flipped.
- **Colour-blind-safe.** The full state is recoverable in greyscale via icon shape + dash
  pattern + position. Test with a deuteranopia/protanopia simulator on every screen.
- **Reduced motion.** Breathing → static line, sweep off, count-up → instant set. **Haptics
  remain** as the accessible confirmation channel and are identical LTR/RTL.
- **Haptics** are the non-visual "exhale" confirmation (native-only) and are announced in
  parallel via `SemanticsService.announce`.
- **Touch targets.** keypad keys ≥ 44dp (target 56×64) · quick-add 56dp · room-nav items 48dp.
- **RTL.** Only directional glyphs, layout and the backspace key flip. The vital pulse-line,
  checkmarks, sweep dot and logo hold. Numerals are locale-driven and *proven distinct*
  (Persian `۰۱۲۳` vs Eastern-Arabic `٠١٢٣`); `٫` decimal vs `٬` grouping is respected in
  parsing and display. Full rules in
  [i18n / RTL / calendars](../../flutter/06-i18n-rtl-calendars.md) and
  [accessibility & dynamic type](../../flutter/15-accessibility-dynamic-type.md).

---

## 15. Component → screen map (from the prototype)

| Screen (prototype) | Primary components |
|--------------------|--------------------|
| 01 First-run | Empty/first-run [§11], toggle-card, accent picker, CTA [§12] |
| 02 Cockpit home | Vitals hero [§1], Vital card [§2], Rooms nav [§4], quick-add, exhale [§3] |
| 03 Quick-log | Keypad sheet [§5], segmented, station row [§8] |
| 04 Vehicle profile | Section header [§10], car-as-body diagram, vrow, spec rows [§8] |
| 05 Pit-lane | Reminder items [§6], status pills [§7], grouped sections |
| 06 Add reminder | Dual-trigger cards [§6], switch, segmented, synthesis card [§12] |
| 07 Expenses | Cost-breakdown bars [§9.3], list rows [§8] |
| 08 Trips | Route primitive, vrow, list rows [§8] |
| 09 Reports | Sparkline/trend [§9.2], cost bars [§9.3], vrow |
| 10 Service history | Recovery timeline [§8], pills [§7] |
| 11 Settings | Segmented, switch, calendar rows [§12] |
| 12 RTL cockpit | All of the above under `dir=rtl` + Nastaliq masthead [§10] |

---

*Next: [`./03-motion-haptics.md`](./04-motion-rtl-accessibility.md) — full timing, the exhale sequence,
breathing and count-up, and the reduced-motion matrix. Foundations & tokens:
[`./01-foundations.md`](./01-tokens.md).*
