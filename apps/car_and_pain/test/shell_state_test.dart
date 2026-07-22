import 'package:car_and_pain/src/shell/shell_state.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

Vehicle _v(String id, {String status = 'active'}) =>
    Vehicle(id: id, nickname: id, status: status);

void main() {
  group('pure scope resolution', () {
    test('active vehicle = pinned when still active, else first', () {
      final vs = [_v('a'), _v('b')];
      expect(resolveActiveVehicleId(vs, 'b'), 'b');
      expect(resolveActiveVehicleId(vs, 'gone'), 'a'); // graceful fallback
      expect(resolveActiveVehicleId(vs, null), 'a');
      expect(resolveActiveVehicleId(const [], 'x'), isNull);
    });

    test('sold/archived vehicles are excluded from the active set', () {
      expect(isActiveVehicle(_v('a')), isTrue);
      expect(isActiveVehicle(_v('b', status: 'sold')), isFalse);
      expect(isActiveVehicle(_v('c', status: 'archived')), isFalse);
    });

    test('scoped ids: per-vehicle is the active one; all/fleet is every active',
        () {
      final active = [_v('a'), _v('b')];
      expect(scopedVehicleIds(VehicleScope.perVehicle, active, 'b'), ['b']);
      expect(
          scopedVehicleIds(VehicleScope.allVehicles, active, 'b'), ['a', 'b']);
      expect(scopedVehicleIds(VehicleScope.fleet, active, 'b'), ['a', 'b']);
      expect(scopedVehicleIds(VehicleScope.perVehicle, active, null), isEmpty);
    });
  });

  test('the active set excludes sold/archived while keeping active vehicles',
      () {
    final all = [
      const Vehicle(id: 'a', nickname: 'Golf'),
      const Vehicle(id: 'b', nickname: 'Civic'),
      const Vehicle(id: 'c', nickname: 'Sold', status: 'sold'),
    ];
    final active = all.where(isActiveVehicle).toList();
    expect(active.map((v) => v.id), ['a', 'b']);
    // Pinned 'b' wins; per-vehicle scope is just it.
    final id = resolveActiveVehicleId(active, 'b');
    expect(scopedVehicleIds(VehicleScope.perVehicle, active, id), ['b']);
  });
}
