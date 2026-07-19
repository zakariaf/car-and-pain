# F3 · PULSE design system implementation

> Translate the PULSE spec into a reusable, theme- and RTL-aware Flutter widget library: dual warm-paper/ink themes on a Persian-miniature palette, an always-redundantly-encoded urgency scale, the single breathing vital with a capped ambient halo, the exhale completion interaction, the Rooms scaffold, and CustomPainter charts with no chart dependency.

## Goal

Turn the PULSE design system from specification into shipping Flutter code. This epic delivers the presentation foundation every MVP module builds on: a single source of design truth (tokens), two fully-realised `ThemeData` themes (warm-paper light, ink dark) drawn from the Persian-miniature palette, and a component library where **status is never carried by colour alone** - every stateful surface encodes urgency redundantly through icon, label, shape, position and stripe.

Concretely, F3 produces:

- **Design tokens** for colour, type, spacing, radius and elevation, exposed as a typed, const, theme-agnostic API that both themes resolve against.
- **The urgency / emotional-temperature scale** (`u0..u4`), mapping each level to a colour *and* a redundant non-colour encoding, with the saffron halo clamp so ambient warmth never exceeds the calm ceiling.
- **The single breathing vital** - one `CustomPainter` pulse-line that breathes - and the **capped ambient halo**, both with a reduced-motion fallback that renders the same information statically.
- **The exhale** - a soft settle animation, one-notch cooling of the relevant temperature, and a weighted haptic on every relieving (completion) action.
- **The Rooms scaffold** - Cockpit / Garage / Pit-lane room chrome and transitions, with symmetric glyphs (pulse, halo, checkmark, logo) that do **not** mirror under RTL.
- **CustomPainter chart primitives** - axis, line and bar painters with `Semantics` wrappers and no third-party chart library.
- **The RTL & accessibility contract** - logical (start/end) properties throughout, WCAG AA verified in both themes, default semantics on every component.
- **A component gallery and golden-test suite** proving the whole system across light / dark / RTL.

The library is built-in-first: no chart package, no design-system package, no animation package beyond the Flutter SDK. It must be consumed identically by every feature module and must degrade gracefully under reduced-motion, large dynamic type, high-contrast and RTL.

## Tier & dependencies

- **Tier:** foundation
- **Depends on:** F1 (project scaffold & tooling - pub workspace, lints, CI, flavors; the internal `core/` design package this library lives in)

## References

- [docs/design/pulse/00-design-system.md](../../design/pulse/00-design-system.md) - PULSE principles & philosophy
- [docs/design/pulse/01-tokens.md](../../design/pulse/01-tokens.md) - colour / type / space / radius / elevation tokens
- [docs/design/pulse/02-components.md](../../design/pulse/02-components.md) - component catalogue
- [docs/design/pulse/03-screens.md](../../design/pulse/03-screens.md) - screen & Rooms compositions
- [docs/design/pulse/04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md) - motion, RTL & accessibility rules
- [docs/flutter/10-performance-rendering.md](../../flutter/10-performance-rendering.md) - CustomPainter & repaint-boundary guidance
- [docs/flutter/15-accessibility-dynamic-type.md](../../flutter/15-accessibility-dynamic-type.md) - accessibility & dynamic-type contract
- [docs/reference/data-model.md](../../reference/data-model.md) - entities the components render

## Tasks

### F3-T1 · Design tokens & dual theme

**Description**
Implement the full token layer - colour, typography, spacing, radius and elevation - as typed, const, theme-neutral primitives, then compose them into two `ThemeData` objects: the warm-paper light theme and the ink dark theme, both drawn from the Persian-miniature palette. Tokens are exposed via a `ThemeExtension` (`PulseTokens`) so components read semantic tokens (`surface`, `onSurface`, `vital`, `haloCeiling`, etc.) rather than raw palette values, and both themes resolve the same semantic keys. Type scale is defined in logical pixels and respects `MediaQuery.textScaler` without breaking layout.

