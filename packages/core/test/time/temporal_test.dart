import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Instant — absolute UTC', () {
    test('fromDateTime normalizes to UTC epoch millis', () {
      final local = DateTime(2026, 7, 20, 9, 30);
      final instant = Instant.fromDateTime(local);
      expect(instant.epochMillis, local.toUtc().millisecondsSinceEpoch);
      expect(instant.utc.isUtc, isTrue);
    });

    test('round-trips through epoch millis', () {
      const millis = 1_784_000_000_000;
      const instant = Instant.fromEpochMillis(millis);
      expect(instant.epochMillis, millis);
      expect(Instant.fromDateTime(instant.utc).epochMillis, millis);
    });

    test('orders chronologically', () {
      const earlier = Instant.fromEpochMillis(1000);
      const later = Instant.fromEpochMillis(2000);
      expect(earlier.compareTo(later), isNegative);
    });
  });

  group('WallClockDateTime — timezone-less schedule anchor', () {
    test('valid civil components build Ok', () {
      final result = WallClockDateTime.of(
        year: 2026,
        month: 7,
        day: 20,
        hour: 9,
      );
      expect(result.valueOrNull, isNotNull);
      expect(result.valueOrNull!.hour, 9);
    });

    test('out-of-range components accumulate a ValidationFailure', () {
      final result = WallClockDateTime.of(year: 2026, month: 13, day: 40);
      expect(result.isErr, isTrue);
      final f = result.failureOrNull!;
      expect(f.fieldErrors.map((e) => e.field), containsAll(['month', 'day']));
    });
  });

  group('Clock port', () {
    test('FixedClock is deterministic and UTC', () {
      final clock = FixedClock(DateTime(2026, 7, 20, 12));
      expect(clock.nowUtc(), DateTime(2026, 7, 20, 12).toUtc());
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('SystemClock returns a UTC instant', () {
      expect(const SystemClock().nowUtc().isUtc, isTrue);
    });
  });
}
