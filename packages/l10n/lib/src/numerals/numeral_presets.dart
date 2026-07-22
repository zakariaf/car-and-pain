import 'numeral_format.dart';
import 'numeral_system.dart';

/// A locale's default numeral presentation: which digit set, how to format, and
/// how to parse input back to canonical values (F4-T4). The digit set is
/// user-overridable in settings (F4-T9) via [resolveNumeralFormat].
class NumeralPreset {
  const NumeralPreset({
    required this.system,
    required this.format,
    required this.parser,
  });

  final NumeralSystem system;
  final NumeralFormat format;
  final NumeralParser parser;
}

// Arabic-script separators, built from code points so this source stays ASCII.
final String _arDecimal = String.fromCharCode(0x066B); // ٫
final String _arThousands = String.fromCharCode(0x066C); // ٬
final String _nnbsp = String.fromCharCode(0x202F); // narrow no-break space

/// The default numeral system a locale resolves to.
NumeralSystem defaultNumeralSystemFor(String languageCode) {
  switch (languageCode) {
    case 'fa':
      return NumeralSystem.persian;
    case 'ar':
    case 'ckb':
      return NumeralSystem.easternArabic;
    default:
      return NumeralSystem.western; // en, de, fr
  }
}

/// Build a formatter for [languageCode], optionally overriding the digit set
/// (settings let the user pick a numeral system independent of locale). Western
/// digits use the locale's own separators; Arabic-Indic/Persian digits use the
/// unambiguous Arabic decimal/thousands marks.
NumeralFormat resolveNumeralFormat(
  String languageCode, {
  NumeralSystem? system,
}) {
  final sys = system ?? defaultNumeralSystemFor(languageCode);
  if (sys != NumeralSystem.western) {
    return NumeralFormat(
      system: sys,
      groupSeparator: _arThousands,
      decimalSeparator: _arDecimal,
    );
  }
  switch (languageCode) {
    case 'de':
      return const NumeralFormat(groupSeparator: '.', decimalSeparator: ',');
    case 'fr':
      return NumeralFormat(groupSeparator: _nnbsp, decimalSeparator: ',');
    default: // en (and any western fallback) — ',' grouping, '.' decimal
      return const NumeralFormat();
  }
}

/// Build a parser for [languageCode]. It always folds every digit set and
/// accepts the unambiguous Arabic marks; the configured sets only disambiguate
/// the Western `.`/`,` roles per locale.
NumeralParser resolveNumeralParser(String languageCode) {
  switch (languageCode) {
    case 'de':
      return const NumeralParser(
        decimalSeparators: {','},
        groupingSeparators: {'.'},
      );
    case 'fr':
      return const NumeralParser(
        decimalSeparators: {','},
        groupingSeparators: {'.'},
      );
    case 'fa':
    case 'ar':
    case 'ckb':
      // '.' decimal / ',' grouping like en; the Arabic ٫ (U+066B) and ٬
      // (U+066C) marks are always accepted regardless of config.
      return const NumeralParser();
    default: // en — '.' decimal, ',' grouping (the constructor defaults)
      return const NumeralParser();
  }
}

/// The full default preset for a locale.
NumeralPreset numeralPresetFor(String languageCode) => NumeralPreset(
      system: defaultNumeralSystemFor(languageCode),
      format: resolveNumeralFormat(languageCode),
      parser: resolveNumeralParser(languageCode),
    );
