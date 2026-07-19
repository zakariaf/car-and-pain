# PULSE Motion & THE EXHALE — timings, sequence, reduced-motion matrix

Source: `docs/design/pulse/04-motion-rtl-accessibility.md`. The one rule:
**motion, warmth and colour are DECORATION — state must be fully legible with all
three switched off.** Every animation has a reduced-motion fallback that
preserves meaning; **haptics survive reduced-motion** as the accessible channel.

PULSE has exactly **four authored motions + one device-only channel (haptics)**.
Restraint is the brand. Every duration/curve is a token (`PulseMotion` in
`packages/design_system/lib/src/motion_tokens.dart`) — never inline a magic
number.

## Reduced-motion global switch

```dart
bool reduceMotion(BuildContext c) =>
    MediaQuery.maybeDisableAnimationsOf(c) ?? false;
```

When `true`: breath is static, count-up snaps to final, the exhale becomes an
instant colour swap + haptic, room transitions become an instant cut with a
1-frame cross-fade. **No meaning is lost** — every state also carries icon +
label + shape + position.

## 1. The breath loop — the living hero

The vitals pulse-line breathes on a ~4s cycle so the car feels alive without
demanding attention. **Direction-agnostic** (symmetric waveform) → identical
LTR/RTL, no mirroring.

- Cycle 4000ms `Cubic(.37,0,.63,1)`.
- What animates: waveform amplitude **±6%** and a `0.85→1.0` opacity on the
  leading tip; **the baseline never moves** (keeps numerals stable).
- Amplitude is scaled by aggregate urgency (calm ±4%, stop-2 ±8%) — a
  **redundant, non-colour urgency cue**.
- Frame budget: repaint only the pulse layer via `RepaintBoundary`, target ≤2ms/
  frame. Drive ONE 4s `AnimationController` app-wide — never a per-point timer or
  N tickers.
- **Reduced-motion:** freeze at resting amplitude (`phase = 0.5`), full opacity;
  don't start the controller. The number + status glyph are unchanged so the
  state reads identically.

## 2. THE EXHALE — the payoff on every completion

Fired on **every pain-relieving action**: log fuel, mark a reminder done, clear/
close an ache. The emotional core: pain → relief, made physical. Synchronized
channels fired together:

1. **Scoped cooling.** The resolved card ramps its `u` **exactly one stop down**
   (to u0 when done) over 520ms `Cubic(.4,0,.2,1)`: border, corner tint and
   stripe cross-fade toward firouzeh; stripe reverts to solid.
2. **Capped halo eases** down **at most one stop** (e.g. u2→u1) over 600ms.
3. **Soft settle.** The card scales `1.0 → 0.985 → 1.0` (or `translateY 0→3→0dp`)
   over 420ms `Cubic(.2,.7,.2,1)` — a body letting go of a held breath.
4. **Count-up.** Readiness rolls UP to the new score, 600ms ease-out, tabular.
5. **Weighted haptic.** A single `HapticFeedback.mediumImpact()` — the
   accessible confirmation channel, **identical byte-for-byte LTR/RTL**.
6. **Copy + pill swap.** Pill → Done ✓; detail → "Recovered · next in 15,000 km";
   hero label → "Healthy — all clear".

> **Critical:** cooling is NEVER the only success signal. The status **icon +
> label flip in the same frame the cool begins** (⚠ Overdue → ✓ Done). Also fire
> `SemanticsService.announce('… marked done. Readiness now 97.', dir)`.

**Reduced-motion:** skip the scale/ramp animation and the count-up (set values
instantly), cross-fade the colour instantly — but **keep the haptic and the
icon/label flip and the announcement**. Canonical wiring:
`examples/exhale_interaction.dart`.

## 3. Count-up numerals — PULSE owns this motion

The hero vital and key figures **roll up on first reveal and on REAL change
only** — never re-counting from 0 on every visit (that is noise, not delight).

- 600ms ease-out, **tabular** figures (no jitter), locale-formatted numerals
  count in the display script.
- Guard on the previous value; `key: ValueKey(value)` so `TweenAnimationBuilder`
  only re-animates on a genuine change.
- The count is a value animation, not spatial → identical LTR/RTL.
- **A11y:** expose the FINAL value to semantics immediately; the visual roll is
  `ExcludeSemantics`. Never read digit-by-digit.
- **Reduced-motion:** print the final formatted string immediately.

## 4. Room transitions — Cockpit / Garage / Pit-lane

The three Rooms are spatial siblings, not a stack → a **shared-axis horizontal
slide**, 320ms `Cubic(.2,0,0,1)`. Outgoing slides 20% + fades to 0; incoming
slides in from the opposite edge + fades 0→1. **Axis sign follows text
direction** — derive `AxisDirection` from `Directionality.of(context)`, never a
hard-coded sign. The quick-add pill and room-nav do NOT transition (chrore).
**Reduced-motion:** instant cut + 120ms opacity cross-fade (no slide); room
identity is carried by the labelled nav indicator.

## 5. Haptics — the direction-agnostic accessible channel

Native-only (a visual settle stands in for HTML mockups), **identical byte-for-
byte LTR/RTL**, **preserved under reduced-motion**.

| Event | Haptic |
|---|---|
| Exhale / completion | `mediumImpact` (weighted, single) |
| Snooze | `lightImpact` |
| Skip / dismiss | `selectionClick` |
| Keypad digit | `selectionClick` (disable-able in settings) |
| Reaching u4 on a card (new acute ache) | double `lightImpact` (a "flutter") |

Provide a **"Reduce haptics"** setting distinct from the OS reduced-motion flag —
some users want motion but not vibration and vice-versa.

## Reduced-motion matrix (acceptance)

| Motion | Normal | Reduced-motion fallback |
|---|---|---|
| Breath | ±6% amplitude, 4s loop, sweep dot | static at rest amplitude, no sweep |
| Exhale cool | 520ms ramp | instant colour swap |
| Exhale settle | 420ms scale dip | none |
| Count-up | 600ms roll | snap to final value |
| Room slide | 320ms shared-axis | instant cut + 120ms cross-fade |
| Haptic | fires | **still fires** |
| Icon/label/announcement | flips + announces | **still flips + announces** |

## CI gate

Every animation must have a reduced-motion fallback that preserves meaning;
haptics preserved under reduced-motion. Enforced via `MediaQuery.disableAnimations`
goldens and the acceptance checklist in `redundant-encoding-a11y.md`.
