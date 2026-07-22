/// The powertrain-adaptive profile model (M2-T2) — a pure resolver deciding
/// which vehicle-profile fields apply to a given `vehicle_type` + energy
/// configuration, so the add/edit form shows exactly the relevant field set and
/// hides the rest. Pure and total; the widget layer preserves hidden-field
/// values on toggle (this only decides visibility, never destroys data).
library;

/// The broad kind of vehicle. Drives default wheel/axle counts, the engine-hour
/// meter, and distance-tracking defaults. Mapped to/from the stored string at
/// the data edge.
enum VehicleType {
  car,
  motorcycle,
  scooter,
  truck,
  van,
  suv,
  bus,
  boat,
  rv,
  atv,
  equipment,
  generator,
  bicycle,
  other,
}

/// The energy source. Primary and (optionally) secondary together configure
/// PHEV (fuel + electric) and bi-fuel (fuel + fuel) profiles.
enum EnergyType {
  gasoline,
  diesel,
  lpg,
  cng,
  ethanol,
  hydrogen,
  electric,
  hybrid, // non-plug hybrid: has a fuel tank; battery is not user-managed.
  plugInHybrid, // implies both a fuel tank and a user-managed EV battery.
}

/// A profile field whose presence depends on the powertrain/type.
enum VehicleField {
  tankCapacity,
  fuelGrade,
  secondaryTank,
  batteryCapacity,
  usableCapacity,
  connectors,
  stateOfHealth,
  energySplit,
  engineHourMeter,
  distanceTracking,
  chainBelt,
  frontTireSpec,
  rearTireSpec,
  wheelConfig,
}

const Set<EnergyType> _fuels = {
  EnergyType.gasoline,
  EnergyType.diesel,
  EnergyType.lpg,
  EnergyType.cng,
  EnergyType.ethanol,
  EnergyType.hydrogen,
};

const Set<VehicleType> _hourMetered = {
  VehicleType.boat,
  VehicleType.rv,
  VehicleType.equipment,
  VehicleType.generator,
};

const Set<VehicleType> _twoWheeled = {
  VehicleType.motorcycle,
  VehicleType.scooter,
  VehicleType.bicycle,
};

/// The pure adaptive-profile resolver. Stateless.
class PowertrainProfile {
  const PowertrainProfile();

  /// True when the configuration burns a liquid/gas fuel (so it has a tank):
  /// any fuel primary/secondary, or a (plug-in) hybrid.
  bool hasCombustion(EnergyType? primary, [EnergyType? secondary]) =>
      _isFuel(primary) ||
      primary == EnergyType.hybrid ||
      primary == EnergyType.plugInHybrid ||
      _isFuel(secondary);

  /// True when there is a **user-managed** traction battery: a pure EV, a PHEV,
  /// or an explicit electric secondary. A plain hybrid (HEV) is excluded — its
  /// pack is neither charged nor serviced by the owner.
  bool hasManagedBattery(EnergyType? primary, [EnergyType? secondary]) =>
      primary == EnergyType.electric ||
      primary == EnergyType.plugInHybrid ||
      secondary == EnergyType.electric;

  /// A bi-fuel setup — two distinct combustion fuels (e.g. petrol + LPG).
  bool isBiFuel(EnergyType? primary, [EnergyType? secondary]) =>
      _isFuel(primary) && _isFuel(secondary) && primary != secondary;

  /// Carries two energy sources that need a split configuration (PHEV or
  /// bi-fuel).
  bool isDualEnergy(EnergyType? primary, [EnergyType? secondary]) =>
      primary == EnergyType.plugInHybrid ||
      isBiFuel(primary, secondary) ||
      (hasCombustion(primary, secondary) &&
          hasManagedBattery(primary, secondary));

  /// The default wheel count for a type (feeds tire-layout diagrams). 0 for
  /// vehicles without road wheels (boats, generators).
  int defaultWheelCount(VehicleType type) => switch (type) {
        VehicleType.motorcycle ||
        VehicleType.scooter ||
        VehicleType.bicycle =>
          2,
        VehicleType.atv => 4,
        VehicleType.car || VehicleType.van || VehicleType.suv => 4,
        VehicleType.truck || VehicleType.bus => 6,
        VehicleType.rv => 6,
        VehicleType.boat || VehicleType.generator || VehicleType.equipment => 0,
        VehicleType.other => 4,
      };

  /// Whether the type is primarily tracked by an engine-hour meter rather than
  /// distance (boats, RVs, equipment, generators).
  bool usesEngineHours(VehicleType type) => _hourMetered.contains(type);

  /// Whether distance tracking is on by default for the type. Hour-metered
  /// types (except RVs, which are road vehicles) default distance off.
  bool distanceTrackingByDefault(VehicleType type) =>
      !usesEngineHours(type) || type == VehicleType.rv;

  /// The set of profile fields to show for a configuration.
  Set<VehicleField> fieldsFor({
    required VehicleType type,
    EnergyType? energy,
    EnergyType? secondaryEnergy,
  }) {
    final fields = <VehicleField>{
      VehicleField.wheelConfig,
      VehicleField.distanceTracking,
    };

    if (hasCombustion(energy, secondaryEnergy)) {
      fields.addAll({VehicleField.tankCapacity, VehicleField.fuelGrade});
    }
    if (isBiFuel(energy, secondaryEnergy)) {
      fields.add(VehicleField.secondaryTank);
    }
    if (hasManagedBattery(energy, secondaryEnergy)) {
      fields.addAll({
        VehicleField.batteryCapacity,
        VehicleField.usableCapacity,
        VehicleField.connectors,
        VehicleField.stateOfHealth,
      });
    }
    if (isDualEnergy(energy, secondaryEnergy)) {
      fields.add(VehicleField.energySplit);
    }
    if (usesEngineHours(type)) {
      fields.add(VehicleField.engineHourMeter);
    }
    if (_twoWheeled.contains(type) && type != VehicleType.bicycle) {
      fields.addAll({
        VehicleField.chainBelt,
        VehicleField.frontTireSpec,
        VehicleField.rearTireSpec,
      });
    }
    return fields;
  }

  bool _isFuel(EnergyType? e) => e != null && _fuels.contains(e);
}
