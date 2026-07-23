import 'package:core/core.dart';
import 'package:test/test.dart';

/// M6-T5 — the pure TCO aggregator. Sums cost buckets + financing + depreciation,
/// computes cost/distance + cost/day with an explicit insufficient-data fallback.
void main() {
  const engine = TcoEngine();

  test('sums buckets + financing + depreciation into a base-currency total',
      () {
    final r = engine.compute(
      costs: const [
        TcoCostItem(bucket: 'fuel', amountMinor: 60000),
        TcoCostItem(bucket: 'service', amountMinor: 40000),
        TcoCostItem(bucket: 'fuel', amountMinor: 10000), // same bucket accrues
      ],
      distanceMetres: 10000000, // 10_000 km
      spanDays: 365,
      financingInterestMinor: 20000,
      depreciationMinor: 300000,
    );
    expect(r.byBucket['fuel'], 70000);
    expect(r.byBucket['service'], 40000);
    expect(r.byBucket['financing'], 20000);
    expect(r.byBucket['depreciation'], 300000);
    // 70000 + 40000 + 20000 + 300000
    expect(r.totalMinor, 430000);
    expect(r.hasEnoughData, isTrue);
    // 430000 minor over 10_000 km → 43 minor/km.
    expect(r.costPerKmMinor, 43);
    // 430000 over 365 days → 1178.08 → 1178.
    expect(r.costPerDayMinor, 1178);
  });

  test('insufficient distance/day suppresses the per-unit figures', () {
    final r = engine.compute(
      costs: const [TcoCostItem(bucket: 'fuel', amountMinor: 5000)],
      distanceMetres: 100000, // 100 km — below the 1_000 km floor
      spanDays: 5, // below the 30-day floor
    );
    expect(r.totalMinor, 5000);
    expect(r.hasEnoughData, isFalse);
    expect(r.costPerKmMinor, isNull);
    expect(r.costPerDayMinor, isNull);
  });

  test('one dimension can be sufficient while the other is not', () {
    final r = engine.compute(
      costs: const [TcoCostItem(bucket: 'fuel', amountMinor: 90000)],
      distanceMetres: 9000000, // 9_000 km — enough
      spanDays: 10, // not enough
    );
    expect(r.hasEnoughData, isFalse); // needs both
    expect(r.costPerKmMinor, 10); // 90000 / 9000 km
    expect(r.costPerDayMinor, isNull);
  });

  test('empty costs total zero', () {
    final r = engine.compute(costs: const [], distanceMetres: 0, spanDays: 0);
    expect(r.totalMinor, 0);
    expect(r.byBucket, isEmpty);
    expect(r.hasEnoughData, isFalse);
  });
}
