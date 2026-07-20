/// Display units for [Pressure]. Canonical storage is always whole pascals.
enum PressureUnit { kilopascal, psi, bar }

/// A pressure, stored canonically as **whole pascals** (SI base). kPa, psi, and
/// bar are display projections computed only at the edge. Whole pascals keeps
/// psi lossless (whole kPa would not).
final class Pressure implements Comparable<Pressure> {
  /// Trusted construction from canonical whole pascals.
  const Pressure.pascals(this.pascals);

  /// From a display unit value; rounded to the nearest pascal.
  factory Pressure.fromDisplay(PressureUnit unit, double value) =>
      Pressure.pascals((value * _paPer(unit)).round());

  /// Canonical storage form.
  final int pascals;

  static const double _paPerKilopascal = 1000;
  static const double _paPerPsi = 6894.757293168;
  static const double _paPerBar = 100000;

  static double _paPer(PressureUnit unit) => switch (unit) {
        PressureUnit.kilopascal => _paPerKilopascal,
        PressureUnit.psi => _paPerPsi,
        PressureUnit.bar => _paPerBar,
      };

  /// Project to a display unit (edge conversion).
  double toDisplay(PressureUnit unit) => pascals / _paPer(unit);

  @override
  int compareTo(Pressure other) => pascals.compareTo(other.pascals);

  @override
  bool operator ==(Object other) =>
      other is Pressure && other.pascals == pascals;

  @override
  int get hashCode => pascals.hashCode;

  @override
  String toString() => 'Pressure(${pascals}Pa)';
}
