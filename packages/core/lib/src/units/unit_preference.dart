import 'distance.dart';
import 'energy.dart';
import 'pressure.dart';
import 'temperature.dart';
import 'volume.dart';

/// Resolve a convertible display preference with the canonical precedence:
/// **per-record override → per-vehicle setting → global default**. Storage is
/// always canonical; this only chooses the display projection.
T resolveUnit<T>(T? record, T? vehicle, T global) =>
    record ?? vehicle ?? global;

/// The global display-unit defaults, resolvable per-vehicle and per-record via
/// [resolveUnit]. Switching any of these never rewrites a stored (canonical)
/// value.
class UnitPreferences {
  const UnitPreferences({
    this.distance = DistanceUnit.kilometre,
    this.volume = VolumeUnit.litre,
    this.pressure = PressureUnit.kilopascal,
    this.temperature = TemperatureUnit.celsius,
    this.energy = EnergyUnit.kilowattHour,
  });

  final DistanceUnit distance;
  final VolumeUnit volume;
  final PressureUnit pressure;
  final TemperatureUnit temperature;
  final EnergyUnit energy;

  @override
  bool operator ==(Object other) =>
      other is UnitPreferences &&
      other.distance == distance &&
      other.volume == volume &&
      other.pressure == pressure &&
      other.temperature == temperature &&
      other.energy == energy;

  @override
  int get hashCode =>
      Object.hash(distance, volume, pressure, temperature, energy);
}
