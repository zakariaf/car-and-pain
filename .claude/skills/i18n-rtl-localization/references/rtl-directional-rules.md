# RTL — Directional-only geometry, bidi isolation, mirroring, charts

RTL is a **layout discipline, not a translation task.** ~90% of RTL bugs are hardcoded
left/right geometry that compiles fine and silently breaks. The fix is to author every
layout with logical start/end properties so it mirrors **by construction** when
`Directionality` flips — which happens automatically the moment `MaterialApp.locale` is
one of fa/ar/ckb. No per-widget conditionals.

## The allowed / banned table

| Concern | USE (correct) | BANNED in feature code (CI grep rejects) |
| --- | --- | --- |
| Padding / margin | `EdgeInsetsDirectional.only(start:, end:)` | `EdgeInsets.only(left:, right:)` |
| Alignment | `AlignmentDirectional.centerStart` / `.centerEnd` | `Alignment.centerLeft` / `.centerRight` |
| Stack positioning | `PositionedDirectional(start:, end:)` | `Positioned(left:, right:)` |
| Text alignment | `TextAlign.start` / `.end` | `TextAlign.left` / `.right` |
| Row/Column main axis | `MainAxisAlignment.start` / `.end` | (physical L/R n/a — but don't hardcode child order for direction) |
| Directional icons | `Icons.adaptive.arrow_back`, `Icons.adaptive.arrow_forward` | `Icons.arrow_back`, `Icons.arrow_forward` |
| Border radius | `BorderRadiusDirectional.only(topStart:, ...)` | `BorderRadius.only(topLeft:, ...)` |

## Icons: mirror the directional, never the absolute

- **Mirror** (direction implied): back/next, chevrons, trend arrows, progress carets.
  Prefer `Icons.adaptive.*`; if absent, flip manually (below).
- **Never mirror** (fixed real-world meaning): clock, checkmark, compass, media
  play/pause/skip, logos.

For a custom directional glyph not in `Icons.adaptive`:

```dart
Transform(
  alignment: Alignment.center,
  transform: Matrix4.rotationY(
    Directionality.of(context) == TextDirection.rtl ? math.pi : 0),
  child: const Icon(Icons.trending_up),
);
```

## Bidi isolation — strong-LTR technical strings inside RTL

VIN, licence plate, phone, IBAN, email, URL, part/paint numbers, prices, and units
visually scramble inside an RTL paragraph unless isolated (a plate's letters and digits
swap ends). Isolate characters live **only at the view layer** — store, search, and
export the raw ASCII string; strip isolates at the boundary.

```dart
// bidi_isolate.dart  (packages/l10n)
String isolateLtr(String s)  => '⁦$s⁩';  // LRI … PDI  (for known-LTR runs)
String isolateAuto(String s) => '⁨$s⁩';  // FSI … PDI  (unknown direction)

// Inline in an RTL sentence:  Text('${l10n.plateLabel}: ${isolateLtr(plate)}')
// Standalone field — set direction explicitly instead of wrapping:
Text(vin, textDirection: TextDirection.ltr, textAlign: TextAlign.end);
TextField(controller: plateCtrl, textDirection: TextDirection.ltr);
```

- Also isolate mixed value+unit runs like `50 km/h` and parenthesized numbers.
- Assert in tests that stored values are stripped of `U+2066`/`U+2068`…`U+2069`.

## CustomPainter charts — do NOT auto-mirror; mirror explicitly

Chart chrome (axes, labels, legend) must mirror and the **time axis inverts** for RTL,
but the **plotted data itself is never flipped** — a rising trend must still look rising.
When painting:

- Read `Directionality.of(context)` in the painter and reverse the X mapping for the
  time axis in RTL; keep the value-to-Y mapping unchanged.
- Place the value axis on the correct side (start/end, not fixed left).
- Apply the numeral formatter to axis and tooltip labels (native digits per preference),
  and isolate numeric tick labels.
- Golden-test each chart across locale × direction × numeral.

## Live locale switch

Changing the DB-persisted locale rebuilds `MaterialApp`, which re-flips `Directionality`
and re-runs every `AppLocalizations` lookup — **live, no restart.** Directional-only
geometry is what makes this correct without touching feature code.

## Testing (RTL slice)

- Golden with **real fonts loaded** (`loadAppFonts()` via `alchemist`) — the default test
  host renders no Arabic/Persian glyphs, so goldens are otherwise blank/non-deterministic.
- Make `textScaler` 1.5–2× and RTL overflow explicit golden dimensions — tall
  Persian/Arabic glyphs overflow fixed-height rows.
- CI Ahem lane catches mirroring cheaply; a narrow real-font lane catches shaping.
- Manual device QA (Impeller, real device): letter joining/diacritics; VIN/plate/phone
  read LTR inside RTL cards; nav icons mirror; charts mirror chrome + invert time axis
  but keep data; live switch re-mirrors without restart.
