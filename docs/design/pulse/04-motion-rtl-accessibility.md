# 🌬️ Motion, RTL & Accessibility

> **PULSE** renders your car's health as a living **vitals pulse-line**: one breathing vital, no visible list, and an emotional "temperature" that concentrates the *ache* on the card that needs care while the aggregate stays a **capped ambient halo**. Every completed action pays off with **"the exhale"** — a soft settle, one notch of cooling, and a haptic. This document is the **implementation contract** for the three places that metaphor is most likely to break: **motion**, **bidirectional / multi-script layout**, and — most critically — **accessibility**, because PULSE deliberately encodes status in *warm colour*, and colour can never be the only channel.

📍 Part of the **PULSE design system** · siblings: [Overview & Philosophy](./00-design-system.md) · [Foundations & Tokens](./01-tokens.md) · [Color & Typography](./01-tokens.md) · [Components & Rooms](./02-components.md)
🔧 Engineering: [i18n, RTL & Calendars](../../flutter/06-i18n-rtl-calendars.md) · [Performance & Rendering](../../flutter/10-performance-rendering.md) · [Accessibility & Dynamic Type](../../flutter/15-accessibility-dynamic-type.md) · Product: [Overview](../../overview.md)

---

## The one rule that governs this whole document

> **Motion, warmth, and colour are DECORATION. State must be fully legible with all three switched off.**

Every animation has a `prefers-reduced-motion` (Flutter: `MediaQuery.disableAnimationsOf(context)`) fallback that preserves meaning. Every warm tint is mirrored by an **icon + text label + shape + position**. If a user cannot see colour, cannot perceive motion, and is listening to a screen reader, they must still get the complete answer to *"is my car OK, and what needs me?"* This is not a nicety in PULSE — it is a **structural requirement**, because the concept's signature move is to carry status in emotional temperature.

---

## 1. Motion signatures

PULSE has exactly **four** authored motions plus one device-only channel (haptics). They are deliberately few; restraint is the brand. All durations/curves below are **tokens** — define them once and reference them; never inline a magic number.

### 1.0 Motion tokens

```css
/* CSS custom properties — prototype / web reference */
:root {
  --motion-breathe-dur:      4000ms;
  --motion-breathe-ease:     cubic-bezier(.37,0,.63,1);   /* symmetric ease-in-out */
  --motion-exhale-settle:    420ms;
  --motion-exhale-ease:      cubic-bezier(.2,.7,.2,1);    /* decel, gentle overshoot-free */
  --motion-cool-dur:         520ms;                        /* one-notch temperature ramp */
  --motion-cool-ease:        cubic-bezier(.4,0,.2,1);
  --motion-countup-dur:      600ms;
  --motion-countup-ease:     cubic-bezier(0,0,.2,1);       /* ease-out */
  --motion-room-dur:         320ms;
  --motion-room-ease:        cubic-bezier(.2,0,0,1);       /* emphasized decelerate */
  --motion-halo-ease-dur:    600ms;                        /* aggregate halo drift */
}
```

```dart
// packages/design_system/lib/src/motion_tokens.dart
abstract final class PulseMotion {
  // Durations
  static const breathe   = Duration(milliseconds: 4000);
  static const exhale    = Duration(milliseconds: 420);
  static const cool      = Duration(milliseconds: 520);
  static const countUp   = Duration(milliseconds: 600);
  static const room      = Duration(milliseconds: 320);
  static const halo      = Duration(milliseconds: 600);

  // Curves
  static const breatheEase = Cubic(0.37, 0.0, 0.63, 1.0);
  static const exhaleEase  = Cubic(0.2, 0.7, 0.2, 1.0);
  static const coolEase    = Cubic(0.4, 0.0, 0.2, 1.0);
  static const countUpEase = Cubic(0.0, 0.0, 0.2, 1.0);
  static const roomEase    = Cubic(0.2, 0.0, 0.0, 1.0);
}
```

