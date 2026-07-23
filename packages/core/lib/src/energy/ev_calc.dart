/// Pure EV / PHEV charge math (M3-T3) — the electric analogue of a fill-up.
/// Energy in canonical whole joules, money in ISO-4217 minor units, distance in
/// metres. No I/O; exhaustively table-testable.
library;

const double _joulesPerKwh = 3600000;

/// Energy delivered to the battery derived from the SoC delta when no meter
/// reading exists: `(end − start)/100 × usable_capacity`. Clamped so a negative
/// or absent delta yields 0 (never a phantom negative charge).
int energyFromSocJoules({
  required int startSocPct,
  required int endSocPct,
  required int usableCapacityJoules,
}) {
  final delta = endSocPct - startSocPct;
  if (delta <= 0 || usableCapacityJoules <= 0) return 0;
  return (usableCapacityJoules * delta / 100).round();
}

/// Wall (grid) energy for a given amount delivered to the battery, grossing up
/// by the AC charging loss so cost is charged on what the meter actually spins.
/// [lossPermille] is the loss fraction in per-mille (e.g. 100 = 10 %).
int wallEnergyJoules({
  required int deliveredJoules,
  required int lossPermille,
}) {
  if (deliveredJoules <= 0) return 0;
  final eff = 1000 - lossPermille; // efficiency in per-mille
  if (eff <= 0) return deliveredJoules;
  return (deliveredJoules * 1000 / eff).round();
}

/// The money cost of a charge: `wall_kWh × price_per_kWh`, keyed to the
/// currency's ISO-4217 [exponent]. [pricePerKwhThousandths] is thousandths of a
/// major unit per kWh (e.g. €0.309/kWh → 309).
int chargeCostMinor({
  required int wallEnergyJoules,
  required int pricePerKwhThousandths,
  required int exponent,
}) {
  var scale = 1;
  for (var i = 0; i < exponent; i++) {
    scale *= 10;
  }
  return (wallEnergyJoules *
          pricePerKwhThousandths *
          scale /
          (_joulesPerKwh * 1000))
      .round();
}

/// PHEV blended cost-per-distance: fuel + electric cost over the ONE shared
/// distance (never summed as two separate distances). Minor units per metre.
double blendedCostPerMetre({
  required int fuelCostMinor,
  required int electricCostMinor,
  required int distanceMetres,
}) {
  if (distanceMetres <= 0) return 0;
  return (fuelCostMinor + electricCostMinor) / distanceMetres;
}

/// Months to recoup an EV's price premium from the per-period running-cost
/// saving vs an ICE: `premium / (ice_cost − ev_cost)`. Returns null when the EV
/// is not cheaper to run (delta ≤ 0) — an honest "never pays back", never a
/// negative or infinite month count.
double? breakEvenMonths({
  required int pricePremiumMinor,
  required int iceCostPerPeriodMinor,
  required int evCostPerPeriodMinor,
}) {
  final delta = iceCostPerPeriodMinor - evCostPerPeriodMinor;
  if (delta <= 0) return null;
  return pricePremiumMinor / delta;
}
