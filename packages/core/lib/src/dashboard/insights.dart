/// M8-T3 · rule-based insights & anomaly detection (pure Dart).
///
/// Turns a vehicle's OWN aggregates into plain-language insight codes and
/// anomaly flags — economy below the vehicle's rolling baseline, spend above its
/// historical norm, and data-integrity anomalies (odometer gap, regression /
/// rollover, duplicate) that would otherwise distort statistics. It emits typed
/// [Insight] codes with params; the presentation layer renders the localized ICU
/// copy (no string concatenation here). Baselines are self-referential — never a
/// global leaderboard. Anomalies are *flagged for review*, never silently
/// discarded or turned into negative distance.
library;

enum InsightKind {
  economyDrop,
  spendSpike,
  odometerGap,
  odometerRegression,
  duplicateEntry,
}

enum InsightSeverity { info, warn, critical }

/// One detected insight: a stable [kind] + [severity] + typed [params] for the
/// ICU message. No user-facing strings.
final class Insight {
  const Insight(this.kind, this.severity, [this.params = const {}]);

  final InsightKind kind;
  final InsightSeverity severity;
  final Map<String, Object?> params;

  @override
  bool operator ==(Object other) =>
      other is Insight && other.kind == kind && other.severity == severity;

  @override
  int get hashCode => Object.hash(kind, severity);
}

/// The detectors. Each returns an [Insight] when the rule fires, else null; the
/// engine's [evaluate] collects the non-null ones.
final class InsightEngine {
  /// [toleranceBps] is how far past baseline/norm counts as notable (default
  /// 15% = 1500 bps).
  const InsightEngine({this.toleranceBps = 1500})
      : assert(toleranceBps >= 0, 'tolerance must be >= 0');

  final int toleranceBps;

  /// Fires when current consumption exceeds the rolling baseline by more than
  /// the tolerance (higher litres-per-100km = worse economy). Values are the
  /// scaled economy figures (`DashboardKpis.litresPer100kmScaled` shape).
  Insight? economyBelowBaseline({
    required int currentL100Scaled,
    required int baselineL100Scaled,
  }) {
    if (baselineL100Scaled <= 0 || currentL100Scaled <= 0) return null;
    final threshold =
        baselineL100Scaled + baselineL100Scaled * toleranceBps ~/ 10000;
    if (currentL100Scaled <= threshold) return null;
    final overBps =
        (currentL100Scaled - baselineL100Scaled) * 10000 ~/ baselineL100Scaled;
    return Insight(
        InsightKind.economyDrop, InsightSeverity.warn, {'overBps': overBps});
  }

  /// Fires when the current period's spend exceeds the historical average by
  /// more than the tolerance.
  Insight? spendAboveNorm({
    required int currentSpendMinor,
    required int avgSpendMinor,
  }) {
    if (avgSpendMinor <= 0 || currentSpendMinor <= 0) return null;
    final threshold = avgSpendMinor + avgSpendMinor * toleranceBps ~/ 10000;
    if (currentSpendMinor <= threshold) return null;
    final overBps =
        (currentSpendMinor - avgSpendMinor) * 10000 ~/ avgSpendMinor;
    return Insight(
        InsightKind.spendSpike, InsightSeverity.warn, {'overBps': overBps});
  }

  /// A missing-distance gap (metres) between consecutive readings — flagged for
  /// review, never invented business miles.
  Insight? odometerGap(int gapMetres) => gapMetres > 0
      ? Insight(InsightKind.odometerGap, InsightSeverity.info,
          {'gapMetres': gapMetres})
      : null;

  /// A decreasing/rollover reading — the meter went backwards.
  Insight? odometerRegression(int deltaMetres) => deltaMetres < 0
      ? Insight(InsightKind.odometerRegression, InsightSeverity.critical,
          {'deltaMetres': deltaMetres})
      : null;

  /// A likely duplicate (same day + amount already seen).
  Insight? duplicate({required bool isDuplicate}) => isDuplicate
      ? const Insight(InsightKind.duplicateEntry, InsightSeverity.warn)
      : null;

  /// Collect every firing insight, most-severe first.
  List<Insight> evaluate(Iterable<Insight?> candidates) {
    final list = candidates.whereType<Insight>().toList()
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return list;
  }
}
