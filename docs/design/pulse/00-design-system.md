# 🫀 PULSE Design System — Overview & Principles

> **A vitals chart for your car.**
> One breathing pulse-line, no visible list. The ache concentrates on the card that needs care; the exhale is the payoff on every completed action. Warm Persian-paper by day, ink by night — first-class in six languages and two directions.

This is the entry point to the PULSE design system for **Car and Pain** — a 100% offline Flutter app (iOS + Android), 25 feature modules, fully bidirectional (LTR: English / German / French — RTL: Persian / Arabic / Sorani Kurdish), multi-calendar (Gregorian / Jalali / Hijri) with Eastern-Arabic and Persian numerals. It defines the *why* and the *principles*; the sibling docs define the *what* and the *how*.

**Map of the system**

| Doc | Owns |
| --- | --- |
| **00 · Overview & Principles** (this doc) | Philosophy, the scoped-temperature model, Rooms IA, design principles, system map |
| [`01-tokens.md`](./01-tokens.md) | Color / type / space / radius / motion tokens → Dart `PulseTokens` + `ColorScheme` (light & dark) |
| [`02-components.md`](./02-components.md) | Widget catalog: pulse-line hero, ache card, status pill, keypad, Rooms nav, sheets |
| [`03-screens.md`](./03-screens.md) | Screen recipes across the 25 modules: Cockpit / Garage / Pit-lane, quick-log, first-run |
| [`04-motion.md`](./04-motion-rtl-accessibility.md) | Breathe, the exhale, count-up, haptics, reduced-motion fallbacks |

**Engineering guides:** [i18n / RTL / calendars](../../flutter/06-i18n-rtl-calendars.md) · [performance & rendering](../../flutter/10-performance-rendering.md) · [accessibility & dynamic type](../../flutter/15-accessibility-dynamic-type.md) · [product overview](../../overview.md)

---

## 1. Philosophy

**"Pain" is a bodily word.** So the most ownable metaphor for Car and Pain is the **car as a living body** and **you as its caregiver** — vitals, readiness, recovery after a service, *aches* for what is overdue. Everything in PULSE serves one emotional arc:

> **Anxiety → Glance → Decision → Relief / Pride.**

You open the app slightly worried ("is my car OK?"), you get one honest answer in a single glance, you decide on one thing, and you are rewarded with **relief** — a visible, felt exhale — never with confetti, streaks, or a mascot.

Three commitments make this concrete and keep it from sliding into a wellness cliché:

1. **Status is rendered as ENVIRONMENT, not status chips** — but **scoped**. The concentrated warmth lives on the *specific item that needs care*; the ambient field is a **capped edge-lit halo that can never fully ache**. A chronically overdue reminder therefore never inverts the brand into daily dread. (See §2.)
2. **The hero is a clinical VITALS PULSE-LINE** — an ECG-like seismograph, *not* a breathing ring. Surfaces are warm Persian paper / ink with **hairlines**, not soft-shadow gradient cards. Temperature is an **edge halo**, not a full-screen mood gradient. This is a deliberate escape from the Oura / Calm / Whoop wellness-clone surface.
3. **The voice is a calm physician / good race engineer** — terse, expert, reassuring. Never a mascot. Never a streak. Never confetti.

**Mood keywords:** calm · caring · warm · reassuring · alive · exhale · premium-restraint.

---

## 2. The scoped emotional-temperature system

PULSE encodes health as **temperature**: cool = calm, warm = ache. The novelty — and the safety mechanism — is that warmth is **scoped** (it lives where it belongs) and **capped** (the whole field can never go full-ache).

> ⚠️ **Accessibility rule, stated up front:** temperature is **mood, never signal.** Every status is *also* encoded redundantly — icon **+** text label **+** position/shape — and all text/controls meet WCAG contrast in both themes. Warmth is decoration painted *behind* content that always passes on its own. See §5.4.

### 2.1 Two palettes: calm vs ache

