# PULSE Tokens — the full bridge (color / type / space / radius / motion → Dart)

Source: `docs/design/pulse/01-tokens.md`. UI composes from these tokens ONLY —
never a raw hex, dp, ms or `Cubic` literal. Tokens live in
`packages/design_system/lib/src/`; read per-theme neutrals with
`PulseTokens.of(context)` (the `PulseColorsExt` ThemeExtension).

## 0. The token contract (non-negotiable)

1. **Warmth is decoration, never signal.** Emotional tints are ambient (halo,
   card wash, stripe). Text/controls always meet WCAG AA; status is redundantly
   encoded (see `redundant-encoding-a11y.md`).
2. **Two hand-tuned palettes.** Night (`ink`) values are selected and validated
   ON the ink surface — never auto-flipped from light.
3. **The temperature ramp is NOT a status palette.** `u0..u4` express emotional
   temperature; semantic `ok/warn/crit` are a distinct set for chips/banners/
   validation and are **never** a chart data series.
4. **The aggregate halo is capped at `u2` (saffron).** Only the one aching card
   may reach `u4`. `haloU = min(aggregateUrgency, 2)`.
5. **Grain is mandatory on ambient tints** to kill OLED banding.

## 1. Colour

### 1.1 Neutrals (warm hue bias — paper not clinical white, warm-ink not blue-black)

| Token | Role | DAY | NIGHT |
|---|---|---|---|
| `base` | app background | `#F4EFE7` | `#0E1317` |
| `surface` | card / sheet fill | `#FFFFFF` | `#141A20` |
| `surface2` | recessed (fields, keys, tracks) | `#FBF8F2` | `#182027` |
| `hairline` | 1px border/divider | `#E4DCD0` | `#222A32` |
| `hairlineStrong` | emphasis / grab bars | `#D6CBBB` | `#2E3841` |
| `text` | primary | `#1B242E` | `#ECF1F3` |
| `text2` | secondary | `#5E6B74` | `#98A4AD` |
| `text3` | tertiary / caption / disabled | `#8A949B` | `#6E7A83` |

`text3` is caption/large-text only — never an interactive label or AA body copy
(day 3.7:1, night 3.6:1). `text`/`text2` pass AA on `surface` in both themes.

### 1.2 Emotional-temperature ramp `u0..u4` (shared across themes)

| u | Token | Hex | Name | Meaning |
|:--:|---|---|---|---|
| 0 | `u0` | `#2FB8A8` | firouzeh | Calm / healthy — resting brand state |
| 1 | `u1` | `#7FBF6A` | pistachio | Watch / scheduled — cool, ahead of due |
| 2 | `u2` | `#E9A43B` | saffron | Due soon — first warm stop; **HALO CAP** |
| 3 | `u3` | `#E8703A` | ember | Pressing / due-overdue — card only |
| 4 | `u4` | `#D64533` | pomegranate | Aching / well overdue — the ONE card only |

Soft washes (the only per-theme divergence; alpha nudged up on ink):

| Token | DAY | NIGHT |
|---|---|---|
| `u0-soft` | `rgba(47,184,168,.12)` | `rgba(47,184,168,.16)` |
| `u2-soft` | `rgba(233,164,59,.14)` | `rgba(233,164,59,.18)` |
| `u3-soft` | `rgba(232,112,58,.16)` | `rgba(232,112,58,.20)` |
| `u4-soft` | `rgba(214,69,51,.16)` | `rgba(214,69,51,.22)` |

Scoping: **aggregate → capped halo** (`min(u,2)`), **acute → the card's true u**
(to 4) + a left urgency stripe whose *shape* changes with u (solid → dashed →
tighter dashes).

### 1.3 Semantic status tokens (DISTINCT from the ramp)

Drive chips/validation/banners/switches; reuse ramp hues at the endpoints but
are a separate named set. `base` = fills/dots/icons; `text-safe` = the colour
when the hue must carry TEXT on surface and still pass AA.

