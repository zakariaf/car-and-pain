import 'numerals/numeral_system.dart' show foldDigitsToAscii;

/// Fold a string to a script-normalized, case-insensitive, digit-folded key for
/// substring search (F4 / M2-T5). So "Golf ٢", "golf 2" and "GOLF 2" all match,
/// and Arabic/Persian orthographic variants (alef hamza forms, yeh, kaf, teh
/// marbuta, tatweel) collapse to a single canonical form. Pure and total.
String normalizeForSearch(String input) {
  final ascii = foldDigitsToAscii(input.trim().toLowerCase());
  final sb = StringBuffer();
  for (final cu in ascii.runes) {
    final n = _normalizeCodePoint(cu);
    if (n != null) sb.writeCharCode(n);
  }
  return sb.toString();
}

/// Map a code point to its canonical search form, or null to drop it (tatweel /
/// bidi controls / combining marks).
int? _normalizeCodePoint(int cu) => switch (cu) {
      // Alef variants (bare / hamza above / hamza below / madda) → bare alef.
      0x0623 || 0x0625 || 0x0622 || 0x0671 => 0x0627,
      // Arabic yeh / alef maqsura → Persian yeh.
      0x064A || 0x0649 => 0x06CC,
      // Arabic kaf → Persian keheh.
      0x0643 => 0x06A9,
      // Teh marbuta → heh.
      0x0629 => 0x0647,
      // Drop tatweel, the bidi marks, and Arabic combining marks.
      0x0640 || 0x200C || 0x200D || 0x200E || 0x200F => null,
      _ when cu >= 0x064B && cu <= 0x0652 => null, // harakat
      _ => cu,
    };