Built on a distinctive **Persian-miniature palette** that reads calm and premium while dodging generic automotive black/red *and* the recognizable wellness gradient.

| Band | Meaning | Named color | Hex |
| --- | --- | --- | --- |
| **Calm** | firouzeh turquoise | `--u0` / accent | `#2FB8A8` |
| | lapis (secondary calm accent) | lapis | `#3E6BE8` |
| | pistachio | `--u1` | `#7FBF6A` |
| **Ache** | saffron | `--u2` | `#E9A43B` |
| | ember | `--u3` | `#E8703A` |
| | pomegranate | `--u4` | `#D64533` |

The **urgency 0→4 → 5-stop temperature ramp** is the spine of the whole system. Each stop ships with **baked grain** to kill OLED banding (a real risk of ambient tints on ink surfaces).

```
u0 #2FB8A8   u1 #7FBF6A   u2 #E9A43B   u3 #E8703A   u4 #D64533
 calm  ························ ache
 firouzeh   pistachio    saffron     ember    pomegranate
            └─ halo cap ─┘
```

### 2.2 The capped ambient halo (the aggregate)

The whole-screen state is a **capped edge-lit halo** — an `inset` glow around the screen frame.

- Its **maximum is stop-2 saffron.** The ambient field **NEVER** goes ember or pomegranate.
- This structurally solves the **"permanent pain"** trap that a naive worst-item full-screen gradient creates: one chronically overdue item can no longer flood the app with dread every single day.
- The halo eases between stops on a `.8s cubic-bezier(.2,.7,.2,1)` transition, and on an exhale it drops **at most one stop.**

```css
.halo[data-u="0"]{ box-shadow: inset 0 0 70px -30px rgba(47,184,168,.55); } /* calm */
.halo[data-u="1"]{ box-shadow: inset 0 0 80px -30px rgba(127,191,106,.55); }
.halo[data-u="2"]{ box-shadow: inset 0 0 96px -26px rgba(233,164,59,.62); } /* CAP — never exceeds saffron */
```

### 2.3 The concentrated ache (the specific card)

The acute warmth **concentrates on the specific aching card**, which — unlike the halo — *may* reach **stop-4 pomegranate**. It is painted as a corner radial wash behind content, plus a redundant **left urgency stripe whose *pattern* changes with severity** (solid → dashed → tighter dashes) so severity survives without color:

```css
.ache[data-u="4"] { border-color: rgba(214,69,51,.6); }
.ache[data-u="4"]::before { background: radial-gradient(120% 130% at 100% 0%, var(--u4-soft), transparent 62%); }
.ustripe[data-u="2"] { background: repeating-linear-gradient(180deg, var(--u2) 0 5px, transparent 5px 8px); } /* dashed */
.ustripe[data-u="4"] { background: repeating-linear-gradient(180deg, var(--u4) 0 3px, transparent 3px 5px); } /* tight dash = most urgent */
```

**In one rule:** *the field warns softly (capped), the card aches sharply (scoped).*

### 2.4 "The exhale" — the payoff

Every **pain-relieving action** (log, clear, close, mark-done) fires **THE EXHALE**:

1. the aching card **cools one notch** (its `data-u` decrements, animating on the exhale curve),
2. a **soft settle** — a gentle downward-ease of the card, `cubic-bezier(.2,.7,.2,1)`,
3. a **weighted haptic** on device (native-only; a visual settle stands in on web mockups),
4. the capped halo eases down **at most one stop.**

This is the emotional core: pain → relief, made physical, on *every* completed action. Details and curves in [`04-motion.md`](./04-motion-rtl-accessibility.md).

---

## 3. Information architecture — "Rooms"

PULSE navigation is **spatial, not a dashboard/list/settings tab bar**. Three **named emotional spaces**, each with a plain-language secondary label for first-run legibility:

| Room | Secondary label | Purpose | Feeling |
| --- | --- | --- | --- |
| **Cockpit** | *Now* | Glance + decide. **Home.** | "Is my car OK?" answered in one glance |
| **Garage** | *Care & history* | The car as a cherished object over time | Pride, continuity, recovery |
| **Pit-lane** | *What's due* | The prioritized "needs you" queue | A calm expert on your side |

