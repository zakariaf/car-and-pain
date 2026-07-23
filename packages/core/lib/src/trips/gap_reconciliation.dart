/// M7-T1 · odometer-gap reconciliation between consecutive trips.
///
/// Pure, deterministic detection of the distance unaccounted-for between one
/// trip's end odometer and the next trip's start — the forgotten-journey signal
/// that would otherwise silently corrupt the business-use percentage. It only
/// *detects and classifies*; writing a personal-use gap-fill or overriding a
/// warning is the repository's job. Rollover and cluster-swap offsets are the
/// ledger's domain, so a genuine odometer regression is surfaced as its own kind
/// rather than mistaken for a negative gap.
library;

/// What the comparison between `prev_end` and `next_start` reveals.
enum GapKind {
  /// `next_start == prev_end`: the series is continuous, nothing missing.
  continuous,

  /// `next_start > prev_end`: distance was driven but not logged — a candidate
  /// forgotten trip. [TripGap.gapMetres] is positive.
  missingDistance,

  /// `next_start < prev_end`: the meter went backwards — a regression the ledger
  /// must explain (rollover/offset/correction), not a gap to fill.
  regression,
}

/// The reconciliation verdict for one adjacent pair of trips.
final class TripGap {
  const TripGap({required this.kind, required this.gapMetres});

  final GapKind kind;

  /// `next_start_odometer − prev_end_odometer`. Positive for a missing-distance
  /// gap, zero when continuous, negative for a regression.
  final int gapMetres;

  bool get isContinuous => kind == GapKind.continuous;
  bool get isMissing => kind == GapKind.missingDistance;
  bool get isRegression => kind == GapKind.regression;
}

/// Detection over a per-vehicle odometer series.
final class GapReconciler {
  /// The tolerance (metres) below which a positive gap is treated as continuous
  /// — GPS/manual rounding noise, not a forgotten trip. Default 0: any positive
  /// gap is surfaced (the UI can still let the user dismiss it).
  const GapReconciler({this.toleranceMetres = 0})
      : assert(toleranceMetres >= 0, 'tolerance must be >= 0');

  final int toleranceMetres;

  /// Classify the gap between a previous trip's end and the next trip's start.
  TripGap between({
    required int prevEndOdometerMetres,
    required int nextStartOdometerMetres,
  }) {
    final gap = nextStartOdometerMetres - prevEndOdometerMetres;
    if (gap < 0) return TripGap(kind: GapKind.regression, gapMetres: gap);
    if (gap > toleranceMetres) {
      return TripGap(kind: GapKind.missingDistance, gapMetres: gap);
    }
    return TripGap(kind: GapKind.continuous, gapMetres: gap);
  }

  /// Reconcile an ordered list of `(start, end)` odometer pairs (chronological),
  /// returning the gap that precedes each trip (the first has no predecessor →
  /// `null`). Preserves the monotonic series: a regression is flagged, never
  /// silently rewritten.
  List<TripGap?> reconcile(List<(int start, int end)> orderedTrips) {
    final gaps = <TripGap?>[];
    for (var i = 0; i < orderedTrips.length; i++) {
      if (i == 0) {
        gaps.add(null);
        continue;
      }
      gaps.add(between(
        prevEndOdometerMetres: orderedTrips[i - 1].$2,
        nextStartOdometerMetres: orderedTrips[i].$1,
      ));
    }
    return gaps;
  }
}
