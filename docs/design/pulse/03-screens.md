# 📱 Screen Blueprints & Module Patterns

> **PULSE** — *a vitals chart for your car.* This document turns the PULSE concept into
> build-ready screen recipes and reusable module patterns. It assumes the tokens,
> components, motion and accessibility rules defined in the sibling docs:
>
> - **Foundations & tokens** → [`./01-foundations.md`](./01-tokens.md)
> - **Component library** → [`./02-components.md`](./02-components.md)
> - **Motion, haptics & "the exhale"** → [`./04-motion-haptics.md`](./04-motion-rtl-accessibility.md)
> - **Accessibility & redundant status encoding** → [`./05-accessibility.md`](./04-motion-rtl-accessibility.md)
> - **RTL, multiscript & calendars** → [`./06-rtl-i18n.md`](./04-motion-rtl-accessibility.md)
>
> Engineering guides: [i18n / RTL / calendars](../../flutter/06-i18n-rtl-calendars.md) ·
> [performance & rendering](../../flutter/10-performance-rendering.md) ·
> [accessibility & dynamic type](../../flutter/15-accessibility-dynamic-type.md) ·
> product context: [overview](../../overview.md).

---

## 0. Reading this document

Every screen is a composition of **components** (Part B primitives) laid onto a
**standard scaffold**. Two rules govern *all* 25 feature modules and are non‑negotiable:

1. **Status is environment, but never *only* colour.** Emotional temperature (warm = ache)
   is decoration layered *behind* content. The same status is *always* re‑encoded with an
   **icon + text label + position/shape** so it survives colour‑blindness, greyscale, and
   both themes. See the **Redundant Status Encoding contract** (§0.2).
2. **Warmth is scoped and capped.** The aggregate field is a **capped edge halo** (max =
   stop‑2 saffron). Only the *specific aching card* may reach stop‑4 pomegranate. A single
   overdue reminder must never turn the whole app into daily dread.

### 0.1 The standard scaffold

Every screen (except the immersive Cockpit home) uses one scaffold so navigation, quick‑add
and the halo behave identically everywhere.

```
┌─────────────────────────────────────┐
│  AmbientHalo  (capped edge-lit, u≤2) │  ← paints behind everything, ignores pointer
│  ┌───────────────────────────────┐  │
│  │  StatusBar (system)           │  │
│  │  RoomHeader (masthead / title)│  │  ← Nastaliq/Ruqaa masthead only on home
│  │                               │  │
│  │  ┌─ scroll region ─────────┐  │  │
│  │  │  page content           │  │  │
│  │  └─────────────────────────┘  │  │
│  │                               │  │
│  │  QuickAddPill (persistent) ●  │  │  ← thumb-reachable, every room, FAB-like
│  │  RoomsNav (Cockpit/Garage/Pit)│  │  ← 3 rooms, plain-language sublabels
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

```dart
/// One scaffold for the whole app. Rooms and QuickAdd are constant chrome.
class PulseScaffold extends StatelessWidget {
  final int urgency;               // aggregate 0..4 -> halo CAPS this at 2
  final Widget? masthead;          // Nastaliq/Ruqaa only on Cockpit
  final String title;
  final Widget body;
  final Room activeRoom;

  const PulseScaffold({super.key, required this.urgency, required this.title,
      required this.body, required this.activeRoom, this.masthead});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: AmbientHalo(urgency: urgency.clamp(0, 2))), // CAP
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(children: [
            RoomHeader(title: title, masthead: masthead),
            Expanded(child: body),
          ]),
        ),
        floatingActionButton: const QuickAddPill(),          // persistent, all rooms
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: RoomsNav(active: activeRoom),
      ),
    ]);
  }
}
```

Frame reference: **390 × 844 logical**, **8 px base grid**. Cards radius **20**, sheets **26**,
pills **999**. Day shadow `0 6px 24px rgba(20,30,40,.07)`; night uses **hairline + glow** (no
drop shadows on OLED).

### 0.2 Redundant Status Encoding contract

The single most important rule in PULSE. Any place that shows urgency renders **all three**
channels. This is enforced with one shared widget so no module can forget.

| Urgency | Token / hex | Colour name | **Icon (redundant)** | **Text label (redundant)** | **Shape/position (redundant)** |
|:--:|:--|:--|:--|:--|:--|
| 0 | `#2FB8A8` | firouzeh | ✓ check‑pulse | "Healthy" / «سالم» | bottom of a sorted list |
| 1 | `#7FBF6A` | pistachio | ◔ quarter‑ring | "Watch" | — |
| 2 | `#E9A43B` | saffron | ▲ triangle | "Due soon" | — |
| 3 | `#E8703A` | ember | ▲! triangle‑bang | "Overdue" | — |
| 4 | `#D64533` | pomegranate | ⊘ ache‑glyph | "Aching" / «درد» | pinned to **top** of list |

