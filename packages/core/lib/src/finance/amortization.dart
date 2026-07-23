/// M6-T4 · the pure-Dart financing backbone: loan/lease amortization, early
/// payoff, refinance, depreciation, and equity/negative-equity — all in integer
/// minor units with deterministic rounding to the currency exponent. No I/O.
library;

import 'dart:math' as math;

/// The kind of financing.
enum FinancingKind { loan, lease }

/// The inputs to an amortization (M6-T4). Money is integer minor units; [aprBps]
/// is the annual percentage rate in **basis points** (599 = 5.99%). For a lease,
/// [residualMinor] is the end-of-term residual/balloon the rent charge amortizes
/// down to (0 for a loan).
final class LoanTerms {
  const LoanTerms({
    required this.principalMinor,
    required this.aprBps,
    required this.termMonths,
    this.kind = FinancingKind.loan,
    this.residualMinor = 0,
  })  : assert(principalMinor > 0, 'principal must be positive'),
        assert(aprBps >= 0, 'APR cannot be negative'),
        assert(termMonths > 0, 'term must be positive'),
        assert(residualMinor >= 0, 'residual cannot be negative');

  final int principalMinor;
  final int aprBps;
  final int termMonths;
  final FinancingKind kind;
  final int residualMinor;

  /// The periodic (monthly) rate as a fraction. For a lease this is the rent
  /// charge rate derived from the money factor (APR / 2400 == moneyFactor, so the
  /// monthly rate is APR/1200 applied to the depreciating+residual base).
  double get monthlyRate => aprBps / 10000 / 12;
}

/// One period of an amortization schedule (M6-T4). All fields are minor units.
final class AmortizationRow {
  const AmortizationRow({
    required this.period,
    required this.paymentMinor,
    required this.interestMinor,
    required this.principalMinor,
    required this.balanceMinor,
  });

  /// 1-based period index.
  final int period;
  final int paymentMinor;
  final int interestMinor;
  final int principalMinor;

  /// Balance remaining AFTER this period's payment.
  final int balanceMinor;
}

/// A computed amortization schedule with the derived positions (M6-T4).
final class AmortizationSchedule {
  const AmortizationSchedule({required this.rows, required this.kind});

  final List<AmortizationRow> rows;
  final FinancingKind kind;

  int get totalInterestMinor => rows.fold(0, (sum, r) => sum + r.interestMinor);

  int get totalPaidMinor => rows.fold(0, (sum, r) => sum + r.paymentMinor);

  /// The scheduled monthly payment (the first row's payment; the final row may
  /// differ by the rounding remainder).
  int get monthlyPaymentMinor => rows.isEmpty ? 0 : rows.first.paymentMinor;

  /// The outstanding balance after [period] payments (0 → the opening balance).
  /// Clamped to the schedule bounds.
  int balanceAfter(int period) {
    if (rows.isEmpty) return 0;
    if (period <= 0) {
      return rows.first.balanceMinor + rows.first.principalMinor;
    }
    if (period >= rows.length) return rows.last.balanceMinor;
    return rows[period - 1].balanceMinor;
  }
}

/// A payoff quote at a point in the schedule (M6-T4).
final class PayoffQuote {
  const PayoffQuote({
    required this.afterPeriod,
    required this.payoffMinor,
    required this.interestSavedMinor,
  });

  /// The payoff is taken immediately after this many periods have been paid.
  final int afterPeriod;

  /// The lump sum to settle the debt now (the outstanding balance).
  final int payoffMinor;

  /// Interest avoided versus running the loan to term.
  final int interestSavedMinor;
}

/// The pure amortization engine (M6-T4). Deterministic, I/O-free, minor units.
final class AmortizationEngine {
  const AmortizationEngine();

  /// The level monthly payment (minor units) for [terms], rounded to the nearest
  /// minor unit. Zero-APR splits the (principal − residual) evenly. The schedule
  /// absorbs the rounding remainder in the final period so the balance zeroes.
  int monthlyPaymentMinor(LoanTerms terms) {
    final financed = terms.principalMinor - terms.residualMinor;
    final r = terms.monthlyRate;
    if (r == 0) {
      return (financed / terms.termMonths).ceil();
    }
    // Standard amortization: P·r / (1 − (1+r)^−n), on the amount above residual,
    // plus the residual's carried interest (a lease pays interest on principal+
    // residual throughout — modelled by financing the full principal and paying
    // the residual as a balloon at term).
    final n = terms.termMonths;
    final factor = r / (1 - math.pow(1 + r, -n));
    return (financed * factor).round();
  }

  /// The full period-by-period schedule for [terms]. The final payment is
  /// adjusted so the running balance reaches the residual (loan → 0) exactly.
  AmortizationSchedule schedule(LoanTerms terms) {
    final r = terms.monthlyRate;
    final basePayment = monthlyPaymentMinor(terms);
    final rows = <AmortizationRow>[];
    var balance = terms.principalMinor;
    // A loan amortizes to 0; a lease amortizes the financed portion to the
    // residual, which is then due as a balloon.
    final floor = terms.residualMinor;

    for (var i = 1; i <= terms.termMonths; i++) {
      final interest = (balance * r).round();
      var payment = basePayment;
      var principal = payment - interest;
      final isLast = i == terms.termMonths;
      // Never amortize below the floor; the last period settles to the floor.
      if (isLast || balance - principal < floor) {
        principal = balance - floor;
        payment = principal + interest;
      }
      balance -= principal;
      rows.add(AmortizationRow(
        period: i,
        paymentMinor: payment,
        interestMinor: interest,
        principalMinor: principal,
        balanceMinor: balance,
      ));
      if (balance <= floor) break;
    }
    return AmortizationSchedule(rows: rows, kind: terms.kind);
  }

  /// A payoff quote after [afterPeriod] payments (M6-T4): the outstanding balance
  /// now, and the interest saved versus running to term. [afterPeriod] is clamped
  /// to `[0, term]`.
  PayoffQuote payoffAfter(LoanTerms terms, int afterPeriod) {
    final full = schedule(terms);
    final p = afterPeriod.clamp(0, full.rows.length);
    final payoff = full.balanceAfter(p);
    // Interest that would still be paid from period p+1 to term.
    final remainingInterest =
        full.rows.skip(p).fold(0, (sum, row) => sum + row.interestMinor);
    return PayoffQuote(
      afterPeriod: p,
      payoffMinor: payoff,
      interestSavedMinor: remainingInterest,
    );
  }

  /// **Refinance** (M6-T4): close [current] after [afterPeriod] payments and open
  /// a successor carrying the outstanding balance at the new APR/term (its
  /// principal is the carried balance). Returns the successor's schedule; the
  /// caller links the two in history.
  AmortizationSchedule refinance(
    LoanTerms current,
    int afterPeriod, {
    required int newAprBps,
    required int newTermMonths,
  }) {
    final carried = payoffAfter(current, afterPeriod).payoffMinor;
    return schedule(LoanTerms(
      principalMinor: carried,
      aprBps: newAprBps,
      termMonths: newTermMonths,
    ));
  }
}
