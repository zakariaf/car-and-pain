/// Numeral shaping primitives (F4-T4).
///
/// Storage is always ASCII digits; these types are **presentation-only**. All
/// three supported digit sets occupy a contiguous Unicode range, so the glyph
/// for a digit `d` is simply `zeroCodeUnit + d`.
library;

/// The digit sets Car and Pain can shape to and de-shape from.
enum NumeralSystem {
  /// `0 1 2 3 4 5 6 7 8 9` — ASCII (U+0030..U+0039).
  western(0x0030),

  /// `٠ ١ ٢ ٣ ٤ ٥ ٦ ٧ ٨ ٩` — Arabic-Indic (U+0660..U+0669).
  easternArabic(0x0660),

  /// `۰ ۱ ۲ ۳ ۴ ۵ ۶ ۷ ۸ ۹` — Extended Arabic-Indic / Persian (U+06F0..U+06F9).
  persian(0x06F0);

  const NumeralSystem(this.zeroCodeUnit);

  /// The Unicode code unit of this set's digit **zero**.
  final int zeroCodeUnit;

  /// The glyph for a single ASCII digit value `0..9`.
  String glyph(int d) {
    assert(d >= 0 && d <= 9, 'digit out of range: $d');
    return String.fromCharCode(zeroCodeUnit + d);
  }

  /// Replace every ASCII digit in [ascii] with this set's glyph. Non-digit
  /// characters (sign, separators, letters) pass through unchanged.
  String shape(String ascii) {
    if (this == NumeralSystem.western) return ascii;
    final out = StringBuffer();
    for (final code in ascii.codeUnits) {
      if (code >= 0x30 && code <= 0x39) {
        out.writeCharCode(zeroCodeUnit + (code - 0x30));
      } else {
        out.writeCharCode(code);
      }
    }
    return out.toString();
  }
}

/// Fold every supported digit set — Western, Arabic-Indic (U+0660..), and
/// Extended Arabic-Indic / Persian (U+06F0..) — to ASCII `0-9`, leaving all
/// other characters (separators, sign, letters) untouched. This is the mandatory
/// first step before any numeric parsing (invariant #8).
String foldDigitsToAscii(String input) {
  final out = StringBuffer();
  for (final code in input.codeUnits) {
    if (code >= 0x0660 && code <= 0x0669) {
      out.writeCharCode(0x30 + (code - 0x0660)); // Arabic-Indic
    } else if (code >= 0x06F0 && code <= 0x06F9) {
      out.writeCharCode(0x30 + (code - 0x06F0)); // Persian
    } else {
      out.writeCharCode(code);
    }
  }
  return out.toString();
}

/// How integer digits are grouped for display.
enum GroupingStyle {
  /// 3-3-3 from the right: `1,234,567`. Used by every launch locale.
  thousands,

  /// South-Asian: the last three, then groups of two — `12,34,567`. Supported
  /// for completeness; no launch locale selects it by default.
  indian,

  /// No grouping at all.
  none,
}

/// Insert [sep] into a run of ASCII integer [digits] per [style]. [digits] must
/// contain only `0-9` — no sign, no separators, no leading fold needed.
String groupInteger(String digits, GroupingStyle style, String sep) {
  if (style == GroupingStyle.none || digits.length <= 3) return digits;
  final buf = StringBuffer();
  if (style == GroupingStyle.thousands) {
    final first = digits.length % 3 == 0 ? 3 : digits.length % 3;
    buf.write(digits.substring(0, first));
    for (var i = first; i < digits.length; i += 3) {
      buf
        ..write(sep)
        ..write(digits.substring(i, i + 3));
    }
  } else {
    // Indian: the final three digits form the last group; everything before is
    // split into groups of two (the leading group may be a single digit).
    final head = digits.length - 3;
    final firstLen = head.isEven ? 2 : 1;
    buf.write(digits.substring(0, firstLen));
    for (var i = firstLen; i < head; i += 2) {
      buf
        ..write(sep)
        ..write(digits.substring(i, i + 2));
    }
    buf
      ..write(sep)
      ..write(digits.substring(head));
  }
  return buf.toString();
}
