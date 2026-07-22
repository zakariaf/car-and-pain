/// A vehicle domain model — the mapped, Drift-free shape repositories emit
/// (never a Drift row). Carries the M2 powertrain-adaptive profile, identity,
/// lifecycle, per-vehicle overrides and organization fields. Canonical storage
/// (SI + base currency) is unaffected by the display-override fields.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.nickname,
    this.make,
    this.model,
    this.trim,
    this.modelYear,
    this.vehicleType = 'car',
    this.energyType,
    this.secondaryEnergyType,
    this.status = 'active',
    this.vin,
    this.vinChecksumValid,
    this.licensePlate,
    this.plateCountry,
    this.tankCapacityMl,
    this.secondaryTankMl,
    this.fuelGrade,
    this.batteryCapacityJoules,
    this.usableCapacityJoules,
    this.connectorTypes,
    this.distanceUnit,
    this.volumeUnit,
    this.consumptionUnit,
    this.currencyCode,
    this.distanceTrackingEnabled = true,
    this.groupId,
    this.tags = const [],
    this.sortOrder,
    this.coverPhotoRef,
    this.isDefault = false,
  });

  final String id;
  final String nickname;
  final String? make;
  final String? model;
  final String? trim;
  final int? modelYear;
  final String vehicleType;
  final String? energyType;
  final String? secondaryEnergyType;
  final String status;
  final String? vin;
  final bool? vinChecksumValid;
  final String? licensePlate;
  final String? plateCountry;
  final int? tankCapacityMl;
  final int? secondaryTankMl;
  final String? fuelGrade;
  final int? batteryCapacityJoules;
  final int? usableCapacityJoules;
  final String? connectorTypes;

  /// Per-vehicle display overrides (null → fall back to the global default).
  final String? distanceUnit;
  final String? volumeUnit;
  final String? consumptionUnit;
  final String? currencyCode;

  final bool distanceTrackingEnabled;
  final String? groupId;
  final List<String> tags;
  final int? sortOrder;
  final String? coverPhotoRef;
  final bool isDefault;

  /// Display label: make + model (+ trim), falling back to the nickname.
  String get displayModel =>
      [make, model, trim].where((s) => s != null && s.isNotEmpty).join(' ');

  @override
  bool operator ==(Object other) =>
      other is Vehicle &&
      other.id == id &&
      other.nickname == nickname &&
      other.make == make &&
      other.model == model &&
      other.trim == trim &&
      other.modelYear == modelYear &&
      other.vehicleType == vehicleType &&
      other.energyType == energyType &&
      other.secondaryEnergyType == secondaryEnergyType &&
      other.status == status &&
      other.vin == vin &&
      other.vinChecksumValid == vinChecksumValid &&
      other.licensePlate == licensePlate &&
      other.plateCountry == plateCountry &&
      other.tankCapacityMl == tankCapacityMl &&
      other.secondaryTankMl == secondaryTankMl &&
      other.fuelGrade == fuelGrade &&
      other.batteryCapacityJoules == batteryCapacityJoules &&
      other.usableCapacityJoules == usableCapacityJoules &&
      other.connectorTypes == connectorTypes &&
      other.distanceUnit == distanceUnit &&
      other.volumeUnit == volumeUnit &&
      other.consumptionUnit == consumptionUnit &&
      other.currencyCode == currencyCode &&
      other.distanceTrackingEnabled == distanceTrackingEnabled &&
      other.groupId == groupId &&
      _sameTags(other.tags) &&
      other.sortOrder == sortOrder &&
      other.coverPhotoRef == coverPhotoRef &&
      other.isDefault == isDefault;

  bool _sameTags(List<String> o) {
    if (o.length != tags.length) return false;
    for (var i = 0; i < tags.length; i++) {
      if (o[i] != tags[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        nickname,
        make,
        model,
        trim,
        modelYear,
        vehicleType,
        energyType,
        secondaryEnergyType,
        status,
        vin,
        vinChecksumValid,
        licensePlate,
        plateCountry,
        tankCapacityMl,
        secondaryTankMl,
        fuelGrade,
        batteryCapacityJoules,
        usableCapacityJoules,
        connectorTypes,
        distanceUnit,
        volumeUnit,
        consumptionUnit,
        currencyCode,
        distanceTrackingEnabled,
        groupId,
        ...tags,
        sortOrder,
        coverPhotoRef,
        isDefault,
      ]);
}
