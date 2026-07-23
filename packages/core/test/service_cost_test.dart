import 'package:core/core.dart';
import 'package:test/test.dart';

/// M4-T10 — pure service cost & DIY-savings math. Integer minor units only; the
/// rounding is defined (round-half-up), so every rate is pinned exactly.
void main() {
  const engine = ServiceCostEngine();

  group('visit total = Σ(parts + labour) + tax − discount + fees', () {
    test('sums line items with tax, discount and fees', () {
      const visit = VisitCost(
        lineItems: [
          ServiceLineItemCost(labourMinor: 5000, partsMinor: 3000),
          ServiceLineItemCost(labourMinor: 2000, partsMinor: 1500),
        ],
        taxMinor: 1000,
        discountMinor: 500,
        feesMinor: 250,
      );
      expect(visit.labourMinor, 7000);
      expect(visit.partsMinor, 4500);
      expect(visit.subtotalMinor, 11500);
      // 11500 + 1000 − 500 + 250
      expect(engine.visitTotalMinor(visit), 12250);
    });

    test('empty visit totals zero', () {
      expect(const VisitCost().totalMinor, 0);
    });

    test('labour share is basis points, null on a zero subtotal', () {
      const visit = VisitCost(
        lineItems: [ServiceLineItemCost(labourMinor: 7500, partsMinor: 2500)],
      );
      expect(visit.labourShareBasisPoints, 7500); // 75.00%
      expect(const VisitCost().labourShareBasisPoints, isNull);
    });
  });

  group('labour from hours', () {
    test('whole-minute labour at an hourly rate, round-half-up', () {
      // 90 minutes at 6000/hour = 9000.
      expect(
        engine.labourCostMinor(labourMinutes: 90, ratePerHourMinor: 6000),
        9000,
      );
      // 50 minutes at 6000/hour = 5000 exactly.
      expect(
        engine.labourCostMinor(labourMinutes: 50, ratePerHourMinor: 6000),
        5000,
      );
      // 10 minutes at 5000/hour = 833.33 → 833.
      expect(
        engine.labourCostMinor(labourMinutes: 10, ratePerHourMinor: 5000),
        833,
      );
    });
  });

  group('DIY-vs-shop savings', () {
    test('positive when DIY is cheaper', () {
      expect(
        engine.diySavingsMinor(estimatedShopMinor: 20000, actualDiyMinor: 7000),
        13000,
      );
    });

    test('negative when DIY cost more (surfaced, not hidden)', () {
      expect(
        engine.diySavingsMinor(estimatedShopMinor: 5000, actualDiyMinor: 8000),
        -3000,
      );
    });
  });

  group('best quote', () {
    test('is the minimum', () {
      expect(engine.bestQuoteMinor([30000, 21000, 25500]), 21000);
    });
    test('is null with no quotes', () {
      expect(engine.bestQuoteMinor(const []), isNull);
    });
  });

  group('running cost', () {
    test('per-km and per-month with defined rounding', () {
      // 12000 minor over 200 km → 60/km; over 6 months (180 days) → 2000/month.
      expect(
        engine.costPerDistanceMinor(totalMinor: 12000, distanceMetres: 200000),
        60,
      );
      expect(
        engine.costPerMonthMinor(totalMinor: 12000, spanDays: 180),
        2000,
      );
    });

    test('rounds half up', () {
      // 100 over 3 km = 33.33/km → 33; 100 over 8 km scaled: 12.5 → 13.
      expect(
        engine.costPerDistanceMinor(totalMinor: 100, distanceMetres: 3000),
        33,
      );
      expect(
        engine.costPerDistanceMinor(totalMinor: 100, distanceMetres: 8000),
        13,
      );
    });

    test('insufficient-data fallbacks are null', () {
      expect(
        engine.costPerDistanceMinor(totalMinor: 12000, distanceMetres: 0),
        isNull,
      );
      expect(
        engine.costPerMonthMinor(totalMinor: 12000, spanDays: 0),
        isNull,
      );
    });

    test('rollup sums and derives both rates, each degrading independently',
        () {
      final rc = engine.runningCost(const [
        ServiceCostPoint(
            totalMinor: 6000, distanceMetres: 100000, spanDays: 90),
        ServiceCostPoint(
            totalMinor: 6000, distanceMetres: 100000, spanDays: 90),
      ]);
      expect(rc.totalMinor, 12000);
      expect(rc.distanceMetres, 200000);
      expect(rc.spanDays, 180);
      expect(rc.costPerKmMinor, 60);
      expect(rc.costPerMonthMinor, 2000);
    });

    test('time-only history still yields cost-per-month', () {
      final rc = engine.runningCost(const [
        ServiceCostPoint(totalMinor: 3000, distanceMetres: 0, spanDays: 30),
      ]);
      expect(rc.costPerKmMinor, isNull); // no distance
      expect(rc.costPerMonthMinor, 3000);
    });

    test('a negative (refund) numerator rounds half away from zero', () {
      // -100 over 3 km = -33.33 → -33 (symmetric with the positive case).
      expect(
        engine.costPerDistanceMinor(totalMinor: -100, distanceMetres: 3000),
        -33,
      );
    });
  });

  test('value objects construct at runtime (guards + getters)', () {
    // `int.parse` defeats const-folding so the constructor bodies actually run.
    final n = int.parse('2');
    final li = ServiceLineItemCost(labourMinor: n, partsMinor: n);
    expect(li.subtotalMinor, 4);
    final visit = VisitCost(lineItems: [li], taxMinor: n, feesMinor: n);
    expect(visit.totalMinor, 4 + 2 + 2);
    final point =
        ServiceCostPoint(totalMinor: n, distanceMetres: n, spanDays: n);
    expect(point.totalMinor, 2);
  });
}