```dart
/// Colour is decoration; icon + label + position carry the real signal.
class StatusBadge extends StatelessWidget {
  final int urgency; // 0..4
  const StatusBadge(this.urgency, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = PulseTokens.of(context);
    final s = t.status(urgency);              // {color, icon, label}
    return Semantics(
      label: s.label,                          // screen-reader hears the WORD, not colour
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.icon, size: 16, color: s.onSurfaceColor), // meets WCAG on surface
        const SizedBox(width: 6),
        Text(s.label, style: t.text.label),
      ]),
    );
  }
}
```

> **Contrast guardrail:** the warm *tint* lives only in the halo / card‑fill at low opacity.
> The **icon and label always use an on‑surface ink colour that passes WCAG AA (≥4.5:1) in
> both themes** — never a saturated status hue as the text colour. Verified per stop in
> [`./05-accessibility.md`](./04-motion-rtl-accessibility.md).

### 0.3 Emotional‑temperature behaviour (shared model)

- **AmbientHalo** = aggregate readiness, `clamp(worstUrgency, 0, 2)`. Edge‑lit, grained to
  kill OLED banding, `IgnorePointer`, `RepaintBoundary`. Eases at most **one stop** on change.
- **Card warmth** = the specific item's own urgency `0..4`; only aching cards glow (fill tint
  + left temperature rail). This is the *concentrated* ache.
- **The Exhale** fires on every pain‑relieving action (log, clear, close): the resolved card
  cools one notch (`cubic-bezier(.2,.7,.2,1)`), a soft settle, and a weighted haptic. The halo
  eases down at most one stop. See [`./04-motion-haptics.md`](./04-motion-rtl-accessibility.md).

---

# Part A — The 12 core screen blueprints

Each blueprint lists: **purpose**, **layout composition**, **components used**, **the hero**,
and **emotional‑temperature behaviour**. Screens map to the numbered prototype cells in
[`./prototype.html`](./prototype.html).

---

## A1 · First‑run — Add your first vehicle

**Purpose:** the very first reading. Establish the car‑as‑body metaphor and capture power
source + vehicle in under a minute, with zero anxiety.

**Layout composition**

```
Eyebrow  "Welcome to Pulse"
Display  "Let's take your car's first reading."
Body     one calm sentence
PulseLineHero  (flat/idle baseline — no ache yet)
Eyebrow  "Power source"
FuelToggle  [ Petrol/Diesel ]  [ Electric ]   ← segmented, 56 tall
FormField    Vehicle (year/make/model)
FormField    Odometer  (numeric keypad, last-3 shortcut)
PrimaryButton "Take first reading"  (full width, 56)
```

**Components:** `FuelToggle`, `FormField`, `NumericKeypadSheet`, `PrimaryButton`, `PulseLineHero`.
**Hero:** the pulse‑line at a **calm idle baseline** — it breathes but reads flat, signalling
"no history yet, no ache." First heartbeat animates in on submit.

**Emotional temperature:** halo pinned at **urgency 0 (firouzeh)** the entire flow. First‑run
must *never* show warmth — there is nothing to ache about yet. Onboarding is the one place the
diegetic nozzle/dipstick flourish may appear as the empty‑state illustration.

**RTL/i18n:** the Nastaliq masthead is deferred to home; here the display line is Vazirmatn.
Calendar picker defaults **Jalali‑primary** when locale ∈ {fa}, Hijri secondary for {ar, ckb}.

---

## A2 · Home — Cockpit "Now" (the single‑vital, no‑list home)

