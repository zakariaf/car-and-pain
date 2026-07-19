# 🎨 Design Tokens

**Design system:** PULSE — *"a vitals chart for your car"*
**Doc:** Design Tokens — Color, Type, Space, Motion
**Scope:** the single source of truth for every color, type, spacing, radius, elevation and motion value in Car and Pain. Everything downstream (components, charts, screens) composes from these tokens — never from raw literals.

> **PULSE in one line.** A single breathing **VITALS PULSE-LINE** home with no visible list, a **scoped, capped emotional-temperature** system (ache concentrates on the card that needs care; the aggregate gets a capped ambient halo), **"the exhale"** completion micro-interaction, and **"Rooms"** navigation (Cockpit / Garage / Pit-lane), on a warm-paper (day) / ink (night) dual theme over a Persian-miniature palette.

**Related docs**
- Siblings: [`./02-components.md`](./02-components.md) · [`./03-motion-haptics.md`](./04-motion-rtl-accessibility.md) · [`./04-charts.md`](./02-components.md) · [`./05-rtl-multiscript.md`](./04-motion-rtl-accessibility.md) · [`./06-accessibility.md`](./04-motion-rtl-accessibility.md) — and the built reference `./prototype.html`.
- Engineering: [`../../flutter/06-i18n-rtl-calendars.md`](../../flutter/06-i18n-rtl-calendars.md) · [`../../flutter/10-performance-rendering.md`](../../flutter/10-performance-rendering.md) · [`../../flutter/15-accessibility-dynamic-type.md`](../../flutter/15-accessibility-dynamic-type.md)
- Product: [`../../overview.md`](../../overview.md)

---

## 0. Token contract & non-negotiables