**Acceptance criteria**
- [ ] Colour, type, space, radius and elevation tokens exist as const, typed values with no magic numbers leaking into components.
- [ ] Semantic tokens are exposed through a `PulseTokens` `ThemeExtension` resolved from `Theme.of(context)`; no component references raw palette constants.
- [ ] Warm-paper (light) and ink (dark) `ThemeData` are both provided and switchable at runtime; every semantic key is defined in both.
- [ ] The Persian-miniature palette is the sole colour source; saffron is defined once as the halo ceiling token.
- [ ] Type scale honours `textScaler` up to the supported maximum without overflow in gallery samples.
- [ ] All token/theme values have unit tests asserting both themes define every semantic key.

**Size:** M
**Depends on:** F1
**Governing docs:** [01-tokens.md](../../design/pulse/01-tokens.md), [00-design-system.md](../../design/pulse/00-design-system.md), [15-accessibility-dynamic-type.md](../../flutter/15-accessibility-dynamic-type.md)

---

### F3-T2 · Urgency temperature system

**Description**
Implement the `Urgency` enum (`u0` calm … `u4` critical) as the single emotional-temperature scale. Each level maps to a colour **and** a redundant non-colour encoding - a stripe treatment, a shape/border cue, an icon and a text label - so state survives colour-blindness, greyscale and high-contrast. Provide a resolver that returns the full encoding bundle for a level in the active theme, and enforce the **saffron halo clamp**: ambient warmth derived from urgency is capped so the always-on halo can never exceed saffron regardless of how many hot cards exist.

**Acceptance criteria**
- [ ] `Urgency { u0, u1, u2, u3, u4 }` defined with an ordered severity relation.
- [ ] Each level resolves to colour + stripe + shape + icon + label; the non-colour encodings are present at **every** level (including `u0`).
- [ ] A pure resolver maps `(Urgency, Brightness) -> UrgencyStyle`, unit-tested table-driven for all 5 levels × 2 themes.
- [ ] The ambient halo intensity function clamps at the saffron ceiling token; a test proves aggregating many `u4` cards never exceeds it.
- [ ] Labels are localisation keys, not hardcoded strings.
- [ ] Every urgency colour pair meets WCAG AA contrast against its surface in both themes (asserted by test).

**Size:** M
**Depends on:** F3-T1
**Governing docs:** [00-design-system.md](../../design/pulse/00-design-system.md), [01-tokens.md](../../design/pulse/01-tokens.md), [04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md)

---

### F3-T3 · Breathing vital & capped halo

**Description**
Build the single breathing vital: one `CustomPainter` pulse-line that animates a slow, calm breathing cycle, plus the ambient halo capped at saffron. The vital is the home screen's sole living element - there is no visible list on home. Drive both with a single `AnimationController` behind a `RepaintBoundary`, and provide a **reduced-motion fallback** that renders an equivalent static frame (no animation, same conveyed state) when `MediaQuery.disableAnimations` is set or the app-level reduced-motion preference is on. Performance-budget the painter (const paint objects, `shouldRepaint` gated on value, no per-frame allocation).

**Acceptance criteria**
- [ ] Pulse-line is a `CustomPainter` (no image/lottie/chart lib) breathing on a single controller, wrapped in a `RepaintBoundary`.
- [ ] Ambient halo intensity is fed by the F3-T2 clamp and never renders hotter than saffron.
- [ ] Reduced-motion fallback renders a static equivalent conveying the same state; verified when `disableAnimations` is true and via the in-app preference.
- [ ] `shouldRepaint` returns false when inputs are unchanged; no allocations inside `paint()` (const `Paint`/`Path` reuse where possible).
- [ ] The vital carries a `Semantics` label describing current overall state textually.
- [ ] Golden tests capture breathing mid-cycle and the reduced-motion static frame in both themes.

**Size:** L
**Depends on:** F3-T2
**Governing docs:** [00-design-system.md](../../design/pulse/00-design-system.md), [04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md), [10-performance-rendering.md](../../flutter/10-performance-rendering.md)

---

### F3-T4 · Core components

**Description**
Build the reusable component set - cards, stat tiles, pills, buttons and inputs - each consuming tokens and each carrying status redundantly beyond colour (icon + label + shape/stripe + position) via the F3-T2 encoding. Components are theme- and RTL-aware by construction (logical padding, `Directionality`-safe) and expose sensible default `Semantics`. Cards surface scoped emotional temperature (the ache on the card that needs care); inputs support validation state, dynamic type and error text that is itself redundantly encoded.

