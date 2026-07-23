import 'package:core/core.dart';
import 'package:test/test.dart';

/// M6-T4 — the loan/lease amortization engine. Integer minor units, deterministic
/// rounding; the schedule always zeroes (loan) or settles to the residual (lease)
/// and the payments sum back to principal + interest exactly.
void main() {
  const engine = AmortizationEngine();

  group('loan schedule', () {
    test('zero-APR splits principal evenly and zeroes the balance', () {
      const terms =
          LoanTerms(principalMinor: 120000, aprBps: 0, termMonths: 12);
      final s = engine.schedule(terms);
      expect(s.rows, hasLength(12));
      expect(s.monthlyPaymentMinor, 10000); // 120000 / 12
      expect(s.rows.every((r) => r.interestMinor == 0), isTrue);
      expect(s.rows.last.balanceMinor, 0);
      expect(s.totalInterestMinor, 0);
      expect(s.totalPaidMinor, 120000);
    });

    test('interest-bearing loan zeroes within a minor unit; payments sum back',
        () {
      // 120_000 minor (1200.00) at 12% APR over 12 months.
      const terms =
          LoanTerms(principalMinor: 120000, aprBps: 1200, termMonths: 12);
      final s = engine.schedule(terms);
      expect(s.rows, hasLength(12));
      expect(s.rows.last.balanceMinor, 0); // fully amortized
      // Every period: payment = interest + principal (no leakage).
      for (final r in s.rows) {
        expect(r.paymentMinor, r.interestMinor + r.principalMinor);
      }
      // Sum-back: total paid = principal + total interest, exactly.
      expect(s.totalPaidMinor, 120000 + s.totalInterestMinor);
      expect(s.totalInterestMinor, greaterThan(0));
      // Balance is monotonically non-increasing.
      var prev = terms.principalMinor;
      for (final r in s.rows) {
        expect(r.balanceMinor, lessThanOrEqualTo(prev));
        prev = r.balanceMinor;
      }
    });
  });

  group('early payoff', () {
    const terms =
        LoanTerms(principalMinor: 120000, aprBps: 1200, termMonths: 12);

    test('payoff after N periods is the outstanding balance + interest saved',
        () {
      final full = engine.schedule(terms);
      final quote = engine.payoffAfter(terms, 6);
      expect(quote.afterPeriod, 6);
      expect(quote.payoffMinor, full.rows[5].balanceMinor); // balance after 6
      // Interest saved = the interest of the periods no longer paid (7..12).
      final remaining =
          full.rows.skip(6).fold(0, (a, r) => a + r.interestMinor);
      expect(quote.interestSavedMinor, remaining);
      expect(quote.interestSavedMinor, greaterThan(0));
    });

    test('payoff at term 0 is the full principal; at term is zero', () {
      expect(engine.payoffAfter(terms, 0).payoffMinor, 120000);
      expect(engine.payoffAfter(terms, 12).payoffMinor, 0);
      // Clamped beyond the term.
      expect(engine.payoffAfter(terms, 99).payoffMinor, 0);
    });
  });

  test('refinance carries the outstanding balance into a new schedule', () {
    const terms =
        LoanTerms(principalMinor: 120000, aprBps: 1200, termMonths: 12);
    final carried = engine.payoffAfter(terms, 6).payoffMinor;
    final successor =
        engine.refinance(terms, 6, newAprBps: 600, newTermMonths: 6);
    // The successor starts from the carried balance and zeroes over its term.
    expect(successor.rows, hasLength(6));
    expect(successor.rows.last.balanceMinor, 0);
    expect(
      successor.rows.first.balanceMinor + successor.rows.first.principalMinor,
      carried,
    );
  });

  test('a lease amortizes the financed portion down to the residual', () {
    // 300_000 minor financed, 24 months, residual 120_000 (settles there).
    const terms = LoanTerms(
      principalMinor: 300000,
      aprBps: 900,
      termMonths: 24,
      kind: FinancingKind.lease,
      residualMinor: 120000,
    );
    final s = engine.schedule(terms);
    expect(s.kind, FinancingKind.lease);
    expect(s.rows.last.balanceMinor, 120000); // settles to the residual
    expect(s.rows.length, lessThanOrEqualTo(24));
  });
}
