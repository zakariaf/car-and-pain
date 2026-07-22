/// Pure fuel range / anomaly projections (M3-T10) — the math behind low-fuel,
/// next-fill, and rising-consumption reminders. Derived from rolling
/// consumption, never a live sensor; canonical units in, canonical units out.
library;

/// The distance a full tank covers at the rolling consumption rate:
/// `range = tank_capacity ÷ consumption`. Returns null on insufficient data
/// (no rolling average yet, or a non-positive tank/rate) — the caller falls
/// back to time-based scheduling rather than inventing a number.
int? fuelRangeMetres({
  required int tankCapacityMl,
  required double? rollingMlPerMetre,
}) {
  if (rollingMlPerMetre == null ||
      rollingMlPerMetre <= 0 ||
      tankCapacityMl <= 0) {
    return null;
  }
  return (tankCapacityMl / rollingMlPerMetre).round();
}

/// The projected odometer at which the next fill is due — the last reading plus
/// a fraction of the full range (default: prompt at 15 % remaining). Null when
/// [fuelRangeMetres] is null.
int? nextFillOdometreMetres({
  required int lastOdometerMetres,
  required int tankCapacityMl,
  required double? rollingMlPerMetre,
  int promptAtPermilleRemaining = 150,
}) {
  final range = fuelRangeMetres(
    tankCapacityMl: tankCapacityMl,
    rollingMlPerMetre: rollingMlPerMetre,
  );
  if (range == null) return null;
  final usable = range * (1000 - promptAtPermilleRemaining) ~/ 1000;
  return lastOdometerMetres + usable;
}

/// True when the latest interval's consumption has degraded beyond
/// [tolerancePermille] above the baseline (a rising-consumption anomaly worth an
/// alert). Both economies are canonical mL-per-metre (higher = thirstier).
bool risingConsumptionAnomaly({
  required double latestMlPerMetre,
  required double baselineMlPerMetre,
  int tolerancePermille = 150,
}) {
  if (baselineMlPerMetre <= 0 || latestMlPerMetre <= 0) return false;
  return latestMlPerMetre >
      baselineMlPerMetre * (1000 + tolerancePermille) / 1000;
}
