# PULSE Components — anatomy, states, RTL, Flutter mapping

Source: `docs/design/pulse/02-components.md` + `03-screens.md`. Every component
obeys the five commitments in SKILL.md. Widgets live in
`packages/design_system/`; screens compose them in feature `presentation/`.

## 0. The urgency scale (shared vocabulary)

`enum Urgency { calm, watch, dueSoon, pressing, overdue } // u0..u4`

| u | name | hex | redundant shape | label key |
|:--:|---|---|---|---|
| 0 | firouzeh | `#2FB8A8` | solid stripe | "Healthy"/"OK" |
| 1 | pistachio | `#7FBF6A` | solid stripe | "Watch"/"Scheduled" |
| 2 | saffron | `#E9A43B` | dashed 8/6 (HALO CAP) | "Due soon" |
| 3 | ember | `#E8703A` | dashed 5/4 | "Pressing"/"Overdue" |
| 4 | pomegranate | `#D64533` | dashed 3/5 (tightest) | "Aching"/"Overdue" |

Acute temperature = the single worst open item on the vehicle; the halo =
`worst.haloClamped` (max u2). Cards use their true u.

## 1. Breathing Vitals Pulse-line hero (`VitalsHero` / `PulseLineHero`)

The daily "is my car OK?" answer: an ECG-like `CustomPainter` seismograph, one
number = readiness. **Deliberately not a ring** (anti-Oura/Whoop signature).

- Line: stroke `2.4dp`, active-vehicle accent, round caps/joins, soft glow
  (`MaskFilter.blur 3`). Height 120dp (80dp compact/first-run).
- Breath: `scaleY 0.94→1.06`, 4s ease-in-out, origin center; a sweep dot travels
  L→R (a monitor cursor). **Direction-agnostic — never mirrors in RTL.**
- Number: hero-numeral 84/88 tabular, reflows to 60/64; **count-up 600ms on real
  change ONLY** — never re-counts from 0 on every visit.
- **The line NEVER warms** — it is identity, not signal. Aggregate mood lives
  only in the capped halo; acute warmth only on the card. (The "permanent pain"
  guardrail.) Variants: Full (120) · Compact (80, static) · Inline mini
  (sparkline).
