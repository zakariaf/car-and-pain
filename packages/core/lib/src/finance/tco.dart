/// M6-T5 · the pure Total-Cost-of-Ownership aggregator. Sums every cost source
/// for a vehicle over a period — the expense ledger (incl. amortized lump costs
/// and projected cross-module rows), financing interest, and depreciation — all
/// already normalised to the base currency (the caller converts via the dated-FX
/// table at the edge). Computes cost/distance and cost/day against the shared
/// odometer/engine-hour ledger denominator with an explicit insufficient-data
/// fallback (never a divide-by-zero or a misleading number on a new vehicle).
/// Pure, deterministic, integer minor units.
library;

/// One cost contributing to TCO, normalised to the base currency (M6-T5). The
/// [bucket] is the analytic category bucket (fuel/service/insurance/…), so custom
/// naming never destabilises the breakdown.
final class TcoCostItem {
  const TcoCostItem({required this.bucket, required this.amountMinor});

  final String bucket;
  final int amountMinor;
}

/// The computed TCO for a scope + period (M6-T5). [costPerKmMinor] /
/// [costPerDayMinor] are null when [hasEnoughData] is false.
final class TcoReport {
  const TcoReport({
    required this.totalMinor,
    required this.byBucket,
    required this.distanceMetres,
    required this.spanDays,
    required this.hasEnoughData,
    this.costPerKmMinor,
    this.costPerDayMinor,
  });

  final int totalMinor;

  /// Total per analytic bucket (includes synthetic `financing` + `depreciation`).
  final Map<String, int> byBucket;
  final int distanceMetres;
  final int spanDays;

  /// False when the denominator is below the min-samples floor — the per-unit
  /// figures are then null and the UI shows "not enough data" instead of a lie.
  final bool hasEnoughData;

  /// Minor units per kilometre, or null on insufficient data.
  final int? costPerKmMinor;

  /// Minor units per day, or null on insufficient data.
  final int? costPerDayMinor;
}

/// The pure TCO engine (M6-T5).
final class TcoEngine {
  const TcoEngine({
    this.minDistanceMetres = 1000000, // 1_000 km before per-km is meaningful
    this.minSpanDays = 30, // a month before per-day is meaningful
  });

  /// Below these the per-unit figures are suppressed as insufficient data.
  final int minDistanceMetres;
  final int minSpanDays;

  /// Aggregate [costs] plus [financingInterestMinor] and [depreciationMinor] (the
  /// value lost over the period, net of any known residual/sale) into a
  /// [TcoReport] over [distanceMetres] / [spanDays]. Every amount must already be
  /// in the base currency. Cross-module rows must be pre-deduplicated by the
  /// caller (count once — a module's own total OR its ledger projection, never
  /// both).
  TcoReport compute({
    required List<TcoCostItem> costs,
    required int distanceMetres,
    required int spanDays,
    int financingInterestMinor = 0,
    int depreciationMinor = 0,
  }) {
    final byBucket = <String, int>{};
    var total = 0;
    for (final c in costs) {
      byBucket.update(c.bucket, (v) => v + c.amountMinor,
          ifAbsent: () => c.amountMinor);
      total += c.amountMinor;
    }
    if (financingInterestMinor != 0) {
      byBucket.update('financing', (v) => v + financingInterestMinor,
          ifAbsent: () => financingInterestMinor);
      total += financingInterestMinor;
    }
    if (depreciationMinor != 0) {
      byBucket.update('depreciation', (v) => v + depreciationMinor,
          ifAbsent: () => depreciationMinor);
      total += depreciationMinor;
    }

    final enoughDistance = distanceMetres >= minDistanceMetres;
    final enoughDays = spanDays >= minSpanDays;
    return TcoReport(
      totalMinor: total,
      byBucket: byBucket,
      distanceMetres: distanceMetres,
      spanDays: spanDays,
      hasEnoughData: enoughDistance && enoughDays,
      costPerKmMinor:
          enoughDistance ? _divRoundHalfUp(total * 1000, distanceMetres) : null,
      costPerDayMinor: enoughDays ? _divRoundHalfUp(total, spanDays) : null,
    );
  }

  /// Round-half-up integer division (exact half threshold), negative-safe so a
  /// net-negative TCO (heavy refunds) rounds symmetrically.
  static int _divRoundHalfUp(int numerator, int denominator) {
    if (numerator < 0) {
      return -((2 * -numerator + denominator) ~/ (2 * denominator));
    }
    return (2 * numerator + denominator) ~/ (2 * denominator);
  }
}
