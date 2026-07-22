import 'package:core/core.dart';

/// A unified energy record — a liquid/gas fill or an EV/PHEV charge session —
/// as repositories emit it (Drift-free). All measures canonical: volume in mL,
/// energy in joules, money in integer minor units + ISO code, instants UTC.
class FuelEntry {
  const FuelEntry({
    required this.id,
    required this.vehicleId,
    required this.filledAt,
    required this.odometerMetres,
    required this.volumeMl,
    required this.totalCostMinor,
    required this.currencyCode,
    this.energyJoules,
    this.isFullTank = true,
    this.isMissedPrevious = false,
    this.excludeFromEconomy = false,
    this.isFree = false,
    this.fuelType,
    this.pricePerUnitThousandths,
    this.startSocPct,
    this.endSocPct,
    this.isHomeCharge = false,
    this.stationName,
    this.notes,
  });

  final String id;
  final String vehicleId;
  final Instant filledAt;
  final int odometerMetres;
  final int volumeMl;
  final int? energyJoules;
  final int totalCostMinor;
  final String currencyCode;
  final bool isFullTank;
  final bool isMissedPrevious;
  final bool excludeFromEconomy;
  final bool isFree;

  /// gasoline | diesel | lpg | cng | ethanol | hydrogen | electric.
  final String? fuelType;
  final int? pricePerUnitThousandths;
  final int? startSocPct;
  final int? endSocPct;
  final bool isHomeCharge;
  final String? stationName;
  final String? notes;

  /// Whether this record is an EV/PHEV charge (electric energy) rather than a
  /// liquid/gas fill.
  bool get isCharge => fuelType == 'electric';

  /// The pure-engine view of this entry (for [EconomyEngine]).
  EnergyFill toEnergyFill() => EnergyFill(
        filledAt: filledAt,
        odometerMetres: odometerMetres,
        volumeMl: volumeMl,
        costMinor: totalCostMinor,
        isFullTank: isFullTank,
        isMissedPrevious: isMissedPrevious,
        excludeFromEconomy: excludeFromEconomy,
      );
}