**Acceptance criteria**
- [ ] Card, stat tile, pill, button and input widgets exist, each reading `PulseTokens` and accepting an `Urgency` where stateful.
- [ ] Any status shown by colour is simultaneously shown by icon + label + shape/stripe - verified by a greyscale golden test.
- [ ] All spacing/padding uses logical (start/end) properties; no `left`/`right` hardcoding.
- [ ] Inputs support validation/error states with non-colour error indication and correct dynamic-type reflow.
- [ ] Each component ships a default `Semantics` label/role; interactive ones expose correct button/field semantics and min 48dp touch targets.
- [ ] Widget tests cover each component in light/dark and enabled/disabled/error states.

**Size:** L
**Depends on:** F3-T1, F3-T2
**Governing docs:** [02-components.md](../../design/pulse/02-components.md), [01-tokens.md](../../design/pulse/01-tokens.md), [15-accessibility-dynamic-type.md](../../flutter/15-accessibility-dynamic-type.md)

---

### F3-T5 · The exhale completion interaction

**Description**
Implement the exhale: the shared micro-interaction played on every *relieving* action (marking a reminder done, logging the overdue service, clearing an alert). It combines a soft settle animation, a **one-notch cooling** of the affected card's temperature (e.g. `u3 -> u2`), and a **weighted haptic**. Expose it as a single reusable API (`Exhale.play(context, target)` / an `ExhaleController`) so every module triggers the identical feel, with a reduced-motion path that still cools the temperature and fires the haptic but skips the animation.

**Acceptance criteria**
- [ ] A single reusable exhale API is invoked from any completion action; modules do not reimplement it.
- [ ] On play: temperature drops exactly one notch (clamped at `u0`), the settle animation runs, and a weighted haptic fires.
- [ ] Reduced-motion path skips the animation but preserves the one-notch cooling and the haptic.
- [ ] Haptic uses the platform haptic API with graceful no-op where unsupported.
- [ ] A `Semantics` live announcement communicates the relief (e.g. "Done - now calm").
- [ ] Unit/widget tests assert the one-notch cooling clamp and that the reduced-motion branch still cools + haptics.

**Size:** M
**Depends on:** F3-T2, F3-T4
**Governing docs:** [00-design-system.md](../../design/pulse/00-design-system.md), [04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md)

---

### F3-T6 · Rooms scaffold widgets

**Description**
Build the Rooms navigation chrome: Cockpit, Garage and Pit-lane room shells with their transitions, designed to slot into the app's `StatefulShellRoute` tabs (F1/navigation). Each room provides its own chrome (title treatment, safe-area handling, scroll behaviour) and a consistent transition. Enforce the symmetry rule: the pulse, halo, checkmark and logo glyphs are symmetric and **must not mirror** under RTL, while everything else follows directionality.

**Acceptance criteria**
- [ ] Cockpit, Garage and Pit-lane room scaffolds exist with shared base chrome and per-room identity.
- [ ] Room transitions are consistent and reduced-motion-aware.
- [ ] Symmetric glyphs (pulse, halo, checkmark, logo) are explicitly excluded from mirroring in RTL; a golden test proves they render identically LTR vs RTL.
- [ ] Rooms integrate with the shell route without owning navigation state (chrome only).
- [ ] Rooms honour safe areas, dynamic type and both themes.
- [ ] Widget/golden tests cover each room in light/dark/RTL.

**Size:** M
**Depends on:** F3-T3, F3-T4
**Governing docs:** [03-screens.md](../../design/pulse/03-screens.md), [00-design-system.md](../../design/pulse/00-design-system.md), [04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md)

---

### F3-T7 · Charts primitives (CustomPainter)

**Description**
Implement reusable chart primitives - axis, line and bar painters - entirely with `CustomPainter`, with **no third-party chart dependency**. Provide a small composable API (data series in, painter out) that later modules (economy, cost/distance, CO2) feed. Every chart is wrapped in a `Semantics` container that exposes a textual summary and, where feasible, per-datapoint semantics, so charts are never colour-only. Painters are performance-budgeted (repaint boundaries, gated `shouldRepaint`, no per-frame allocation) and RTL-aware (axis direction follows locale where semantically correct, numerals localised).