**Purpose:** answer *"is my car OK?"* in one glance. The structural signature of PULSE: **one
hero vital, NO visible list.** The prioritised list is one pull‑down away.

**Layout composition**

```
Masthead  PULSE  (Nastaliq/Ruqaa in RTL) · "A vitals chart for your car"
                                     ← generous negative space
        ┌───────────────────────────┐
        │   PulseLineHero (breathing)│   the ECG seismograph, full-bleed
        │        84/88 count-up      │   ONE number = current state
        │      "Readiness"  label    │
        └───────────────────────────┘
        StatusBadge  ▲ "Due soon · 1 item"   ← redundant encoding of aggregate
                                     ← negative space
   ↑ pull / swipe up reveals the "Needs you now" list (Pit-lane preview)
        RoomsNav  [Cockpit•] [Garage] [Pit-lane]      QuickAdd ●
```

**Components:** `Masthead`, `PulseLineHero`, `CountUpNumeral`, `StatusBadge`, hidden
`NeedsYouNowSheet` (drag‑reveal), `RoomsNav`, `QuickAddPill`.

**Hero:** the **breathing VITALS PULSE‑LINE** — an ECG‑like seismograph (CustomPainter, ~4 s
breath, direction‑agnostic). A single count‑up numeral is the car's current readiness score.
Deliberately **not a ring** — this is what escapes the Oura/Whoop template.

```dart
/// The signature hero. Symmetric => needs NO RTL mirroring.
class PulseLinePainter extends CustomPainter {
  final double phase;    // 0..1 breathing, driven by a 4s AnimationController
  final int urgency;     // tints the trace subtly; never the sole signal
  PulseLinePainter(this.phase, this.urgency);

  @override
  void paint(Canvas c, Size s) {
    final mid = s.height / 2;
    final amp = 1.0 + 0.06 * math.sin(phase * 2 * math.pi); // barely-there breath
    final path = Path()..moveTo(0, mid);
    // flat lead-in -> QRS spike -> flat tail (seismograph), scaled by amp
    path.lineTo(s.width*.30, mid);
    path.lineTo(s.width*.34, mid - 18*amp);
    path.lineTo(s.width*.40, mid + 40*amp);
    path.lineTo(s.width*.45, mid - 28*amp);
    path.lineTo(s.width*.50, mid);
    path.lineTo(s.width, mid);
    c.drawPath(path, Paint()
      ..style = PaintingStyle.stroke ..strokeWidth = 2
      ..strokeCap = StrokeCap.round ..strokeJoin = StrokeJoin.round
      ..color = PulseTokens.trace(urgency));
  }
  @override
  bool shouldRepaint(PulseLinePainter o) => o.phase != phase || o.urgency != urgency;
}
```

> **Reduced motion:** `MediaQuery.disableAnimations` (or app setting) → render `phase` static
> and stop the controller. Haptics remain the accessible feedback channel; see
> [performance & rendering](../../flutter/10-performance-rendering.md) for `RepaintBoundary`
> isolation so the 4 s breath never repaints the whole tree.

**Emotional temperature:** aggregate halo = `clamp(worst, 0, 2)` — the home can warm only to
**saffron**, never ember/pomegranate. The count‑up numeral only re‑counts on *real change*,
never on every visit. Pulling the hidden list up does **not** change the halo.

---

## A3 · Fuel / Charge entry — keypad‑first quick‑log

**Purpose:** the most frequent action. **1–2 taps** to capture a fill/charge. Keypad is the
default input; the nozzle/dipstick is *only* a flourish, never the mechanism.

**Layout composition (bottom sheet, radius 26)**

```
Grabber
Segmented  [ Litres ]  [ € total ]   ← "enter any two", app derives the third
BigValue   "— L"   large tabular, updates live from keypad
OdometerRow  128 4[__]  ← last-3-digits shortcut chip
NumericKeypad  3×4 grid, keys 56×64 (44 min), decimal ٫ vs grouping ٬
PrimaryButton "Log — the exhale"  (fires haptic + cool)
```

**Components:** `QuickLogSheet`, `SegmentedControl`, `CountUpNumeral` (live), `OdometerShortcut`,
`NumericKeypadSheet`, `PrimaryButton`.

