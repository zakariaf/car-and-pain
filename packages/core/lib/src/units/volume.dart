/// Display units for [Volume]. Canonical storage is always whole millilitres.
enum VolumeUnit { millilitre, litre, usGallon, imperialGallon }

/// A volume, stored canonically as **whole millilitres**. Litres and the two
/// (different!) gallons are display projections computed only at the edge.
final class Volume implements Comparable<Volume> {
  /// Trusted construction from canonical whole millilitres.
  const Volume.millilitres(this.millilitres);

  /// From litres (display unit); rounded to the nearest millilitre.
  Volume.fromLitres(double litres)
      : millilitres = (litres * _mlPerLitre).round();

  /// From **US** gallons; rounded to the nearest millilitre.
  Volume.fromUsGallons(double gallons)
      : millilitres = (gallons * _mlPerUsGallon).round();

  /// From **Imperial** gallons; rounded to the nearest millilitre.
  Volume.fromImperialGallons(double gallons)
      : millilitres = (gallons * _mlPerImperialGallon).round();

  /// From a display unit value; rounded to the nearest millilitre.
  factory Volume.fromDisplay(VolumeUnit unit, double value) =>
      Volume.millilitres((value * _mlPer(unit)).round());

  /// Canonical storage form.
  final int millilitres;

  static const double _mlPerLitre = 1000;
  // Exact conversions: guard against the US vs Imperial gallon trap.
  static const double _mlPerUsGallon = 3785.411784;
  static const double _mlPerImperialGallon = 4546.09;

  static double _mlPer(VolumeUnit unit) => switch (unit) {
        VolumeUnit.millilitre => 1,
        VolumeUnit.litre => _mlPerLitre,
        VolumeUnit.usGallon => _mlPerUsGallon,
        VolumeUnit.imperialGallon => _mlPerImperialGallon,
      };

  /// Project to a display unit (edge conversion).
  double toDisplay(VolumeUnit unit) => millilitres / _mlPer(unit);

  /// The volume in litres (edge conversion).
  double get litres => millilitres / _mlPerLitre;

  /// The volume in US gallons (edge conversion).
  double get usGallons => millilitres / _mlPerUsGallon;

  /// The volume in Imperial gallons (edge conversion).
  double get imperialGallons => millilitres / _mlPerImperialGallon;

  /// Sum of two volumes.
  Volume operator +(Volume other) =>
      Volume.millilitres(millilitres + other.millilitres);

  /// Difference of two volumes.
  Volume operator -(Volume other) =>
      Volume.millilitres(millilitres - other.millilitres);

  @override
  int compareTo(Volume other) => millilitres.compareTo(other.millilitres);

  @override
  bool operator ==(Object other) =>
      other is Volume && other.millilitres == millilitres;

  @override
  int get hashCode => millilitres.hashCode;

  @override
  String toString() => 'Volume(${millilitres}mL)';
}