> **Reduced-motion global switch.** Wrap the app so any animation controller can ask one question:
> ```dart
> bool reduceMotion(BuildContext c) =>
>     MediaQuery.maybeDisableAnimationsOf(c) ?? false;
> ```
> When `true`: the breath is static, count-up snaps to final, the exhale becomes an instant colour swap + haptic, room transitions become an instant cut with a 1-frame cross-fade. **No meaning is lost** because every state also carries icon+label+shape (§4).

---

### 1.1 The breath loop — the living hero

The **vitals pulse-line** (ECG-like seismograph) breathes on a ~4 s cycle so the car feels *alive* without demanding attention. It is **direction-agnostic** (symmetric waveform) and therefore identical in LTR and RTL — no mirroring.

| Property | Value |
|---|---|
| Cycle | `--motion-breathe-dur` = **4000 ms**, `--motion-breathe-ease` |
| What animates | Amplitude scale of the waveform **±6%** and a **0.85→1.0 opacity** on the leading pulse tip; **the baseline never moves** (keeps numerals stable) |
| Frame budget | Repaint only the pulse layer via `RepaintBoundary`; target **≤2 ms/frame** on the painter (see [Performance & Rendering](../../flutter/10-performance-rendering.md)) |
| Amplitude modulation | Breath amplitude is scaled by aggregate urgency: calm = subtle (±4%), stop-2 halo = slightly quicker/wider (±8%) — a **redundant, non-colour urgency cue** |

**CustomPainter sketch** — drive one `AnimationController`, not a per-point timer:

```dart
class PulseLinePainter extends CustomPainter {
  PulseLinePainter({required this.phase, required this.urgency, required this.color})
      : super(repaint: null); // controller passed via AnimatedBuilder

  final double phase;    // 0..1 from the 4s controller (or fixed 0.5 when reduced)
  final int urgency;     // 0..4 aggregate → drives amplitude, NOT just colour
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final breath = 1 + 0.06 * math.sin(phase * 2 * math.pi) * (0.6 + urgency * 0.1);
    final path = Path();
    // ... seismograph polyline, y scaled by `breath`, baseline fixed ...
    canvas.drawPath(path, Paint()
      ..color = color ..style = PaintingStyle.stroke ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(PulseLinePainter old) =>
      old.phase != phase || old.urgency != urgency || old.color != color;
}
```

```dart
// Static fallback: pass a fixed phase, don't start the controller.
final controller = AnimationController(vsync: this, duration: PulseMotion.breathe);
if (!reduceMotion(context)) controller.repeat();
```

**Reduced-motion fallback:** waveform frozen at its resting amplitude (`phase = 0.5`), full opacity. The vital number and its status glyph are unchanged, so the state reads identically.

---

### 1.2 The exhale — the payoff on every completion

Fired on **every pain-relieving action**: log fuel, mark a reminder done, clear/close an ache. Three synchronized channels:

| Channel | Spec | Reduced-motion | Colour-blind |
|---|---|---|---|
| **Settle** | Card scales `1.0 → 0.985 → 1.0` over `--motion-exhale-settle` (**420 ms**, `exhaleEase`); a 1px hairline "relax" | Instant, no scale | n/a (motion) |
| **Cool** | Card temperature ramps **exactly one urgency stop down** over `--motion-cool-dur` (**520 ms**); aggregate halo eases down **at most one stop** | Instant colour swap | Icon+label also update (§4) — the *word* changes from "Due" → "OK", not just the hue |
| **Haptic** | `HapticFeedback.mediumImpact()` (weighted, single) — the **accessible confirmation channel**, identical byte-for-byte LTR/RTL | **Preserved** (haptics survive reduced-motion) | **Preserved** |

> **Critical:** the exhale's cooling is never the *only* signal that an action succeeded. The status **label and icon flip** in the same frame the cool begins (e.g. the pill goes from `⚠ Overdue` warm to `✓ Done` cool). A user who can't see the colour transition still sees the checkmark and reads "Done"; a blind user hears the semantic announcement (§4.3) and feels the haptic.