| Token | base | DAY text-safe | NIGHT text-safe |
|---|---|---|---|
| `ok` | `#2FB8A8` | `#1F8F82` | `#3ED6C4` |
| `warn` | `#E9A43B` | `#9A6B12` | `#F0BD6A` |
| `crit` | `#D64533` | `#A5352A` | `#F08A7C` |

### 1.4 Accent + per-vehicle accent

- System `accent = #2FB8A8`; ink-safe `accentInk` = `#1F8F82` (day) / `#3ED6C4`
  (night). `secondary = #E9A43B`.
- **Per-vehicle accent** is chosen at onboarding and used for IDENTITY only
  (vehicle-switcher dot, garage header, timeline nodes, the pulse-line hero of
  the active vehicle) — **never** for status. Palette (each with an ink-safe
  stroke/text tone): Firouzeh `#2FB8A8`/`#1F8F82`, Lapis `#3E6BE8`/`#3E6BE8`,
  Saffron `#E9A43B`/`#9A6B12`, Plum `#B65CC4`/`#9A45A8`, Pistachio
  `#7FBF6A`/`#4E8C3C`. Guardrail: because a vehicle accent could collide with the
  temperature language, status is ALWAYS read from stripe-shape + icon + label,
  never the vehicle accent.

## 2. Typography

| Role | px / lh | Weight | tracking | tabular | Usage |
|---|---|---|---|---|---|
| `hero-numeral` | 84 / 88 | 600 | `-0.04em` | ✅ | the single home vital; count-up; reflows to **60/64** on de/long-ar & large scale |
| `display` | 30 / 38 | 600 | `-0.02em` | — | screen titles |
| `title` | 20 / 28 | 600 | `-0.01em` | — | card/section titles |
| `body` | 16 / 26 | 400 | 0 | — | paragraphs, row text (**fa/ar/ckb +2 lh**) |
| `label` | 13 / 20 | 600 | 0 | — | secondary labels, chips |
| `caption` | 12 / 18 | 500 | 0 | — | fine print |
| `eyebrow` | 11 / 16 | 700 | `.16em` UPPER | — | section eyebrows — **Latin only** |
| `entry-big` | 52 / 52 | 600 | `-0.03em` | ✅ | keypad live value |

**Tabular rule:** every numeral that can change or aligns in a column uses
`FontFeature.tabularFigures()` so digits never jitter during count-up.

Fonts (all bundled as assets — offline; never `google_fonts`): Latin **Hanken
Grotesk** 400/600 (tabular); Arabic/Persian/Sorani **Vazirmatn** (variable);
Persian masthead **Noto Nastaliq Urdu** (≥1.8 lh, masthead/milestone only);
Arabic masthead **Aref Ruqaa**. Never conflate Nastaliq (Persian) with Ruqaa
(Arabic); never letter-space or ALL-CAPS Arabic; eyebrow drops tracking+caps in
RTL. Numerals/calendars/bidi belong to the `i18n-rtl-localization` skill.

## 3. Spacing (8px base grid; half-step 4)

`s0=0 · sHalf=4 · s1=8 · s2=16 · s3=24 · s4=32 · s5=40 · s6=56`
(chip/keypad gap 8, card inner-y 16, screen pad 24, section 32, hero breathing
40). Generous negative space is a brand value.

**Tap targets:** keypad key min 44 / target 56×64 · quick-add 56×56 · room-nav
48 · any tappable min 44. Device frame 390×844 logical.

## 4. Radii

`rCard=20` (cards, fields, fuel tiles) · `rSheet=26` (bottom-sheet top) ·
`rPill=999` (chips, pills, quick-add, switches, segmented) · `rIconTile=12`
(row leading icon) · `rSmall=16` (keypad keys, vitals-row container).

## 5. Elevation (one language per theme)

