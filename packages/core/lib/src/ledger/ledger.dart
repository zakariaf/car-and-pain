import '../result/validation.dart';
import '../time/clock.dart';
import '../time/temporal.dart';

/// Which module wrote a ledger reading. Mandatory on every reading and preserved
/// through export/import.
enum LedgerSource { fuel, service, expense, trip, tire, manual, import }

/// One reading on the shared per-vehicle odometer / engine-hour timeline — the
/// app's spine. [value] is canonical (metres for the odometer, whole minutes for
/// an hour-meter). [cumulativeOffset] carries cluster-swap/rollover offsets so
/// the *logical* distance stays continuous across a physical instrument change:
/// `lifetimeValue = value + cumulativeOffset`.
final class LedgerReading {
  const LedgerReading({
    required this.value,
    required this.takenAt,
    required this.source,
    this.cumulativeOffset = 0,
    this.isRegressionOverride = false,
  });

  final int value;
  final Instant takenAt;
  final LedgerSource source;
  final int cumulativeOffset;

  /// Set when the user knowingly accepts a lower-than-previous reading.
  final bool isRegressionOverride;

  /// Logical lifetime distance/hours: raw value plus any cluster-swap offset.
  int get lifetimeValue => value + cumulativeOffset;

  @override
  bool operator ==(Object other) =>
      other is LedgerReading &&
      other.value == value &&
      other.takenAt == takenAt &&
      other.source == source &&
      other.cumulativeOffset == cumulativeOffset &&
      other.isRegressionOverride == isRegressionOverride;

  @override
  int get hashCode => Object.hash(
      value, takenAt, source, cumulativeOffset, isRegressionOverride);
}

/// Pure, Clock-injected ledger math: monotonicity/rollover/duplicate detection,
/// cluster-swap offsets, and usage-rate derivation. Feature modules **append**
/// to this timeline; they never store their own odometer.
final class LedgerEngine {
  const LedgerEngine({
    Clock clock = const SystemClock(),
    int rolloverDropThreshold = _defaultRolloverDrop,
  })  : _clock = clock,
        _rolloverDropThreshold = rolloverDropThreshold;

  final Clock _clock;

  /// A raw backward jump at least this large reads as a physical rollover / swap
  /// rather than a data-entry regression. Default 500,000 km in metres.
  final int _rolloverDropThreshold;
  static const int _defaultRolloverDrop = 500000000;

  /// Warnings for appending [candidate] to [history] (order-independent). An
  /// empty list means clean. Warn-with-override: a non-empty result is a
  /// dismissible warning, never a hard block. Each entry is a stable-code
  /// [FieldError] the presentation layer localizes.
  List<FieldError> check(
    List<LedgerReading> history,
    LedgerReading candidate,
  ) {
    final warnings = <FieldError>[];

    final prior = _priorTo(history, candidate.takenAt);
    if (prior != null && candidate.lifetimeValue < prior.lifetimeValue) {
      final rawDrop = prior.value - candidate.value;
      if (rawDrop >= _rolloverDropThreshold) {
        warnings.add(const FieldError('odometer', 'rollover'));
      } else if (!candidate.isRegressionOverride) {
        warnings.add(const FieldError('odometer', 'regression'));
      }
    }

    final isDuplicate = history.any(
      (r) =>
          r.takenAt == candidate.takenAt &&
          r.value == candidate.value &&
          r.source == candidate.source,
    );
    if (isDuplicate) {
      warnings.add(const FieldError('odometer', 'duplicate'));
    }

    return warnings;
  }

  /// The cluster-swap offset to apply to readings **after** an instrument change,
  /// so the logical odometer is continuous: the replaced cluster last read
  /// [priorLifetimeValue]; the new cluster starts at [newRawStart].
  int clusterSwapOffset({
    required int priorLifetimeValue,
    required int newRawStart,
  }) =>
      priorLifetimeValue - newRawStart;

  /// Average lifetime units per day across the timeline. Returns null with fewer
  /// than two readings or a zero/negative time span (insufficient-data fallback).
  double? avgDailyValue(List<LedgerReading> history) {
    if (history.length < 2) return null;
    final sorted = _sortedByTime(history);
    final first = sorted.first;
    final last = sorted.last;
    final spanMs = last.takenAt.epochMillis - first.takenAt.epochMillis;
    if (spanMs <= 0) return null;
    final spanDays = spanMs / Duration.millisecondsPerDay;
    return (last.lifetimeValue - first.lifetimeValue) / spanDays;
  }

  /// Estimated lifetime odometer/hours **now**, projecting the average daily rate
  /// forward from the latest reading. Null when [avgDailyValue] is null.
  int? estimatedValueNow(List<LedgerReading> history) {
    final rate = avgDailyValue(history);
    if (rate == null) return null;
    final last = _sortedByTime(history).last;
    final nowMs = _clock.nowUtc().millisecondsSinceEpoch;
    final daysSinceLast =
        (nowMs - last.takenAt.epochMillis) / Duration.millisecondsPerDay;
    final projected = daysSinceLast <= 0 ? 0.0 : rate * daysSinceLast;
    return last.lifetimeValue + projected.round();
  }

  LedgerReading? _priorTo(List<LedgerReading> history, Instant at) {
    LedgerReading? prior;
    for (final r in history) {
      if (r.takenAt.epochMillis > at.epochMillis) continue;
      if (prior == null || r.takenAt.epochMillis > prior.takenAt.epochMillis) {
        prior = r;
      }
    }
    return prior;
  }

  List<LedgerReading> _sortedByTime(List<LedgerReading> history) {
    final sorted = [...history]
      ..sort((a, b) => a.takenAt.epochMillis.compareTo(b.takenAt.epochMillis));
    return sorted;
  }
}