```dart
Future<void> exhale(BuildContext c, {required int fromStop}) async {
  HapticFeedback.mediumImpact();                 // always, even reduced-motion
  final toStop = math.max(0, fromStop - 1);
  status.value = status.value.copyWith(stop: toStop); // icon+label update NOW
  if (reduceMotion(c)) return;                   // no scale/ramp animation
  await settleController.forward(from: 0);        // 420ms scale dip
}
```

---

### 1.3 Count-up numerals — PULSE owns this motion

The hero vital and key figures **roll up** on **first reveal and on real change only** — never re-counting from 0 on every visit (that would be noise, not delight).

| Property | Value |
|---|---|
| Duration | `--motion-countup-dur` = **600 ms**, `ease-out` |
| Figures | **Tabular** (Hanken Grotesk / Vazirmatn tnum) so digits don't jitter; fixed width per column |
| Trigger | Only when the **canonical value actually changes** (guard on previous value); locale-formatted numerals count in the **display script** (Persian ۰۱۲۳ etc., §3) |
| Direction | The *count* is a value animation, not a spatial one → **identical in LTR/RTL**; alignment follows text direction (§2) |

```dart
class CountUpNumeral extends StatelessWidget {
  final num value; final String Function(num) format; // locale-aware
  @override Widget build(BuildContext c) {
    if (reduceMotion(c)) return Text(format(value), style: _tabular);
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),                        // only re-animates on REAL change
      tween: Tween(begin: _lastShown, end: value.toDouble()),
      duration: PulseMotion.countUp, curve: PulseMotion.countUpEase,
      builder: (_, v, __) => Text(format(v), style: _tabular),
    );
  }
}
```

**Reduced-motion fallback:** value is printed at its final formatted string immediately. The number is never *conveyed by* the animation, so nothing is lost.

---

### 1.4 Room transitions — Cockpit / Garage / Pit-lane

The three **Rooms** are spatial siblings, not a stack. Moving between them is a **shared-axis** slide (horizontal), reinforcing that they are *places*, not pushed screens.

| Property | Value |
|---|---|
| Duration | `--motion-room-dur` = **320 ms**, `roomEase` |
| Transform | Outgoing room slides **20% + fades to 0**, incoming slides in from opposite edge + fades 0→1 |
| **Axis direction** | **Follows text direction.** LTR: Pit-lane is to the *right*, Garage to the *left* of Cockpit. RTL: mirrored — see §2.4. Use `AxisDirection` derived from `Directionality.of(context)`, **not** a hard-coded sign |
| Persistent element | The quick-add pill and room-nav do **not** transition — they are chrome, anchored (mirrored position in RTL) |

**Reduced-motion fallback:** instant cut with a **120 ms opacity cross-fade** (no slide). Room identity is carried by the labelled nav indicator, not the motion, so orientation is preserved.

```dart
PageTransitionsBuilder roomTransition(TextDirection dir) => SharedAxisTransitionBuilder(
  transitionType: SharedAxisTransitionType.horizontal, // sign resolved from `dir`
);
```

---

### 1.5 Haptics — the direction-agnostic accessible channel

Haptics are a **first-class feedback language**, not garnish. They are **native-only** (a visual settle stands in for the HTML mockups), **identical byte-for-byte in LTR and RTL**, and **preserved under reduced-motion**.

| Event | Haptic |
|---|---|
| Exhale / completion | `mediumImpact` (weighted, single) |
| Snooze | `lightImpact` |
| Skip / dismiss | `selectionClick` |
| Keypad digit | `selectionClick` (can be disabled in settings) |
| Reaching urgency stop-4 on a card (new acute ache) | double `lightImpact` (a "flutter") |

Provide a **"Reduce haptics"** setting distinct from the OS reduced-motion flag; some users want motion but not vibration and vice-versa.