**The structural signature: the Cockpit home LEADS WITH A SINGLE VITAL AND NO VISIBLE LIST.** The prioritized "needs you now" list is **one swipe/pull away**, surfaced in Pit-lane. This is the deliberate break from a hero-plus-telemetry dashboard or an app that opens on an index. One vital, one glance, one decision.

Two things are reachable **from every room**:

- a **persistent thumb quick-add** (the findability fix) — its default is a **numeric keypad** with *"enter any two"* + a **last-3-digits odometer shortcut**. The diegetic nozzle/dipstick is **demoted** to an optional flourish and empty-state animation, **never** the input mechanism.
- room navigation itself (bottom, 48dp min targets).

Reminders in Pit-lane are triaged with a satisfying **done / snooze / skip** card motion (each `done` fires the exhale).

**Car-as-body vocabulary** names the world instead of using generic labels: **Vitals · Readiness · Recovery** (after a service) · **Aches** (overdue).

---

## 4. Design principles

### 4.1 Bold but usable
The concept is emotionally bold — a breathing hero, ambient temperature, a felt exhale — but never at the cost of legibility or reach. Tints are **ambient and behind** content; controls, text, and tap targets always meet spec on their own (keypad keys 44dp min / 56×64 target, quick-add 56dp, room-nav 48dp). Restraint *is* the premium signal.

### 4.2 One vital at a time
The landing is the **leanest** of a 3-tier progressive disclosure: **one hero vital, no list.** Drill-down reveals full interactive charts; the raw table is **always opt-in**. Density is *earned* by intent, never dumped on arrival. (See §5.2.)

### 4.3 Redundant status encoding *(non-negotiable)*
Because PULSE encodes status in emotional **color**, every status is encoded **at least three more ways**: **icon + text label + position/shape**. The urgency stripe changes *pattern*, not just hue. Status pills carry an icon *and* a word ("Due soon", "Healthy"). Nothing in PULSE is knowable by color alone — this is what makes a warm, mood-driven app **colour-blind-safe**. See §5.4.

### 4.4 Warm humanism
Persian-paper day / ink night on a Persian-miniature palette; hairlines not heavy shadows; soft rounded 2px medical/vital glyphs; a car-as-body diagram that *highlights the aching part* rather than a photoreal render. The voice is a calm physician. The result is **warm, human, and premium** where competitors are cold cockpits or spreadsheet cards — without ever tipping into cute, medical, or mascot registers.

---

## 5. How the system serves the hard constraints

### 5.1 Offline-first
100% offline, first-party-only. State via **Riverpod providers + Drift `.watch()` streams** (ephemeral widget state may still use `ValueNotifier`). Charts are **`CustomPainter`** — no chart library. Calendars use our own **Jalali/Hijri conversion**; numerals via **`intl`**. Consequences for design: **no skeleton loaders** — instant paint is the flex (data is local, so paint is immediate); **count-up numerals fire only on real change**, never re-counting from 0 on every visit. Everything renders from local data on first frame.

### 5.2 Data density (3-tier progressive disclosure)
- **Tier 1 — landing:** one hero vital, no list (deliberately the leanest).
- **Tier 2 — drill-down:** full interactive `CustomPainter` charts.
- **Tier 3 — opt-in:** the raw table.

**"Vs your own history"** framing turns rows into stories — *"this tank was your cheapest since March"*; *"you've driven Berlin→Tehran this year."* Instrument tactility (machined **tabular** figures) keeps dense numbers touchable without a wall of gray labels. Chart tokens (sequential firouzeh ramp + **redundant pattern/label**, reserved status hues that are **never a data series**) live in [`01-tokens.md`](./01-tokens.md); painters in [`02-components.md`](./02-components.md) and [`10-performance-rendering.md`](../../flutter/10-performance-rendering.md).

