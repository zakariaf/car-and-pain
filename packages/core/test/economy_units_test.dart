import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  // 8 L/100km ⇔ 0.08 mL/m.
  const eco = 0.08;

  test('liquid projections from mL/metre', () {
    expect(litresPer100km(eco), closeTo(8, 1e-9));
    expect(kmPerLitre(eco), closeTo(12.5, 1e-9));
    // 8 L/100km ≈ 29.4 US MPG, 35.3 UK MPG — US and UK are NEVER conflated.
    expect(mpgUs(eco), closeTo(29.4018, 1e-3));
    expect(mpgUk(eco), closeTo(35.3101, 1e-3));
    expect(mpgUk(eco), greaterThan(mpgUs(eco))); // UK gallon is larger
  });

  test('EV projections from joules/metre', () {
    // 150 Wh/km = 540000 J / 1000 m = 540 J/m.
    const jpm = 540.0;
    expect(whPerKm(jpm), closeTo(150, 1e-9));
    expect(kwhPer100km(jpm), closeTo(15, 1e-9));
    // 150 Wh/km ≈ 4.14 mi/kWh.
    expect(miPerKwh(jpm), closeTo(4.1425, 1e-3));
  });

  test('project* returns null for the wrong energy family', () {
    expect(projectLiquid(eco, EconomyMode.whPerKm), isNull);
    expect(projectElectric(540, EconomyMode.mpgUs), isNull);
    expect(projectLiquid(eco, EconomyMode.mpgUs), closeTo(29.4018, 1e-3));
    expect(projectElectric(540, EconomyMode.kwhPer100km), closeTo(15, 1e-9));
  });

  test('zero economy is guarded (no divide-by-zero)', () {
    expect(kmPerLitre(0), 0);
    expect(mpgUs(0), 0);
    expect(miPerKwh(0), 0);
  });
}