---

## 2. RTL & bidirectional layout

PULSE supports **six locales**: `fa`, `ar`, `ckb` (RTL) and `en`, `de`, `fr` (LTR). RTL is **first-class by construction** — the symmetric pulse-line and edge-halo need no mirroring — and **first-class by expression**: a Persian **Nastaliq masthead**, **Jalali-primary** framing, and a **Nowruz-aware motif** so the RTL build is authored, not merely reflected. Geometry is **Directional-only from module #1** (see [i18n, RTL & Calendars](../../flutter/06-i18n-rtl-calendars.md)).

### 2.1 Golden rule of mirroring

> Use **`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `start`/`end`** everywhere. A raw `left`/`right`, `Alignment.centerRight`, or a hard-coded `Offset` sign is a **bug** and must fail code review / the RTL golden test.

### 2.2 What flips vs. what holds

| Element | Flips in RTL? | Rationale |
|---|---|---|
| Page layout, reading order, list start-edge | ✅ | Standard bidi |
| Room-nav order & room slide axis | ✅ | Places live in reading order (§2.4) |
| Quick-add pill anchor | ✅ | Thumb-reach start-edge follows direction |
| Directional glyphs (chevrons, back, trend arrows, "next service") | ✅ | Point *with* reading flow |
| Progress / cadence heatmap fill direction | ✅ | Time reads start→end |
| **Vitals pulse-line waveform** | ❌ | Symmetric & direction-agnostic — an ECG has no handedness |
| **Checkmarks (✓)** | ❌ | A checkmark is a fixed symbol, not directional |
| **Logo / masthead wordmark** | ❌ | Brand mark is invariant (its *placement* mirrors, glyph does not) |
| **The exhale, haptics, breath** | ❌ | Identical across directions by design |
| **Numbers, VIN, plates, odometer, currency amounts** | ❌ (internally LTR) | Bidi-isolated — see §2.3 |
| Non-directional icons (heart, oil-drop, battery, wrench) | ❌ | No inherent handedness |

### 2.3 Bidi isolation — plates, VIN, numbers, mixed strings

Numeric and Latin-technical runs (VIN, licence plates, odometer, `1.5 L`, prices, part numbers) are **intrinsically LTR** and must be **isolated** so they don't reorder or "jump" when embedded in RTL Persian/Arabic text.

- **Flutter:** wrap such runs in the framework's Unicode bidi isolation, or interpolate with **`⁨` (FSI) … `⁩` (PDI)** in the formatted string. `intl`'s `Bidi.enforceDirection` / directional formatters handle this; prefer letting the l10n layer emit isolated runs (see [i18n doc](../../flutter/06-i18n-rtl-calendars.md)).
- **Web/prototype:** `<bdi>` element, or CSS `unicode-bidi: isolate` / `dir="ltr"` on the numeric span.

```dart
// A plate/VIN inside RTL body text:
Text.rich(TextSpan(children: [
  const TextSpan(text: 'شماره شاسی: '),
  TextSpan(text: '⁨$vin⁩', style: _monoTabular), // FSI…PDI keeps VIN LTR
]));
```

| Data | Direction inside | Alignment of the field |
|---|---|---|
| VIN | LTR, mono/tabular | Follows paragraph direction (start-aligned) |
| Licence plate | LTR (even Arabic-script plates render as a unit — isolate) | start |
| Odometer / distance | LTR digits, **display numerals** (§3) | tabular, end-aligned in tables |
| Price / amount | LTR, currency symbol placement per `NumberFormat(locale)` | end-aligned in tables |
| Decimal keypad entry | `٫` decimal vs `٬` grouping explicitly distinguished (`1٫5` = 1.5) | see [i18n doc](../../flutter/06-i18n-rtl-calendars.md) |

### 2.4 Room order & nav in RTL

- **LTR** reading order: `Garage ↔ Cockpit ↔ Pit-lane` with Cockpit centred; Pit-lane ("what's due") sits toward the **end** edge.
- **RTL**: the whole strip mirrors — Pit-lane toward the **end** (left) edge, Garage toward **start** (right). Achieve this by laying the nav out with a **`Row` under `Directionality`** using logical order; do **not** reverse the list manually.
- The room **slide axis** derives its sign from `Directionality.of(context)` so "forward" always means "toward `end`."

### 2.5 The Nastaliq masthead placement

The calligraphic display accent is **script-correct, never conflated**:

| Script | Masthead / milestone face |
|---|---|
| Persian (`fa`) | **True Nastaliq** — `Noto Nastaliq Urdu` (or `Gulzar`). **Explicitly NOT Ruqaa.** |
| Arabic (`ar`) | **`Aref Ruqaa`** |
| Kurdish Sorani (`ckb`) | Vazirmatn display weight (Nastaliq not idiomatic for Sorani UI) |
| Latin (`en`/`de`/`fr`) | Hanken Grotesk display weight (no calligraphic masthead) |

Placement rules:

- The masthead sits at the **top start edge** of the Cockpit (mirrors in RTL) and is **decorative** — it is **not** the only place the app/vehicle name appears, and it carries an `excludeSemantics` wrapper with the plain name exposed separately (Nastaliq ligatures confuse TTS).
- Nastaliq needs **generous line-height and vertical breathing room** — reserve **≥1.8× line-height**; never letter-space, never all-caps, never clip ascenders/descenders (diacritics and dots must survive — see §4.4 dynamic type).
- Nastaliq is a **masthead/milestone flourish only** — never body, labels, or numerals (those are Vazirmatn, ink-density-matched to Hanken Grotesk).

---

## 3. Calendars & numerals

All dates are stored as **calendar-neutral UTC epoch millis** and **projected only at display** (see [i18n, RTL & Calendars](../../flutter/06-i18n-rtl-calendars.md)). PULSE never stores a formatted date.

### 3.1 Calendars

**Four** calendars are first-class; **Jalali is primary in RTL**:

| Calendar | Engine | Locale default | Month names |
|---|---|---|---|
| **Gregorian** | `intl` `DateFormat` | `en`, `de`, `fr` | Locale-correct |
| **Jalali (Shamsi)** | `shamsi_date` (jalaali-js) | **`fa` primary** | Nowruz-aware (فروردین…اسفند) |
| **Hijri** | `hijri` (Um Al-Qura) + user ±day offset | `ar` option | Locale-correct |
| **Hebrew** | (as specced, first-class) | option | Locale-correct |

- **Primary + secondary framing:** in `fa`, show Jalali large with a **muted Gregorian secondary** underneath for cross-reference (and vice-versa in `en`). Both derive from the same canonical epoch.
- **First-day-of-week** is locale/calendar-driven: **Saturday** (`fa`, `ar` common), **Monday** (`de`, `fr`, ISO), **Sunday** (`en-US`). Drive the cadence heatmap and any date picker from `MaterialLocalizations.firstDayOfWeekIndex` — never hard-code.
- **Nowruz-aware motif:** the Garage may surface a Nowruz seasonal accent when the Jalali year turns; purely decorative, never load-bearing.

```dart
String formatDate(DateTime utc, Locale locale) {
  switch (locale.languageCode) {
    case 'fa': return Jalali.fromDateTime(utc.toLocal()).formatter.let((f) => '${f.d} ${f.mN} ${f.y}');
    case 'ar': return HijriCalendar.fromDate(utc.toLocal()).toFormat('dd MMMM yyyy');
    default:   return DateFormat.yMMMMd(locale.toString()).format(utc.toLocal());
  }
}
```

### 3.2 Numerals

Numerals are a **presentation-only transform** via `NumberFormat(locale)`, with a **"Western digits" toggle**. **All numeric input is normalized to ASCII before any math or storage** (see [i18n doc](../../flutter/06-i18n-rtl-calendars.md)).

| Locale | Digits | Note |
|---|---|---|
| `fa` | Persian ۰۱۲۳۴۵۶۷۸۹ | **4/5/6 differ from Eastern-Arabic** (۴۵۶ vs ٤٥٦) |
| `ar` | Eastern-Arabic ٠١٢٣٤٥٦٧٨٩ | distinct from Persian |
| `ckb` | via Vazirmatn (verified coverage ڕ ڵ ۆ ێ ە ھ) | Persian-style digits |
| `en`/`de`/`fr` | Western 0123456789 | German uses `.`/`,` grouping/decimal |
| (Devanagari option) | ०१२३ | **Indian lakh/crore 2-2-3 grouping** |

- **Separators (RTL decimal):** the keypad explicitly distinguishes **`٫` decimal** from **`٬` grouping** — `1٫5` = 1.5. Never confuse them in parse or display.
- **Tabular figures** for all aligned/columnar data so digits line up regardless of script.
- **Count-up (§1.3)** animates in the **display script**.
- **Round-trip test:** every numeral formatter has a golden test that formats then re-parses to the identical canonical value in all six locales (see [Testing](../../flutter/11-testing.md) via the i18n doc).

---

## 4. Accessibility — the critical section

> **PULSE encodes status in emotional colour (warm = ache). Colour is therefore the ONE channel we may never rely on alone.** This section is a hard gate, enforced in CI (`meetsGuideline`, RTL + 1.5×/2.0× goldens — see [Accessibility & Dynamic Type](../../flutter/15-accessibility-dynamic-type.md)).

### 4.1 Mandatory redundant encoding — every status carries FOUR signals

For **every** urgency stop, status is encoded **four ways** (colour is the fifth, supporting, never sole):

| Urgency | Temperature (support only) | **Icon** (shape) | **Text label** | **Shape / fill** | **Position** |
|---|---|---|---|---|---|
| 0 · Healthy | firouzeh `#2FB8A8` | pulse ♡ (steady line) | **"Healthy" / "OK"** | solid pill, calm outline | bottom of Pit-lane / absent |
| 1 · Watch | pistachio `#7FBF6A` | eye / soft dot | **"Watch"** | solid pill | low in list |
| 2 · Due | saffron `#E9A43B` | clock ◔ | **"Due"** | pill + **thin ring** | rises in list |
| 3 · Overdue | ember `#E8703A` | triangle ⚠ | **"Overdue"** | pill + **hatch pattern** | near top |
| 4 · Acute | pomegranate `#D64533` | filled alert ▲ / heart-beat | **"Needs care now"** | filled + **dense hatch**, heavier weight | **top of list**, concentrated card |