### 5.3 RTL + multi-script (first-class *by expression*, not by mirroring)
The symmetric vitals pulse-line and edge-halo need **no mirroring** — so RTL is first-class *by construction*. But symmetry alone would make the RTL showcase look identical to LTR, so PULSE **deliberately authors RTL-distinct expression**:

- a Persian **Nastaliq** calligraphic masthead (`Noto Nastaliq Urdu` / `Gulzar` — explicitly **not** Ruqaa), Arabic milestones use **Aref Ruqaa**;
- **Jalali-primary** date framing in RTL, with a **Nowruz-aware** motif and locale-correct month names;
- **four calendars first-class** — Gregorian / Jalali (primary in RTL) / Hijri / Hebrew.

Numerals are locale-driven and *proven distinct*: Persian ۰۱۲۳ vs Eastern-Arabic ٠١٢٣ (4/5/6 differ), Sorani Kurdish via Vazirmatn's verified coverage (ڕ ڵ ۆ ێ ە ھ), tabular for aligned data; the fuel keypad distinguishes **٫ decimal from ٬ grouping** (1٫5 = 1.5). Type pairs a warm humanist grotesque (**Hanken Grotesk**) with an ink-density-matched **Vazirmatn** so "calm" reads across scripts. **Never letter-space or all-caps Arabic**; give it +2 line-height so diacritics/dots survive at UI sizes. **Only directional glyphs flip** — the vital pulse-line, checkmarks, and logo hold. The reassurance voice is authored *per language*; **the exhale and haptics are byte-for-byte identical across directions.** Full rules in [`06-i18n-rtl-calendars.md`](../../flutter/06-i18n-rtl-calendars.md).

### 5.4 Accessibility
- **Redundant encoding everywhere** (§4.3): color is never the only channel — icon + label + shape/position always accompany it.
- **Contrast:** emotional tints stay ambient; text/controls meet **WCAG** in *both* themes. Dark temperature steps are **selected and validated on the ink surface**, never auto-flipped.
- **Colour-blind-safe** by consequence of redundancy + pattern-coded urgency stripes.
- **Motion:** breathing has a **complete `prefers-reduced-motion` static fallback**; the **haptic language remains the accessible feedback channel** and is preserved under reduced-motion.
- **Dynamic type:** the hero numeral reflows 84/88 → 60/64 under German / long-Arabic expansion; tap targets hold their minimums.

Full spec in [`15-accessibility-dynamic-type.md`](../../flutter/15-accessibility-dynamic-type.md).

---

## 6. Foundations at a glance

Full values live in [`01-tokens.md`](./01-tokens.md); this is the orientation set.

### 6.1 Dual theme

| Token | Day (warm paper) | Night (ink) |
| --- | --- | --- |
| base | `#F4EFE7` | `#0E1317` |
| surface | `#FFFFFF` | `#141A20` |
| hairline | `#E4DCD0` | `#222A32` |
| text / text-2 | `#1B242E` / `#5E6B74` | `#ECF1F3` / `#98A4AD` |
| elevation | `0 6px 24px rgba(20,30,40,.07)` | hairline + glow (no drop shadow) |

**Radii:** cards 20 · sheets 26 · pill 999. **Spacing:** 8px base grid, generous negative space. **Device frame:** 390×844 logical.

### 6.2 Type scale

| Role | px / line-height | Notes |
| --- | --- | --- |
| hero-numeral | 84 / 88 | count-up, **tabular**; reflows to 60/64 on expansion |
| display | 30 / 38 | |
| title | 20 / 28 | |
| body | 16 / 26 | Arabic/Persian **+2** line-height |
| label | 13 / 20 | |
| caption | 12 / 18 | |

**Fonts:** Latin `Hanken Grotesk` 400/600 (tabular numerals) · Persian/Arabic/Sorani `Vazirmatn` (variable) · Arabic masthead `Aref Ruqaa` · Persian masthead **Nastaliq** `Noto Nastaliq Urdu`/`Gulzar`.

