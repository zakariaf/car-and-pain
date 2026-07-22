import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  // 60 kWh usable pack.
  const pack = 216000000; // 60 * 3_600_000 J

  group('energyFromSocJoules', () {
    test('SoC delta × usable capacity', () {
      // 20 % → 80 % of a 60 kWh pack = 36 kWh = 129_600_000 J.
      expect(
        energyFromSocJoules(
            startSocPct: 20, endSocPct: 80, usableCapacityJoules: pack),
        129600000,
      );
    });

    test('a non-positive delta or capacity yields 0 (never negative)', () {
      expect(
          energyFromSocJoules(
              startSocPct: 80, endSocPct: 20, usableCapacityJoules: pack),
          0);
      expect(
          energyFromSocJoules(
              startSocPct: 20, endSocPct: 80, usableCapacityJoules: 0),
          0);
    });
  });

  group('wallEnergyJoules (loss factor)', () {
    test('grosses delivered up by the AC loss', () {
      // 36 kWh delivered at 10 % loss → 40 kWh drawn from the wall.
      expect(
        wallEnergyJoules(deliveredJoules: 129600000, lossPermille: 100),
        144000000, // 40 kWh
      );
    });

    test('zero loss → wall equals delivered', () {
      expect(wallEnergyJoules(deliveredJoules: 129600000, lossPermille: 0),
          129600000);
    });
  });

  group('chargeCostMinor', () {
    test('wall kWh × price/kWh at the currency exponent', () {
      // 40 kWh @ €0.309/kWh = €12.36 → 1236 cents.
      expect(
        chargeCostMinor(
            wallEnergyJoules: 144000000,
            pricePerKwhThousandths: 309,
            exponent: 2),
        1236,
      );
    });
  });

  group('blendedCostPerMetre (PHEV)', () {
    test('fuel + electric over one shared distance', () {
      // (€8.00 fuel + €4.00 electric) over 200 km → 1200 cents / 200000 m.
      expect(
        blendedCostPerMetre(
            fuelCostMinor: 800, electricCostMinor: 400, distanceMetres: 200000),
        closeTo(1200 / 200000, 1e-12),
      );
    });

    test('non-positive distance → 0', () {
      expect(
          blendedCostPerMetre(
              fuelCostMinor: 800, electricCostMinor: 400, distanceMetres: 0),
          0);
    });
  });

  group('breakEvenMonths (EV vs ICE)', () {
    test('premium ÷ per-period saving', () {
      // €4000 premium, ICE €120/mo, EV €40/mo → 4000/80 = 50 months.
      expect(
        breakEvenMonths(
            pricePremiumMinor: 400000,
            iceCostPerPeriodMinor: 12000,
            evCostPerPeriodMinor: 4000),
        closeTo(50, 1e-9),
      );
    });

    test('no saving (EV not cheaper) → null, never negative/∞', () {
      expect(
          breakEvenMonths(
              pricePremiumMinor: 400000,
              iceCostPerPeriodMinor: 4000,
              evCostPerPeriodMinor: 4000),
          isNull); // delta 0
      expect(
          breakEvenMonths(
              pricePremiumMinor: 400000,
              iceCostPerPeriodMinor: 3000,
              evCostPerPeriodMinor: 5000),
          isNull); // EV dearer to run
    });
  });
}