Rules:

- **Never a colour-only chip.** Status pills always show **icon + word**. The prototype's warm halo is *ambient mood*; the **card's own pill states the status in text**.
- **Shape is monotonic with urgency** (outline → ring → hatch → dense hatch) so a fully colour-blind user reads severity from *pattern density* and *position*.
- **Position is a signal:** the single-vital home surfaces the *most acute* item; the hidden prioritized list is **sorted by urgency**, so *where* a card sits encodes *how* urgent — independently of hue.
- **Charts:** status hues (saffron/ember/pomegranate) are **reserved, never a data series**; any highlighted category uses a **hatch pattern + direct label** (redundant non-colour), and any ≥2-series chart carries a **legend** (see chart tokens in [Foundations & Tokens](./01-tokens.md)).

```dart
// Status is a value object; colour is derived LAST, never the source of truth.
class VitalStatus {
  final int urgency;               // 0..4 — the canonical signal
  String get label => const ['Healthy','Watch','Due','Overdue','Needs care now'][urgency];
  IconData get icon => const [Icons.favorite, Icons.visibility, Icons.schedule,
                              Icons.warning_amber, Icons.priority_high][urgency];
  ShapePattern get pattern => ShapePattern.values[urgency]; // outline→denseHatch
  Color color(PulseColors c) => c.temperature[urgency];     // decoration only
}
```

