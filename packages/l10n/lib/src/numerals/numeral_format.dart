import 'numeral_system.dart';

/// Formats canonical machine values (ints / fixed-point minor units) into a
/// localized numeric string — grouping, decimal separator, and digit shaping
/// (F4-T4). It never rounds: the exact stored value is rendered, so money
/// (ISO-4217 minor units) shows without double-rounding.
class NumeralFormat {
  const NumeralFormat({
    this.system = NumeralSystem.western,
    this.grouping = GroupingStyle.thousands,
    this.groupSeparator = ',',
    this.decimalSeparator = '.',
    this.minusSign = '-',
  });

  final NumeralSystem system;
  final GroupingStyle grouping;
  final String groupSeparator;
  final String decimalSeparator;
  final String minusSign;

  /// Format a plain integer (counts, distances-as-int, …).
  String formatInt(int value) =>
      _assemble(value.isNegative, value.abs().toString(), '');

  /// Format a value stored as [scaled] with [fractionDigits] implied decimals —
  /// e.g. ISO-4217 minor units (`fractionDigits == currency exponent`) or a
  /// fixed-point measure. The exact value is rendered; no rounding.
  String formatScaled(int scaled, int fractionDigits) {
    if (fractionDigits <= 0) return formatInt(scaled);
    final digits = scaled.abs().toString().padLeft(fractionDigits + 1, '0');
    final cut = digits.length - fractionDigits;
    return _assemble(
      scaled.isNegative,
      digits.substring(0, cut),
      digits.substring(cut),
    );
  }

  String _assemble(bool negative, String intDigits, String fracDigits) {
    final sb = StringBuffer();
    if (negative) sb.write(minusSign);
    sb.write(groupInteger(intDigits, grouping, groupSeparator));
    if (fracDigits.isNotEmpty) {
      sb
        ..write(decimalSeparator)
        ..write(fracDigits);
    }
    return system.shape(sb.toString());
  }
}

// Code units of the always-recognized special characters (kept as hex so this
// source stays pure-ASCII and free of ambiguous invisible glyphs).
const int _cuArabicDecimal = 0x066B; // ٫
const int _cuArabicThousands = 0x066C; // ٬
const int _cuArabicComma = 0x060C; // ،
const int _cuAsciiMinus = 0x002D; // -
const int _cuAsciiPlus = 0x002B; // +
const int _cuUnicodeMinus = 0x2212; // −

bool _isBidiMark(int cu) =>
    cu == 0x200E || // LRM
    cu == 0x200F || // RLM
    cu == 0x061C || // ALM
    (cu >= 0x2066 && cu <= 0x2069); // isolates

bool _isSpaceGrouping(int cu) =>
    cu == 0x0020 || // space
    cu == 0x00A0 || // no-break space
    cu == 0x202F || // narrow no-break space
    cu == 0x2009 || // thin space
    cu == 0x2007; // figure space

/// Parses user-entered numbers in any digit set / separator convention back to
/// canonical machine values (F4-T4). Accepts Western/Arabic-Indic/Persian
/// digits, the locale's configured separators, and the always-unambiguous
/// Arabic decimal (U+066B) and thousands (U+066C). Returns `null` on invalid
/// input — callers wrap that in a typed `Result`/`Failure`.
class NumeralParser {
  const NumeralParser({
    this.decimalSeparators = const {'.'},
    this.groupingSeparators = const {','},
  });

  /// Characters accepted as the decimal point (e.g. `{'.'}` for en, `{','}` for
  /// de/fr). The Arabic decimal U+066B is always additionally accepted.
  final Set<String> decimalSeparators;

  /// Characters accepted as grouping (ignored). The Arabic thousands U+066C,
  /// the Arabic comma U+060C, and the space family are always additionally
  /// accepted.
  final Set<String> groupingSeparators;

  /// Parse into a canonical scaled integer with [fractionDigits] implied
  /// decimals (0 for counts, the currency exponent for money). Rejects input
  /// with more fractional digits than allowed — no silent rounding.
  int? parseScaled(String input, int fractionDigits) {
    final intBuf = StringBuffer();
    final fracBuf = StringBuffer();
    var negative = false;
    var inFrac = false;
    var anyDigit = false;
    var signAllowed = true;

    for (final cu in foldDigitsToAscii(input).codeUnits) {
      if (_isBidiMark(cu)) continue;
      if (cu >= 0x30 && cu <= 0x39) {
        anyDigit = true;
        signAllowed = false;
        (inFrac ? fracBuf : intBuf).writeCharCode(cu);
      } else if (!inFrac && _isDecimal(cu)) {
        inFrac = true;
        signAllowed = false;
      } else if (_isGrouping(cu)) {
        if (inFrac) return null; // grouping inside the fraction is malformed
      } else if (signAllowed &&
          (cu == _cuAsciiMinus || cu == _cuUnicodeMinus)) {
        negative = true;
        signAllowed = false;
      } else if (signAllowed && cu == _cuAsciiPlus) {
        signAllowed = false;
      } else {
        return null; // stray character
      }
    }
    if (!anyDigit) return null;
    if (fracBuf.length > fractionDigits) return null;

    final intPart = intBuf.isEmpty ? '0' : intBuf.toString();
    final fracPart = fractionDigits <= 0
        ? ''
        : fracBuf.toString().padRight(fractionDigits, '0');
    final value = int.parse('$intPart$fracPart');
    return negative ? -value : value;
  }

  /// Parse a plain integer count.
  int? parseInt(String input) => parseScaled(input, 0);

  bool _isDecimal(int cu) =>
      cu == _cuArabicDecimal ||
      decimalSeparators.contains(String.fromCharCode(cu));

  bool _isGrouping(int cu) =>
      cu == _cuArabicThousands ||
      cu == _cuArabicComma ||
      _isSpaceGrouping(cu) ||
      groupingSeparators.contains(String.fromCharCode(cu));
}
