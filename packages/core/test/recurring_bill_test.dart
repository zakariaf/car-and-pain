import 'package:core/core.dart';
import 'package:test/test.dart';

/// M6-T2 — lump-cost amortization + recurrence materialization. Amortized parts
/// sum back exactly; recurrence honours end date / occurrence count.
void main() {
  Instant at(int y, int m, int d) =>
      Instant.fromDateTime(DateTime.utc(y, m, d));

  group('lump amortization', () {
    const amortizer = LumpAmortizer();

    test('splits across periods summing back exactly (remainder distributed)',
        () {
      final parts = amortizer.overPeriods(100, 3);
      expect(parts, [34, 33, 33]); // remainder → earliest period
      expect(parts.fold(0, (a, b) => a + b), 100);

      final even = amortizer.overPeriods(1200, 12);
      expect(even.every((p) => p == 100), isTrue);
    });

    test('handles a negative (refund) spread symmetrically', () {
      final parts = amortizer.overPeriods(-100, 3);
      expect(parts, [-34, -33, -33]);
      expect(parts.fold(0, (a, b) => a + b), -100);
    });

    test('distance amortization is round-half-up and window-guarded', () {
      // 12_000 covering 10_000 km, used 2_500 km → 3_000.
      expect(
        amortizer
            .forDistance(
                amountMinor: 12000, windowMetres: 10000000, usedMetres: 2500000)
            .valueOrNull,
        3000,
      );
      // Non-positive window → typed failure.
      expect(
        amortizer
            .forDistance(amountMinor: 12000, windowMetres: 0, usedMetres: 100)
            .failureOrNull,
        isA<ValidationFailure>(),
      );
    });
  });

  group('recurrence materialization', () {
    test('monthly instances honour an end date', () {
      final bill = RecurringBill(
        anchor: at(2026, 1, 15),
        recurrence: const Recurrence(1, RecurrenceUnit.months),
        endAt: at(2026, 4, 1),
      );
      final dates = bill.occurrencesUntil(at(2026, 12, 31));
      expect(dates, [at(2026, 1, 15), at(2026, 2, 15), at(2026, 3, 15)]);
    });

    test('occurrence count caps the series', () {
      final bill = RecurringBill(
        anchor: at(2026, 1, 1),
        recurrence: const Recurrence(3, RecurrenceUnit.months), // quarterly
        maxOccurrences: 4,
      );
      final dates = bill.occurrencesUntil(at(2030, 1, 1));
      expect(dates, hasLength(4));
      expect(dates.last, at(2026, 10, 1)); // Jan, Apr, Jul, Oct
    });

    test('end-of-month clamps (monthly from Jan 31)', () {
      final bill = RecurringBill(
        anchor: at(2026, 1, 31),
        recurrence: const Recurrence(1, RecurrenceUnit.months),
        maxOccurrences: 3,
      );
      final dates = bill.occurrencesUntil(at(2027, 1, 1));
      expect(dates, [at(2026, 1, 31), at(2026, 2, 28), at(2026, 3, 28)]);
    });
  });
}