### 4.2 Contrast targets — both themes, WCAG AA (verified, not auto-flipped)

> **Emotional tint stays AMBIENT; text and controls always meet WCAG.** Warmth is mood, never signal degradation.

| Element | Target | Day (`#F4EFE7` base / `#FFFFFF` surface) | Night (`#0E1317` base / `#141A20` surface) |
|---|---|---|---|
| Body text | **≥4.5:1** | `#1B242E` on paper | `#ECF1F3` on ink |
| Secondary text | **≥4.5:1** | `#5E6B74` on paper ✓ | `#98A4AD` on ink ✓ |
| Large text (≥24px / ≥19px bold) | **≥3:1** | ✓ | ✓ |
| Non-text (icons, status ring, hairline-as-boundary, focus ring) | **≥3:1** | verify each temp stop's **icon/outline**, not the fill | dark steps **selected & validated on ink**, not auto-flipped |
| Status **text/icon** over a warm card | **≥4.5:1** | ink text over tint — verify at the *warmest* stop the card can reach (stop-4) | verify on ink-warm |

- **Warm tints are capped in luminance** so text over them never drops below AA — the aggregate halo maxes at **stop-2 saffron** and the field never goes full ember/pomegranate, which also protects the status bar / system chrome contrast.
- **Grain** is baked into every tint to kill OLED banding — verify grain does not reduce text contrast (it sits *behind* text layers).
- CI runs contrast checks on **all 5 stops × 2 themes × (text, icon, outline)** — a matrix, not a spot check.

