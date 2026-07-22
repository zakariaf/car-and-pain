/// Bidi isolation helpers (F4-T5). Embed inherently-LTR tokens — VIN, license
/// plate, phone, IBAN — inside RTL sentences without digit/character reordering
/// or bracket flipping, using Unicode directional **isolates** (which, unlike
/// the older embeddings/overrides, don't leak direction into surrounding text).
///
/// Source is kept pure-ASCII — the control characters are addressed by code
/// point, never written as ambiguous invisible literals.
library;

const int _lri = 0x2066; // LEFT-TO-RIGHT ISOLATE
const int _rli = 0x2067; // RIGHT-TO-LEFT ISOLATE
const int _fsi = 0x2068; // FIRST STRONG ISOLATE
const int _pdi = 0x2069; // POP DIRECTIONAL ISOLATE

/// Wrap [s] so it renders as an intact **LTR** run inside any paragraph. Use for
/// VIN, plate, phone, IBAN — Latin/numeric identifiers embedded in RTL text.
String ltrIsolate(String s) =>
    '${String.fromCharCode(_lri)}$s${String.fromCharCode(_pdi)}';

/// Wrap [s] as an intact **RTL** run inside any paragraph.
String rtlIsolate(String s) =>
    '${String.fromCharCode(_rli)}$s${String.fromCharCode(_pdi)}';

/// Wrap [s] in a first-strong isolate — its own first strong character decides
/// the direction. Use for user free-text of unknown direction.
String isolate(String s) =>
    '${String.fromCharCode(_fsi)}$s${String.fromCharCode(_pdi)}';

/// Remove every bidi control character (the isolates, the legacy
/// embeddings/overrides U+202A..U+202E, and LRM/RLM/ALM). Apply before copying a
/// value to the clipboard, comparing, or persisting it, so the controls never
/// leak into stored data.
String stripBidi(String s) {
  final out = StringBuffer();
  for (final cu in s.codeUnits) {
    if (_isBidiControl(cu)) continue;
    out.writeCharCode(cu);
  }
  return out.toString();
}

bool _isBidiControl(int cu) =>
    cu == 0x200E || // LRM
    cu == 0x200F || // RLM
    cu == 0x061C || // ALM
    (cu >= 0x202A && cu <= 0x202E) || // LRE RLE PDF LRO RLO
    (cu >= 0x2066 && cu <= 0x2069); // LRI RLI FSI PDI