**Hero:** the **numeric keypad** + the live big value. Capture is the point; nothing decorative
blocks entry. "Enter any two of {litres, price/L, total}" and the app computes the rest.

**Emotional temperature:** on **Log**, fire **the Exhale** — if this fill resolves the "fuel
low / due" ache, that card cools one notch and the halo eases down one stop. Weighted haptic
confirms. This is the payoff moment; make it feel *good*.

**RTL/i18n:** keypad must distinguish **decimal `٫`** from **grouping `٬`** ( `1٫5 = 1.5` ).
Numerals locale‑driven — Persian `۰۱۲۳` vs Eastern‑Arabic `٠١٢٣` (4/5/6 differ), Kurdish Sorani
via Vazirmatn. Formatting via `intl` `NumberFormat`; see
[i18n / RTL / calendars](../../flutter/06-i18n-rtl-calendars.md).

---

## A4 · Vehicle profile — the car‑as‑body

**Purpose:** the cherished object. Identity, specs, and a **car‑as‑body diagram** that
highlights the aching part.

**Layout composition**

```
Header  vehicle name + year   (Latin plate figure)
CarBodyDiagram  gentle line-art; the aching part glows (wheel / oil / battery)
StatSpecGrid  2-col tabular: odometer · avg economy · in service since
SectionList  "Vitals" rows: Oil, Tyres, Battery, Brakes  → each a StatusRow
QuickAdd ●   RoomsNav
```

**Components:** `CarBodyDiagram`, `StatSpecGrid`, `StatusRow` (List pattern), `SectionHeader`.
**Hero:** the **car‑as‑body diagram** — organic, reassuring, never a photoreal render or
cartoon mascot. The specific aching subsystem is highlighted (concentrated warmth) with its
`StatusBadge` beside it.

**Emotional temperature:** each vital row carries its *own* urgency (concentrated). The diagram
glows *only* on the aching part. Page halo = aggregate of this vehicle's vitals, capped at 2.

**RTL:** the diagram does **not** mirror (a car is a car); directional chevrons on rows do.

---

## A5 · Reminders list — Pit‑lane "What's due"

**Purpose:** the calm expert on your side. A triaged, sorted list of what needs care —
**pomegranate aches pinned to the top**, healthy at the bottom.

**Layout composition**

```
Title   "What's due"  ·  count
FilterChips  [All] [Overdue] [Soon] [Scheduled]   ← redundant text filters
ReminderCard (aching, u=4)  ⊘ "Aching · Oil service · 900 km over"
   swipe → [Done] [Snooze] [Skip]   satisfying triage motion
ReminderCard (u=2)  ▲ "Due soon · Inspection"
ReminderCard (u=0)  ✓ "Healthy · Tyre rotation"   (sorted to bottom)
QuickAdd ●   RoomsNav[Pit-lane•]
```

**Components:** standard **List pattern** (`StatusRow`/`ReminderCard`), `SwipeActions`
(done/snooze/skip), `FilterChips`, `StatusBadge`.
**Hero:** the **prioritised list itself**, sorted by urgency. This is the "one swipe away" list
teased on the Cockpit home.

**Emotional temperature:** the **top card may reach stop‑4** (concentrated ache); lower cards
cool progressively. Swiping **Done** fires the Exhale on that card (cool + settle + haptic) and
eases the page halo. Sort order *is* the redundant position encoding (§0.2).

---

## A6 · Add / Edit reminder — form pattern

**Purpose:** create a maintenance reminder by distance, date, or both.

**Layout composition**

```
SheetHeader  "New reminder"
FormField    Type (Oil / Brakes / Inspection / custom)  → picker
SegmentedControl  Trigger: [ Every km ]  [ Every date ]  [ Both ]
FormField    Interval value (numeric keypad)
DatePickerField  calendar-aware (Gregorian/Jalali/Hijri)
Toggle       Notify me
PrimaryButton "Save reminder"
```

**Components:** Add/Edit **form pattern** (§B3): `FormField`, `SegmentedControl`, `KeypadSheet`,
`CalendarField`, `SwitchTile`, `PrimaryButton`.
**Hero:** the trigger `SegmentedControl` — the core decision (distance vs time).

**Emotional temperature:** **neutral (urgency 0)** while composing — editing is not an ache.
Saving a reminder that is already overdue re‑evaluates aggregate urgency on return to Pit‑lane.

