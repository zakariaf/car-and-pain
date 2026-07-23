import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  const p = PowertrainProfile();

  Set<VehicleField> fields(
    VehicleType type,
    EnergyType? energy, [
    EnergyType? secondary,
  ]) =>
      p.fieldsFor(type: type, energy: energy, secondaryEnergy: secondary);

  group('field visibility per powertrain', () {
    test('ICE (petrol) shows tank + grade, hides battery', () {
      final f = fields(VehicleType.car, EnergyType.gasoline);
      expect(
          f, containsAll([VehicleField.tankCapacity, VehicleField.fuelGrade]));
      expect(
          f,
          isNot(anyElement(isIn([
            VehicleField.batteryCapacity,
            VehicleField.connectors,
            VehicleField.stateOfHealth,
          ]))));
    });

    test('EV shows battery/SoH/connectors, hides tank', () {
      final f = fields(VehicleType.car, EnergyType.electric);
      expect(
          f,
          containsAll([
            VehicleField.batteryCapacity,
            VehicleField.usableCapacity,
            VehicleField.connectors,
            VehicleField.stateOfHealth,
          ]));
      expect(f, isNot(contains(VehicleField.tankCapacity)));
      expect(f, isNot(contains(VehicleField.energySplit)));
    });

    test('PHEV shows BOTH tank and battery plus the split config', () {
      final f = fields(VehicleType.car, EnergyType.plugInHybrid);
      expect(
          f,
          containsAll([
            VehicleField.tankCapacity,
            VehicleField.batteryCapacity,
            VehicleField.energySplit,
          ]));
    });

    test('plain hybrid has a tank but no user-managed battery', () {
      final f = fields(VehicleType.car, EnergyType.hybrid);
      expect(f, contains(VehicleField.tankCapacity));
      expect(f, isNot(contains(VehicleField.batteryCapacity)));
    });

    test('bi-fuel (petrol + LPG) shows a secondary tank + split', () {
      final f = fields(VehicleType.car, EnergyType.gasoline, EnergyType.lpg);
      expect(
          f,
          containsAll([
            VehicleField.tankCapacity,
            VehicleField.secondaryTank,
            VehicleField.energySplit,
          ]));
      expect(f, isNot(contains(VehicleField.batteryCapacity)));
    });

    test('petrol + electric secondary = PHEV-shaped (tank + battery + split)',
        () {
      final f =
          fields(VehicleType.car, EnergyType.gasoline, EnergyType.electric);
      expect(
          f,
          containsAll([
            VehicleField.tankCapacity,
            VehicleField.batteryCapacity,
            VehicleField.energySplit,
          ]));
      expect(f, isNot(contains(VehicleField.secondaryTank)));
    });

    test('motorcycle exposes chain/belt + front/rear tire specs', () {
      final f = fields(VehicleType.motorcycle, EnergyType.gasoline);
      expect(
          f,
          containsAll([
            VehicleField.chainBelt,
            VehicleField.frontTireSpec,
            VehicleField.rearTireSpec,
          ]));
    });

    test('boat/equipment expose the engine-hour meter', () {
      expect(fields(VehicleType.boat, EnergyType.diesel),
          contains(VehicleField.engineHourMeter));
      expect(fields(VehicleType.equipment, EnergyType.diesel),
          contains(VehicleField.engineHourMeter));
      expect(fields(VehicleType.car, EnergyType.diesel),
          isNot(contains(VehicleField.engineHourMeter)));
    });

    test('every configuration always offers wheel + distance-tracking fields',
        () {
      for (final t in VehicleType.values) {
        final f = fields(t, null);
        expect(
            f,
            containsAll([
              VehicleField.wheelConfig,
              VehicleField.distanceTracking,
            ]));
      }
    });
  });

  group('type-driven defaults', () {
    test('wheel-count defaults per type', () {
      expect(p.defaultWheelCount(VehicleType.car), 4);
      expect(p.defaultWheelCount(VehicleType.motorcycle), 2);
      expect(p.defaultWheelCount(VehicleType.truck), 6);
      expect(p.defaultWheelCount(VehicleType.boat), 0);
    });

    test('hour-metered types + distance defaults', () {
      expect(p.usesEngineHours(VehicleType.boat), isTrue);
      expect(p.usesEngineHours(VehicleType.generator), isTrue);
      expect(p.usesEngineHours(VehicleType.car), isFalse);
      // Boats/equipment default distance OFF; RVs (road vehicles) keep it on.
      expect(p.distanceTrackingByDefault(VehicleType.boat), isFalse);
      expect(p.distanceTrackingByDefault(VehicleType.rv), isTrue);
      expect(p.distanceTrackingByDefault(VehicleType.car), isTrue);
    });
  });

  group('derived predicates', () {
    test('hasCombustion / hasManagedBattery / isBiFuel', () {
      expect(p.hasCombustion(EnergyType.diesel), isTrue);
      expect(p.hasCombustion(EnergyType.electric), isFalse);
      expect(p.hasManagedBattery(EnergyType.electric), isTrue);
      expect(p.hasManagedBattery(EnergyType.hybrid), isFalse);
      expect(p.isBiFuel(EnergyType.gasoline, EnergyType.cng), isTrue);
      expect(p.isBiFuel(EnergyType.gasoline, EnergyType.gasoline), isFalse);
    });
  });
}
