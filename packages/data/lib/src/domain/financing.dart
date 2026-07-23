import 'package:core/core.dart';

/// A loan or lease against a vehicle (M6-T4), Drift-free. The amortization
/// schedule is recomputed by the pure [AmortizationEngine] from these terms.
class Financing {
  const Financing({
    required this.id,
    required this.vehicleId,
    required this.kind,
    required this.principalMinor,
    required this.currencyCode,
    required this.aprBps,
    required this.termMonths,
    required this.startDate,
    this.residualMinor = 0,
    this.refinancedFromId,
    this.closedAt,
    this.notes,
  });

  final String id;
  final String vehicleId;

  /// loan | lease.
  final String kind;
  final int principalMinor;
  final String currencyCode;
  final int aprBps;
  final int termMonths;
  final Instant startDate;
  final int residualMinor;
  final String? refinancedFromId;
  final Instant? closedAt;
  final String? notes;

  bool get isClosed => closedAt != null;

  FinancingKind get financingKind =>
      kind == 'lease' ? FinancingKind.lease : FinancingKind.loan;

  /// The pure-engine inputs (M6-T4).
  LoanTerms toLoanTerms() => LoanTerms(
        principalMinor: principalMinor,
        aprBps: aprBps,
        termMonths: termMonths,
        kind: financingKind,
        residualMinor: residualMinor,
      );
}

/// A spending budget (M6-T3), Drift-free.
class Budget {
  const Budget({
    required this.id,
    required this.period,
    required this.targetMinor,
    required this.currencyCode,
    this.vehicleId,
    this.categoryId,
    this.basis = 'cash',
    this.lastAlertThreshold,
    this.lastAlertPeriod,
  });

  final String id;

  /// null = all-vehicles.
  final String? vehicleId;

  /// null = overall (across categories).
  final String? categoryId;

  /// monthly | quarterly | annual.
  final String period;
  final int targetMinor;
  final String currencyCode;

  /// cash | amortized.
  final String basis;

  /// The highest alert threshold already fired + the period key it fired for
  /// (M6-T3 de-dup: fire each threshold once per period).
  final int? lastAlertThreshold;
  final String? lastAlertPeriod;

  BudgetPeriod get budgetPeriod => switch (period) {
        'quarterly' => BudgetPeriod.quarterly,
        'annual' => BudgetPeriod.annual,
        _ => BudgetPeriod.monthly,
      };
}
