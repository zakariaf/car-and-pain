/// M4-T10 · pure service-cost & DIY-savings math over the line-item / labour /
/// parts / tax data. Every amount is **integer minor units in a single currency**
/// (the visit's) — there is no float anywhere in the money path. Combining
/// entries recorded in different currencies is the caller's job: convert through
/// the dated FX layer at the edge first, then feed one common currency here. This
/// engine never silently mixes currencies.
///
/// Feeds service cost analytics and, upstream, the TCO stack.
library;

/// One line item's cost, split into labour and parts (minor units).
final class ServiceLineItemCost {
  const ServiceLineItemCost({this.labourMinor = 0, this.partsMinor = 0})
      : assert(labourMinor >= 0, 'labour must be >= 0'),
        assert(partsMinor >= 0, 'parts must be >= 0');

  final int labourMinor;
  final int partsMinor;

  int get subtotalMinor => labourMinor + partsMinor;
}

/// A visit's full cost breakdown. The **visit total** is the canonical formula
/// `Σ(parts + labour) + tax − discount + fees`; the labour/parts split is exposed
/// for analytics. Discount is stored positive and subtracted.
final class VisitCost {
  const VisitCost({
    this.lineItems = const [],
    this.taxMinor = 0,
    this.discountMinor = 0,
    this.feesMinor = 0,
  })  : assert(taxMinor >= 0, 'tax must be >= 0'),
        assert(discountMinor >= 0, 'discount is stored positive'),
        assert(feesMinor >= 0, 'fees must be >= 0');

  final List<ServiceLineItemCost> lineItems;
  final int taxMinor;
  final int discountMinor;
  final int feesMinor;

  int get labourMinor => lineItems.fold(0, (sum, li) => sum + li.labourMinor);

  int get partsMinor => lineItems.fold(0, (sum, li) => sum + li.partsMinor);

  int get subtotalMinor => labourMinor + partsMinor;

  /// `Σ(parts + labour) + tax − discount + fees`.
  int get totalMinor => subtotalMinor + taxMinor - discountMinor + feesMinor;

  /// Labour as a fraction of the parts+labour subtotal, in basis points
  /// (0–10000), or null when the subtotal is zero. Deterministic, integer-only.
  int? get labourShareBasisPoints => subtotalMinor == 0
      ? null
      : _divRoundHalfUp(labourMinor * 10000, subtotalMinor);
}

/// A single historical visit contributing to a running-cost rollup: its total
/// cost plus the odometer and time span it covers since the previous visit.
final class ServiceCostPoint {
  const ServiceCostPoint({
    required this.totalMinor,
    required this.distanceMetres,
    required this.spanDays,
  });

  final int totalMinor;

  /// Distance covered attributable to this cost (metres).
  final int distanceMetres;

  /// Calendar days this cost spans.
  final int spanDays;
}

/// A derived running-cost view — null-safe on insufficient data.
final class RunningCost {
  const RunningCost({
    required this.totalMinor,
    required this.distanceMetres,
    required this.spanDays,
    required this.costPerKmMinor,
    required this.costPerMonthMinor,
  });

  final int totalMinor;
  final int distanceMetres;
  final int spanDays;

  /// Minor units per kilometre, or null when distance is unknown/zero.
  final int? costPerKmMinor;

  /// Minor units per 30-day month, or null when the span is unknown/zero.
  final int? costPerMonthMinor;
}

/// Pure, I/O-free cost engine. All methods are deterministic and table-testable.
final class ServiceCostEngine {
  const ServiceCostEngine();

  /// `Σ(parts + labour) + tax − discount + fees` for one visit.
  int visitTotalMinor(VisitCost visit) => visit.totalMinor;

  /// Labour cost from canonical whole-minute [labourMinutes] at
  /// [ratePerHourMinor] (minor units per hour), round-half-up.
  int labourCostMinor({
    required int labourMinutes,
    required int ratePerHourMinor,
  }) {
    assert(labourMinutes >= 0, 'minutes must be >= 0');
    assert(ratePerHourMinor >= 0, 'rate must be >= 0');
    return _divRoundHalfUp(ratePerHourMinor * labourMinutes, 60);
  }

  /// DIY-vs-shop savings = estimated shop cost − actual DIY cost. Not clamped: a
  /// DIY that cost *more* returns a real negative number rather than hiding it.
  int diySavingsMinor({
    required int estimatedShopMinor,
    required int actualDiyMinor,
  }) =>
      estimatedShopMinor - actualDiyMinor;

  /// `best_quote = min(quotes)`. Null when there are no quotes.
  int? bestQuoteMinor(List<int> quoteMinors) {
    if (quoteMinors.isEmpty) return null;
    return quoteMinors.reduce((a, b) => a < b ? a : b);
  }

  /// Cost per [perMetres] of distance in minor units (round-half-up). Per-km is
  /// the default. Null when distance ≤ 0 (insufficient-data fallback).
  int? costPerDistanceMinor({
    required int totalMinor,
    required int distanceMetres,
    int perMetres = 1000,
  }) {
    if (distanceMetres <= 0) return null;
    return _divRoundHalfUp(totalMinor * perMetres, distanceMetres);
  }

  /// Cost per [daysPerMonth]-day month in minor units (round-half-up). Null when
  /// the span ≤ 0.
  int? costPerMonthMinor({
    required int totalMinor,
    required int spanDays,
    int daysPerMonth = 30,
  }) {
    if (spanDays <= 0) return null;
    return _divRoundHalfUp(totalMinor * daysPerMonth, spanDays);
  }

  /// Roll a service-cost history up into a [RunningCost]. Distance and span are
  /// summed; each rate degrades to null independently when its denominator is
  /// zero, so a time-only history still yields cost-per-month.
  RunningCost runningCost(List<ServiceCostPoint> history) {
    var total = 0;
    var distance = 0;
    var days = 0;
    for (final p in history) {
      total += p.totalMinor;
      distance += p.distanceMetres;
      days += p.spanDays;
    }
    return RunningCost(
      totalMinor: total,
      distanceMetres: distance,
      spanDays: days,
      costPerKmMinor:
          costPerDistanceMinor(totalMinor: total, distanceMetres: distance),
      costPerMonthMinor: costPerMonthMinor(totalMinor: total, spanDays: days),
    );
  }

  /// Round-half-up integer division for a non-negative-safe rate. [denominator]
  /// must be > 0 (guaranteed by callers). Uses `(2n + d) ~/ (2d)` so the half
  /// threshold is exact for any denominator; handles negative numerators
  /// symmetrically (round half away from zero).
  static int _divRoundHalfUp(int numerator, int denominator) {
    if (numerator < 0) {
      return -((2 * -numerator + denominator) ~/ (2 * denominator));
    }
    return (2 * numerator + denominator) ~/ (2 * denominator);
  }
}

// Expose the same rounding to VisitCost's basis-point split without duplicating.
int _divRoundHalfUp(int numerator, int denominator) =>
    ServiceCostEngine._divRoundHalfUp(numerator, denominator);
