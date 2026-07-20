import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Failure — stable codes', () {
    final cases = <({Failure failure, String code})>[
      (
        failure: const ConstraintViolation('vehicles'),
        code: 'db.constraint_violation'
      ),
      (
        failure: const TransactionRolledBack(),
        code: 'db.transaction_rolled_back'
      ),
      (failure: const DecryptFailed(), code: 'db.decrypt_failed'),
      (failure: const NotFound('vehicle'), code: 'db.not_found'),
      (failure: const BackupWriteFailed(), code: 'backup.write_failed'),
      (failure: const BackupVerifyFailed(), code: 'backup.verify_failed'),
      (failure: const CorruptArchive(), code: 'import.corrupt_archive'),
      (
        failure: const SchemaVersionMismatch(expected: 3, found: 2),
        code: 'import.schema_version_mismatch',
      ),
      (failure: const PermissionDenied(), code: 'notif.permission_denied'),
      (failure: const ExactAlarmDenied(), code: 'notif.exact_alarm_denied'),
      (
        failure: const PendingCapExceeded(70),
        code: 'notif.pending_cap_exceeded'
      ),
      (
        failure: const DatabaseOpenFailed(),
        code: 'startup.database_open_failed'
      ),
      (
        failure: const KeyStoreUnavailable(),
        code: 'startup.key_store_unavailable'
      ),
      (
        failure: const TimezoneInitFailed(),
        code: 'startup.timezone_init_failed'
      ),
      (
        failure: const AppDirsUnavailable(),
        code: 'startup.app_dirs_unavailable'
      ),
      (failure: const ComputeFailure(), code: 'compute.failed'),
      (failure: const UnknownFailure(), code: 'unknown'),
    ];
    for (final c in cases) {
      test('${c.failure.runtimeType} => ${c.code}', () {
        expect(c.failure.code, c.code);
      });
    }
  });

  test('typed params are carried, not stringified', () {
    const f = SchemaVersionMismatch(expected: 3, found: 2);
    expect(f.expected, 3);
    expect(f.found, 2);
    expect(const PendingCapExceeded(70).requested, 70);
    expect(const ConstraintViolation('fuel').table, 'fuel');
  });

  test('failures are value-equal by their params', () {
    expect(const DecryptFailed(), equals(const DecryptFailed()));
    expect(
      const SchemaVersionMismatch(expected: 3, found: 2),
      equals(const SchemaVersionMismatch(expected: 3, found: 2)),
    );
    expect(
      const SchemaVersionMismatch(expected: 3, found: 2),
      isNot(equals(const SchemaVersionMismatch(expected: 3, found: 1))),
    );
  });

  test('a sealed DbFailure switch is exhaustive without a default', () {
    // If a new DbFailure subtype is added, this switch stops compiling — which
    // is exactly the compile-time safety we want. No `default:` clause.
    String describe(DbFailure f) => switch (f) {
          ConstraintViolation(:final table) => 'constraint:$table',
          TransactionRolledBack() => 'rolled_back',
          DecryptFailed() => 'decrypt',
          NotFound(:final entity) => 'missing:$entity',
        };
    expect(describe(const ConstraintViolation('t')), 'constraint:t');
    expect(describe(const NotFound('v')), 'missing:v');
  });

  test('Validation accumulates all errors applicatively', () {
    final v = Validation()
      ..add('a', 'required')
      ..add('b', 'not_a_number');
    expect(v.hasErrors, isTrue);
    final result = v.build(0);
    expect(result.isErr, isTrue);
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(result.failureOrNull!.fieldErrors, hasLength(2));
  });

  test('a clean Validation builds Ok', () {
    final result = Validation().build(42);
    expect(result.valueOrNull, 42);
  });
}
