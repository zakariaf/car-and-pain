/// A vehicle domain model — the mapped, Drift-free shape repositories emit
/// (never a Drift row). M2 enriches it; F2 carries the backbone.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.nickname,
    this.make,
    this.model,
    this.vehicleType = 'car',
    this.status = 'active',
    this.currencyCode,
    this.isDefault = false,
  });

  final String id;
  final String nickname;
  final String? make;
  final String? model;
  final String vehicleType;
  final String status;
  final String? currencyCode;
  final bool isDefault;

  @override
  bool operator ==(Object other) =>
      other is Vehicle &&
      other.id == id &&
      other.nickname == nickname &&
      other.make == make &&
      other.model == model &&
      other.vehicleType == vehicleType &&
      other.status == status &&
      other.currencyCode == currencyCode &&
      other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(
        id,
        nickname,
        make,
        model,
        vehicleType,
        status,
        currencyCode,
        isDefault,
      );
}
