import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Currency — ISO-4217 exponent table', () {
    final cases = <({Currency currency, int exponent, int minorPerMajor})>[
      (currency: Currency.irr, exponent: 0, minorPerMajor: 1),
      (currency: Currency.jpy, exponent: 0, minorPerMajor: 1),
      (currency: Currency.usd, exponent: 2, minorPerMajor: 100),
      (currency: Currency.eur, exponent: 2, minorPerMajor: 100),
      (currency: Currency.kwd, exponent: 3, minorPerMajor: 1000),
      (currency: Currency.bhd, exponent: 3, minorPerMajor: 1000),
    ];
    for (final c in cases) {
      test('${c.currency.code}: exp ${c.exponent}, scale ${c.minorPerMajor}',
          () {
        expect(c.currency.exponent, c.exponent);
        expect(c.currency.minorPerMajor, c.minorPerMajor);
      });
    }

    test('tryParse resolves shipped codes and rejects unknown', () {
      expect(Currency.tryParse('USD'), Currency.usd);
      expect(Currency.tryParse('TRY'), Currency.try_);
      expect(Currency.tryParse('XXX'), isNull);
      expect(Currency.tryParse('usd'), isNull); // case-sensitive ISO codes
    });
  });

  group('Money.tryParseMajor — exponent-aware parsing', () {
    final cases = <({String input, Currency ccy, int? minor, String? errCode})>[
      (input: '12.34', ccy: Currency.usd, minor: 1234, errCode: null),
      (input: '12', ccy: Currency.usd, minor: 1200, errCode: null),
      (input: '12.3', ccy: Currency.usd, minor: 1230, errCode: null),
      (input: '0.05', ccy: Currency.usd, minor: 5, errCode: null),
      (input: '-3.50', ccy: Currency.eur, minor: -350, errCode: null),
      // IRR is exponent 0 — any fractional digit is a mismatch.
      (input: '5', ccy: Currency.irr, minor: 5, errCode: null),
      (
        input: '5.0',
        ccy: Currency.irr,
        minor: null,
        errCode: 'too_many_fraction_digits'
      ),
      // KWD is exponent 3.
      (input: '1.234', ccy: Currency.kwd, minor: 1234, errCode: null),
      (
        input: '1.2345',
        ccy: Currency.kwd,
        minor: null,
        errCode: 'too_many_fraction_digits'
      ),
      // Malformed.
      (input: 'abc', ccy: Currency.usd, minor: null, errCode: 'not_a_number'),
      (input: '', ccy: Currency.usd, minor: null, errCode: 'not_a_number'),
      (input: '1.2.3', ccy: Currency.usd, minor: null, errCode: 'not_a_number'),
    ];
    for (final c in cases) {
      test('"${c.input}" ${c.ccy.code} => ${c.minor ?? c.errCode}', () {
        final result = Money.tryParseMajor(c.input, c.ccy);
        if (c.errCode == null) {
          expect(result.valueOrNull, isNotNull);
          expect(result.valueOrNull!.minorUnits, c.minor);
          expect(result.valueOrNull!.currency, c.ccy);
        } else {
          expect(result.isErr, isTrue);
          final f = result.failureOrNull!;
          expect(f.fieldErrors.single.code, c.errCode);
        }
      });
    }
  });

  group('Money — arithmetic', () {
    test('same-currency add/subtract/scale', () {
      const a = Money(1000, Currency.usd);
      const b = Money(250, Currency.usd);
      expect((a + b).minorUnits, 1250);
      expect((a - b).minorUnits, 750);
      expect((b * 3).minorUnits, 750);
      expect((-a).minorUnits, -1000);
    });

    test('compareTo orders by minor units', () {
      const a = Money(100, Currency.usd);
      const b = Money(200, Currency.usd);
      expect(a.compareTo(b), isNegative);
      expect(b.compareTo(a), isPositive);
      expect(a.compareTo(const Money(100, Currency.usd)), 0);
    });

    test('zero and equality', () {
      expect(const Money.zero(Currency.eur).minorUnits, 0);
      expect(
          const Money(5, Currency.eur), equals(const Money(5, Currency.eur)));
      expect(
        const Money(5, Currency.eur),
        isNot(equals(const Money(5, Currency.usd))),
      );
    });
  });

  group('Money — Rial/Toman display view', () {
    test('fromToman keeps IRR canonical (1 Toman = 10 Rial)', () {
      final m = Money.fromToman(1500);
      expect(m.currency, Currency.irr);
      expect(m.minorUnits, 15000);
      expect(m.tomanWhole, 1500);
      expect(m.tomanRialRemainder, 0);
    });

    test('sub-Toman Rial remainder is preserved', () {
      final m = Money.fromToman(1500, rial: 5);
      expect(m.minorUnits, 15005);
      expect(m.tomanWhole, 1500);
      expect(m.tomanRialRemainder, 5);
    });
  });
}
