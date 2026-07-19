# PULSE Redundant Encoding & Accessibility — the hard gate

Source: `docs/design/pulse/04-motion-rtl-accessibility.md` §4 + `01-tokens.md`
§1.4. **PULSE encodes status in emotional colour (warm = ache), so colour is the
ONE channel we may never rely on alone.** This is a CI-gated structural
requirement, not a nicety. If a user cannot see colour, cannot perceive motion,
and is on a screen reader, they must still fully get *"is my car OK, and what
needs me?"*.

## 1. Mandatory redundant encoding — every status carries FOUR signals

Colour is the fifth, supporting, never sole channel.

| Urgency | Temperature (support) | Icon (shape) | Text label | Shape / fill | Position |
|---|---|---|---|---|---|
| 0 · Healthy | firouzeh `#2FB8A8` | ♡ steady pulse | "Healthy" / "OK" | solid pill, calm outline | bottom of list / absent |
| 1 · Watch | pistachio `#7FBF6A` | eye / soft dot | "Watch" | solid pill | low in list |
| 2 · Due | saffron `#E9A43B` | ◔ clock | "Due soon" | pill + thin ring, dashed stripe 8/6 | rises in list |
| 3 · Overdue | ember `#E8703A` | ⚠ triangle | "Pressing" / "Overdue" | pill + hatch, dashed stripe 5/4 | near top |
| 4 · Acute | pomegranate `#D64533` | ▲ filled alert | "Aching" / "Needs care now" | filled + dense hatch, dashed stripe 3/5, heavier weight | **top** of list, concentrated card |

Rules:

- **Never a colour-only chip.** Status pills always show **icon + word**. The
  warm halo is ambient MOOD; the card's own pill states the status in TEXT.
- **Shape is MONOTONIC with urgency** (outline → ring → hatch → dense hatch;
  stripe dashes tighten) so a fully colour-blind user reads severity from pattern
  density AND position.
- **Position is a signal:** the single-vital home surfaces the most acute item;
  the hidden list is sorted by urgency, so *where* a card sits encodes *how*
  urgent — independent of hue.
- **Charts:** status hues are reserved, never a data series; highlighted
  categories use a **hatch + direct label**; ≥2-series charts carry a legend.

```dart
// Status is a value object; colour is derived LAST, never the source of truth.
class VitalStatus {
  final int urgency;                       // 0..4 — the canonical signal
  String label(AppLocalizations l) => ... // routed through gen-l10n
  IconData get icon => const [Icons.favorite, Icons.visibility, Icons.schedule,
      Icons.warning_amber, Icons.priority_high][urgency];
  ShapePattern get pattern => ShapePattern.values[urgency]; // outline→denseHatch
  Color color(PulseColors c) => c.temperature[urgency];     // decoration ONLY
}
```

## 2. Contrast — both themes, WCAG AA (verified, not auto-flipped)

Emotional tint stays AMBIENT; text and controls always meet WCAG.

| Element | Target | Day | Night |
|---|---|---|---|
| Body text | ≥4.5:1 | `#1B242E` on paper (13.6:1) | `#ECF1F3` on ink (14.1:1) |
| Secondary text | ≥4.5:1 | `#5E6B74` (5.6:1) | `#98A4AD` (5.9:1) |
| Large text (≥24px / ≥19px bold) | ≥3:1 | ✓ | ✓ |
| Non-text (icon, status ring, focus ring, hairline-as-boundary) | ≥3:1 | verify each stop's icon/outline, not the fill | dark steps validated on ink |
| Status text/icon over a warm card | ≥4.5:1 | verify at the warmest stop the card reaches (u4) | verify on ink-warm |

- **Warm tints are capped in luminance** so text over them never drops below AA —
  the aggregate halo maxes at saffron u2 and the field never goes ember/
  pomegranate (this also protects system-chrome contrast).
- **Grain** sits behind text layers — verify it never reduces text contrast.
- **`text3` (`#8A949B` / `#6E7A83`) is caption/large-text ONLY** — never an
  interactive label or AA body copy.
- CI runs contrast on **5 stops × 2 themes × (text, icon, outline)** — a matrix,
  not a spot check.

