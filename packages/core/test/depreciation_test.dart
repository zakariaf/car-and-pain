import 'package:core/core.dart';
import 'package:test/test.dart';

/// M6-T4 — depreciation curves + equity/negative-equity. Integer minor units.
void main() {
  group('straight-line', () {
    const curve = DepreciationCurve(
      initialValueMinor: 2000000, // 20_000.00
      usefulLifeMonths: 60,
      salvageValueMinor: 200000, // 2_000.00 floor
    );

    test('spreads the loss evenly to the salvage floor', () {
      expect(curve.valueAt(0), 2000000);
      // Half-life: initial − (depreciable × 30/60) = 2_000_000 − 900_000.
      expect(curve.valueAt(30), 1100000);
      expect(curve.valueAt(60), 200000); // salvage
      expect(curve.valueAt(120), 200000); // never below salvage
    });
  });

  group('declining-balance', () {
    const curve = DepreciationCurve(
      initialValueMinor: 2000000,
      usefulLifeMonths: 60,
      method: DepreciationMethod.decliningBalance,
    );

    test('applies a constant annual rate', () {
      expect(curve.valueAt(0), 2000000);
      expect(curve.valueAt(12), 1600000); // ×0.8
      expect(curve.valueAt(24), 1280000); // ×0.64
    });

    test('never falls below salvage', () {
      const floored = DepreciationCurve(
        initialValueMinor: 2000000,
        usefulLifeMonths: 60,
        method: DepreciationMethod.decliningBalance,
        annualRateBps: 5000,
        salvageValueMinor: 500000,
      );
      expect(floored.valueAt(120), 500000);
    });
  });

  group('equity / negative equity', () {
    test('positive equity when worth more than owed', () {
      const e = EquityPosition(valueMinor: 1500000, loanBalanceMinor: 1000000);
      expect(e.equityMinor, 500000);
      expect(e.isNegative, isFalse);
    });

    test('negative equity is surfaced, never clamped', () {
      const e = EquityPosition(valueMinor: 1000000, loanBalanceMinor: 1200000);
      expect(e.equityMinor, -200000);
      expect(e.isNegative, isTrue);
    });
  });
}
