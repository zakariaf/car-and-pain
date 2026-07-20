import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  const day = Duration.millisecondsPerDay;
  const base = 1000000000000;
  // A non-const instant helper keeps the test literals out of const contexts.
  Instant on(int dayN) => Instant.fromEpochMillis(base + dayN * day);

  group('FxRate.tryParse', () {
    test('decimal → exact ratio', () {
      final r = FxRate.tryParse(
        from: Currency.eur,
        to: Currency.usd,
        decimal: '1.0825',
        asOf: on(0),
      ).valueOrNull!;
      expect(r.rateNum, 10825);
      expect(r.rateDen, 10000);
    });

    test('integer rate', () {
      final r = FxRate.tryParse(
        from: Currency.usd,
        to: Currency.irr,
        decimal: '42000',
        asOf: on(0),
      ).valueOrNull!;
      expect(r.rateNum, 42000);
      expect(r.rateDen, 1);
    });

    test('invalid / zero / multi-dot rejected', () {
      for (final bad in ['x', '0', '1.2.3', '']) {
        expect(
          FxRate.tryParse(
            from: Currency.usd,
            to: Currency.eur,
            decimal: bad,
            asOf: on(0),
          ).isErr,
          isTrue,
          reason: bad,
        );
      }
    });

    test('inverse swaps direction + ratio', () {
      final r = FxRate(
        from: Currency.usd,
        to: Currency.eur,
        rateNum: 92,
        rateDen: 100,
        asOf: on(0),
      );
      final inv = r.inverse;
      expect(inv.from, Currency.eur);
      expect(inv.to, Currency.usd);
      expect(inv.rateNum, 100);
      expect(inv.rateDen, 92);
      expect(r == inv, isFalse);
      expect(r.hashCode, isNot(inv.hashCode));
      expect(r.toString(), contains('USD'));
    });
  });

  group('FxTable.rateFor', () {
    test('picks latest effective-dated rate + inverse fallback', () {
      final table = FxTable([
        FxRate(
            from: Currency.usd,
            to: Currency.eur,
            rateNum: 90,
            rateDen: 100,
            asOf: on(-10)),
        FxRate(
            from: Currency.usd,
            to: Currency.eur,
            rateNum: 92,
            rateDen: 100,
            asOf: on(0)),
      ]);
      expect(table.rateFor(Currency.usd, Currency.eur)!.rateNum, 92);
      expect(
          table.rateFor(Currency.usd, Currency.eur, asOf: on(-5))!.rateNum, 90);
      expect(table.rateFor(Currency.eur, Currency.usd)!.from, Currency.eur);
      expect(table.rateFor(Currency.usd, Currency.jpy), isNull);
    });
  });

  group('FxConverter.convert', () {
    test('same currency is a no-op', () {
      const converter = FxConverter(FxTable([]));
      final r = converter.convert(const Money(100, Currency.usd), Currency.usd);
      expect(r.valueOrNull, const Money(100, Currency.usd));
    });

    test('USD → EUR (same exponent)', () {
      final converter = FxConverter(FxTable([
        FxRate(
            from: Currency.usd,
            to: Currency.eur,
            rateNum: 92,
            rateDen: 100,
            asOf: on(0)),
      ]));
      final r = converter.convert(const Money(100, Currency.usd), Currency.eur);
      expect(r.valueOrNull, const Money(92, Currency.eur)); // $1.00 → €0.92
    });

    test('USD → IRR and back (cross-exponent)', () {
      final converter = FxConverter(FxTable([
        FxRate(
            from: Currency.usd,
            to: Currency.irr,
            rateNum: 42000,
            rateDen: 1,
            asOf: on(0)),
      ]));
      final toIrr =
          converter.convert(const Money(100, Currency.usd), Currency.irr);
      expect(toIrr.valueOrNull,
          const Money(42000, Currency.irr)); // $1 → 42000 rial
      final back =
          converter.convert(const Money(42000, Currency.irr), Currency.usd);
      expect(back.valueOrNull, const Money(100, Currency.usd)); // via inverse
    });

    test('no rate → Err(NoFxRate)', () {
      const converter = FxConverter(FxTable([]));
      final r = converter.convert(const Money(100, Currency.usd), Currency.eur);
      expect(r.isErr, isTrue);
      expect(r.failureOrNull, isA<NoFxRate>());
      expect(r.failureOrNull!.code, 'fx.no_rate');
    });

    test('rounding modes at the .5 boundary', () {
      final converter = FxConverter(FxTable([
        FxRate(
            from: Currency.usd,
            to: Currency.eur,
            rateNum: 925,
            rateDen: 1000,
            asOf: on(0)),
      ]));
      // 100 * 925 * 100 / (1000 * 100) = 92.5 exactly.
      Money out(RoundingMode m) => converter
          .convert(const Money(100, Currency.usd), Currency.eur, rounding: m)
          .valueOrNull!;
      expect(out(RoundingMode.halfEven).minorUnits, 92); // nearest even
      expect(out(RoundingMode.halfUp).minorUnits, 93);
      expect(out(RoundingMode.ceil).minorUnits, 93);
      expect(out(RoundingMode.floor).minorUnits, 92);
    });

    test('negative amounts round symmetrically', () {
      final converter = FxConverter(FxTable([
        FxRate(
            from: Currency.usd,
            to: Currency.eur,
            rateNum: 925,
            rateDen: 1000,
            asOf: on(0)),
      ]));
      final r = converter.convert(
        const Money(-100, Currency.usd),
        Currency.eur,
        rounding: RoundingMode.halfUp,
      );
      expect(r.valueOrNull!.minorUnits, -93);
    });
  });

  group('FxConverter.stalenessOf', () {
    FxConverter at(int dayN) => FxConverter(
          const FxTable([]),
          clock: FixedClock(
            DateTime.fromMillisecondsSinceEpoch(base + dayN * day, isUtc: true),
          ),
        );

    FxRate rateOn(int dayN) => FxRate(
          from: Currency.usd,
          to: Currency.eur,
          rateNum: 92,
          rateDen: 100,
          asOf: on(dayN),
        );

    test('fresh / aging / stale bands', () {
      final converter = at(0);
      expect(converter.stalenessOf(rateOn(-3)), FxStaleness.fresh);
      expect(converter.stalenessOf(rateOn(-10)), FxStaleness.aging);
      expect(converter.stalenessOf(rateOn(-40)), FxStaleness.stale);
    });
  });
}
