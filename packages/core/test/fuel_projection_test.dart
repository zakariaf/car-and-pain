import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('fuelRangeMetres', () {
    test('tank ÷ consumption', () {
      // 50 L tank at 8 L/100km (0.08 mL/m) → 625 km = 625000 m.
      expect(
        fuelRangeMetres(tankCapacityMl: 50000, rollingMlPerMetre: 0.08),
        625000,
      );
    });

    test('insufficient data → null (fall back to time-based)', () {
      expect(fuelRangeMetres(tankCapacityMl: 50000, rollingMlPerMetre: null),
          isNull);
      expect(
          fuelRangeMetres(tankCapacityMl: 50000, rollingMlPerMetre: 0), isNull);
      expect(
          fuelRangeMetres(tankCapacityMl: 0, rollingMlPerMetre: 0.08), isNull);
    });
  });

  group('nextFillOdometreMetres', () {
    test('last reading + usable range (prompt at 15% remaining)', () {
      // range 625 km, usable 85% = 531.25 km → +531250 m over the last reading.
      expect(
        nextFillOdometreMetres(
          lastOdometerMetres: 1000000,
          tankCapacityMl: 50000,
          rollingMlPerMetre: 0.08,
        ),
        1000000 + 531250,
      );
    });

    test('null when the range is unknown', () {
      expect(
        nextFillOdometreMetres(
            lastOdometerMetres: 1000000,
            tankCapacityMl: 50000,
            rollingMlPerMetre: null),
        isNull,
      );
    });
  });

  group('risingConsumptionAnomaly', () {
    test('fires when latest exceeds baseline by the tolerance', () {
      // Baseline 8, latest 10 (+25%) with a 15% tolerance → anomaly.
      expect(
        risingConsumptionAnomaly(
            latestMlPerMetre: 0.10, baselineMlPerMetre: 0.08),
        isTrue,
      );
    });

    test('does not fire within tolerance', () {
      // +10% is under the 15% tolerance.
      expect(
        risingConsumptionAnomaly(
            latestMlPerMetre: 0.088, baselineMlPerMetre: 0.08),
        isFalse,
      );
    });

    test('guards zero/negative economies', () {
      expect(
          risingConsumptionAnomaly(
              latestMlPerMetre: 0.10, baselineMlPerMetre: 0),
          isFalse);
    });
  });
}