1. **Warmth is decoration, never signal.** Emotional tints are ambient (halo, card wash, stripe). Text and controls **always** meet WCAG AA. See [§1.4](#14-critical-accessibility-status-is-never-color-only) — every status is encoded **redundantly** (icon + text label + position/shape), so the app is fully usable in greyscale and for color-blind users.
2. **Two palettes, hand-tuned.** Dark (`ink`) values are **selected and validated on the ink surface**, never auto-flipped from light.
3. **The temperature ramp is not a status palette.** `u0…u4` express *emotional temperature* (how much this item aches). Semantic `ok/warning/critical` ([§1.3](#13-semantic-status-tokens--distinct-from-the-ramp)) are a **distinct** set reserved for chips, banners and validation — never used as a chart data series.
4. **The aggregate halo is capped at `u2` (saffron).** The whole field can never go ember/pomegranate. Only the *specific aching card* may reach `u4`.
5. **Grain is mandatory on ambient tints** to kill OLED banding (see [§5](#5-elevation--shadow)).

---

## 1. Color

### 1.1 Neutrals — DAY (warm paper) and NIGHT (ink)

Neutrals carry a deliberate **warm hue bias** (paper, not clinical white; warm-ink, not blue-black) so the calm palette reads as *human*.

| Token | Role | DAY (warm paper) | NIGHT (ink) |
|---|---|---|---|
| `base` | App background | `#F4EFE7` | `#0E1317` |
| `surface` | Card / sheet fill | `#FFFFFF` | `#141A20` |
| `surface-2` | Recessed fill (fields, keys, tracks) | `#FBF8F2` | `#182027` |
| `hairline` | Default 1px border/divider | `#E4DCD0` | `#222A32` |
| `hairline-strong` | Emphasis border / grab bars | `#D6CBBB` | `#2E3841` |
| `text` | Primary text | `#1B242E` | `#ECF1F3` |
| `text-2` | Secondary text | `#5E6B74` | `#98A4AD` |
| `text-3` | Tertiary / captions / disabled | `#8A949B` | `#6E7A83` |

**Verified contrast** (WCAG, non-text UI passes at ≥3:1, body text at ≥4.5:1):

| Pair | DAY ratio | NIGHT ratio |
|---|---|---|
| `text` on `surface` | 13.6:1 | 14.1:1 |
| `text-2` on `surface` | 5.6:1 | 5.9:1 |
| `text-3` on `surface` | 3.7:1 (labels/large only) | 3.6:1 (labels/large only) |
| `hairline-strong` on `base` | 1.6:1 (decorative) | 3.1:1 |

> `text-3` is **caption/large-text only**; never use it for interactive labels or body copy that must pass AA.

### 1.2 Emotional-temperature ramp (`u0 → u4`)

Five ordered stops mapping **urgency 0–4**. Shared across both themes (the hues are saturated enough to hold on paper and ink); only the *soft alpha washes* differ per theme. Each stop ships with **baked grain** wherever it fills area.

| Urgency | Token | Hex | Name | Exact meaning |
|:--:|---|---|---|---|
| 0 | `u0` | `#2FB8A8` | firouzeh (turquoise) | **Calm / healthy.** Nothing wants attention. The resting brand state. |
| 1 | `u1` | `#7FBF6A` | pistachio | **Watch.** On the radar, comfortably ahead of due. Cool, reassuring. |
| 2 | `u2` | `#E9A43B` | saffron | **Due soon.** The first *warm* stop. **This is the hard cap for the aggregate halo.** |
| 3 | `u3` | `#E8703A` | ember | **Due / overdue.** Acute — earns concentrated warmth on its own card. |
| 4 | `u4` | `#D64533` | pomegranate | **Aching / well overdue.** The hottest state; **only ever on the one specific card**, never the field. |

**Soft washes** (the only per-theme divergence in the ramp) — used behind aching cards; alpha is nudged up on ink so the tint survives:

| Token | DAY | NIGHT |
|---|---|---|
| `u0-soft` | `rgba(47,184,168,.12)` | `rgba(47,184,168,.16)` |
| `u2-soft` | `rgba(233,164,59,.14)` | `rgba(233,164,59,.18)` |
| `u3-soft` | `rgba(232,112,58,.16)` | `rgba(232,112,58,.20)` |
| `u4-soft` | `rgba(214,69,51,.16)` | `rgba(214,69,51,.22)` |

**Scoping rules (the signature):**
- **Aggregate → capped ambient halo.** An edge-lit inset glow whose maximum is `u2`. Implementation clamps the halo urgency: `haloU = min(aggregateUrgency, 2)`.
- **Acute → concentrated card warmth.** The single most-urgent item's card washes to its true `u`, up to `u4`, plus a **left urgency stripe** whose *shape* changes with urgency (solid → dashed → tighter dashes) so urgency is legible in form, not color alone.

### 1.3 Semantic status tokens — DISTINCT from the ramp

These drive **chips, validation, banners, switches** and any explicit status label. They deliberately reuse ramp *hues* at the endpoints (so the world feels coherent) but are a **separate, named set** and are **never** used as chart data series.

| Token | Role | Base hex | DAY text-safe | NIGHT text-safe |
|---|---|---|---|---|
| `ok` | success / healthy | `#2FB8A8` | `#1F8F82` (`accent-ink`) | `#3ED6C4` |
| `warn` | caution / due-soon | `#E9A43B` | `#9A6B12` | `#F0BD6A` |
| `crit` | error / overdue / destructive | `#D64533` | `#A5352A` | `#F08A7C` |

> The **base hex** is for fills, dots and icons; the **text-safe** column is the color to use when the semantic hue must carry *text* on `surface`/`surface-2` and still pass AA. Pills follow this split (tinted background from the ramp wash + text-safe foreground).

### 1.4 CRITICAL accessibility: status is never color-only

Because PULSE encodes status in emotional **color**, every status is **also** encoded in at least two of: **icon**, **text label**, **position/shape**.

| State | Color (mood) | Icon | Text label | Shape / position |
|---|---|---|---|---|
| Healthy (`ok`) | firouzeh | ✓ check | "Healthy" / "OK" | solid stripe; item sits low in list |
| Due soon (`warn`) | saffron | △ triangle-alert | "Due soon" | dashed stripe (wide); rises in list |
| Overdue (`crit`) | ember/pomegranate | ⨯ / bell | "Overdue" | dashed stripe (tight); top of list, surfaced as *the one ache* |

Greyscale test: the app must remain fully operable with all `u*`/semantic hues mapped to grey. If a state is only distinguishable by hue, it is a bug. See [`../../flutter/15-accessibility-dynamic-type.md`](../../flutter/15-accessibility-dynamic-type.md).

### 1.5 Accent & per-vehicle accent

- **System accent** `accent = #2FB8A8` (firouzeh); ink-safe variant `accent-ink` = `#1F8F82` (day) / `#3ED6C4` (night). Secondary `secondary = #E9A43B` (saffron).
- **Per-vehicle accent.** Each vehicle carries its own accent chosen at onboarding, used **only for identity affordances** (vehicle-switcher dot, garage header, timeline nodes) — **never** for status. The pulse-line hero uses the *active vehicle's* accent.

Offered vehicle palette (all pre-validated on both themes; each has a paired ink-safe tone for text/stroke):

| Name | Hex | Ink-safe (for stroke/text) |
|---|---|---|
| Firouzeh (default) | `#2FB8A8` | `#1F8F82` |
| Lapis | `#3E6BE8` | `#3E6BE8` |
| Saffron | `#E9A43B` | `#9A6B12` |
| Plum | `#B65CC4` | `#9A45A8` |
| Pistachio | `#7FBF6A` | `#4E8C3C` |

> **Guardrail:** because a vehicle accent could collide with the temperature language (e.g. a saffron car), status is *always* read from stripe-shape + icon + label, and the aching-card wash uses the `u*` ramp, not the vehicle accent. The vehicle accent never tints a status surface.

### 1.6 CSS custom properties (reference)

```css
:root{
  /* DAY (warm paper) — default */
  --base:#F4EFE7;  --surface:#FFFFFF;  --surface-2:#FBF8F2;
  --hairline:#E4DCD0; --hairline-strong:#D6CBBB;
  --text:#1B242E; --text-2:#5E6B74; --text-3:#8A949B;

  /* Temperature 5-stop (urgency 0–4) — shared both themes */
  --u0:#2FB8A8; --u1:#7FBF6A; --u2:#E9A43B; --u3:#E8703A; --u4:#D64533;
  --u0-soft:rgba(47,184,168,.12); --u2-soft:rgba(233,164,59,.14);
  --u3-soft:rgba(232,112,58,.16); --u4-soft:rgba(214,69,51,.16);

  /* Accent + semantic (semantic kept distinct from ramp) */
  --accent:#2FB8A8; --accent-ink:#1F8F82; --secondary:#E9A43B;
  --ok:#2FB8A8; --warn:#E9A43B; --crit:#D64533;

  /* Radii */
  --r-card:20px; --r-sheet:26px; --r-pill:999px;

  /* Elevation */
  --shadow:0 6px 24px rgba(20,30,40,.07);
  --shadow-lg:0 12px 40px rgba(20,30,40,.10);
  --grain-op:.05;
}
[data-theme="night"]{
  --base:#0E1317; --surface:#141A20; --surface-2:#182027;
  --hairline:#222A32; --hairline-strong:#2E3841;
  --text:#ECF1F3; --text-2:#98A4AD; --text-3:#6E7A83;
  --u0-soft:rgba(47,184,168,.16); --u2-soft:rgba(233,164,59,.18);
  --u3-soft:rgba(232,112,58,.20); --u4-soft:rgba(214,69,51,.22);
  --accent-ink:#3ED6C4;
  --shadow:0 0 0 1px #222A32;                 /* night = hairline, not drop-shadow */
  --shadow-lg:0 8px 30px rgba(0,0,0,.5), 0 0 0 1px #222A32;
  --grain-op:.06;
}
```

---

## 2. Typography

### 2.1 Font families & fallbacks

| Role | Family | Weights | Fallback stack | Notes |
|---|---|---|---|---|
| Latin UI (en/de/fr) | **Hanken Grotesk** | 400 / 600 | `ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif` | warm humanist grotesque; ships with tabular figures |
| Numerals | **Hanken Grotesk** (tabular) | 600 | `ui-monospace, "SF Mono", Menlo, monospace` | `font-variant-numeric: tabular-nums` **always on** for numbers |
| Arabic / Persian / Sorani Kurdish | **Vazirmatn** (variable) | 400 / 600 | `"Noto Sans Arabic", ui-sans-serif, system-ui, sans-serif` | ink-density matched to Hanken; full Kurdish coverage (ڕ ڵ ۆ ێ ە ھ); distinct Persian ۰۱۲۳ vs Eastern-Arabic ٠١٢٣ |
| Persian masthead (display) | **Noto Nastaliq Urdu** | 400 | `"Gulzar", serif` | true Nastaliq; masthead & milestones **only**. Needs `line-height ≥ 1.9` |
| Arabic masthead (display) | **Aref Ruqaa** | 400/700 | `serif` | Arabic milestone/masthead idiom — **not** conflated with Nastaliq |

> Script correctness is a hard rule: **Persian → Nastaliq**, **Arabic → Ruqaa**. Never letter-space or ALL-CAPS Arabic/Persian; give them extra line-height so dots/diacritics survive at UI sizes.

Bundle all fonts as **app assets** (offline-first; no network fonts). Register in `pubspec.yaml` and select at runtime by script — see [§6.4](#64-flutter-font--textstyle-mapping) and [`../../flutter/06-i18n-rtl-calendars.md`](../../flutter/06-i18n-rtl-calendars.md).

### 2.2 Type scale

| Role | Size / line-height (px) | Weight | Letter-spacing | tabular? | Usage |
|---|---|---|---|---|---|
| `hero-numeral` | **84 / 88** | 600 | `-0.04em` | ✅ | the single home vital (readiness score); **count-up** |
| `display` | 30 / 38 | 600 | `-0.02em` | — | screen titles ("Let's take your first reading") |
| `title` | 20 / 28 | 600 | `-0.01em` | — | card / section titles |
| `body` | 16 / 26 | 400 | `0` | — | paragraphs, row primary text |
| `label` | 13 / 20 | 600 | `0` | — | secondary labels, chips |
| `caption` | 12 / 18 | 500 | `0` | — | fine print, meta |
| `eyebrow` | 11 / 16 | 700 | `0.16em` upper | — | section eyebrows (**Latin only** — never on Arabic/Persian) |
| `entry-big` | 52 / 52 | 600 | `-0.03em` | ✅ | keypad live entry value |

**Tabular-nums rule:** every numeral that can *change* or that *aligns in columns* (hero vital, vitals row, keypad, chart labels, odometer, prices) uses tabular figures so digits never jitter during count-up and stay column-aligned.

### 2.3 Script-specific overrides & text expansion

| Concern | Rule |
|---|---|
| Arabic/Persian line-height | **+2px** over the Latin value at `body` and below (e.g. body 16/**28** in fa/ar) so diacritics/dots clear. |
| Hero numeral reflow | On **German** (long compounds) and **long Arabic**, the 84/88 hero **reflows to 60/64** rather than truncating/overflowing. Implement as a min/max-size fit, not a fixed downscale. |
| No caps / no tracking on RTL | `text-transform` and positive `letter-spacing` are **forbidden** on Arabic/Persian/Kurdish runs. Eyebrows drop their tracking+caps and fall back to a plain `label` in RTL. |
| Numerals are locale-driven | Persian `۰۱۲۳`, Eastern-Arabic `٠١٢٣`, Latin `0123`, Devanagari with lakh/crore (2-2-3) grouping — via `intl`, not hand-rolled. Decimal `٫` vs grouping `٬` explicitly distinguished (`1٫5 = 1.5`). |
| Expansion budget | Design all strings to tolerate **+35% width** (German) and full RTL mirroring without clipping; labels wrap to 2 lines before truncation. |

---

## 3. Spacing scale

**8px base grid.** Generous negative space is a brand value (one hero + hidden list). Half-step `4` is allowed for tight icon/text gaps.

| Token | px | Typical use |
|---|--:|---|
| `space-0` | 0 | reset |
| `space-half` | 4 | icon↔label gap, stripe insets |
| `space-1` | 8 | base unit; chip padding, keypad gap |
| `space-2` | 16 | card inner padding (y), row gaps |
| `space-3` | 24 | screen horizontal padding (`pad`) |
| `space-4` | 32 | section separation |
| `space-5` | 40 | hero top/bottom breathing room |
| `space-6` | 56 | large empty-state / footer separation |

**Tap targets (accessibility floor):**

| Element | Min | Target |
|---|--:|--:|
| Keypad key | 44 | 56 × 64 |
| Quick-add pill | — | 56 × 56 |
| Room-nav item | 48 | 48+ |
| Any tappable | 44 | — |

**Device frame reference:** 390 × 844 logical px, 8px grid.

---

## 4. Radii

| Token | px | Applied to |
|---|--:|---|
| `r-card` | 20 | cards, fields, fuel-toggle tiles |
| `r-sheet` | 26 | bottom-sheet top corners |
| `r-pill` | 999 | chips, pills, quick-add, switches, segmented control |
| (icon tiles) | 12 | row leading icon tiles |
| (keys / small) | 16 | keypad keys, vitals-row container |

---

## 5. Elevation & shadow

Two elevation languages, one per theme:

| Token | DAY | NIGHT |
|---|---|---|
| `shadow` (resting card) | `0 6px 24px rgba(20,30,40,.07)` | **hairline only:** `0 0 0 1px #222A32` |
| `shadow-lg` (sheet / phone) | `0 12px 40px rgba(20,30,40,.10)` | `0 8px 30px rgba(0,0,0,.5), 0 0 0 1px #222A32` |

**Rules**
- **Night uses hairlines + glow, not drop shadows.** Cards get borders; accent elements get a soft `drop-shadow` glow (pulse-line, active room icon).
- **Grain overlay is mandatory** on any element carrying an ambient `u*` tint or a large flat fill: a fractal-noise SVG at `--grain-op` (`.05` day / `.06` night), `mix-blend-mode: overlay`. This prevents OLED banding on the halo and card washes. See [`../../flutter/10-performance-rendering.md`](../../flutter/10-performance-rendering.md) for the Flutter equivalent (a cached noise `ImageShader` / `BlendMode.overlay` layer, not a per-frame repaint).
- **The ambient halo** is an inset edge-glow, capped at `u2`:
  - `u0`: `inset 0 0 70px -30px rgba(47,184,168,.55)`
  - `u1`: `inset 0 0 80px -30px rgba(127,191,106,.55)`
  - `u2`: `inset 0 0 96px -26px rgba(233,164,59,.62)` — **maximum; never exceeded.**

---

## 6. Motion tokens

| Token | Value | Applied to |
|---|---|---|
| `dur-breath` | **4000ms**, `ease-in-out`, infinite | hero pulse-line breathing + sweep |
| `dur-exhale` | **800ms**, `cubic-bezier(.2,.7,.2,1)` | "the exhale" — card cools one notch, halo eases ≤1 stop, soft settle |
| `dur-count` | **600ms**, `ease-out` | count-up numerals, **on real change only** |
| `dur-sheet` | **380ms**, `cubic-bezier(.2,.7,.2,1)` | keypad/bottom-sheet slide |
| `dur-fast` | **200ms**, `ease-out` | switches, segmented control, small toggles |
| `dur-halo` | **800ms**, `cubic-bezier(.2,.7,.2,1)` | ambient halo transitions |
| `ease-exhale` | `cubic-bezier(0.2,0.7,0.2,1)` | the house "settle" curve (decelerate, soft landing) |
| `ease-standard` | `cubic-bezier(0.2,0.0,0.2,1)` | generic enter/exit |

**Signature interactions**
- **Breath.** The pulse-line scales `scaleY .94 → 1.06` and opacity `.9 → 1` over 4s; a dot sweeps across. **Reduced-motion → fully static** pulse-line (no scale, no sweep). See below.
- **The exhale.** Fired on *every* pain-relieving action (log / clear / close): (1) the aching card's `u` drops one notch with `ease-exhale`, (2) the aggregate halo eases down **at most one stop** (and only down to its cap), (3) a soft vertical settle, (4) a **weighted haptic** on device.
- **Count-up.** Numerals roll from previous value to new value in `dur-count`, **never** re-counting from 0 on every visit — only on genuine value change.
- **Haptics** are the accessible feedback channel, **identical byte-for-byte in LTR and RTL** and preserved under reduced-motion (a visual settle stands in only for the HTML mockups). See [`./03-motion-haptics.md`](./04-motion-rtl-accessibility.md).

```css
@media (prefers-reduced-motion: reduce){
  .breathe, .sweep, .part-hot { animation: none !important; }
  /* count-up snaps to final value; exhale becomes an instant tint change + haptic */
}
```

---

## 7. Flutter mapping

Tokens live in a plain Dart class (no dependency), then feed `ColorScheme` + `TextTheme` inside `ThemeData`. Theme switching via a Riverpod `ThemeMode` provider (a plain `ValueNotifier<ThemeMode>` also suffices for just the toggle) — see [`../../flutter/02-state-management.md`](../../flutter/02-state-management.md) if present, and [`../../flutter/15-accessibility-dynamic-type.md`](../../flutter/15-accessibility-dynamic-type.md) for dynamic-type behavior.

### 7.1 Raw token class

```dart
import 'package:flutter/material.dart';

/// Immutable, theme-agnostic raw values. UI reads THESE, never hex literals.
abstract final class PulseTokens {
  // ---- Temperature ramp (urgency 0..4), shared across themes ----
  static const List<Color> temp = [
    Color(0xFF2FB8A8), // u0 firouzeh — calm/healthy
    Color(0xFF7FBF6A), // u1 pistachio — watch
    Color(0xFFE9A43B), // u2 saffron   — due soon  (HALO CAP)
    Color(0xFFE8703A), // u3 ember     — due/overdue
    Color(0xFFD64533), // u4 pomegranate — aching (card only)
  ];
  /// Aggregate halo may never exceed u2.
  static const int haloMaxUrgency = 2;
  static Color halo(int aggregateUrgency) =>
      temp[aggregateUrgency.clamp(0, haloMaxUrgency)];
  static Color card(int urgency) => temp[urgency.clamp(0, 4)];

  // ---- Vehicle accent palette (identity only, never status) ----
  static const List<Color> vehicleAccents = [
    Color(0xFF2FB8A8), Color(0xFF3E6BE8), Color(0xFFE9A43B),
    Color(0xFFB65CC4), Color(0xFF7FBF6A),
  ];

  // ---- Radii ----
  static const double rCard = 20, rSheet = 26, rPill = 999;
  static const double rIconTile = 12, rSmall = 16;

  // ---- Spacing (8px grid; 4 = half step) ----
  static const double s0=0, sHalf=4, s1=8, s2=16, s3=24, s4=32, s5=40, s6=56;

  // ---- Tap targets ----
  static const double tapMin = 44, quickAdd = 56, roomNav = 48;

  // ---- Motion ----
  static const Duration breath = Duration(milliseconds: 4000);
  static const Duration exhale = Duration(milliseconds: 800);
  static const Duration count  = Duration(milliseconds: 600);
  static const Duration sheet  = Duration(milliseconds: 380);
  static const Duration fast   = Duration(milliseconds: 200);
  static const Cubic easeExhale = Cubic(0.2, 0.7, 0.2, 1.0);
  static const Cubic easeStd    = Cubic(0.2, 0.0, 0.2, 1.0);

  // ---- Grain opacity ----
  static const double grainDay = .05, grainNight = .06;
}

/// Per-theme neutrals + semantic text-safe tones, resolved by brightness.
class PulseColors {
  final Color base, surface, surface2, hairline, hairlineStrong;
  final Color text, text2, text3;
  final Color accentInk;               // ink-safe accent for strokes/labels
  final Color okText, warnText, critText; // AA-safe semantic text tones
  const PulseColors._({
    required this.base, required this.surface, required this.surface2,
    required this.hairline, required this.hairlineStrong,
    required this.text, required this.text2, required this.text3,
    required this.accentInk,
    required this.okText, required this.warnText, required this.critText,
  });

  static const light = PulseColors._(
    base: Color(0xFFF4EFE7), surface: Color(0xFFFFFFFF), surface2: Color(0xFFFBF8F2),
    hairline: Color(0xFFE4DCD0), hairlineStrong: Color(0xFFD6CBBB),
    text: Color(0xFF1B242E), text2: Color(0xFF5E6B74), text3: Color(0xFF8A949B),
    accentInk: Color(0xFF1F8F82),
    okText: Color(0xFF1F8F82), warnText: Color(0xFF9A6B12), critText: Color(0xFFA5352A),
  );
  static const dark = PulseColors._(
    base: Color(0xFF0E1317), surface: Color(0xFF141A20), surface2: Color(0xFF182027),
    hairline: Color(0xFF222A32), hairlineStrong: Color(0xFF2E3841),
    text: Color(0xFFECF1F3), text2: Color(0xFF98A4AD), text3: Color(0xFF6E7A83),
    accentInk: Color(0xFF3ED6C4),
    okText: Color(0xFF3ED6C4), warnText: Color(0xFFF0BD6A), critText: Color(0xFFF08A7C),
  );
}

/// Expose neutrals to the widget tree via ThemeExtension so widgets read
/// Theme.of(context).extension<PulseColorsExt>()!  (ColorScheme can't hold them all).
@immutable
class PulseColorsExt extends ThemeExtension<PulseColorsExt> {
  final PulseColors c;
  const PulseColorsExt(this.c);
  @override PulseColorsExt copyWith({PulseColors? c}) => PulseColorsExt(c ?? this.c);
  @override PulseColorsExt lerp(ThemeExtension<PulseColorsExt>? o, double t) => this; // snap on theme switch
}
```

### 7.2 ColorScheme (light & dark)

```dart
const _seedTurquoise = Color(0xFF2FB8A8);

final ColorScheme pulseLightScheme = const ColorScheme(
  brightness: Brightness.light,
  primary:   Color(0xFF1F8F82),  // accent-ink (AA on paper)
  onPrimary: Color(0xFF04241F),
  secondary: Color(0xFFE9A43B),  // saffron
  onSecondary: Color(0xFF2A1C00),
  error:     Color(0xFFA5352A),  // crit text-safe
  onError:   Color(0xFFFFFFFF),
  surface:   Color(0xFFFFFFFF),
  onSurface: Color(0xFF1B242E),
  // extended neutrals live in PulseColorsExt (base, surface-2, hairlines, text-2/3)
);

final ColorScheme pulseDarkScheme = const ColorScheme(
  brightness: Brightness.dark,
  primary:   Color(0xFF3ED6C4),
  onPrimary: Color(0xFF04241F),
  secondary: Color(0xFFE9A43B),
  onSecondary: Color(0xFF2A1C00),
  error:     Color(0xFFF08A7C),
  onError:   Color(0xFF2A0B07),
  surface:   Color(0xFF141A20),
  onSurface: Color(0xFFECF1F3),
);
```

### 7.3 TextTheme

`tabular` is applied via `fontFeatures: [FontFeature.tabularFigures()]` on every numeric style. Line-height is `height = lineHeightPx / sizePx`.

```dart
const _latin = 'HankenGrotesk';

TextTheme buildPulseTextTheme(Color onSurface, Color onSurface2) {
  const tab = [FontFeature.tabularFigures()];
  return TextTheme(
    // hero-numeral 84/88 — see PulseHeroNumeral widget for German/AR reflow to 60/64
    displayLarge:  TextStyle(fontFamily: _latin, fontSize: 84, height: 88/84,
                             fontWeight: FontWeight.w600, letterSpacing: -0.04*84,
                             fontFeatures: tab, color: onSurface),
    // display 30/38
    displayMedium: TextStyle(fontFamily: _latin, fontSize: 30, height: 38/30,
                             fontWeight: FontWeight.w600, letterSpacing: -0.02*30, color: onSurface),
    // title 20/28
    titleLarge:    TextStyle(fontFamily: _latin, fontSize: 20, height: 28/20,
                             fontWeight: FontWeight.w600, letterSpacing: -0.01*20, color: onSurface),
    // body 16/26  (fa/ar → height 28/16 applied by locale override)
    bodyLarge:     TextStyle(fontFamily: _latin, fontSize: 16, height: 26/16,
                             fontWeight: FontWeight.w400, color: onSurface),
    // label 13/20
    labelLarge:    TextStyle(fontFamily: _latin, fontSize: 13, height: 20/13,
                             fontWeight: FontWeight.w600, color: onSurface2),
    // caption 12/18
    bodySmall:     TextStyle(fontFamily: _latin, fontSize: 12, height: 18/12,
                             fontWeight: FontWeight.w500, color: onSurface2),
  );
}
```

**Locale/script override.** Wrap the app in a `Localizations`-aware builder that swaps `fontFamily → 'Vazirmatn'` and **adds +2 to line-height** at `bodyLarge`/`labelLarge`/`bodySmall` for `fa`, `ar`, `ckb`, and drops eyebrow tracking/caps. Masthead widgets pick `'NotoNastaliqUrdu'` (Persian) or `'ArefRuqaa'` (Arabic) explicitly. Numerals go through `intl.NumberFormat` for locale digits + `٫`/`٬` disambiguation — see [`../../flutter/06-i18n-rtl-calendars.md`](../../flutter/06-i18n-rtl-calendars.md).

### 7.4 Flutter font / TextStyle mapping

```yaml
# pubspec.yaml — all fonts bundled (offline-first, no network fonts)
flutter:
  fonts:
    - family: HankenGrotesk
      fonts: [{asset: assets/fonts/HankenGrotesk-Regular.ttf, weight: 400},
              {asset: assets/fonts/HankenGrotesk-SemiBold.ttf, weight: 600}]
    - family: Vazirmatn      # variable; full Persian/Arabic/Sorani coverage
      fonts: [{asset: assets/fonts/Vazirmatn[wght].ttf}]
    - family: NotoNastaliqUrdu
      fonts: [{asset: assets/fonts/NotoNastaliqUrdu-Regular.ttf}]
    - family: ArefRuqaa
      fonts: [{asset: assets/fonts/ArefRuqaa-Regular.ttf, weight: 400},
              {asset: assets/fonts/ArefRuqaa-Bold.ttf, weight: 700}]
```

### 7.5 Assembling ThemeData

```dart
ThemeData pulseTheme(Brightness b) {
  final cs = b == Brightness.dark ? pulseDarkScheme : pulseLightScheme;
  final pc = b == Brightness.dark ? PulseColors.dark : PulseColors.light;
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: pc.base,
    textTheme: buildPulseTextTheme(pc.text, pc.text2),
    extensions: [PulseColorsExt(pc)],
    splashFactory: NoSplash.splashFactory, // calm; the exhale is our feedback, not ripples
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    }),
  );
}
```

### 7.6 CustomPainter sketch — breathing vitals pulse-line

Charts and the hero are `CustomPainter` (no chart library). The breath is driven by an `AnimationController`; reduced-motion holds it static. Full chart-token specs live in [`./04-charts.md`](./02-components.md); performance guidance in [`../../flutter/10-performance-rendering.md`](../../flutter/10-performance-rendering.md).

```dart
class VitalsPulsePainter extends CustomPainter {
  VitalsPulsePainter({required this.accent, required this.breath}) : super(repaint: breath);
  final Color accent;
  final Animation<double> breath; // 0..1..0 over 4s; a constant(1.0) under reduced-motion

  @override
  void paint(Canvas canvas, Size size) {
    // scaleY 0.94..1.06 about the vertical center (direction-agnostic: NO x-flip in RTL)
    final s = 0.94 + 0.12 * breath.value;
    canvas.save();
    canvas.translate(0, size.height / 2);
    canvas.scale(1, s);
    canvas.translate(0, -size.height / 2);

    final path = _ecgPath(size); // fixed ECG-like seismograph geometry
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3); // soft glow
    canvas.drawPath(path, line);
    canvas.restore();
  }
  @override
  bool shouldRepaint(VitalsPulsePainter old) => old.accent != accent;
}
```

### 7.7 Widget-tree sketch — the aching card (redundant status)

```
PulseCard(urgency: u)                     // washes to temp[u], border tints
 └ Row
    ├ UrgencyStripe(u)                     // SHAPE encodes urgency (solid→dashed→tight)
    ├ Column
    │   ├ StatusPill(icon: warnIcon,       // ICON + TEXT (never color-only)
    │   │            label: 'Due soon',
    │   │            fg: pc.warnText)       // AA-safe text tone
    │   ├ Text('Oil & filter', style: titleLarge)
    │   └ Text('Due in 850 km or 40 days', style: labelLarge)
    └ ExhaleButton(onDone: () {            // fires THE EXHALE
        controller.cool(item);             //   card u -= 1, halo eases ≤1 stop
        Haptics.weightedSettle();          //   identical LTR/RTL, survives reduced-motion
      })
```

---

## 8. Token quick-reference (cheat sheet)

| Category | Values |
|---|---|
| **Base / surface / surface-2** | `#F4EFE7 / #FFFFFF / #FBF8F2` (day) · `#0E1317 / #141A20 / #182027` (night) |
| **Text 1/2/3** | `#1B242E / #5E6B74 / #8A949B` · `#ECF1F3 / #98A4AD / #6E7A83` |
| **Hairline / strong** | `#E4DCD0 / #D6CBBB` · `#222A32 / #2E3841` |
| **Temperature u0→u4** | `#2FB8A8 · #7FBF6A · #E9A43B · #E8703A · #D64533` (halo cap = u2) |
| **Semantic ok/warn/crit** | base `#2FB8A8 / #E9A43B / #D64533`; text-safe day `#1F8F82 / #9A6B12 / #A5352A` |
| **Radii** | card 20 · sheet 26 · pill 999 · icon-tile 12 · small 16 |
| **Spacing** | 4 · 8 · 16 · 24 · 32 · 40 · 56 |
| **Type sizes/lh** | 84/88 · 30/38 · 20/28 · 16/26 · 13/20 · 12/18 (fa/ar +2 lh; hero→60/64 on de/long-ar) |
| **Motion** | breath 4000 · exhale 800 `(.2,.7,.2,1)` · count 600 · sheet 380 · fast 200 |
| **Tap targets** | key 44/56×64 · quick-add 56 · room-nav 48 |
