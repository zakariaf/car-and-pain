import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Pressure — canonical pascals', () {
    test('display round-trips within tolerance', () {
      expect(Pressure.fromDisplay(PressureUnit.bar, 2.5).pascals, 250000);
      expect(
          Pressure.fromDisplay(PressureUnit.kilopascal, 220).pascals, 220000);
      expect(Pressure.fromDisplay(PressureUnit.psi, 32).pascals, 220632);
      final p = Pressure.fromDisplay(PressureUnit.psi, 32);
      expect(p.toDisplay(PressureUnit.psi), closeTo(32, 0.001));
      expect(p.toDisplay(PressureUnit.bar), closeTo(2.206, 0.001));
    });

    test('semantics', () {
      const a = Pressure.pascals(250000);
      expect(a, const Pressure.pascals(250000));
      expect(a.hashCode, const Pressure.pascals(250000).hashCode);
      expect(a.compareTo(const Pressure.pascals(100000)), isPositive);
      expect(a.toString(), contains('Pa'));
    });
  });

  group('Temperature — canonical milli-kelvin (offset scale)', () {
    test('celsius/fahrenheit/kelvin conversions', () {
      expect(Temperature.fromDisplay(TemperatureUnit.celsius, 0).milliKelvin,
          273150);
      expect(
        Temperature.fromDisplay(TemperatureUnit.celsius, 100).milliKelvin,
        373150,
      );
      final freezing = Temperature.fromDisplay(TemperatureUnit.celsius, 0);
      expect(
          freezing.toDisplay(TemperatureUnit.fahrenheit), closeTo(32, 0.001));
      expect(
          freezing.toDisplay(TemperatureUnit.kelvin), closeTo(273.15, 0.001));
      final boiling = Temperature.fromDisplay(TemperatureUnit.fahrenheit, 212);
      expect(boiling.toDisplay(TemperatureUnit.celsius), closeTo(100, 0.001));
    });

    test('semantics', () {
      const t = Temperature.milliKelvin(300000);
      expect(t, const Temperature.milliKelvin(300000));
      expect(t.hashCode, const Temperature.milliKelvin(300000).hashCode);
      expect(t.compareTo(const Temperature.milliKelvin(200000)), isPositive);
      expect(t.toString(), contains('mK'));
    });
  });

  group('Energy — canonical joules', () {
    test('kWh and MJ conversions', () {
      expect(Energy.fromDisplay(EnergyUnit.kilowattHour, 60).joules, 216000000);
      expect(Energy.fromDisplay(EnergyUnit.megajoule, 1).joules, 1000000);
      final pack = Energy.fromDisplay(EnergyUnit.kilowattHour, 60);
      expect(pack.toDisplay(EnergyUnit.kilowattHour), closeTo(60, 0.001));
      expect(pack.toDisplay(EnergyUnit.megajoule), closeTo(216, 0.001));
    });

    test('semantics', () {
      const e = Energy.joules(216000000);
      expect(e, const Energy.joules(216000000));
      expect(e.hashCode, const Energy.joules(216000000).hashCode);
      expect(e.compareTo(const Energy.joules(1)), isPositive);
      expect(e.toString(), contains('J'));
    });
  });

  group('Distance/Volume — unit-enum display API', () {
    test('Distance.fromDisplay/toDisplay', () {
      expect(Distance.fromDisplay(DistanceUnit.kilometre, 12.5).metres, 12500);
      expect(Distance.fromDisplay(DistanceUnit.mile, 1).metres, 1609);
      expect(
        const Distance.metres(1000).toDisplay(DistanceUnit.kilometre),
        1.0,
      );
    });

    test('Volume.fromDisplay/toDisplay (gallon trap)', () {
      expect(Volume.fromDisplay(VolumeUnit.usGallon, 1).millilitres, 3785);
      expect(
          Volume.fromDisplay(VolumeUnit.imperialGallon, 1).millilitres, 4546);
      expect(const Volume.millilitres(50000).toDisplay(VolumeUnit.litre), 50.0);
    });
  });

  group('Unit precedence resolver', () {
    test('per-record → per-vehicle → global', () {
      expect(
        resolveUnit(
            DistanceUnit.mile, DistanceUnit.kilometre, DistanceUnit.metre),
        DistanceUnit.mile, // record wins
      );
      expect(
        resolveUnit<DistanceUnit>(
            null, DistanceUnit.kilometre, DistanceUnit.metre),
        DistanceUnit.kilometre, // vehicle wins
      );
      expect(
        resolveUnit<DistanceUnit>(null, null, DistanceUnit.metre),
        DistanceUnit.metre, // global default
      );
    });

    test('UnitPreferences defaults + equality', () {
      const p = UnitPreferences();
      expect(p.distance, DistanceUnit.kilometre);
      expect(p.temperature, TemperatureUnit.celsius);
      expect(p, const UnitPreferences());
      expect(p.hashCode, const UnitPreferences().hashCode);
    });
  });
}