### 4.3 Screen-reader semantics — the pulse-line & vitals

A `CustomPaint` pulse-line is **one opaque rectangle** to TalkBack/VoiceOver. It must be given an explicit, information-complete `Semantics` node — the *number and status*, never the waveform.

```dart
Semantics(
  container: true,
  label: 'Vehicle vitals',
  value: '$readinessValue percent. Status: ${status.label}. '
         '$acuteItemName needs care.',       // the ANSWER, spoken — not the shape
  liveRegion: true,                            // announce on real change (exhale)
  child: ExcludeSemantics(child: PulseLineHero(...)), // hide the decorative painter
)
```

- **Every vital / stat tile / chart** carries its own `Semantics` node with `label` (what it is) + `value` (the figure **in display numerals**, read correctly RTL) + status word. `MergeSemantics` groups a tile's number + label + icon into one readable unit.
- **The exhale announces:** on completion the status node is a `liveRegion`, so the SR speaks e.g. *"Oil change. Done. Now healthy."* — the payoff is audible, matching the haptic.
- **Count-up is not read digit-by-digit:** expose the **final value** to semantics immediately; the visual roll is `ExcludeSemantics`.
- **The hidden list** is reachable by SR at the same swipe affordance, and its **sort order = urgency**, so traversal order itself communicates priority.
- **Masthead** Nastaliq is `ExcludeSemantics`; the plain vehicle/app name is exposed on a sibling node (TTS mangles Nastaliq ligatures).
- Focus & traversal order **mirror in RTL** (`FocusTraversalGroup`); the app-lock (PIN/biometric) is fully SR-operable.

### 4.4 Dynamic type — up to 2×

Every layout survives `MediaQuery.textScaler` from **1.0 to 2.0** without clipping (CI golden dimensions at **1.5× and 2.0×**, see [Accessibility & Dynamic Type](../../flutter/15-accessibility-dynamic-type.md)).

