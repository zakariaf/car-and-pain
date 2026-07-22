import 'package:core/core.dart';
import 'package:test/test.dart';

EnergyFill _fill(
  int ms,
  int odoMetres,
  int volumeMl, {
  int cost = 6000,
  bool full = true,
  bool missed = false,
  bool exclude = false,
}) =>
    EnergyFill(
      filledAt: Instant.fromEpochMillis(ms),
      odometerMetres: odoMetres,
      volumeMl: volumeMl,
      costMinor: cost,
      isFullTank: full,
      isMissedPrevious: missed,
      excludeFromEconomy: exclude,
    );

void main() {
  const engine = EconomyEngine();

  group('full-to-full economy', () {
    test('two full tanks yield one interval = Σvol / distance', () {
      final r = engine.compute([
        _fill(1000, 0, 40000), // baseline
        _fill(2000, 500000, 40000), // 500 km on 40 L
      ]);
      expect(r.intervals, hasLength(1));
      expect(r.latest!.distanceMetres, 500000);
      expect(r.latest!.volumeMl, 40000);
      expect(r.latest!.mlPerMetre, closeTo(0.08, 1e-9)); // 8 L/100km
      expect(r.pending, isFalse);
    });

    test('the first fill alone is pending — never 0, never infinity', () {
      final r = engine.compute([_fill(1000, 0, 40000)]);
      expect(r.pending, isTrue);
      expect(r.latest, isNull);
      expect(r.lifetimeMlPerMetre, isNull);
    });

    test('a partial fill folds into the next full-tank interval', () {
      final r = engine.compute([
        _fill(1000, 0, 40000), // baseline full
        _fill(2000, 250000, 20000, full: false), // partial
        _fill(3000, 500000, 20000), // full
      ]);
      expect(r.intervals, hasLength(1));
      expect(r.latest!.volumeMl, 40000); // partial + closing full
      expect(r.latest!.distanceMetres, 500000);
    });

    test('consecutive partials are summed across the whole span', () {
      final r = engine.compute([
        _fill(1000, 0, 40000),
        _fill(2000, 200000, 15000, full: false),
        _fill(3000, 350000, 10000, full: false),
        _fill(4000, 500000, 15000),
      ]);
      expect(r.intervals, hasLength(1));
      expect(r.latest!.volumeMl, 40000); // 15+10+15
    });
  });

  group('excluded intervals', () {
    test('a missed fill excludes its interval but keeps cost in spend', () {
      final r = engine.compute([
        _fill(1000, 0, 40000, cost: 100),
        _fill(2000, 500000, 40000, cost: 200), // valid interval 1
        _fill(3000, 1000000, 40000, cost: 400, missed: true), // broken
        _fill(4000, 1500000, 40000, cost: 800), // valid interval (f2→f3)
      ]);
      expect(r.intervals, hasLength(2)); // the missed interval is excluded
      expect(r.totalSpendMinor, 1500); // every fill's cost retained
    });

    test('a splash/excluded fill does not distort economy; cost retained', () {
      final r = engine.compute([
        _fill(1000, 0, 40000, cost: 100),
        _fill(2000, 500000, 5000, cost: 50, exclude: true), // jerrycan
        _fill(3000, 1000000, 40000, cost: 400),
      ]);
      // The excluded fill resets the baseline, so the only clean interval is the
      // final full establishing a fresh baseline → no completed interval.
      expect(r.pending, isTrue);
      expect(r.totalSpendMinor, 550); // 100 + 50 + 400
    });

    test(r'a free ($0) fill still counts its volume in economy', () {
      final r = engine.compute([
        _fill(1000, 0, 40000),
        _fill(2000, 500000, 40000, cost: 0), // free top-up
      ]);
      expect(r.intervals, hasLength(1));
      expect(r.latest!.volumeMl, 40000);
      expect(r.totalSpendMinor, 6000);
    });

    test('a non-positive distance interval is skipped', () {
      final r = engine.compute([
        _fill(1000, 500000, 40000),
        _fill(2000, 500000, 40000), // same odometer → distance 0
      ]);
      expect(r.pending, isTrue);
    });
  });

  group('aggregates', () {
    List<EnergyFill> series() => [
          _fill(1000, 0, 40000), // baseline
          _fill(2000, 500000, 40000), // 8 L/100km
          _fill(3000, 900000, 40000), // 400km/40L = 10 L/100km (worse)
          _fill(4000, 1500000, 30000), // 600km/30L = 5 L/100km (best)
        ];

    test('lifetime aggregates Σvol/Σdist; best/worst by efficiency', () {
      final r = engine.compute(series());
      expect(r.intervals, hasLength(3));
      // lifetime = (40000+40000+30000) / (500000+400000+600000) = 110000/1500000
      expect(r.lifetimeMlPerMetre, closeTo(110000 / 1500000, 1e-9));
      expect(r.best!.distanceMetres, 600000); // 5 L/100km
      expect(r.worst!.distanceMetres, 400000); // 10 L/100km
    });

    test('rolling-N averages only the last N intervals', () {
      final r = engine.compute(series());
      expect(r.rollingMlPerMetre(1), closeTo(30000 / 600000, 1e-9));
      expect(r.rollingMlPerMetre(99), r.lifetimeMlPerMetre); // clamps
      expect(r.rollingMlPerMetre(0), isNull);
    });
  });

  test('a backdated (out-of-order) insert is deterministic', () {
    final ordered = [
      _fill(1000, 0, 40000),
      _fill(2000, 500000, 40000),
      _fill(3000, 1000000, 40000),
    ];
    final shuffled = [ordered[2], ordered[0], ordered[1]];
    final a = engine.compute(ordered);
    final b = engine.compute(shuffled);
    expect(b.intervals, a.intervals); // identical inputs → identical outputs
    expect(b.lifetimeMlPerMetre, a.lifetimeMlPerMetre);
  });
}