**Acceptance criteria**
- [ ] Axis, line and bar painters implemented as `CustomPainter`s with no chart package in `pubspec`.
- [ ] A composable API accepts typed series and renders via the painters; used by at least the gallery.
- [ ] Each chart has a `Semantics` wrapper with a textual summary; data is not conveyed by colour alone (redundant markers/labels).
- [ ] Painters are wrapped in `RepaintBoundary`, `shouldRepaint` is value-gated, and no allocation occurs inside `paint()`.
- [ ] Axes and numerals localise correctly and behave under RTL.
- [ ] Golden tests cover line and bar charts in light/dark; a unit test asserts the semantic summary string.

**Size:** M
**Depends on:** F3-T1, F3-T4
**Governing docs:** [02-components.md](../../design/pulse/02-components.md), [10-performance-rendering.md](../../flutter/10-performance-rendering.md), [15-accessibility-dynamic-type.md](../../flutter/15-accessibility-dynamic-type.md)

---

### F3-T8 · RTL & accessibility contract

**Description**
Codify and enforce the cross-cutting RTL and accessibility contract for the whole library: logical (start/end) properties everywhere, non-mirrored symmetric glyphs, WCAG AA contrast verified in both themes, and a default-semantics guarantee on every component. Deliver this as shared helpers plus an automated verification pass (a contrast-checker test over the palette, and lint/test guards against physical `left`/`right` usage and against colour-only status). This task is the enforcement backbone for the redundant-encoding rule across F3.

**Acceptance criteria**
- [ ] A palette contrast test asserts every foreground/background semantic pair meets WCAG AA (and AAA where the spec requires) in both themes.
- [ ] A guard test/lint flags any component using physical `left`/`right` instead of logical properties.
- [ ] A guard asserts no component conveys status by colour alone (paired with the greyscale golden strategy).
- [ ] Symmetric-glyph non-mirroring is documented and test-enforced (shared `Directionality` helper for excluded glyphs).
- [ ] Every public component exposes non-empty default `Semantics`; a test enumerates the gallery and fails on any missing label.
- [ ] Reduced-motion, high-contrast and large-text behaviours are documented as a component contract in code doc comments.

**Size:** M
**Depends on:** F3-T2, F3-T4
**Governing docs:** [04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md), [15-accessibility-dynamic-type.md](../../flutter/15-accessibility-dynamic-type.md), [06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md)

---

### F3-T9 · Component gallery & golden tests

**Description**
Build a Storybook-style component gallery (an in-app debug/dev screen) enumerating every token, component, chart, room and interaction across light / dark / RTL and reduced-motion, and back it with a golden-test suite. The gallery doubles as the manual QA surface and the golden-test fixture source, so adding a component means adding a gallery entry and its goldens. Golden matrix covers light × dark × LTR × RTL for every component, plus greyscale goldens that prove redundant encoding.

**Acceptance criteria**
- [ ] A gallery screen lists all tokens and components with live theme, directionality and reduced-motion toggles.
- [ ] Golden tests exist for every component across light/dark and LTR/RTL.
- [ ] Greyscale goldens exist for every stateful component, proving status survives without colour.
- [ ] Goldens include the breathing vital (mid-cycle + reduced-motion static) and both chart types.
- [ ] Golden suite runs in CI and fails on unreviewed pixel diffs.
- [ ] A short README documents how to add a component + its gallery entry + goldens.

**Size:** M
**Depends on:** F3-T1, F3-T2, F3-T3, F3-T4, F3-T5, F3-T6, F3-T7, F3-T8
**Governing docs:** [02-components.md](../../design/pulse/02-components.md), [03-screens.md](../../design/pulse/03-screens.md), [11-testing.md](../../flutter/11-testing.md)

---

### F3-T10 · i18n & localisation wiring for the library _(added for a complete slice)_

**Description**
Wire the library into the app's gen-l10n / ARB pipeline so every human-visible string it emits - urgency labels, exhale announcements, chart summaries, default semantic labels, gallery copy - is a localisation key, not a literal, and renders correctly under all supported locales including RTL (fa/ar/ckb) and localised numerals. This closes the gap between "RTL-aware layout" (F3-T8) and "fully localised content", and is required before any MVP module can adopt the library without hardcoding strings.