- **Hero numeral reflows:** `84/88` → **`60/64`** on German/long-Arabic expansion *and* under large text scale — the type scale specifies this fallback; never let the hero clip or overflow.
- **No fixed-height rows** — fixed heights clip scaled Persian/Arabic ascenders/descenders (tail on ج/چ, dots on پ/ژ) and Nastaliq diacritics. Rows size to content.
- **Arabic/Persian body gets +2 line-height** vs Latin at the same size (16/26 Latin → 16/28 Arabic) so dots/diacritics survive.
- Dense RTL screens (fuel rows, cost tiles) must **wrap, not truncate**, at 2×; tabular numerals keep columns aligned as they grow.
- The type scale (hero 84/88 · display 30/38 · title 20/28 · body 16/26 · label 13/20 · caption 12/18) is the **1.0× base**; all sizes scale from tokens, none hard-coded — see [Color & Typography](./01-tokens.md).

### 4.5 Colour-blind-safe verification

Because warm = ache, PULSE is verified against the three common CVD types **plus greyscale**:

| Simulation | Must still convey |
|---|---|
| **Deuteranopia** (green-weak) | firouzeh vs saffron can converge → rely on **icon + label + position** ✓ |
| **Protanopia** (red-weak) | ember vs pomegranate converge → **hatch density + "Overdue"/"Needs care now" text** distinguishes ✓ |
| **Tritanopia** (blue-weak) | firouzeh vs pistachio shift → **outline vs no-outline shape + word** distinguishes ✓ |
| **Full greyscale** | The *entire status system must still be readable* — this is the acceptance test: if a screenshot in pure greyscale still answers "what needs me?", we pass |

- CI includes a **greyscale golden** of the Cockpit and the hidden list at each urgency; a reviewer must read status from it with colour stripped.
- Temperature stops are chosen with **monotonic luminance** (0→4 gets warmer *and* the icon/shape gets heavier), so severity survives desaturation.

### 4.6 Minimum touch targets

| Element | Minimum | PULSE target |
|---|---|---|
| Absolute floor (all interactive) | **44×44 dp** (iOS HIG) / 48×48 dp (Material) | — |
| Keypad keys | 44 min | **56×64** |
| Quick-add pill | — | **56** dp |
| Room-nav items | — | **48** dp |
| Reminder card actions (done/snooze/skip) | 44 | ≥48, generous swipe zones |

- Spacing is on an **8 dp base grid**; targets never overlap; the persistent quick-add sits in the **start-edge thumb arc** (mirrored RTL) so it's reachable one-handed in both directions.
- Swipe gestures (done/snooze/skip, reveal-the-list) always have a **visible, labelled tap alternative** — no gesture is the only path to an action.

---

## Acceptance checklist (CI-gated)

- [ ] Every animation has a `prefers-reduced-motion` fallback that preserves meaning; haptics preserved under reduced-motion.
- [ ] No `left`/`right`/hard-coded offset signs — Directional-only; RTL golden passes.
- [ ] Plates/VIN/numbers bidi-isolated (FSI…PDI); persist as canonical, display transformed.
- [ ] Four calendars project from one epoch; first-day-of-week locale-driven; numerals round-trip in all six locales.
- [ ] **Every status = icon + label + shape + position**, verified in **greyscale**.
- [ ] Contrast matrix: 5 stops × 2 themes × (text, icon, outline) all meet AA; warm tints capped.
- [ ] Pulse-line & every vital/chart carry a complete `Semantics` node; exhale announces via `liveRegion`.
- [ ] 1.5× & 2.0× dynamic-type goldens pass; hero reflows, no clipped Persian/Nastaliq glyphs.
- [ ] All touch targets ≥44 dp; every swipe has a labelled tap alternative.

---

*See also — PULSE siblings: [Overview](./00-design-system.md) · [Foundations & Tokens](./01-tokens.md) · [Color & Typography](./01-tokens.md) · [Components & Rooms](./02-components.md). Engineering: [i18n, RTL & Calendars](../../flutter/06-i18n-rtl-calendars.md) · [Performance & Rendering](../../flutter/10-performance-rendering.md) · [Accessibility & Dynamic Type](../../flutter/15-accessibility-dynamic-type.md). Product: [Overview](../../overview.md).*
