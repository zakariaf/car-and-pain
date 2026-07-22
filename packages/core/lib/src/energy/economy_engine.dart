/// The pure fuel-economy state machine (M3-T2) — the correctness core.
///
/// It walks a vehicle's chronologically ordered energy fills and computes
/// real-world consumption via the **full-to-full algorithm**: over a full→full
/// interval, `distance = odo_end − odo_start` and `fuel = Σ volumes in the
/// interval`. It classifies each entry through the full / partial / missed /
/// first-fill / excluded state machine. No I/O — plain value in, plain value
/// out, exhaustively table-testable.
library;

import '../time/temporal.dart';

/// A single energy purchase (liquid/gas fill or EV charge) as the economy
/// engine sees it — **canonical units only** (mL, metres, minor currency units,
/// UTC instant). Display conversion (L/100km, MPG, …) lives at the edge.
class EnergyFill {
  const EnergyFill({
    required this.filledAt,
    required this.odometerMetres,
    required this.volumeMl,
    required this.costMinor,
    this.isFullTank = true,
    this.isMissedPrevious = false,
    this.excludeFromEconomy = false,
  });

  final Instant filledAt;
  final int odometerMetres;

  /// Fuel volume in millilitres (SI base); for an EV charge this carries the
  /// energy proxy the caller chose to compare on, or 0 if economy is energy-led.
  final int volumeMl;
  final int costMinor;

  /// Whether the tank was filled to full (the interval-closing boundary). A
  /// partial fill is `false`.
  final bool isFullTank;

  /// A fill was forgotten before this one — the interval it belongs to cannot be
  /// measured (economy excluded), but its cost still counts in spend.
  final bool isMissedPrevious;

  /// Splash-fill / jerrycan: keep the cost in spend but never let it distort an
  /// economy interval.
  final bool excludeFromEconomy;
}

/// A completed full-to-full consumption interval, canonical units.
class ConsumptionInterval {
  const ConsumptionInterval({
    required this.endAt,
    required this.distanceMetres,
    required this.volumeMl,
    required this.costMinor,
  });

  final Instant endAt;

  /// `odo_end − odo_start`, always > 0.
  final int distanceMetres;

  /// Σ of every fill's volume across the interval (partials included).
  final int volumeMl;

  /// Σ of fuel cost across the interval (drives cost-per-distance).
  final int costMinor;

  /// Canonical economy: millilitres burned per metre (lower is more efficient).
  double get mlPerMetre => volumeMl / distanceMetres;

  @override
  bool operator ==(Object other) =>
      other is ConsumptionInterval &&
      other.endAt == endAt &&
      other.distanceMetres == distanceMetres &&
      other.volumeMl == volumeMl &&
      other.costMinor == costMinor;

  @override
  int get hashCode => Object.hash(endAt, distanceMetres, volumeMl, costMinor);
}

/// The economy summary over a vehicle's fill history.
class EconomyReport {
  const EconomyReport({
    required this.intervals,
    required this.totalSpendMinor,
  });

  /// Completed full-to-full intervals with a valid economy figure, oldest first.
  final List<ConsumptionInterval> intervals;

  /// Σ cost of EVERY fill (including missed and excluded ones).
  final int totalSpendMinor;

  /// True when there is no valid interval yet — the first fill (or the first
  /// after a reset) reports economy as "pending", never 0 and never ∞.
  bool get pending => intervals.isEmpty;

  /// The most recent completed interval.
  ConsumptionInterval? get latest => intervals.isEmpty ? null : intervals.last;

  /// Lifetime economy: total volume / total distance across valid intervals.
  double? get lifetimeMlPerMetre => _aggregate(intervals);

  /// Rolling economy over the last [n] completed intervals.
  double? rollingMlPerMetre(int n) {
    if (n <= 0 || intervals.isEmpty) return null;
    final from = intervals.length <= n ? 0 : intervals.length - n;
    return _aggregate(intervals.sublist(from));
  }

  /// The most efficient (lowest mL/metre) interval.
  ConsumptionInterval? get best => _extreme(min: true);

  /// The least efficient (highest mL/metre) interval.
  ConsumptionInterval? get worst => _extreme(min: false);

  static double? _aggregate(List<ConsumptionInterval> xs) {
    if (xs.isEmpty) return null;
    var v = 0;
    var d = 0;
    for (final i in xs) {
      v += i.volumeMl;
      d += i.distanceMetres;
    }
    return d == 0 ? null : v / d;
  }

  ConsumptionInterval? _extreme({required bool min}) {
    if (intervals.isEmpty) return null;
    var chosen = intervals.first;
    for (final i in intervals.skip(1)) {
      final better = min
          ? i.mlPerMetre < chosen.mlPerMetre
          : i.mlPerMetre > chosen.mlPerMetre;
      if (better) chosen = i;
    }
    return chosen;
  }
}

/// The pure engine. Stateless.
class EconomyEngine {
  const EconomyEngine();

  /// Compute the economy report. Inputs may arrive out of order (a backdated
  /// insert) — they are sorted deterministically by `(filledAt, odometer)`, so
  /// identical inputs always yield identical outputs.
  EconomyReport compute(List<EnergyFill> fills) {
    final totalSpend = fills.fold<int>(0, (s, f) => s + f.costMinor);

    final sorted = [...fills]..sort((a, b) {
        final byTime = a.filledAt.epochMillis.compareTo(b.filledAt.epochMillis);
        return byTime != 0
            ? byTime
            : a.odometerMetres.compareTo(b.odometerMetres);
      });

    final intervals = <ConsumptionInterval>[];
    EnergyFill? prevFull; // the full tank that opened the current interval
    var volSince = 0;
    var costSince = 0;
    var broken = false; // a missed/excluded fill invalidated the open interval

    for (final f in sorted) {
      if (prevFull == null) {
        // No baseline yet: only a (non-excluded) full tank establishes one.
        if (f.isFullTank && !f.excludeFromEconomy) {
          prevFull = f;
          volSince = 0;
          costSince = 0;
          broken = false;
        }
        continue;
      }

      volSince += f.volumeMl;
      costSince += f.costMinor;
      if (f.isMissedPrevious || f.excludeFromEconomy) broken = true;

      if (f.isFullTank) {
        final distance = f.odometerMetres - prevFull.odometerMetres;
        if (!broken && distance > 0) {
          intervals.add(ConsumptionInterval(
            endAt: f.filledAt,
            distanceMetres: distance,
            volumeMl: volSince,
            costMinor: costSince,
          ));
        }
        // Start a fresh interval from this full tank (unless it's excluded, in
        // which case it can't be a reliable baseline).
        if (f.excludeFromEconomy) {
          prevFull = null;
        } else {
          prevFull = f;
        }
        volSince = 0;
        costSince = 0;
        broken = false;
      }
    }

    return EconomyReport(intervals: intervals, totalSpendMinor: totalSpend);
  }
}