**Acceptance criteria**
- [ ] All user-visible and semantic strings emitted by the library are ARB-backed keys; a test/lint fails on literal user-facing strings.
- [ ] Urgency labels, exhale announcements and chart semantic summaries are translatable and pluralisable where relevant (ICU).
- [ ] Numerals in charts/stat tiles render via the app's numeral system (Western/Eastern-Arabic/Persian) per locale.
- [ ] The gallery is verifiable in at least one RTL locale end-to-end.
- [ ] Missing-translation behaviour degrades to base locale without crashing.

**Size:** S
**Depends on:** F3-T2, F3-T4, F3-T7
**Governing docs:** [06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md), [15-accessibility-dynamic-type.md](../../flutter/15-accessibility-dynamic-type.md)

---

### F3-T11 · Reduced-motion & app-level preference plumbing _(added for a complete slice)_

**Description**
Provide the single source of truth for the reduced-motion decision the whole library depends on: a resolver that combines the OS `MediaQuery.disableAnimations` signal with the app-level accessibility preference (from Settings), exposed to every animated surface (vital, exhale, room transitions, chart entrance). Without this, T3/T5/T6 each invent their own check. Read-only here - the preference itself is owned by the Settings/accessibility module; this task defines the contract and the default when Settings is absent.

**Acceptance criteria**
- [ ] A single `reducedMotion(context)` resolver combines OS `disableAnimations` OR app preference and is the only motion gate used by the library.
- [ ] Vital, exhale, room transitions and chart entrance all consult this resolver (no ad-hoc checks).
- [ ] Defaults safely to "motion enabled" when no app preference is wired, and to reduced when the OS flag is set.
- [ ] Unit tests cover the OR-combination truth table.

**Size:** S
**Depends on:** F3-T1
**Governing docs:** [04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md), [15-accessibility-dynamic-type.md](../../flutter/15-accessibility-dynamic-type.md)

## Definition of Done

- [ ] All tasks (F3-T1…F3-T11) meet their acceptance criteria and are merged behind passing CI.
- [ ] **Tests:** unit tests for tokens/urgency/exhale/motion resolvers; widget tests for every component and room; golden tests across light × dark × LTR × RTL, plus greyscale goldens proving redundant encoding, running green in CI.
- [ ] **Built-in-first honoured:** no chart library, no design-system library, no animation package beyond the Flutter SDK added to `pubspec`; charts and the breathing vital are `CustomPainter`.
- [ ] **Dual theme:** warm-paper (light) and ink (dark) themes both complete, every semantic token defined in both, runtime-switchable.
- [ ] **Redundant encoding rule:** no component conveys status by colour alone; every stateful surface adds icon + label + shape/stripe + position, verified by greyscale goldens and a guard test.
- [ ] **Urgency & halo:** the `u0..u4` scale and the saffron halo clamp are implemented and test-proven never to exceed the ceiling.
- [ ] **The exhale:** a single reusable interaction (settle + one-notch cooling + weighted haptic) is the only completion feel modules use, with a reduced-motion path preserving cooling + haptic.
- [ ] **i18n complete:** every user-visible and semantic string is ARB-backed; numerals localise; no hardcoded user-facing literals (lint/test enforced).
- [ ] **RTL verified:** logical properties throughout; symmetric glyphs (pulse/halo/checkmark/logo) proven non-mirrored; the gallery passes in an RTL locale.
- [ ] **Accessible per the redundant-encoding rule:** WCAG AA contrast verified in both themes; default `Semantics` on every component; min 48dp touch targets; dynamic type reflow; reduced-motion fallbacks for vital, exhale, rooms and charts.
- [ ] **In backup/export:** the only persisted state this library introduces (theme choice, reduced-motion/accessibility-relevant display preferences it reads) is owned by Settings and covered by that module's backup/export - this epic adds no un-exported persisted state.
- [ ] **Adoption-ready:** the component gallery documents the full library and every MVP module can consume F3 without redefining tokens, reimplementing the exhale, or hardcoding strings.
