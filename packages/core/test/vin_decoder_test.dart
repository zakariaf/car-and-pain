import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  const d = VinDecoder();

  // A well-formed VIN built with a chosen position-7 (index 6) and position-10
  // (index 9) so year decode can be exercised in isolation. Check digit is not
  // necessarily valid — year/region/WMI don't depend on it.
  String yearVin({required String pos7, required String pos10}) =>
      '1G1AA' // 0..4
      'A' // 5
      '$pos7' // 6
      'AA' // 7,8
      '$pos10' // 9
      'AAAAAAA'; // 10..16  (7)

  group('check digit (ISO 3779 mod-11)', () {
    // Known-valid VINs (Wikipedia canonical examples + the all-ones vector).
    const valid = [
      '1HGCM82633A004352', // check digit 3 (canonical example)
      '1M8GDM9AXKP042788', // check digit X (canonical example)
      '11111111111111111', // check digit 1 (all-ones vector)
    ];
    for (final v in valid) {
      test('$v is valid', () {
        final r = d.decode(v);
        expect(r.wellFormed, isTrue);
        expect(r.checkDigitValid, isTrue, reason: 'expected valid check digit');
      });
    }

    test('a single-character mutation of the check digit fails', () {
      // Flip the check digit (index 8) of the known-good 1HGCM82633A004352.
      const bad = '1HGCM82643A004352'; // was '3' at index 8
      final r = d.decode(bad);
      expect(r.wellFormed, isTrue);
      expect(r.checkDigitValid, isFalse);
    });

    test('checkDigit() exposes the expected character', () {
      expect(d.checkDigit('1M8GDM9AXKP042788'), 'X');
      expect(d.checkDigit('1HGCM82633A004352'), '3');
      expect(d.checkDigit('not a vin'), ''); // not well-formed
    });
  });

  group('well-formedness + charset', () {
    const malformed = {
      '': 'empty',
      '1HGCM8263': 'too short',
      '1HGCM82633A004352X': 'too long',
      '1HGCM8263IA004352': 'contains I',
      '1HGCM8263OA004352': 'contains O',
      '1HGCM8263QA004352': 'contains Q',
    };
    for (final entry in malformed.entries) {
      test('${entry.value} → not well-formed, checkDigitValid false', () {
        final r = d.decode(entry.key);
        expect(r.wellFormed, isFalse, reason: entry.value);
        expect(r.checkDigitValid, isFalse);
        expect(r.modelYear, isNull);
      });
    }

    test('lowercase + surrounding whitespace normalize before decoding', () {
      final r = d.decode('  1hgcm82633a004352  ');
      expect(r.vin, '1HGCM82633A004352');
      expect(r.wellFormed, isTrue);
      expect(r.checkDigitValid, isTrue);
    });
  });

  group('WMI → manufacturer + region', () {
    test('bundled WMIs resolve manufacturer and region', () {
      expect(d.decode('1HGCM82633A004352').manufacturer, 'Honda');
      expect(d.decode('1HGCM82633A004352').region, VinRegion.northAmerica);
      expect(d.decode('WVWZZZ1KZAW000000').manufacturer, 'Volkswagen');
      expect(d.decode('WVWZZZ1KZAW000000').region, VinRegion.europe);
      expect(d.decode('JHMZZZZZZZZ000000'.padRight(17, '0')).region,
          VinRegion.asia);
    });

    test('an unknown WMI leaves manufacturer null (free-text fallback)', () {
      // 1G1 is Chevrolet in the table; ZZZ is a definitely-unknown WMI.
      final known = d.decode(yearVin(pos7: 'A', pos10: 'A'));
      expect(known.wmi, '1G1');
      expect(known.manufacturer, 'Chevrolet');
      final unknown =
          d.decode('ZZZ${yearVin(pos7: 'A', pos10: 'A').substring(3)}');
      expect(unknown.manufacturer, isNull);
    });

    test('region spans every first-character band', () {
      expect(d.decode('A${'0' * 16}').region, VinRegion.africa);
      expect(d.decode('J${'0' * 16}').region, VinRegion.asia);
      expect(d.decode('S${'0' * 16}').region, VinRegion.europe);
      expect(d.decode('1${'0' * 16}').region, VinRegion.northAmerica);
      expect(d.decode('6${'0' * 16}').region, VinRegion.oceania);
      expect(d.decode('9${'0' * 16}').region, VinRegion.southAmerica);
    });

    test('small-volume manufacturer flagged when WMI third char is 9', () {
      final r = d.decode('WP9${'0' * 14}');
      expect(r.smallManufacturer, isTrue);
      expect(d.decode('WP0${'0' * 14}').smallManufacturer, isFalse);
    });
  });

  group('model year (position 10 + position-7 disambiguation)', () {
    test('numeric position 7 → 1980–2009 cycle', () {
      expect(d.decode(yearVin(pos7: '2', pos10: 'A')).modelYear, 1980);
      expect(d.decode(yearVin(pos7: '2', pos10: 'Y')).modelYear, 2000);
      expect(d.decode(yearVin(pos7: '5', pos10: '9')).modelYear, 2009);
    });

    test('alphabetic position 7 → 2010–2039 cycle', () {
      expect(d.decode(yearVin(pos7: 'F', pos10: 'A')).modelYear, 2010);
      expect(d.decode(yearVin(pos7: 'F', pos10: 'Y')).modelYear, 2030);
      expect(d.decode(yearVin(pos7: 'F', pos10: 'L')).modelYear, 2020);
    });

    test('a year code of I/O/Q makes the VIN not well-formed (null year)', () {
      expect(d.decode(yearVin(pos7: '2', pos10: 'I')).modelYear, isNull);
    });
  });

  test('value semantics', () {
    expect(d.decode('1HGCM82633A004352'), d.decode('1HGCM82633A004352'));
    expect(d.decode('1HGCM82633A004352').hashCode,
        d.decode('1HGCM82633A004352').hashCode);
  });
}
