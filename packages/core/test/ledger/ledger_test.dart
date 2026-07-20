import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  const day = Duration.millisecondsPerDay;
  Instant at(int dayN) => Instant.fromEpochMillis(dayN * day);
  const engine = LedgerEngine();

  LedgerReading r(
    int value,
    int dayN, {
    LedgerSource source = LedgerSource.manual,
    int offset = 0,
    bool override = false,
  }) =>
      LedgerReading(
        value: value,
        takenAt: at(dayN),
        source: source,
        cumulativeOffset: offset,
        isRegressionOverride: override,
      );

  group('LedgerEngine.check', () {
    test('an increasing reading is clean', () {
      expect(engine.check([r(10000000, 0)], r(10700000, 7)), isEmpty);
    });

    test('a small backward jump warns regression', () {
      final w = engine.check([r(10000000, 0)], r(9999000, 1));
      expect(w.map((e) => e.code), ['regression']);
    });

    test('regression override suppresses the warning', () {
      expect(
        engine.check([r(10000000, 0)], r(9999000, 1, override: true)),
        isEmpty,
      );
    });

    test('a huge backward jump warns rollover, not regression', () {
      final w = engine.check([r(999000000, 0)], r(1000000, 1));
      expect(w.map((e) => e.code), ['rollover']);
    });

    test('an identical reading warns duplicate', () {
      final w = engine.check(
        [r(10000000, 0, source: LedgerSource.fuel)],
        r(10000000, 0, source: LedgerSource.fuel),
      );
      expect(w.map((e) => e.code), contains('duplicate'));
    });
  });

  group('LedgerEngine cluster-swap continuity', () {
    test('offset keeps logical odometer continuous across a swap', () {
      final offset = engine.clusterSwapOffset(
        priorLifetimeValue: 200000000, // 200,000 km
        newRawStart: 0, // new cluster reads 0
      );
      expect(offset, 200000000);
      final afterSwap = r(5000000, 30, offset: offset); // raw 5,000 km
      expect(afterSwap.lifetimeValue, 205000000); // 205,000 km logical
    });
  });

  group('LedgerEngine usage-rate derivation', () {
    test('avgDailyValue over the span', () {
      final history = [r(10000000, 0), r(10700000, 7)];
      expect(engine.avgDailyValue(history), 100000); // m/day
    });

    test('insufficient data → null', () {
      expect(engine.avgDailyValue([r(10000000, 0)]), isNull);
      expect(engine.avgDailyValue([r(1, 5), r(2, 5)]), isNull); // zero span
    });

    test('estimatedValueNow projects forward from the latest reading', () {
      final clockEngine = LedgerEngine(
        clock: FixedClock(
          DateTime.fromMillisecondsSinceEpoch(10 * day, isUtc: true),
        ),
      );
      final history = [r(10000000, 0), r(10700000, 7)];
      // rate 100,000/day; last at day 7; +3 days → +300,000.
      expect(clockEngine.estimatedValueNow(history), 11000000);
    });

    test('estimatedValueNow is null on insufficient data', () {
      expect(engine.estimatedValueNow([r(10000000, 0)]), isNull);
    });
  });
}
