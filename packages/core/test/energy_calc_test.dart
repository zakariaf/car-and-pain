import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('completeFill (enter-any-two, 3-decimal price)', () {
    test('volume + price → total (EUR, exponent 2)', () {
      // 40 L @ €1.759/L = €70.36 → 7036 cents.
      final r =
          completeFill(exponent: 2, volumeMl: 40000, priceThousandths: 1759);
      expect(r!.totalMinor, 7036);
    });

    test('total + volume → price', () {
      final r = completeFill(exponent: 2, volumeMl: 40000, totalMinor: 7036);
      expect(r!.priceThousandths, 1759);
    });

    test('total + price → volume', () {
      final r =
          completeFill(exponent: 2, priceThousandths: 1759, totalMinor: 7036);
      expect(r!.volumeMl, closeTo(40000, 20)); // rounds to the litre-ish
    });

    test('exponent 0 (JPY/IRR): whole-unit money', () {
      // 40 L @ ¥170.500/L = ¥6820.
      final r =
          completeFill(exponent: 0, volumeMl: 40000, priceThousandths: 170500);
      expect(r!.totalMinor, 6820);
    });

    test('exponent 3 (KWD): three-decimal money', () {
      // 40 L @ 0.105/L (fils-precision) → 40 * 0.105 = 4.200 KWD = 4200 fils.
      final r =
          completeFill(exponent: 3, volumeMl: 40000, priceThousandths: 105);
      expect(r!.totalMinor, 4200);
    });

    test('all three present pass through unchanged (authoritative fields win)',
        () {
      final r = completeFill(
          exponent: 2,
          volumeMl: 40000,
          priceThousandths: 1759,
          totalMinor: 7000);
      expect(r!.volumeMl, 40000);
      expect(r.priceThousandths, 1759);
      expect(r.totalMinor, 7000); // NOT recomputed to 7036
    });

    test('fewer than two knowns → null', () {
      expect(completeFill(exponent: 2, volumeMl: 40000), isNull);
      expect(completeFill(exponent: 2), isNull);
    });

    test('zero guards never divide by zero', () {
      expect(
          completeFill(exponent: 2, volumeMl: 0, totalMinor: 500)!
              .priceThousandths,
          0);
      expect(
          completeFill(exponent: 2, priceThousandths: 0, totalMinor: 500)!
              .volumeMl,
          0);
    });
  });
}
