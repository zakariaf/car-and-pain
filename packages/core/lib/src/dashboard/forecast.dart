/// M8-T4 · pure forecasting with an honest minimum-sample fallback.
///
/// Projects future spend and the next-service-due date from average daily
/// distance and historical spend. It **refuses to guess**: below the configured
/// minimum sample count / minimum span it returns [ForecastInsufficient] and the
/// UI shows an "not enough history yet" state instead of a fabricated number.
/// Above threshold the result carries the basis (sample count, span) it used, so
/// the estimate is inspectable. Deterministic: same inputs → same output.
library;

/// The outcome of a projection — either a value with its basis, or an explicit
/// insufficient-data verdict.
sealed class ForecastResult {
  const ForecastResult();
}

/// Not enough history to project honestly. Carries what was missing.
final class ForecastInsufficient extends ForecastResult {
  const ForecastInsufficient({
    required this.samples,
    required this.spanDays,
    required this.minSamples,
    required this.minSpanDays,
  });

  final int samples;
  final int spanDays;
  final int minSamples;
  final int minSpanDays;
}

/// A spend projection over [horizonDays], with the basis used.
final class SpendForecast extends ForecastResult {
  const SpendForecast({
    required this.projectedSpendMinor,
    required this.perDayMinor,
    required this.samples,
    required this.spanDays,
    required this.horizonDays,
  });

  final int projectedSpendMinor;
  final int perDayMinor;
  final int samples;
  final int spanDays;
  final int horizonDays;
}

/// A predicted next-service-due, as an odometer target and an ETA in days.
final class ServiceDueForecast extends ForecastResult {
  const ServiceDueForecast({
    required this.dueOdometerMetres,
    required this.metresRemaining,
    required this.etaDays,
    required this.avgDailyMetres,
  });

  final int dueOdometerMetres;
  final int metresRemaining;
  final int etaDays;
  final int avgDailyMetres;
}

/// The forecasting engine. Thresholds default to a fortnight of history over at
/// least three data points — below that, projecting is dishonest.
final class ForecastEngine {
  const ForecastEngine({this.minSamples = 3, this.minSpanDays = 14})
      : assert(minSamples >= 1, 'need at least one sample'),
        assert(minSpanDays >= 1, 'need at least one day of span');

  final int minSamples;
  final int minSpanDays;

  bool _enough(int samples, int spanDays) =>
      samples >= minSamples && spanDays >= minSpanDays;

  ForecastInsufficient _insufficient(int samples, int spanDays) =>
      ForecastInsufficient(
        samples: samples,
        spanDays: spanDays,
        minSamples: minSamples,
        minSpanDays: minSpanDays,
      );

  /// Project spend over [horizonDays] from [totalSpendMinor] observed across
  /// [samples] entries spanning [spanDays]. Below threshold → insufficient.
  ForecastResult spend({
    required int totalSpendMinor,
    required int samples,
    required int spanDays,
    required int horizonDays,
  }) {
    if (!_enough(samples, spanDays)) return _insufficient(samples, spanDays);
    final perDay = _divRoundHalfUp(totalSpendMinor, spanDays);
    return SpendForecast(
      projectedSpendMinor: perDay * horizonDays,
      perDayMinor: perDay,
      samples: samples,
      spanDays: spanDays,
      horizonDays: horizonDays,
    );
  }

  /// Predict the next-service-due odometer + ETA from the average daily
  /// distance implied by [distanceMetres] over [spanDays] across [samples]
  /// readings. [currentOdometerMetres] + [serviceIntervalMetres] set the target.
  ForecastResult nextServiceDue({
    required int currentOdometerMetres,
    required int serviceIntervalMetres,
    required int lastServiceOdometerMetres,
    required int distanceMetres,
    required int samples,
    required int spanDays,
  }) {
    if (!_enough(samples, spanDays)) return _insufficient(samples, spanDays);
    final avgDaily = _divRoundHalfUp(distanceMetres, spanDays);
    final dueOdometer = lastServiceOdometerMetres + serviceIntervalMetres;
    final remaining = dueOdometer - currentOdometerMetres;
    if (avgDaily <= 0) return _insufficient(samples, spanDays);
    // Already overdue → eta 0 (never negative).
    final eta = remaining <= 0 ? 0 : _divRoundHalfUp(remaining, avgDaily);
    return ServiceDueForecast(
      dueOdometerMetres: dueOdometer,
      metresRemaining: remaining,
      etaDays: eta,
      avgDailyMetres: avgDaily,
    );
  }
}

int _divRoundHalfUp(int numerator, int denominator) {
  if (numerator < 0) {
    return -((2 * -numerator + denominator) ~/ (2 * denominator));
  }
  return (2 * numerator + denominator) ~/ (2 * denominator);
}
