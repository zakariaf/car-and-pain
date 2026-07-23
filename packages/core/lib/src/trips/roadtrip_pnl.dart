/// M7-T4 · the pure per-road-trip profit-and-loss aggregator.
///
/// A road trip groups legs, linked fuel fills, and linked expenses into one
/// container. This engine folds those into live running totals — distance,
/// spend, daily average, per-person share, cost-per-distance — with **no float
/// in the money path**. Aggregated fuel economy is deliberately *not* computed
/// here: it is the `EconomyEngine`'s full-to-full job (so a partial fill defers
/// the figure instead of reporting a wrong one), and the caller feeds the linked
/// fills straight to it. Midnight-spanning / multi-day / DST trips are handled
/// by the caller passing a whole-day `spanDays`; this engine never double-counts.
library;

/// The inputs for one road trip's P&L, all canonical (metres, minor units, whole
/// days). Currency is single: convert linked costs through the dated FX layer at
/// the edge before summing.
final class RoadTripInput {
  const RoadTripInput({
    required this.currencyCode,
    this.legDistancesMetres = const [],
    this.fuelCostMinor = 0,
    this.expenseCostMinor = 0,
    this.spanDays = 1,
    this.companionCount = 1,
  })  : assert(spanDays >= 1, 'a trip spans at least one day'),
        assert(companionCount >= 1, 'at least one person'),
        assert(fuelCostMinor >= 0 && expenseCostMinor >= 0,
            'costs are stored non-negative');

  final String currencyCode;

  /// Each leg's distance (metres); summed for the trip distance.
  final List<int> legDistancesMetres;

  /// Σ of linked fills' cost (minor units).
  final int fuelCostMinor;

  /// Σ of linked expenses — tolls, parking, lodging (minor units).
  final int expenseCostMinor;

  /// Whole days elapsed (≥ 1); the caller computes this from the leg calendar so
  /// DST and midnight spans never inflate it.
  final int spanDays;

  /// People sharing the trip cost (≥ 1); drives the per-person share.
  final int companionCount;
}

/// The rolled-up P&L for a road trip. Every figure is derived; nothing stored.
final class RoadTripPnl {
  const RoadTripPnl({
    required this.currencyCode,
    required this.distanceMetres,
    required this.fuelCostMinor,
    required this.expenseCostMinor,
    required this.spanDays,
    required this.companionCount,
  });

  /// Fold a [RoadTripInput] into a P&L.
  factory RoadTripPnl.of(RoadTripInput input) {
    final distance = input.legDistancesMetres.fold<int>(0, (sum, d) => sum + d);
    return RoadTripPnl(
      currencyCode: input.currencyCode,
      distanceMetres: distance,
      fuelCostMinor: input.fuelCostMinor,
      expenseCostMinor: input.expenseCostMinor,
      spanDays: input.spanDays,
      companionCount: input.companionCount,
    );
  }

  final String currencyCode;
  final int distanceMetres;
  final int fuelCostMinor;
  final int expenseCostMinor;
  final int spanDays;
  final int companionCount;

  /// Fuel + expenses.
  int get totalCostMinor => fuelCostMinor + expenseCostMinor;

  /// `total_cost / span_days`, round-half-up. Always defined (span ≥ 1).
  int get avgCostPerDayMinor => _divRoundHalfUp(totalCostMinor, spanDays);

  /// `total_cost / companion_count`, round-half-up. Always defined (count ≥ 1).
  int get perPersonShareMinor =>
      _divRoundHalfUp(totalCostMinor, companionCount);

  /// `total_cost / distance` expressed per kilometre (minor units), or null when
  /// no distance has been logged yet. `total × 1000m / distance`, round-half-up.
  int? get costPerKmMinor => distanceMetres <= 0
      ? null
      : _divRoundHalfUp(totalCostMinor * 1000, distanceMetres);
}

int _divRoundHalfUp(int numerator, int denominator) {
  if (numerator < 0) {
    return -((2 * -numerator + denominator) ~/ (2 * denominator));
  }
  return (2 * numerator + denominator) ~/ (2 * denominator);
}
