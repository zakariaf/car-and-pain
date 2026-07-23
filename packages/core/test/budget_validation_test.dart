import 'package:core/core.dart';
import 'package:test/test.dart';

/// M6-T3 + M6-T10 — the pure budget-evaluation engine and the cost-integrity
/// validators.
void main() {
  group('budget evaluation (M6-T3)', () {
    const engine = BudgetEngine();

    test('under / at / over budget by spend-to-date', () {
      final under = engine.evaluate(
        targetMinor: 10000,
        spentToDateMinor: 6000,
        elapsedDays: 15,
        periodDays: 30,
      );
      expect(under.isOverBudget, isFalse);
      expect(under.percentUsed, 60);

      final over = engine.evaluate(
        targetMinor: 10000,
        spentToDateMinor: 11000,
        elapsedDays: 30,
        periodDays: 30,
      );
      expect(over.isOverBudget, isTrue);
      expect(over.percentUsed, 110);
    });

    test('projects end-of-period from run-rate + upcoming recurring', () {
      // 5_000 over 10 of 30 days → run-rate projects +10_000 for the remaining
      // 20 days → 15_000; plus a known 2_000 recurring instance → 17_000.
      final s = engine.evaluate(
        targetMinor: 12000,
        spentToDateMinor: 5000,
        elapsedDays: 10,
        periodDays: 30,
        upcomingRecurringMinor: 2000,
      );
      expect(s.projectedMinor, 17000);
      expect(s.isOverBudget, isFalse); // 5_000 ≤ 12_000 so far…
      expect(s.isProjectedOver, isTrue); // …but projected to blow it
    });

    test('crossed thresholds are reported highest-first, target-guarded', () {
      final s = engine.evaluate(
        targetMinor: 10000,
        spentToDateMinor: 9000,
        elapsedDays: 30,
        periodDays: 30,
      );
      expect(engine.crossedThresholds(s, [50, 80, 100]), [80, 50]);
      // A zero target crosses nothing (avoids divide-by-zero noise).
      final zero = engine.evaluate(
        targetMinor: 0,
        spentToDateMinor: 100,
        elapsedDays: 1,
        periodDays: 30,
      );
      expect(engine.crossedThresholds(zero, [80]), isEmpty);
    });
  });

  group('cost validators (M6-T10)', () {
    const v = CostValidators();

    test('FX rate: missing/zero/out-of-band warns; sane is clean', () {
      expect(v.fxRate(rateThousandths: null).single.code, 'missing_or_zero');
      expect(v.fxRate(rateThousandths: 0).single.code, 'missing_or_zero');
      expect(
        v
            .fxRate(
                rateThousandths: 50,
                sanityLowThousandths: 800,
                sanityHighThousandths: 1500)
            .single
            .code,
        'out_of_band',
      );
      expect(
        v.fxRate(
            rateThousandths: 920,
            sanityLowThousandths: 800,
            sanityHighThousandths: 1500),
        isEmpty,
      );
    });

    test('duplicate heuristic warns on a same day/amount/category repeat', () {
      const existing = [
        ExpenseKey(dayEpoch: 20000, amountMinor: 5000, categoryId: 'insurance'),
      ];
      expect(
        v.isLikelyDuplicate(
          const ExpenseKey(
              dayEpoch: 20000, amountMinor: 5000, categoryId: 'insurance'),
          existing,
        ),
        isTrue,
      );
      expect(
        v.isLikelyDuplicate(
          const ExpenseKey(dayEpoch: 20001, amountMinor: 5000),
          existing,
        ),
        isFalse,
      );
    });

    test('budget target and financing terms reject hard-invalid inputs', () {
      expect(v.budgetTarget(0).isErr, isTrue);
      expect(v.budgetTarget(100).isOk, isTrue);
      expect(
        v.financingTerms(principalMinor: -1, termMonths: 12).isErr,
        isTrue,
      );
      expect(
        v.financingTerms(principalMinor: 100000, termMonths: 0).isErr,
        isTrue,
      );
      expect(
        v.financingTerms(principalMinor: 100000, termMonths: 12).isOk,
        isTrue,
      );
    });
  });
}
