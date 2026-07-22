import 'package:core/core.dart';
import 'package:l10n/l10n.dart';

/// Maps the core [VehicleType]/[EnergyType] enums to their stored string codes
/// (the enum `name`) and localized labels. Keeps the powertrain-adaptive form
/// (M2-T2) free of hardcoded strings and stable across storage/UI.

VehicleType vehicleTypeFromCode(String? code) => VehicleType.values.firstWhere(
      (t) => t.name == code,
      orElse: () => VehicleType.car,
    );

EnergyType? energyTypeFromCode(String? code) {
  if (code == null || code.isEmpty) return null;
  for (final e in EnergyType.values) {
    if (e.name == code) return e;
  }
  return null;
}

String vehicleTypeLabel(AppLocalizations l10n, VehicleType type) =>
    switch (type) {
      VehicleType.car => l10n.vehicleTypeCar,
      VehicleType.motorcycle => l10n.vehicleTypeMotorcycle,
      VehicleType.scooter => l10n.vehicleTypeScooter,
      VehicleType.truck => l10n.vehicleTypeTruck,
      VehicleType.van => l10n.vehicleTypeVan,
      VehicleType.suv => l10n.vehicleTypeSuv,
      VehicleType.bus => l10n.vehicleTypeBus,
      VehicleType.boat => l10n.vehicleTypeBoat,
      VehicleType.rv => l10n.vehicleTypeRv,
      VehicleType.atv => l10n.vehicleTypeAtv,
      VehicleType.equipment => l10n.vehicleTypeEquipment,
      VehicleType.generator => l10n.vehicleTypeGenerator,
      VehicleType.bicycle => l10n.vehicleTypeBicycle,
      VehicleType.other => l10n.vehicleTypeOther,
    };

String energyTypeLabel(AppLocalizations l10n, EnergyType energy) =>
    switch (energy) {
      EnergyType.gasoline => l10n.energyGasoline,
      EnergyType.diesel => l10n.energyDiesel,
      EnergyType.lpg => l10n.energyLpg,
      EnergyType.cng => l10n.energyCng,
      EnergyType.ethanol => l10n.energyEthanol,
      EnergyType.hydrogen => l10n.energyHydrogen,
      EnergyType.electric => l10n.energyElectric,
      EnergyType.hybrid => l10n.energyHybrid,
      EnergyType.plugInHybrid => l10n.energyPlugInHybrid,
    };
