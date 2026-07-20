/// Display units for [Temperature]. Canonical storage is always milli-kelvin.
enum TemperatureUnit { celsius, fahrenheit, kelvin }

/// A temperature, stored canonically as **milli-kelvin** (SI base, 0.001 K
/// precision). °C and °F are display projections. Temperature has an *offset*
/// (not a pure ratio), so conversions add/subtract as well as scale.
final class Temperature implements Comparable<Temperature> {
  /// Trusted construction from canonical milli-kelvin.
  const Temperature.milliKelvin(this.milliKelvin);

  /// From a display unit value; rounded to the nearest milli-kelvin.
  factory Temperature.fromDisplay(TemperatureUnit unit, double value) {
    final kelvin = switch (unit) {
      TemperatureUnit.kelvin => value,
      TemperatureUnit.celsius => value + _celsiusZeroK,
      TemperatureUnit.fahrenheit => (value - 32) * 5 / 9 + _celsiusZeroK,
    };
    return Temperature.milliKelvin((kelvin * 1000).round());
  }

  /// Canonical storage form.
  final int milliKelvin;

  static const double _celsiusZeroK = 273.15;

  /// Project to a display unit (edge conversion).
  double toDisplay(TemperatureUnit unit) {
    final kelvin = milliKelvin / 1000;
    return switch (unit) {
      TemperatureUnit.kelvin => kelvin,
      TemperatureUnit.celsius => kelvin - _celsiusZeroK,
      TemperatureUnit.fahrenheit => (kelvin - _celsiusZeroK) * 9 / 5 + 32,
    };
  }

  @override
  int compareTo(Temperature other) => milliKelvin.compareTo(other.milliKelvin);

  @override
  bool operator ==(Object other) =>
      other is Temperature && other.milliKelvin == milliKelvin;

  @override
  int get hashCode => milliKelvin.hashCode;

  @override
  String toString() => 'Temperature(${milliKelvin}mK)';
}
