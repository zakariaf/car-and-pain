import 'package:core/core.dart';
import 'package:test/test.dart';

/// M8-T1/T3/T4/T7 · the dashboard engines: KPI aggregation over rollups (with
/// mixed-currency safety), the min-samples forecasting fallback, rule-based
/// insights, and streak/badge gamification. All pure, integer-only money.
void main() {
  group('DashboardKpis.of', () {
    test('sums same-currency contributions and derives ratios', () {
      final k = DashboardKpis.of(const [
        KpiContribution(
            currencyCode: 'EUR',
            spendMinor: 6000,
            distanceMetres: 100000,
            fuelMl: 40000,
            fillCount: 1),
        KpiContribution(
            currencyCode: 'EUR',
            spendMinor: 4000,
            distanceMetres: 100000,
            fuelMl: 30000,
            fillCount: 1),
      ]);
      expect(k.mixedCurrency, isFalse);
      expect(k.spendMinor, 10000);
      expect(k.distanceMetres, 200000); // 200 km
      expect(k.fillCount, 2);
      expect(k.currencyCode, 'EUR');
      // 10000 minor × 1000 / 200000 m = 50 minor per km.
      expect(k.costPerKmMinor, 50);
      // 70000 ml over 200 km → 35 L/100km → scaled ×100 = 3500.
      expect(k.litresPer100kmScaled, 3500);
      // 70000 ml petrol × 2310 mg/ml / 1000 = 161700 g.
      expect(k.co2Grams, 161700);
    });

    test('mixed currencies are flagged, never summed', () {
      final k = DashboardKpis.of(const [
        KpiContribution(currencyCode: 'EUR', spendMinor: 5000, fillCount: 1),
        KpiContribution(currencyCode: 'USD', spendMinor: 5000, fillCount: 1),
      ]);
      expect(k.mixedCurrency, isTrue);
      expect(k.spendMinor, 0); // not summable across currencies
      expect(k.currencyCode, '');
    });

    test('no distance → null ratios, not a divide-by-zero', () {
      final k = DashboardKpis.of(
          const [KpiContribution(currencyCode: 'EUR', spendMinor: 500)]);
      expect(k.costPerKmMinor, isNull);
      expect(k.litresPer100kmScaled, isNull);
    });
  });

  group('ForecastEngine', () {
    const engine = ForecastEngine(); // defaults: 3 samples, 14 days

    test('below the sample/span threshold → insufficient, never a guess', () {
      final r = engine.spend(
          totalSpendMinor: 9000, samples: 2, spanDays: 30, horizonDays: 30);
      expect(r, isA<ForecastInsufficient>());
      final r2 = engine.spend(
          totalSpendMinor: 9000, samples: 5, spanDays: 7, horizonDays: 30);
      expect(r2, isA<ForecastInsufficient>());
    });

    test('at/above threshold projects spend with its basis', () {
      final r = engine.spend(
          totalSpendMinor: 9000, samples: 6, spanDays: 30, horizonDays: 30);
      expect(r, isA<SpendForecast>());
      final f = r as SpendForecast;
      expect(f.perDayMinor, 300); // 9000 / 30
      expect(f.projectedSpendMinor, 9000); // 300 × 30
      expect(f.samples, 6);
    });

    test('next-service-due ETA from average daily distance', () {
      final r = engine.nextServiceDue(
        currentOdometerMetres: 12000000,
        serviceIntervalMetres: 15000000,
        lastServiceOdometerMetres: 0,
        distanceMetres: 300000, // 300 km over 30 days = 10 km/day
        samples: 5,
        spanDays: 30,
      );
      final f = r as ServiceDueForecast;
      expect(f.dueOdometerMetres, 15000000);
      expect(f.metresRemaining, 3000000); // 3000 km
      expect(f.avgDailyMetres, 10000); // 10 km/day
      expect(f.etaDays, 300); // 3000 km / 10 km-day
    });

    test('overdue service → eta 0, never negative', () {
      final r = engine.nextServiceDue(
        currentOdometerMetres: 16000000,
        serviceIntervalMetres: 15000000,
        lastServiceOdometerMetres: 0,
        distanceMetres: 300000,
        samples: 5,
        spanDays: 30,
      ) as ServiceDueForecast;
      expect(r.etaDays, 0);
      expect(r.metresRemaining, -1000000);
    });
  });

  group('InsightEngine', () {
    const engine = InsightEngine(); // default tolerance 1500 bps = 15%

    test('economy below baseline fires past the tolerance', () {
      // baseline 5.00 L/100 (500 scaled); current 6.00 (600) → +20% > 15%.
      final i = engine.economyBelowBaseline(
          currentL100Scaled: 600, baselineL100Scaled: 500);
      expect(i, isNotNull);
      expect(i!.kind, InsightKind.economyDrop);
      // Within tolerance → no insight.
      expect(
          engine.economyBelowBaseline(
              currentL100Scaled: 550, baselineL100Scaled: 500),
          isNull);
    });

    test('spend spike + integrity anomalies, sorted most-severe first', () {
      final insights = engine.evaluate([
        engine.spendAboveNorm(currentSpendMinor: 20000, avgSpendMinor: 10000),
        engine.odometerGap(5000),
        engine.odometerRegression(-2000),
        engine.duplicate(isDuplicate: true),
      ]);
      expect(insights.first.severity, InsightSeverity.critical); // regression
      expect(insights.map((i) => i.kind),
          contains(InsightKind.odometerRegression));
      expect(insights.map((i) => i.kind), contains(InsightKind.spendSpike));
      // A non-anomalous reading yields nothing.
      expect(engine.odometerRegression(500), isNull);
      expect(engine.odometerGap(0), isNull);
    });
  });

  group('GamificationEngine', () {
    const g = GamificationEngine();

    test('streak counts the trailing consecutive run, breaks on a gap', () {
      // Periods 10,11,12 then current is 12 → current streak 3.
      final s = g.streak([10, 11, 12], currentPeriod: 12);
      expect(s.current, 3);
      expect(s.longest, 3);
      // A lapsed streak (last logged well before current) → current 0.
      final lapsed = g.streak([5, 6, 7], currentPeriod: 12);
      expect(lapsed.current, 0);
      expect(lapsed.longest, 3);
    });

    test("badges are milestone-based on the user's own history", () {
      final earned = g.badges(
        totalDistanceMetres: 12000000, // 12 000 km
        loggedEntries: 5,
        economyImproved: true,
      );
      expect(earned, contains(Badge.firstLog));
      expect(earned, contains(Badge.distance1000km));
      expect(earned, contains(Badge.distance10000km));
      expect(earned, isNot(contains(Badge.distance100000km)));
      expect(earned, contains(Badge.economyImproved));
    });

    test('newlyEarned is the delta that fires the exhale', () {
      final delta = g.newlyEarned(
        {Badge.firstLog},
        {Badge.firstLog, Badge.distance1000km},
      );
      expect(delta, {Badge.distance1000km});
    });
  });
}
