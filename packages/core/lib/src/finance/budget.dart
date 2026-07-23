/// M6-T3 · the pure budget-evaluation engine. Computes spend-to-date against a
/// target and a projected end-of-period spend (run-rate + known upcoming
/// recurring instances), and reports which alert thresholds are crossed. Integer
/// minor units, no I/O; alert de-duplication (fire once per crossing per period)
/// is the repository's concern — this engine only computes the state.
library;

/// A budget's calendar-aware period.
enum BudgetPeriod { monthly, quarterly, annual }

/// The evaluated state of a budget for the current period (M6-T3).
final class BudgetStatus {
  const BudgetStatus({
    required this.targetMinor,
    required this.spentMinor,
    required this.projectedMinor,
    required this.percentUsed,
  });

  final int targetMinor;

  /// Spend committed so far this period (on the chosen cash/amortized basis).
  final int spentMinor;

  /// Projected end-of-period spend: spend-to-date + run-rate over the remaining
  /// days + known upcoming recurring instances.
  final int projectedMinor;

  /// Spend-to-date as a percent of target (0 when the target is 0).
  final int percentUsed;

  bool get isOverBudget => spentMinor > targetMinor;
  bool get isProjectedOver => projectedMinor > targetMinor;
}

/// The pure budget engine (M6-T3).
final class BudgetEngine {
  const BudgetEngine();

  /// Evaluate a budget of [targetMinor] given [spentToDateMinor] over
  /// [elapsedDays] of a [periodDays] period, plus the [upcomingRecurringMinor]
  /// already-known recurring instances still to land this period. The projection
  /// extends the current run-rate over the remaining days and adds the known
  /// upcoming instances.
  BudgetStatus evaluate({
    required int targetMinor,
    required int spentToDateMinor,
    required int elapsedDays,
    required int periodDays,
    int upcomingRecurringMinor = 0,
  }) {
    final elapsed = elapsedDays < 1 ? 1 : elapsedDays;
    final remaining = periodDays - elapsed;
    final projectedFromRate = remaining <= 0
        ? 0
        : _divRoundHalfUp(spentToDateMinor * remaining, elapsed);
    final projected =
        spentToDateMinor + projectedFromRate + upcomingRecurringMinor;
    final percent = targetMinor == 0
        ? 0
        : _divRoundHalfUp(spentToDateMinor * 100, targetMinor);
    return BudgetStatus(
      targetMinor: targetMinor,
      spentMinor: spentToDateMinor,
      projectedMinor: projected,
      percentUsed: percent,
    );
  }

  /// The alert [thresholds] (percentages, e.g. `[80, 100]`) that spend-to-date has
  /// crossed for [status], highest first. The caller de-duplicates against what
  /// was already fired this period so each crossing notifies once.
  List<int> crossedThresholds(BudgetStatus status, List<int> thresholds) {
    if (status.targetMinor <= 0) return const [];
    final crossed = thresholds.where((t) => status.percentUsed >= t).toList()
      ..sort((a, b) => b.compareTo(a));
    return crossed;
  }

  static int _divRoundHalfUp(int numerator, int denominator) {
    if (numerator < 0) {
      return -((2 * -numerator + denominator) ~/ (2 * denominator));
    }
    return (2 * numerator + denominator) ~/ (2 * denominator);
  }
}
