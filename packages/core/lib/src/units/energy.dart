/// Display units for [Energy]. Canonical storage is always whole joules.
enum EnergyUnit { kilowattHour, megajoule, joule }

/// An amount of energy, stored canonically as **whole joules** (SI base). kWh
/// (EV charging) and MJ are display projections. 60 kWh = 216,000,000 J fits an
/// int64 comfortably.
final class Energy implements Comparable<Energy> {
  /// Trusted construction from canonical whole joules.
  const Energy.joules(this.joules);

  /// From a display unit value; rounded to the nearest joule.
  factory Energy.fromDisplay(EnergyUnit unit, double value) =>
      Energy.joules((value * _joulesPer(unit)).round());

  /// Canonical storage form.
  final int joules;

  static const double _joulesPerKwh = 3600000;
  static const double _joulesPerMj = 1000000;

  static double _joulesPer(EnergyUnit unit) => switch (unit) {
        EnergyUnit.kilowattHour => _joulesPerKwh,
        EnergyUnit.megajoule => _joulesPerMj,
        EnergyUnit.joule => 1,
      };

  /// Project to a display unit (edge conversion).
  double toDisplay(EnergyUnit unit) => joules / _joulesPer(unit);

  @override
  int compareTo(Energy other) => joules.compareTo(other.joules);

  @override
  bool operator ==(Object other) => other is Energy && other.joules == joules;

  @override
  int get hashCode => joules.hashCode;

  @override
  String toString() => 'Energy(${joules}J)';
}