- States: default calm (breathing, halo u0) · ache (line stays cool, halo ≤u2) ·
  overdue (line still cool, halo u2, the *card* goes u4) · done (count-up ↑, halo
  eases one stop) · empty/first-run (static flat line, "—", "Let's take your
  first reading").
- A11y: painter is decorative → `ExcludeSemantics`; the number+label form the
  semantic node (`Semantics(liveRegion: true, label: 'Readiness 92 of 100,
  Healthy, one item due soon')`). Wrap the animating subtree in a
  `RepaintBoundary`; drive one app-wide 4s `AnimationController` (not N tickers).

## 2. Vital Card (`VitalCard`) — scoped temperature + capped halo

The one aching card on home, and the atom of Pit-lane lists. Carries
concentrated warmth without bleeding into the whole screen.

- Card: `surface`, `border 1dp hairline`, radius 20, day shadow / night hairline.
- **`UStripe`** (left, 4dp, inset 14 top/bottom): the redundant urgency SHAPE —
  solid (u0/1) then repeating dashes tightening 8/6 → 5/4 → 3/5 as it warms.
- **Corner tint** (`::before` radial from the top corner): `u-soft` alpha, sits
  UNDER content (`IgnorePointer`), never behind text that needs contrast.
- States: calm u0 (solid firouzeh, `.12` tint) · soon u2 (dashed saffron, Mark
  done · Snooze) · overdue u4 (dashed pomegranate, Mark done · Snooze · Skip) ·
  done (animates u→u0 over 700ms `Cubic(.2,.7,.2,1)`, pill → Done ✓) · disabled
  (40% opacity, no tint) · empty (dashed hairline, "Nothing aching").
- RTL: `UStripe` moves to the right edge, corner tint mirrors to top-left, row
  content flips — via `Positioned.directional` / `EdgeInsetsDirectional`.
- A11y: three redundant channels beyond colour — (1) stripe dash pattern, (2)
  pill icon+text, (3) position (aching items sort to top under "Aching now").
  Full info in greyscale, zero hue needed. See `examples/vital_card.dart`.

## 3. AmbientHalo — the capped aggregate

Edge-lit inset glow = aggregate readiness, `clamp(worstUrgency, 0, 2)`. Grained
(kills OLED banding), `IgnorePointer`, `RepaintBoundary`. Eases at most ONE stop
on change (600ms). NEVER goes ember/pomegranate. In `PulseScaffold` it paints
behind everything: `Positioned.fill(child: AmbientHalo(urgency: urgency.clamp(0,
2)))`.

## 4. Rooms navigation (`RoomsNav`)

Three named emotional spaces, not a tab bar: **Cockpit** ("Now") · **Garage**
("Care & history") · **Pit-lane** ("What's due"). Each item column layout, min
48dp, radius 14. Selected = `accentInk` + icon drop-shadow glow (position/label
unchanged). Pit-lane gains a **dot badge + count** (text, not colour-only) when
items ache. LTR order Cockpit·Garage·Pit-lane; **RTL reverses** automatically
under `Directionality` (do not reverse the list manually). Use `NavigationBar`
semantics (`selected:`, spoken label). The **persistent quick-add is a separate
`FloatingActionButton(centerDocked)`** — reachable from EVERY room, never a nav
destination.

## 5. Quick-log keypad (`QuickLogSheet`) — keypad-first

1–2-tap fuel/charge capture, reachable everywhere. Default is a numeric keypad,
NOT a form; the nozzle/dipstick is a demoted flourish that never blocks entry.

- Bottom sheet radius 26, `translateY 102%→0` in 380ms `Cubic(.2,.7,.2,1)`.
- **Enter any two** of {volume, price/L, total, odometer}; PULSE computes the
  rest. Active field = accent border + `u0-soft` fill.
- **Odometer shortcut:** tap `…320` fills the last 3 digits onto the remembered
  prefix (`84,320`) → most fills are last-3 + volume.
- Keys min 56dp / target 56×64, radius 16, tabular. Save key = accent gradient
  `160deg #3ED6C4→#1F8F82`, ink text `#04241f`, spans all 3 columns.
- **Decimal vs grouping (critical):** Persian/Arabic decimal `٫` (U+066B) vs
  grouping `٬` (U+066C) — `1٫5 = 1.5`. Parse via `intl NumberFormat` — this is
  the `i18n-rtl-localization` skill's job; the keypad only surfaces both keys.
- Variants: Fuel (L · L/100km) / Charge (kWh · Wh/km) via a header segmented
  toggle; full-screen entry (screen A3) vs bottom-sheet — same widget.
- RTL: **digit order stays 1-2-3 / 4-5-6** (keypads are not mirrored); sheet
  chrome/labels/enter-two cards flip; `⌫` backspace glyph mirrors.
- On Save → `repo.insertFill` → DB stream emits → home hero recomputes → THE
  EXHALE fires on the vehicle.

## 6. Reminder tile (whichever-first: time OR distance)

Fires on whichever trigger arrives first. Row: part icon · title · dual-trigger
subline ("In 850 km or 40 days · whichever first", the winning trigger phrased in
TEXT) · status pill. Triage: swipe → done (=exhale) / snooze (slide + settle) /
skip (fade); every swipe has an equivalent labelled button for switch-control.
RTL: dates render Jalali-primary. Grouped by section header ("Aching now" /
"Wanting attention" / "Healthy · scheduled") — position is the redundant channel.

## 7. Status chip / pill (`StatusPill`)

The redundant-encoding workhorse that makes colour optional — **always icon +
text**, never a bare colour dot for status. Radius 999, padding 4/10/4/8, font
11.5/600, 1dp border, tinted bg, leading icon ~11dp.

| variant | fg day | fg night | bg | icon | text |
|---|---|---|---|---|---|
| ok | `#1F8F82` | `#3ED6C4` | `u0-soft` | ✓ check | OK / Done / Recovered |
| warn | `#9A6B12` | `#F0BD6A` | `u2-soft` | ⚠ triangle | Soon / Due soon |
| crit | `#A5352A` | `#F08A7C` | `u4-soft` | ! / clock | Overdue |
| neutral | `text2` | `text2` | `surface2` | — | Auto / Scheduled |

Night foregrounds are hand-selected on ink, not auto-flipped — each passes AA on
`#141A20`. **The icon SHAPE differs per status** so the pill is distinguishable
in greyscale. See `examples/urgency_value_object.dart`.

## 8. List row (`PulseRow`)

Dense-but-touchable row for history/expenses/trips/documents. `ricon` 38dp
radius-12 `surface2` tile · title 14/600 · subtitle 12 `text2` · trailing value
tabular, end-aligned (mirrors in RTL). `Semantics(button:, label: '$title,
$subtitle, $value')` — trailing value is part of the label so SR never loses it.
Row height ≥48dp effective. "Vs your own history" framing turns rows into
stories.

## 9. Chart primitives (CustomPainter — no chart library)

PULSE fixes only the PALETTE rules here; painter mechanics belong to the
`custompainter-charts` skill.

- **Status hues (saffron/ember/pomegranate) are RESERVED and never a data
  series.** Magnitude uses the sequential firouzeh ramp (light→dark `#7FD4C8 ·
  #2FB8A8 · #1F8F82`).
- Every categorical encoding carries a **redundant pattern + direct label**;
  legend required for ≥2 series; dark steps validated on ink, not auto-flipped.
- **No skeleton loaders** — offline data paints instantly.
- Pulse-line painter: not mirrored in RTL; wrap in `RepaintBoundary`.
- Sparkline: 2dp firouzeh line + 4.5dp rounded data-end dot + a **"vs your
  history" reference band** (`u0-soft` rect, dashed edges); end value labelled
  directly.
- Cost breakdown: **primary = ranked horizontal bars** (largest darkest) with
  direct labels + a **hatch pattern on the highlighted/largest category** (the
  redundant non-colour cue); donut is optional secondary only.
- Cadence heatmap: sequential firouzeh over a Jalali/Gregorian month grid; each
  cell has a text-count tooltip; encodes activity, never status.

## 10. Headers, empty/first-run, supporting controls

- **Masthead** (Cockpit): logo mark + wordmark; RTL adds the Nastaliq masthead
  (Persian) / Ruqaa (Arabic), `ExcludeSemantics` with the plain name on a sibling
  node. Header text **never warms** — only an inline count badge may appear.
- **Section header:** eyebrow (11/700 tracking upper `text3`, **tracking+caps
  removed in RTL**) + title/display + optional caption; one `Semantics(header:
  true)` per section.
- **Empty / first-run:** the ONLY place the demoted nozzle/dipstick flourish may
  lead. Always `ExcludeSemantics` on the illustration, honours reduced-motion,
  carries a **text explanation + next action** (never just an illustration).
  Accent swatches show a **ring** (shape) plus spoken selection, not colour
  alone. Halo pinned at u0 — an empty screen is never an ache.
- **Supporting atoms:** segmented (order flips RTL), switch (44×26, label states
  meaning not colour), toggle-card (selected = accent border + `u0-soft` +
  tinted glyph), CTA (radius 16, accent gradient `160deg #3ED6C4→#1F8F82`, ink
  text; `.ghost` = hairline outline), vehicle-switcher (colour dot ALWAYS paired
  with the vehicle name — never colour-only ID).

## 11. The standard scaffold (`PulseScaffold`)

Every screen except the immersive Cockpit home uses one scaffold so nav,
quick-add and halo behave identically: a `Stack` of `AmbientHalo` (capped, behind
everything, ignores pointer) + a transparent `Scaffold` with a `RoomHeader`, the
page body, a persistent `QuickAddPill` FAB, and `RoomsNav`. Frame 390×844, 8px
grid. See `examples/pulse_theme.dart` for the theme it reads and
`docs/design/pulse/03-screens.md` for the 12 screen recipes + 6 module patterns
(List / Detail-Timeline / Add-Edit form / Report / Settings / Empty).
