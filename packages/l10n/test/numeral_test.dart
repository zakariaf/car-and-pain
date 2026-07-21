import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

/// Independent re-implementation of digit shaping, so tests don't validate the
/// engine against itself. Maps ASCII digits in [ascii] onto the set whose zero
/// is [zero]; leaves other characters alone.
String toSet(String ascii, int zero) => ascii.codeUnits
    .map((c) => (c >= 0x30 && c <= 0x39)
        ? String.fromCharCode(zero + c - 0x30)
        : String.fromCharCode(c))
    .join();

const int _eastern = 0x0660; // Arabic-Indic
const int _persian = 0x06F0; // Extended Arabic-Indic
String _cp(int c) => String.fromCharCode(c);
final String _arDecimal = _cp(0x066B); // ٫
final String _arThousands = _cp(0x066C); // ٬

void main() {
  group('NumeralSystem.shape / glyph', () {
    test('western is identity; eastern & persian remap digits only', () {
      expect(NumeralSystem.western.shape('1,234.5'), '1,234.5');
      expect(NumeralSystem.easternArabic.shape('1,234.5'),
          toSet('1,234.5', _eastern));
      expect(
          NumeralSystem.persian.shape('1,234.5'), toSet('1,234.5', _persian));
    });

    test('glyph returns the right codepoint per set', () {
      expect(NumeralSystem.western.glyph(7), '7');
      expect(NumeralSystem.easternArabic.glyph(0), _cp(_eastern));
      expect(NumeralSystem.persian.glyph(9), _cp(_persian + 9));
    });
  });

  group('foldDigitsToAscii', () {
    test('folds every set back to ASCII, leaving separators untouched', () {
      expect(foldDigitsToAscii(toSet('1234567890', _persian)), '1234567890');
      expect(foldDigitsToAscii(toSet('1234567890', _eastern)), '1234567890');
      expect(foldDigitsToAscii('1234567890'), '1234567890');
      // A mixed string keeps its separators.
      expect(foldDigitsToAscii('${toSet('12', _persian)}.$_arThousands'),
          '12.$_arThousands');
    });
  });

  group('groupInteger', () {
    test('thousands (3-3-3)', () {
      expect(groupInteger('1', GroupingStyle.thousands, ','), '1');
      expect(groupInteger('123', GroupingStyle.thousands, ','), '123');
      expect(groupInteger('1000', GroupingStyle.thousands, ','), '1,000');
      expect(
          groupInteger('1234567', GroupingStyle.thousands, ','), '1,234,567');
      expect(
          groupInteger('10000000', GroupingStyle.thousands, ','), '10,000,000');
    });

    test('indian (last 3, then 2-2)', () {
      expect(groupInteger('1234', GroupingStyle.indian, ','), '1,234');
      expect(groupInteger('12345', GroupingStyle.indian, ','), '12,345');
      expect(groupInteger('123456', GroupingStyle.indian, ','), '1,23,456');
      expect(groupInteger('1234567', GroupingStyle.indian, ','), '12,34,567');
      expect(
          groupInteger('12345678', GroupingStyle.indian, ','), '1,23,45,678');
    });

    test('none leaves digits intact', () {
      expect(groupInteger('1234567', GroupingStyle.none, ','), '1234567');
    });
  });

  group('NumeralFormat', () {
    test('formatInt: grouping, sign', () {
      const en = NumeralFormat();
      expect(en.formatInt(0), '0');
      expect(en.formatInt(1234567), '1,234,567');
      expect(en.formatInt(-42), '-42');
    });

    test('formatScaled: exact minor units, no rounding', () {
      const en = NumeralFormat();
      expect(en.formatScaled(5, 2), '0.05');
      expect(en.formatScaled(123456, 2), '1,234.56');
      expect(en.formatScaled(-105, 2), '-1.05');
      expect(en.formatScaled(1000, 0), '1,000');
      // exponent-0 currency (e.g. JPY): scaled == major.
      expect(en.formatScaled(2500, 0), '2,500');
      // exponent-3 currency (e.g. BHD).
      expect(en.formatScaled(1234, 3), '1.234');
    });

    test('German uses . grouping and , decimal', () {
      const de = NumeralFormat(groupSeparator: '.', decimalSeparator: ',');
      expect(de.formatScaled(1234567, 2), '12.345,67');
    });

    test('Persian preset shapes digits + Arabic separators', () {
      final fa = resolveNumeralFormat('fa');
      final expected = toSet('1', _persian) +
          _arThousands +
          toSet('234', _persian) +
          _arDecimal +
          toSet('56', _persian);
      expect(fa.formatScaled(123456, 2), expected);
    });

    test('Indian grouping is available as a mechanism', () {
      const f = NumeralFormat(grouping: GroupingStyle.indian);
      expect(f.formatInt(1234567), '12,34,567');
    });
  });

  group('NumeralParser', () {
    test('en: grouping ignored, . decimal, strict fraction width', () {
      const p = NumeralParser();
      expect(p.parseScaled('1,234.56', 2), 123456);
      expect(p.parseInt('1,234'), 1234);
      expect(p.parseScaled('.5', 2), 50);
      expect(p.parseScaled('-1,000.00', 2), -100000);
      expect(p.parseScaled('12.345', 2), isNull); // too many fraction digits
      expect(p.parseScaled('abc', 2), isNull);
      expect(p.parseScaled('', 2), isNull);
      expect(p.parseScaled('1.2.3', 2), isNull); // two decimals
    });

    test('de: , decimal and . grouping', () {
      const p =
          NumeralParser(decimalSeparators: {','}, groupingSeparators: {'.'});
      expect(p.parseScaled('12.345,67', 2), 1234567);
    });

    test('accepts Persian/Eastern digits and Arabic marks', () {
      const p = NumeralParser();
      final persianInput = toSet('1', _persian) +
          _arThousands +
          toSet('234', _persian) +
          _arDecimal +
          toSet('56', _persian);
      expect(p.parseScaled(persianInput, 2), 123456);

      final easternMixed =
          toSet('12', _eastern) + _arDecimal + toSet('5', _eastern);
      expect(p.parseScaled(easternMixed, 2), 1250);
    });

    test('strips bidi control marks around the number', () {
      const p = NumeralParser();
      final wrapped = '${_cp(0x200F)}123${_cp(0x200E)}';
      expect(p.parseInt(wrapped), 123);
    });
  });

  group('format -> parse -> format round-trips losslessly', () {
    const values = [0, 5, 42, 1000, 123456, 9999999];
    for (final lang in ['en', 'de', 'fr', 'fa', 'ar', 'ckb']) {
      test('locale $lang', () {
        final f = resolveNumeralFormat(lang);
        final p = resolveNumeralParser(lang);
        for (final v in values) {
          final s = f.formatScaled(v, 2);
          expect(p.parseScaled(s, 2), v, reason: '$lang: $v -> "$s"');
          expect(f.formatScaled(p.parseScaled(s, 2)!, 2), s);
        }
      });
    }
  });

  group('presets map locales to the right digit set', () {
    test('defaultNumeralSystemFor', () {
      expect(defaultNumeralSystemFor('en'), NumeralSystem.western);
      expect(defaultNumeralSystemFor('de'), NumeralSystem.western);
      expect(defaultNumeralSystemFor('fr'), NumeralSystem.western);
      expect(defaultNumeralSystemFor('fa'), NumeralSystem.persian);
      expect(defaultNumeralSystemFor('ar'), NumeralSystem.easternArabic);
      expect(defaultNumeralSystemFor('ckb'), NumeralSystem.easternArabic);
    });

    test('a user can override the digit set independent of locale', () {
      final f = resolveNumeralFormat('en', system: NumeralSystem.persian);
      expect(f.formatInt(123), toSet('123', _persian));
    });
  });
}