## 3. Screen-reader semantics — the decorative pulse-line

A `CustomPaint` pulse-line is one opaque rectangle to TalkBack/VoiceOver. Give
it an explicit, information-complete node — the number and status, never the
waveform:

```dart
Semantics(
  container: true,
  label: 'Vehicle vitals',
  value: '$readiness percent. Status: ${status.label}. $acuteItem needs care.',
  liveRegion: true,                                   // announces on exhale
  child: ExcludeSemantics(child: PulseLineHero(...)), // hide the decorative painter
)
```

- Every vital / stat tile / chart carries its own `Semantics(label + value)` with
  the figure in display numerals; `MergeSemantics` groups a tile's number + label
  + icon into one readable unit.
- **The exhale announces** via a `liveRegion` (SR says "Oil change. Done. Now
  healthy.") — the payoff is audible, matching the haptic.
- **Count-up:** expose the final value immediately; the roll is
  `ExcludeSemantics`.
- **Masthead** Nastaliq is `ExcludeSemantics`; the plain name is a sibling node
  (TTS mangles Nastaliq ligatures).
- Focus & traversal order **mirror in RTL** (`FocusTraversalGroup`); the hidden
  list's traversal order = urgency.

## 4. Dynamic type — up to 2×

- **Hero numeral reflows `84/88 → 60/64`** on German/long-Arabic AND under large
  text scale — never clips or overflows (a min/max fit, not a fixed downscale).
- **No fixed-height rows** — they clip scaled Persian/Arabic ascenders/descenders
  and Nastaliq diacritics. Rows size to content.
- **Arabic/Persian body gets +2 line-height** vs Latin at the same size (16/26 →
  16/28).
- Dense RTL screens **wrap, not truncate** at 2×; tabular numerals keep columns
  aligned as they grow.
- CI golden dimensions at **1.5× and 2.0×**.

## 5. Colour-blind-safe verification

Because warm = ache, verify against the three common CVD types plus greyscale:

| Simulation | Must still convey via |
|---|---|
| Deuteranopia (green-weak) | firouzeh vs saffron converge → icon + label + position |
| Protanopia (red-weak) | ember vs pomegranate converge → hatch density + "Overdue"/"Needs care now" text |
| Tritanopia (blue-weak) | firouzeh vs pistachio shift → outline-vs-no-outline shape + word |
| Full greyscale | the **acceptance test** — a pure-greyscale screenshot must still answer "what needs me?" |

Temperature stops have **monotonic luminance** (0→4 warmer *and* heavier icon/
shape), so severity survives desaturation. CI includes a greyscale golden of the
Cockpit + hidden list at each urgency.

## 6. Touch targets & gestures

| Element | Minimum | PULSE target |
|---|---|---|
| Any interactive | 44×44 dp | — |
| Keypad key | 44 | 56×64 |
| Quick-add pill | — | 56 |
| Room-nav item | — | 48 |
| Reminder actions (done/snooze/skip) | 44 | ≥48, generous swipe zones |

8dp base grid; targets never overlap; the persistent quick-add sits in the
start-edge thumb arc (mirrored RTL). **Every swipe has a visible, labelled tap
alternative** — no gesture is the only path to an action.

## Acceptance checklist (CI-gated)

- [ ] Every animation has a reduced-motion fallback that preserves meaning;
      haptics preserved under reduced-motion.
- [ ] No `left`/`right`/hard-coded offset signs — Directional-only; RTL golden
      passes; pulse-line/checkmark/logo do NOT mirror.
- [ ] **Every status = icon + label + shape + position, verified in greyscale.**
- [ ] Contrast matrix 5 stops × 2 themes × (text, icon, outline) all meet AA;
      warm tints capped at u2 for the halo.
- [ ] Pulse-line & every vital/chart carry a complete `Semantics` node; the
      exhale announces via `liveRegion`.
- [ ] 1.5× & 2.0× dynamic-type goldens pass; hero reflows; no clipped Persian/
      Nastaliq glyphs.
- [ ] All touch targets ≥44 dp; every swipe has a labelled tap alternative.