**RTL:** date field is **Jalali‑primary** in `fa`, with Gregorian in a caption; Nowruz‑aware
month names. See [`./06-rtl-i18n.md`](./04-motion-rtl-accessibility.md).

---

## A7 · Expenses — cost story, not a spreadsheet

**Purpose:** turn rows into stories ("this tank was your cheapest since March").

**Layout composition**

```
Title  "Costs"  ·  period selector
CostBreakdownChart  ranked horizontal bars, firouzeh light→dark ramp
                    + direct labels + HATCH on highlighted category
InsightCard  "Fuel is 68% of spend — €0.11/km this quarter"
ExpenseRow list (List pattern): Fuel · Service · Insurance · Parts
QuickAdd ●   RoomsNav
```

**Components:** **Report pattern** (§B4) + **List pattern**: `CostBreakdownChart`
(CustomPainter), `InsightCard`, `ExpenseRow`.
**Hero:** the **ranked cost‑breakdown bars** — the *primary* chart. The highlighted category
carries a **hatch pattern (redundant, non‑colour)** plus a direct label; a donut is optional
secondary only.

```dart
/// Ranked bars > donut. Redundant hatch on the highlighted category.
class CostBreakdownPainter extends CustomPainter {
  final List<CostSlice> data;     // pre-sorted desc; slice.highlighted:bool
  final ColorScheme scheme;
  // ...
  void paint(Canvas c, Size s) {
    // sequential firouzeh ramp (light->dark), NOT status hues.
    // highlighted slice: same fill + diagonal hatch (Path + PathMetric)
    // direct value label at bar end, tabular figures.
  }
}
```

**Emotional temperature:** costs are **neutral by default** — money is not an ache. Status
hues (saffron/ember/pomegranate) are **reserved and never used as a data series** here; the
firouzeh sequential ramp carries magnitude.

---

## A8 · Trips & Road‑trip — "vs your own history"

**Purpose:** journeys as stories ("you've driven Berlin→Tehran this year").

**Layout composition**

```
Title  "Trips"
DistanceHeadline  count-up total km this year (tabular)
EconomyTrendChart  firouzeh line 2px + 4px rounded data-end
                   + a "vs your history" reference band
RoadTripCard  named journey · distance · dates (multi-calendar)
TripRow list (List pattern)
```

**Components:** **Report pattern**: `CountUpNumeral`, `EconomyTrendChart`, `RoadTripCard`,
`TripRow`.
**Hero:** the **economy‑trend line** with a **"vs your history" reference band** — the framing
that makes a number mean something.

**Emotional temperature:** neutral/celebratory. A milestone (e.g. 100 000 km) may trigger the
**calligraphic display accent** (Nastaliq/Ruqaa, script‑correct) as a one‑off flourish — pride,
not ache.

---

## A9 · Reports — full drill‑down

**Purpose:** tier‑3 of progressive disclosure. Full interactive charts + opt‑in raw table.

**Layout composition**

```
Title  "Reports"  ·  range picker (calendar-aware)
SummaryStatGrid  economy · cost/km · km · fills  (tabular)
EconomyTrendChart  (large)
CostBreakdownChart (large)
CadenceHeatmap  sequential firouzeh ramp in Jalali/Gregorian calendar
Disclosure "Show raw data" → RawTable (opt-in, horizontal scroll)
```

**Components:** **Report pattern** (§B4) — every chart from `02-components`. `Disclosure` →
`RawTable`.
**Hero:** the chart the user drilled into; the **cadence heatmap** is the distinctive one,
rendered in the **active calendar** (Jalali‑primary in RTL).

**Emotional temperature:** analytics are **cool/neutral** — never ache. **No skeleton loaders**
— instant paint is the flex (offline, local DB). Dark‑theme chart steps are *hand‑selected and
validated on the ink surface*, never auto‑flipped. Legend shown for **≥2 series**.

---

## A10 · Service history — the timeline

**Purpose:** the car's medical record. A reverse‑chronological timeline of care, showing
**Recovery** (readiness rising after a service).

**Layout composition**

