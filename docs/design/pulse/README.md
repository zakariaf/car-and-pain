# 🫀 PULSE Design System — Index

> **"A vitals chart for your car."** The implementation-ready design system for **Car and Pain** — a 100% offline Flutter app (iOS + Android), 25 feature modules, fully bidirectional (LTR English/German/French + RTL Persian/Arabic/Sorani Kurdish), multi-calendar (Gregorian/Jalali/Hijri) with locale-driven Eastern-Arabic/Persian numerals.

---

## What PULSE is

PULSE treats **the car as a living body and the owner as its caregiver**. The emotional arc is explicit — **Anxiety → Glance → Decision → Relief/Pride** — and it is rendered as **environment, not status chips**:

- **A single breathing VITALS PULSE-LINE home** — an ECG-like seismograph (not a wellness ring), one number = the car's current state, with **no visible list** (the prioritized "needs you now" list is one swipe away).
- **SCOPED emotional temperature** — the ache **concentrates on the specific card that needs care** (can reach pomegranate), while the aggregate is a **capped ambient halo** that maxes out at saffron and **never** goes full-ache. This structurally defeats the "permanent whole-screen dread" trap.
- **"THE EXHALE" completion micro-interaction** — a soft settle + one-notch cooling + a weighted haptic fired on **every** pain-relieving action (log / clear / close).
- **"ROOMS" navigation** — **Cockpit** ("Now"), **Garage** ("Care & history"), **Pit-lane** ("What's due"), each with a plain-language label, plus a persistent thumb quick-add reachable from every room.
- **Warm-paper (day) / ink (night) dual theme** on a **Persian-miniature palette** (firouzeh turquoise + lapis + pistachio = calm; saffron → ember → pomegranate = ache).
- **Type**: Hanken Grotesk (Latin) + Vazirmatn (Arabic/Persian/Kurdish), with a script-correct Nastaliq/Ruqaa masthead.

Voice: a **calm physician / good race engineer** — terse, expert, reassuring. Never a mascot, streak, or confetti.

> ### ⚠️ The one non-negotiable rule
> PULSE encodes status in **emotional colour** (warm = ache). Colour is **decoration, never signal**. Every status **MUST** also be encoded redundantly — **icon + text label + position/shape** — must pass **WCAG contrast in both themes**, and must be **colour-blind-safe**. Warmth is mood; text and controls always meet contrast. This rule governs every component in this system.

---

## The documents

Read in order for a full pass; jump to any doc when implementing a slice.

| # | Document | Covers |
|---|----------|--------|
| 00 | [Foundations & Philosophy](./00-design-system.md) | The car-as-body metaphor, the Anxiety→Relief arc, the "Rooms" spatial model, car-as-body vocabulary (Vitals / Readiness / Recovery / Aches), the physician/race-engineer voice, and the design principles + guardrails every other doc inherits. |
| 01 | [Design Tokens](./01-tokens.md) | All concrete values: day/ink base + surface + hairline + text palettes, the **5-stop urgency temperature ramp** (0–4, grained), accents, radii/shadows/spacing, the full type scale with line-heights, fonts per script, tap targets, and the device frame — delivered as **CSS custom properties** *and* a **Dart `PulseTokens` class + light/dark `ColorScheme`/`TextTheme`**. |
| 02 | [Components](./02-components.md) | The signature components as build-ready specs: the **breathing VITALS PULSE-LINE hero** (`CustomPainter`), the **scoped temperature + capped halo** system, the **exhale card motion** (done/snooze/skip), **"Rooms" nav**, the **single-vital no-list home**, the **keypad-first quick-log**, chart widgets, and car-as-body diagram — each with its redundant-encoding contract. |
| 03 | [Motion & Interaction](./04-motion-rtl-accessibility.md) | Timing and physics: the ~4s **breathe** loop, **"the exhale"** settle `cubic-bezier(.2,.7,.2,1)` + one-notch cool, **rolling count-up numerals** (600ms, real-change-only, tabular), the scoped warm→cool transition, the **haptic language** (direction-agnostic, native-only), and the complete **prefers-reduced-motion** fallbacks. |
| 04 | [RTL, Multi-script, Calendars & Accessibility](./04-motion-rtl-accessibility.md) | First-class RTL **by construction and by authored expression** (Nastaliq masthead, Jalali-primary framing, Nowruz motif); locale-driven numerals (Persian ۰۱۲۳ vs Eastern-Arabic ٠١٢٣, Sorani Kurdish coverage); the ٫ decimal vs ٬ grouping rule for the fuel keypad; four first-class calendars; and the redundant-encoding + contrast + colour-blind accessibility spec that satisfies the critical rule. |

---

## How to use this system

Work **tokens → components → screens**, always downward:

1. **Start at tokens ([01](./01-tokens.md)).** Never hard-code a hex, radius, duration, or font size in a widget. Everything resolves through `PulseTokens` / the `ColorScheme` / the `TextTheme`. Theme swaps (day↔ink) and script swaps (Latin↔Vazirmatn) then cost nothing at the call site.
2. **Compose with components ([02](./02-components.md)).** Reach for the signature widgets before inventing UI. Each ships its **redundant-encoding contract** (icon + label + shape/position) already wired — do not strip it to "just use the colour."
3. **Wire motion & feedback ([03](./04-motion-rtl-accessibility.md)).** Apply the breathe/exhale/count-up signatures via the shared animation helpers, and always register the reduced-motion fallback in the same commit.
4. **Assemble screens inside "Rooms" ([00](./00-design-system.md) + [02](./02-components.md)).** Cockpit leads with **one vital and no list**; the list is one swipe down. Quick-add is present in every room.
5. **Validate bidi + a11y last, on every screen ([04](./04-motion-rtl-accessibility.md)).** Run the LTR/RTL mirror check, the numeral/calendar check, and the contrast + colour-blind check before calling a screen done.

**Engineering constraints** this system respects (owner prefers built-in / first-party, minimal deps): Flutter theming via `ThemeData`/`ColorScheme`/`TextTheme`; charts via `CustomPainter` (**no chart library**); own Jalali/Hijri conversion + `intl` numerals; state via **Riverpod providers + Drift `.watch()` streams**.

---

## Links

- 🖥️ **Live prototype:** [`./prototype.html`](./prototype.html) — the concrete visual reference for every spec in this folder.
- 🧭 **Product overview:** [`../../overview.md`](../../overview.md)
- ⚙️ **Engineering guides:**
  - [`../../flutter/06-i18n-rtl-calendars.md`](../../flutter/06-i18n-rtl-calendars.md) — bidi, numerals, Jalali/Hijri conversion.
  - [`../../flutter/10-performance-rendering.md`](../../flutter/10-performance-rendering.md) — `CustomPainter` charts, the breathing loop, OLED grain.
  - [`../../flutter/15-accessibility-dynamic-type.md`](../../flutter/15-accessibility-dynamic-type.md) — redundant encoding, contrast, dynamic type, reduced motion.

---

*PULSE — calm, caring, warm, reassuring, alive. Premium restraint. The ache sits where it belongs, and the relief is in your hands.*
