/// Pure economy display projections (M3-T6) from canonical values — never store
/// these, only render them. Liquid/gas economy is canonical **millilitres per
/// metre**; EV economy is canonical **joules per metre**. US and UK gallons are
/// distinct exact constants and never conflated.
library;

// Exact unit constants.
const double _mlPerUsGallon = 3785.411784;
const double _mlPerUkGallon = 4546.09;
const double _metresPerMile = 1609.344;
const double _joulesPerWh = 3600;
const double _joulesPerKwh = 3600000;

/// The consumption display modes the UI can pick from.
enum EconomyMode {
  litresPer100km,
  kmPerLitre,
  mpgUs,
  mpgUk,
  whPerKm,
  miPerKwh,
  kwhPer100km,
}

/// Litres per 100 km from mL/metre. (8 L/100km ⇐ 0.08 mL/m.)
double litresPer100km(double mlPerMetre) => mlPerMetre * 100;

/// Kilometres per litre from mL/metre.
double kmPerLitre(double mlPerMetre) => mlPerMetre == 0 ? 0 : 1 / mlPerMetre;

/// Miles per US gallon from mL/metre.
double mpgUs(double mlPerMetre) =>
    mlPerMetre == 0 ? 0 : _mlPerUsGallon / (mlPerMetre * _metresPerMile);

/// Miles per Imperial (UK) gallon from mL/metre.
double mpgUk(double mlPerMetre) =>
    mlPerMetre == 0 ? 0 : _mlPerUkGallon / (mlPerMetre * _metresPerMile);

/// Watt-hours per km from joules/metre (EV).
double whPerKm(double joulesPerMetre) => joulesPerMetre * 1000 / _joulesPerWh;

/// kWh per 100 km from joules/metre (EV).
double kwhPer100km(double joulesPerMetre) =>
    joulesPerMetre * 100000 / _joulesPerKwh;

/// Miles per kWh from joules/metre (EV).
double miPerKwh(double joulesPerMetre) =>
    joulesPerMetre == 0 ? 0 : _joulesPerKwh / (joulesPerMetre * _metresPerMile);

/// Project a liquid/gas economy (mL/metre) into [mode]; EV modes return null.
double? projectLiquid(double mlPerMetre, EconomyMode mode) => switch (mode) {
      EconomyMode.litresPer100km => litresPer100km(mlPerMetre),
      EconomyMode.kmPerLitre => kmPerLitre(mlPerMetre),
      EconomyMode.mpgUs => mpgUs(mlPerMetre),
      EconomyMode.mpgUk => mpgUk(mlPerMetre),
      _ => null,
    };

/// Project an EV economy (joules/metre) into [mode]; liquid modes return null.
double? projectElectric(double joulesPerMetre, EconomyMode mode) =>
    switch (mode) {
      EconomyMode.whPerKm => whPerKm(joulesPerMetre),
      EconomyMode.miPerKwh => miPerKwh(joulesPerMetre),
      EconomyMode.kwhPer100km => kwhPer100km(joulesPerMetre),
      _ => null,
    };