```
Title  "Care & history"   (Garage room)
RecoveryStrip  small pulse-line showing readiness recovering post-service
TimelineNode  ● 2026‑03 · Oil & filter · 128,400 km · €89
   │           connector rail
TimelineNode  ● 2025‑11 · Brakes · ...
Disclosure  per-node details / receipt photo
```

**Components:** **Detail/Timeline pattern** (§B2): `TimelineNode`, connector `Rail`,
`RecoveryStrip` (mini pulse‑line), `Disclosure`.
**Hero:** the **timeline** with the recovery motif — the car healing over time.

**Emotional temperature:** past aches render **cooled/muted** (they were resolved — show the
relief, not lingering pain). The recovery strip visibly *cools* after each service node. Dates
are multi‑calendar; **Jalali‑primary framing in RTL**.

**RTL:** the timeline rail flows from the **inline‑start** edge (right in RTL) — use
`EdgeInsetsDirectional`, never hard‑coded left/right.

---

## A11 · Settings — calm, plain‑language

**Purpose:** configure units, language, calendar, numerals, theme, notifications, backup —
without anxiety.

**Layout composition**

```
Title  "Settings"
SettingsGroup "Appearance"
   SwitchTile  Theme: Day / Night (warm paper / ink)
   Toggle      Reduce motion
SettingsGroup "Language & format"
   NavTile  Language  → fa · ar · ckb · en · de · fr
   NavTile  Calendar  → Gregorian / Jalali / Hijri / Hebrew
   NavTile  Numerals  → Latin / Persian / Eastern-Arabic
   NavTile  Units     → L·100km / mpg / km·mi
SettingsGroup "Data"
   NavTile  Backup & export   NavTile  About
```

**Components:** **Settings pattern** (§B5): `SettingsGroup`, `SwitchTile`, `NavTile`,
`SectionHeader`.
**Hero:** none — settings is intentionally flat and quiet.

**Emotional temperature:** **halo forced to urgency 0** everywhere in Settings. This is a
neutral utility space; ache has no place here.

**RTL:** every `NavTile` chevron mirrors; the live‑preview numeral in the Numerals row updates
to show `۱۲۳ / ٠١٢٣ / 123` so the choice is concrete.

---

## A12 · RTL showcase — first‑class by expression

**Purpose:** *prove* RTL is authored, not mirrored. Demonstrates the Nastaliq masthead,
Jalali‑primary framing, and the Nowruz‑aware motif.

**Layout composition (mirrors A2 home, but authored)**

```
Masthead  «پالس»  in true NASTALIQ (Noto Nastaliq Urdu / Gulzar) — NOT Ruqaa
          Arabic locale → Aref Ruqaa for «بَلْس»
PulseLineHero  (symmetric — identical, needs no mirror)
CountUpNumeral  ۱۲۸٬۴۰۰  Persian digits, tabular, grouping ٬
StatusBadge  ⊘ «درد · سرویس روغن»   (icon + Persian label + top position)
DateFrame  «۲۹ خرداد ۱۴۰۵»  Jalali primary · Gregorian caption · Nowruz motif
RoomsNav (mirrored order)   QuickAdd ● (inline-start)
```

**Components:** same as A2, with `NastaliqMasthead`, `JalaliDateFrame`, `NowruzMotif`.
**Hero:** the **Nastaliq masthead + Jalali‑primary hero** — the deliberately authored,
RTL‑distinct expression.

**Emotional temperature:** identical model to LTR — the halo, scoped warmth, and **the exhale
+ haptics are byte‑for‑byte identical across directions** (the accessible haptic channel does
not flip). Only *directional glyphs* mirror; the **pulse‑line, checkmarks, and logo hold**.

> Full RTL rules, numeral tables, calendar month names and the decimal‑vs‑grouping spec live in
> [`./06-rtl-i18n.md`](./04-motion-rtl-accessibility.md) and
> [i18n / RTL / calendars](../../flutter/06-i18n-rtl-calendars.md).

---

# Part B — Reusable module patterns (all 25 modules)

These six patterns let any of the 25 feature modules be built consistently. Each maps to
components, and each notes **RTL** and **data‑density** handling. Build a new module by picking
a pattern, not by inventing layout.

---

## B1 · List pattern — the standard row list

**Use for:** reminders, expenses, trips, documents, vehicles, parts, fill history — any
collection.

