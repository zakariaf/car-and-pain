/// M8-T1 · pure KPI aggregation over pre-computed rollups.
///
/// The dashboard reads the per-(vehicle, period) rollup tables, never a raw-row
/// scan, so multi-year histories resolve instantly. This engine combines those
/// rollup contributions into scope KPIs (spend, distance, fuel, fill count,
/// cost-per-distance, economy, CO₂) with **no float in the money path**.
///
/// Mixed currencies are never silently summed: a scope spanning more than one
/// ISO currency is flagged so the UI segregates it instead of adding pounds to
/// dollars. Every value is canonical (SI metres/millilitres, integer minor
/// units + ISO code); display conversion happens only at render.
library;

/// One rollup contribution to a scope (a vehicle-period's totals in ONE
/// currency). The aggregator folds a list of these.
final class KpiContribution {
  const KpiContribution({
    required this.currencyCode,
    this.spendMinor = 0,
    this.distanceMetres = 0,
    this.fuelMl = 0,
    this.fillCount = 0,
  })  : assert(distanceMetres >= 0, 'distance >= 0'),
        assert(fuelMl >= 0, 'fuel >= 0'),
        assert(fillCount >= 0, 'fills >= 0');

  final String currencyCode;
  final int spendMinor;
  final int distanceMetres;
  final int fuelMl;
  final int fillCount;
}

/// The rolled-up KPIs for a scope (one vehicle, all vehicles, or fleet).
final class DashboardKpis {
  const DashboardKpis({
    required this.spendMinor,
    required this.distanceMetres,
    required this.fuelMl,
    required this.fillCount,
    required this.currencyCode,
    required this.mixedCurrency,
  });

  /// Fold a scope's contributions into one KPI set. Spend sums only within a
  /// single currency; a second currency trips [mixedCurrency] and zeroes the
  /// summed spend (the caller shows a segregated breakdown instead).
  factory DashboardKpis.of(Iterable<KpiContribution> contributions) {
    String? currency;
    var mixed = false;
    var spend = 0;
    var distance = 0;
    var fuel = 0;
    var fills = 0;
    for (final c in contributions) {
      distance += c.distanceMetres;
      fuel += c.fuelMl;
      fills += c.fillCount;
      if (c.spendMinor != 0 || c.fillCount != 0) {
        if (currency == null) {
          currency = c.currencyCode;
        } else if (currency != c.currencyCode) {
          mixed = true;
        }
      }
      spend += c.spendMinor;
    }
    return DashboardKpis(
      spendMinor: mixed ? 0 : spend,
      distanceMetres: distance,
      fuelMl: fuel,
      fillCount: fills,
      currencyCode: mixed ? '' : (currency ?? ''),
      mixedCurrency: mixed,
    );
  }

  /// Petrol CO₂ factor: 2.31 kg per litre → 2310 mg per millilitre. Kept as an
  /// integer (milligrams per ml) so CO₂ stays off the float path.
  static const int _co2MgPerMlPetrol = 2310;

  final int spendMinor;
  final int distanceMetres;
  final int fuelMl;
  final int fillCount;

  /// The single ISO currency of the scope, or `''` when [mixedCurrency].
  final String currencyCode;

  /// True when the scope spanned more than one currency — [spendMinor] is then
  /// not meaningful as a single figure and the UI must segregate by currency.
  final bool mixedCurrency;

  /// All-in cost per kilometre (minor units), or null with no distance.
  /// `spend × 1000m / distance`, round-half-up.
  int? get costPerKmMinor => distanceMetres <= 0
      ? null
      : _divRoundHalfUp(spendMinor * 1000, distanceMetres);

  /// Fuel economy as litres-per-100km ×100 (two implied decimals), or null when
  /// there is no distance or fuel. `L/100km = fuelMl×100/distanceMetres`; the
  /// extra ×100 carries the two decimals → `fuelMl × 10000 / distanceMetres`.
  int? get litresPer100kmScaled => (distanceMetres <= 0 || fuelMl <= 0)
      ? null
      : _divRoundHalfUp(fuelMl * 10000, distanceMetres);

  /// Tailpipe CO₂ in grams from the scope's petrol volume (integer milligrams
  /// per ml, floored to grams). EV energy contributes zero tailpipe.
  int get co2Grams => (fuelMl * _co2MgPerMlPetrol) ~/ 1000;
}

int _divRoundHalfUp(int numerator, int denominator) {
  if (numerator < 0) {
    return -((2 * -numerator + denominator) ~/ (2 * denominator));
  }
  return (2 * numerator + denominator) ~/ (2 * denominator);
}