### 6.3 Motion primitives

| Motion | Value |
| --- | --- |
| breathe | `4s ease-in-out infinite` (reduced-motion → static) |
| exhale settle | `cubic-bezier(.2,.7,.2,1)` + one-notch cool |
| count-up | `600ms ease-out` — **on real change only** |
| halo transition | `.8s cubic-bezier(.2,.7,.2,1)`, eases ≤ 1 stop |

### 6.4 The token bridge (Flutter)

Tokens map to a Dart `PulseTokens` class + a light/dark `ColorScheme` + `TextTheme`. Sketch (full version in [`01-tokens.md`](./01-tokens.md)):

```dart
class PulseTokens {
  // Temperature ramp — urgency 0..4 (shared across themes; dark tints validated on ink)
  static const temp = [
    Color(0xFF2FB8A8), // u0 firouzeh — calm
    Color(0xFF7FBF6A), // u1 pistachio
    Color(0xFFE9A43B), // u2 saffron — HALO CAP
    Color(0xFFE8703A), // u3 ember
    Color(0xFFD64533), // u4 pomegranate — ache (card only)
  ];
  static const haloMaxUrgency = 2; // aggregate halo never exceeds saffron

  static const rCard = 20.0, rSheet = 26.0, rPill = 999.0;
  static const space = 8.0; // base grid
}

final pulseLight = ColorScheme.fromSeed(
  seedColor: PulseTokens.temp[0],
  brightness: Brightness.light,
).copyWith(surface: const Color(0xFFFFFFFF), background: const Color(0xFFF4EFE7));

final pulseDark = ColorScheme.fromSeed(
  seedColor: PulseTokens.temp[0],
  brightness: Brightness.dark,
).copyWith(surface: const Color(0xFF141A20), background: const Color(0xFF0E1317));
```

---

## 7. Signature components (map)

Full specs and widget trees in [`02-components.md`](./02-components.md); screen assemblies in [`03-screens.md`](./03-screens.md).

- **Breathing VITALS PULSE-LINE hero** — ECG-like `CustomPainter` seismograph, ~4s breath, direction-agnostic. One number = the car's current state. Deliberately **not** a ring.
- **Scoped emotional-temperature** — capped ambient halo (§2.2) + concentrated ache card (§2.3).
- **THE EXHALE** — the completion micro-interaction (§2.4, [`04-motion.md`](./04-motion-rtl-accessibility.md)).
- **Rooms nav** — Cockpit / Garage / Pit-lane, plain-language labels, + persistent quick-add.
- **Single-vital HOME with no visible list** — the structural signature (§3).
- **Keypad-first quick-log** — "enter any two" + last-3-digits odometer shortcut; nozzle demoted.
- **Status pill + urgency stripe** — icon + label + pattern-coded shape (the redundant-encoding workhorses, §4.3).
- **RTL-distinct expression** — Nastaliq masthead, Jalali-primary, Nowruz motif (§5.3).

---

## 8. Risks & guardrails

| Risk | Guardrail |
| --- | --- |
| Warmth degrades legibility | Tints are **decoration, never signal** — text/controls always pass WCAG in both themes (§5.4). |
| Care metaphor feels gimmicky / "medical" / soft | Terse physician voice; **no mascot, no streak, no confetti**; nozzle stays a flourish. |
| Aggregate halo becomes "permanent pain" | Halo **capped at saffron (stop-2)**; eases down ≤ 1 stop; ache is scoped to the card (§2.2). |
| Breathing excludes reduced-motion / vestibular users | **Complete static fallback**; haptics remain the accessible channel (§5.4). |
| OLED banding on ambient tints | **Baked grain** on every temperature stop (§2.1). |
| Log becomes slow | Keypad stays **1–2 taps**; nozzle never blocks entry (§3). |

---

*PULSE — feel your car's health as a living pulse-line. One vital, no clutter; the ache sits on the card that needs you, and the relief is in your hands.*