**Composition:** `PulseScaffold` → `FilterChips` (optional) → `ListView.builder` of
`StatusRow`s, sorted by urgency (aching first), healthy last.

```
StatusRow
┌──────────────────────────────────────────┐
│ [tempRail]  Icon  Title            Value  │
│             StatusBadge (icon+label)  ›    │
└──────────────────────────────────────────┘
   ↑ left rail = concentrated warmth (this item's urgency 0..4)
```

- **Components:** `StatusRow`, `StatusBadge` (§0.2), `SwipeActions` (where actionable),
  `FilterChips`.
- **Emotional temperature:** each row carries its **own** urgency; only aching rows warm. Sort
  order = redundant *position* encoding. `Done` swipe → the Exhale on that row.
- **RTL:** row is a `Row` with `Directional` padding; the temperature rail sits on the
  **inline‑start** edge; chevron mirrors; the status **icon does not**.
- **Data density:** default is one value per row (lean). Long lists use `ListView.builder`
  (lazy). Secondary metrics hidden behind tap → Detail (B2). Tabular figures for alignment.

```dart
Widget buildRow(BuildContext c, Item it) => StatusRow(
  leadingRail: TemperatureRail(it.urgency),          // concentrated warmth
  icon: it.icon,
  title: it.title,
  trailing: CountUpNumeral(it.value, tabular: true),
  badge: StatusBadge(it.urgency),                     // redundant icon+label
  onSwipeDone: () => exhale(c, it),                   // cool + settle + haptic
);
```

---

## B2 · Detail / Timeline pattern

**Use for:** service history, a single reminder, a trip detail, a fill detail — anything with
a history or a "recovery" arc.

**Composition:** `PulseScaffold` → optional `RecoveryStrip` (mini pulse‑line) → vertical
`Timeline` of `TimelineNode`s connected by a `Rail`, each expandable via `Disclosure`.

- **Components:** `TimelineNode`, `Rail`, `RecoveryStrip`, `Disclosure`, `StatSpecGrid`.
- **Emotional temperature:** current state may warm (concentrated); **resolved past events
  render cooled/muted** — show recovery, not lingering ache. Recovery strip cools after each
  positive node.
- **RTL:** rail on the inline‑start edge (`EdgeInsetsDirectional`); node timestamps are
  **calendar‑aware** (Jalali‑primary in RTL); connector direction flips, node dots do not.
- **Data density:** tier‑2 — node summary visible, full detail/receipt behind `Disclosure`
  (opt‑in). Never dump the raw record inline.

---

## B3 · Add / Edit form pattern

**Use for:** add reminder, edit vehicle, log a repair, add a document — any create/update.

**Composition:** bottom `Sheet` (radius 26) → `SheetHeader` → stack of `FormField` /
`SegmentedControl` / `CalendarField` / `SwitchTile` → sticky `PrimaryButton` (56, full width).
Numeric fields open the **`NumericKeypadSheet`** (keys 56×64, 44 min).

- **Components:** `FormField`, `SegmentedControl`, `NumericKeypadSheet`, `CalendarField`,
  `SwitchTile`, `PrimaryButton`.
- **Emotional temperature:** **neutral (urgency 0)** throughout — editing is never an ache.
  Warmth is re‑evaluated only on **save**, on return to the list.
- **RTL:** labels start‑aligned; keypad distinguishes **`٫` decimal from `٬` grouping**;
  calendar field **Jalali‑primary** in `fa`; numerals locale‑driven; text fields set
  `textDirection` per content, not per UI.
- **Data density:** progressive — show required fields; advanced/optional fields behind a
  "More options" `Disclosure`. Never a wall of fields.

---

## B4 · Report pattern

**Use for:** expenses, reports, trips analytics, economy — any chart surface.

**Composition:** `PulseScaffold` → range/period picker → `SummaryStatGrid` (tabular) →
one or more `CustomPainter` charts → optional `Disclosure` → opt‑in `RawTable`.

- **Components:** `EconomyTrendChart`, `CostBreakdownChart`, `CadenceHeatmap`, `SummaryStatGrid`,
  `InsightCard`, `RawTable` — all CustomPainter, **no chart library**.
