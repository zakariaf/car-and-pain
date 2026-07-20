import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Distance — canonical metres, edge conversion', () {
    test('from km / miles rounds to whole metres', () {
      expect(Distance.fromKilometres(1).metres, 1000);
      expect(Distance.fromKilometres(12.5).metres, 12500);
      expect(Distance.fromMiles(1).metres, 1609); // round(1609.344)
      expect(Distance.fromMiles(100).metres, 160934);
    });

    test('display getters project from canonical metres', () {
      expect(const Distance.metres(1000).kilometres, 1.0);
      expect(const Distance.metres(1609).miles, closeTo(1.0, 0.001));
    });

    test('km round-trip is lossless within a metre', () {
      for (final km in [1.0, 10.0, 250.0, 12345.0]) {
        expect(Distance.fromKilometres(km).kilometres, closeTo(km, 0.001));
      }
    });

    test('arithmetic and ordering', () {
      const a = Distance.metres(1000);
      const b = Distance.metres(500);
      expect((a + b).metres, 1500);
      expect((a - b).metres, 500);
      expect(a.compareTo(b), isPositive);
    });
  });

  group('Volume — canonical millilitres, gallon trap', () {
    test('US and Imperial gallons are different', () {
      expect(Volume.fromUsGallons(1).millilitres, 3785);
      expect(Volume.fromImperialGallons(1).millilitres, 4546);
      expect(Volume.fromLitres(50).millilitres, 50000);
    });

    test('litre round-trip', () {
      for (final l in [1.0, 40.0, 66.6]) {
        expect(Volume.fromLitres(l).litres, closeTo(l, 0.001));
      }
    });
  });

  group('EngineHours — canonical minutes', () {
    test('from decimal hours rounds to whole minutes', () {
      expect(EngineHours.fromHours(1.5).minutes, 90);
      expect(EngineHours.fromHours(2).minutes, 120);
      expect(const EngineHours.minutes(90).hours, 1.5);
    });
  });
}
