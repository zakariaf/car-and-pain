/// Display units for [Distance]. Canonical storage is always whole metres.
enum DistanceUnit { metre, kilometre, mile }

/// A distance, stored canonically as **whole metres**. Kilometres and miles are
/// display projections computed only at the presentation edge — never stored.
final class Distance implements Comparable<Distance> {
  /// Trusted construction from canonical whole metres.
  const Distance.metres(this.metres);

  /// From kilometres (display unit); rounded to the nearest metre.
  Distance.fromKilometres(double km) : metres = (km * _metresPerKm).round();

  /// From miles (display unit); rounded to the nearest metre.
  Distance.fromMiles(double miles) : metres = (miles * _metresPerMile).round();

  /// From a display unit value; rounded to the nearest metre.
  factory Distance.fromDisplay(DistanceUnit unit, double value) =>
      Distance.metres((value * _metresPer(unit)).round());

  /// Canonical storage form.
  final int metres;

  static const double _metresPerKm = 1000;
  // Exact international mile.
  static const double _metresPerMile = 1609.344;

  static double _metresPer(DistanceUnit unit) => switch (unit) {
        DistanceUnit.metre => 1,
        DistanceUnit.kilometre => _metresPerKm,
        DistanceUnit.mile => _metresPerMile,
      };

  /// Project to a display unit (edge conversion).
  double toDisplay(DistanceUnit unit) => metres / _metresPer(unit);

  /// The distance in kilometres (edge conversion).
  double get kilometres => metres / _metresPerKm;

  /// The distance in miles (edge conversion).
  double get miles => metres / _metresPerMile;

  /// Sum of two distances.
  Distance operator +(Distance other) => Distance.metres(metres + other.metres);

  /// Difference of two distances.
  Distance operator -(Distance other) => Distance.metres(metres - other.metres);

  @override
  int compareTo(Distance other) => metres.compareTo(other.metres);

  @override
  bool operator ==(Object other) => other is Distance && other.metres == metres;

  @override
  int get hashCode => metres.hashCode;

  @override
  String toString() => 'Distance(${metres}m)';
}