- Day resting card: `0 6px 24px rgba(20,30,40,.07)`; sheet/phone `0 12px 40px
  rgba(20,30,40,.10)`.
- **Night uses hairline + glow, NOT drop shadow:** card `0 0 0 1px #222A32`;
  sheet `0 8px 30px rgba(0,0,0,.5), 0 0 0 1px #222A32`. Accent elements
  (pulse-line, active room icon) get a soft `drop-shadow` glow.
- **Grain overlay is mandatory** on any `u*` tint or large flat fill: a cached
  fractal-noise layer at opacity `.05` day / `.06` night, `BlendMode.overlay`,
  **not** a per-frame repaint (see the `custompainter-charts` / performance
  guidance). It sits *behind* text — verify it never reduces text contrast.
- Ambient halo (inset edge-glow, capped at u2): u0 `inset 0 0 70px -30px
  rgba(47,184,168,.55)` · u1 `inset 0 0 80px -30px rgba(127,191,106,.55)` · u2
  `inset 0 0 96px -26px rgba(233,164,59,.62)` — maximum, never exceeded.

## 6. Motion tokens

| Token | Value | Applied to |
|---|---|---|
| breathe | 4000ms `Cubic(.37,0,.63,1)` infinite | pulse-line breath + sweep |
| exhale settle | 420ms `Cubic(.2,.7,.2,1)` | card scale dip on completion |
| cool | 520ms `Cubic(.4,0,.2,1)` | one-notch temperature ramp |
| count-up | 600ms `Cubic(0,0,.2,1)` (ease-out) | numerals — **on real change only** |
| room | 320ms `Cubic(.2,0,0,1)` | Cockpit/Garage/Pit-lane shared-axis slide |
| halo | 600ms `Cubic(.2,.7,.2,1)` | aggregate halo drift, eases ≤1 stop |
| fast | 200ms ease-out | switches, segmented, small toggles |
| sheet | 380ms `Cubic(.2,.7,.2,1)` | keypad / bottom-sheet slide |

`ease-exhale = Cubic(0.2,0.7,0.2,1)` is the house "settle" curve. Full motion
spec + reduced-motion matrix: `motion-exhale.md`.

## 7. Dart mapping (what to build)

- `PulseTokens` — `abstract final class`, theme-agnostic: `temp` list `[u0..u4]`,
  `haloMaxUrgency = 2`, helpers `halo(int)` (clamps to 2) and `card(int)`
  (clamps to 4), `vehicleAccents`, radii, spacing, tap targets, motion durations/
  curves, grain opacities.
- `PulseColors` — `.day` / `.night` consts holding neutrals + `accentInk` +
  `okText/warnText/critText`. Exposed via `PulseColorsExt extends
  ThemeExtension<PulseColorsExt>` (ColorScheme cannot hold them all); `lerp`
  snaps on theme switch.
- `pulseLightScheme` / `pulseDarkScheme` — hand-built `ColorScheme`s (primary =
  `accentInk`, secondary = saffron, error = crit text-safe).
- `buildPulseTextTheme(onSurface, onSurface2)` — every numeric style carries
  `fontFeatures: [FontFeature.tabularFigures()]`; `height = lineHeightPx/sizePx`.
- `pulseTheme(Brightness)` — assembles `ThemeData(useMaterial3: true,
  colorScheme, scaffoldBackgroundColor: base, textTheme, extensions:
  [PulseColorsExt(...)], splashFactory: NoSplash.splashFactory)`.
- **Locale/script override:** a `Localizations`-aware builder swaps `fontFamily
  → 'Vazirmatn'` and adds +2 line-height at body/label/caption for `fa/ar/ckb`,
  and drops eyebrow tracking/caps. Masthead widgets pick `NotoNastaliqUrdu`
  (Persian) / `ArefRuqaa` (Arabic) explicitly.

Full assembled Dart: `examples/pulse_theme.dart`.
