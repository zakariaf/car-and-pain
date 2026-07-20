import 'package:core/core.dart';
import 'package:test/test.dart';

/// Exhaustive value-semantics coverage for the crown-jewel package: equality,
/// hashCode, toString, and the remaining operators/getters across every value
/// object and failure. Keeps `core` on the diamond-top of the pyramid.
void main() {
  group('Failure — value semantics for every variant', () {
    final failures = <Failure>[
      const ConstraintViolation('vehicles'),
      const TransactionRolledBack(),
      const DecryptFailed(),
      const NotFound('vehicle'),
      const BackupWriteFailed(),
      const BackupVerifyFailed(),
      const CorruptArchive(),
      const SchemaVersionMismatch(expected: 3, found: 2),
      const PermissionDenied(),
      const ExactAlarmDenied(),
      const PendingCapExceeded(70),
      const DatabaseOpenFailed(),
      const KeyStoreUnavailable(),
      const TimezoneInitFailed(),
      const AppDirsUnavailable(),
      const ComputeFailure(),
      const UnknownFailure('x'),
      const ValidationFailure([FieldError('a', 'b')]),
    ];

    for (final f in failures) {
      test('${f.runtimeType} is reflexively equal + stable hashCode', () {
        expect(f == f, isTrue);
        expect(f.hashCode, f.hashCode);
        expect(f.code, isNotEmpty);
        // Not equal to an unrelated failure (exercises the `is`-false branch).
        expect(f == const UnknownFailure('___unique___'), isFalse);
      });
    }

    test('parameterized failures differ by their params', () {
      expect(
        const ConstraintViolation('a') == const ConstraintViolation('b'),
        isFalse,
      );
      expect(const NotFound('a') == const NotFound('b'), isFalse);
      expect(
          const PendingCapExceeded(1) == const PendingCapExceeded(2), isFalse);
      expect(const UnknownFailure('a') == const UnknownFailure('b'), isFalse);
      expect(
        const ValidationFailure([FieldError('a', 'x')]) ==
            const ValidationFailure([FieldError('a', 'y')]),
        isFalse,
      );
      expect(
        const ValidationFailure([FieldError('a', 'x')]) ==
            const ValidationFailure([FieldError('a', 'x')]),
        isTrue,
      );
    });
  });

  group('Result — full combinator + value semantics', () {
    Result<int, ValidationFailure> ok(int v) => Ok(v);
    Result<int, ValidationFailure> err() =>
        const Err(ValidationFailure([FieldError('x', 'bad')]));

    test('mapErr/then/getOrElse on both branches', () {
      expect(ok(2).mapErr((_) => const UnknownFailure()).valueOrNull, 2);
      expect(err().mapErr((_) => const UnknownFailure()).isErr, isTrue);
      expect(
          ok(3).then((v) => Ok<int, ValidationFailure>(v + 1)).valueOrNull, 4);
      expect(err().then(Ok<int, ValidationFailure>.new).isErr, isTrue);
      expect(ok(9).getOrElse((_) => -1), 9);
      expect(err().getOrElse((_) => -1), -1);
    });

    test('toString / equality / hashCode', () {
      expect(ok(1).toString(), 'Ok(1)');
      expect((err() as Err).toString(), contains('Err('));
      expect(ok(1) == ok(1), isTrue);
      expect(ok(1) == ok(2), isFalse);
      expect(ok(1).hashCode, ok(1).hashCode);
      expect(err() == err(), isTrue);
      expect(err().hashCode, err().hashCode);
    });
  });

  group('FieldError — value semantics', () {
    test('equality by field/code/params + toString', () {
      const a = FieldError('liters', 'not_a_number', {'x': 1});
      const b = FieldError('liters', 'not_a_number', {'x': 1});
      const c = FieldError('liters', 'not_a_number', {'x': 2});
      expect(a, equals(b));
      expect(a == c, isFalse);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('liters'));
    });
  });

  group('Money — operators, getters, edge parses', () {
    test('subtract, unary minus, isNegative, toString, zero', () {
      const a = Money(500, Currency.usd);
      const b = Money(200, Currency.usd);
      expect((a - b).minorUnits, 300);
      expect((-a).minorUnits, -500);
      expect((-a).isNegative, isTrue);
      expect(a.isNegative, isFalse);
      expect(a.toString(), 'Money(500 USD)');
      expect(const Money.zero(Currency.usd).hashCode, isA<int>());
    });

    test('parse leading + and bare fraction', () {
      expect(Money.tryParseMajor('+2.50', Currency.usd).valueOrNull!.minorUnits,
          250);
      expect(
          Money.tryParseMajor('.5', Currency.usd).valueOrNull!.minorUnits, 50);
    });
  });

  group('Units — full arithmetic/getters/semantics', () {
    test('Volume ops + getters + semantics', () {
      const a = Volume.millilitres(3000);
      const b = Volume.millilitres(1000);
      expect((a + b).millilitres, 4000);
      expect((a - b).millilitres, 2000);
      expect(a.compareTo(b), isPositive);
      expect(a.litres, 3.0);
      expect(a == const Volume.millilitres(3000), isTrue);
      expect(a.hashCode, const Volume.millilitres(3000).hashCode);
      expect(a.toString(), contains('mL'));
      expect(Volume.fromImperialGallons(1).imperialGallons, closeTo(1, 0.001));
      expect(Volume.fromUsGallons(1).usGallons, closeTo(1, 0.001));
    });

    test('EngineHours ops + semantics', () {
      const a = EngineHours.minutes(120);
      const b = EngineHours.minutes(60);
      expect((a + b).minutes, 180);
      expect((a - b).minutes, 60);
      expect(a.compareTo(b), isPositive);
      expect(a == const EngineHours.minutes(120), isTrue);
      expect(a.hashCode, const EngineHours.minutes(120).hashCode);
      expect(a.toString(), contains('min'));
    });

    test('Distance semantics + toString', () {
      const a = Distance.metres(1000);
      expect(a == const Distance.metres(1000), isTrue);
      expect(a.hashCode, const Distance.metres(1000).hashCode);
      expect(a.toString(), contains('m'));
    });
  });

  group('Temporal — toString + semantics', () {
    test('Instant equality/hashCode/toString', () {
      const a = Instant.fromEpochMillis(1000);
      expect(a == const Instant.fromEpochMillis(1000), isTrue);
      expect(a.hashCode, const Instant.fromEpochMillis(1000).hashCode);
      expect(a.toString(), contains('Instant('));
    });

    test('WallClockDateTime equality/hashCode/toString', () {
      final a =
          WallClockDateTime.of(year: 2026, month: 7, day: 20).valueOrNull!;
      final b =
          WallClockDateTime.of(year: 2026, month: 7, day: 20).valueOrNull!;
      final c =
          WallClockDateTime.of(year: 2026, month: 7, day: 21).valueOrNull!;
      expect(a, equals(b));
      expect(a == c, isFalse);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('no tz'));
    });
  });
}