- **Emotional temperature:** analytics are **cool/neutral**. **Status hues
  (saffron/ember/pomegranate) are reserved and never used as a data series** — magnitude uses
  the sequential firouzeh ramp; any status point is icon+label. Legend for **≥2 series**.
- **RTL:** category axis and bars start at the **inline‑start** edge; direct labels flip side;
  heatmap uses the **active calendar** (Jalali/Gregorian). Numerals + `NumberFormat` locale‑driven
  (lakh/crore 2‑2‑3 grouping where applicable).
- **Data density:** tier‑3 — summary stats first, full chart, raw table **opt‑in only**.
  **No skeleton loaders** — instant local paint. Dark steps hand‑validated on ink, not
  auto‑flipped. See [performance & rendering](../../flutter/10-performance-rendering.md) for
  `RepaintBoundary` around each chart.

---

## B5 · Settings pattern

**Use for:** app settings, per‑vehicle settings, notification prefs, backup/export.

**Composition:** `PulseScaffold` → grouped `SettingsGroup`s, each a `SectionHeader` + rows of
`SwitchTile` / `NavTile` / `RadioTile`.

- **Components:** `SettingsGroup`, `SectionHeader`, `SwitchTile`, `NavTile`, `RadioTile`.
- **Emotional temperature:** **halo forced to urgency 0** — settings are a neutral utility
  space, never warm.
- **RTL:** every `NavTile` chevron mirrors (`Directionality`); live numeral/date previews render
  in the selected locale so choices are concrete; toggles keep physical LTR knob motion but
  labels flip.
- **Data density:** flat and quiet — one setting per row, plain‑language sublabels, no nesting
  beyond one `NavTile` push.

---

## B6 · Empty pattern

**Use for:** the first‑visit state of any list/report before data exists.

**Composition:** centred `Illustration` (the demoted **nozzle/dipstick flourish** or car‑body
line‑art) → `EmptyTitle` → one calm `Body` line → single `PrimaryButton` (the first action).

- **Components:** `EmptyState`, `Illustration`, `PrimaryButton`.
- **Emotional temperature:** **always urgency 0 (firouzeh calm)** — an empty screen is *never*
  an ache. This is the *only* place the diegetic nozzle/dipstick animation is allowed to lead.
- **RTL:** the illustration does not mirror; the CTA and copy do. Voice is authored per language
  (calm physician / good race engineer — never a mascot or streak).
- **Data density:** the leanest state by definition — one illustration, one sentence, one
  action. No placeholders, no skeletons.

---

## Appendix — token quick‑reference (for this doc)

| Token | Day | Night |
|:--|:--|:--|
| base | `#F4EFE7` warm paper | `#0E1317` ink |
| surface | `#FFFFFF` | `#141A20` |
| hairline | `#E4DCD0` | `#222A32` |
| text / muted | `#1B242E` / `#5E6B74` | `#ECF1F3` / `#98A4AD` |
| accent | `#2FB8A8` firouzeh | `#2FB8A8` |
| secondary | `#E9A43B` saffron | `#E9A43B` |

**Temperature 5‑stop (baked grain):** 0 `#2FB8A8` · 1 `#7FBF6A` · 2 `#E9A43B` (**halo cap**) ·
3 `#E8703A` · 4 `#D64533`.

**Type scale (px/lh):** hero‑numeral 84/88 (→60/64 on German/long‑Arabic) · display 30/38 ·
title 20/28 · body 16/26 (Arabic/Persian +2 lh) · label 13/20 · caption 12/18.

**Radii:** card 20 · sheet 26 · pill 999. **Tap targets:** keypad 56×64 (44 min) · quick‑add 56
· rooms‑nav 48. **Motion:** breathe 4s ease‑in‑out infinite (reduced → static) · exhale settle
`cubic-bezier(.2,.7,.2,1)` + one‑notch cool · count‑up 600ms ease‑out on real change only.

Full token source, the Dart `PulseTokens` class, and both `ColorScheme`s live in
[`./01-foundations.md`](./01-tokens.md). Accessibility contrast proofs per stop and theme
are in [`./05-accessibility.md`](./04-motion-rtl-accessibility.md) and
[accessibility & dynamic type](../../flutter/15-accessibility-dynamic-type.md).
