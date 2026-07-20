import 'package:core/core.dart';
import 'package:test/test.dart';

// A worked table-driven pattern (the F1-T8 canonical example). Each case is a
// record; a single `for` loop registers one `test` per row.
void main() {
  Result<int, ValidationFailure> ok(int v) => Ok(v);
  Result<int, ValidationFailure> err() =>
      const Err(ValidationFailure([FieldError('x', 'bad')]));

  group('Result — construction & inspection', () {
    test('Ok exposes value, isOk, valueOrNull', () {
      final r = ok(7);
      expect(r.isOk, isTrue);
      expect(r.isErr, isFalse);
      expect(r.valueOrNull, 7);
      expect(r.failureOrNull, isNull);
    });

    test('Err exposes failure, isErr, failureOrNull', () {
      final r = err();
      expect(r.isErr, isTrue);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(r.valueOrNull, isNull);
    });

    test('equality is structural', () {
      expect(ok(1), equals(ok(1)));
      expect(ok(1), isNot(equals(ok(2))));
      expect(err(), equals(err()));
    });
  });

  group('Result — fold', () {
    final cases = <({Result<int, ValidationFailure> input, String expected})>[
      (input: ok(3), expected: 'ok:3'),
      (input: err(), expected: 'err:validation.field_errors'),
    ];
    for (final c in cases) {
      test('fold collapses ${c.input}', () {
        final out = c.input.fold(
          (v) => 'ok:$v',
          (f) => 'err:${f.code}',
        );
        expect(out, c.expected);
      });
    }
  });

  group('Result — map / mapErr / flatMap / getOrElse', () {
    final mapCases = <({Result<int, ValidationFailure> input, int? expected})>[
      (input: ok(2), expected: 4),
      (input: err(), expected: null),
    ];
    for (final c in mapCases) {
      test('map doubles Ok, preserves Err (${c.input})', () {
        expect(c.input.map((v) => v * 2).valueOrNull, c.expected);
      });
    }

    test('mapErr transforms only the failure branch', () {
      final mapped = err().mapErr((_) => const UnknownFailure('x'));
      expect(mapped.failureOrNull, isA<UnknownFailure>());
      expect(ok(1).mapErr((_) => const UnknownFailure('x')).valueOrNull, 1);
    });

    test('flatMap chains on Ok, short-circuits on Err', () {
      Result<int, ValidationFailure> half(int v) =>
          v.isEven ? Ok(v ~/ 2) : err();
      expect(ok(8).flatMap(half).valueOrNull, 4);
      expect(ok(7).flatMap(half).isErr, isTrue);
      expect(err().flatMap(half).isErr, isTrue);
    });

    test('getOrElse returns value or the fallback', () {
      expect(ok(5).getOrElse((_) => -1), 5);
      expect(err().getOrElse((_) => -1), -1);
    });
  });
}
