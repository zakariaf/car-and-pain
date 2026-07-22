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
      (
        failure: const AttachmentChecksumMismatch(
          attachmentId: 'a1',
          expected: 'abc',
          found: 'def',
        ),
        code: 'import.attachment_checksum_mismatch',
      ),
      (
        failure: const UnsupportedMediaType('text/plain'),
        code: 'attachment.unsupported_type',
      ),
      (
        failure: const MediaProcessingFailed(),
        code: 'attachment.processing_failed',
      ),
      (failure: const BlobNotFound(), code: 'attachment.blob_not_found'),
      (failure: const BlobIoFailed(), code: 'attachment.io_failed'),
      (
        failure: const WrongBackupPassphrase(),
        code: 'import.wrong_passphrase',
      ),
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
    expect(
        const WrongBackupPassphrase(), equals(const WrongBackupPassphrase()));
    expect(const WrongBackupPassphrase().hashCode,
        const WrongBackupPassphrase().hashCode);
  });

  test('attachment/media failures are value-equal by their params (F8)', () {
    // Parameterless singletons.
    for (final f in const <AttachmentFailure>[
      MediaProcessingFailed(),
      BlobNotFound(),
      BlobIoFailed(),
    ]) {
      expect(f, equals(f));
      expect(f.hashCode, f.code.hashCode);
    }
    expect(const BlobNotFound(), isNot(equals(const BlobIoFailed())));

    // Parameterised: equal params ⇒ equal, differing params ⇒ not.
    expect(const UnsupportedMediaType('image/png'),
        equals(const UnsupportedMediaType('image/png')));
    expect(const UnsupportedMediaType('image/png'),
        isNot(equals(const UnsupportedMediaType('image/jpeg'))));
    expect(const UnsupportedMediaType('a').hashCode,
        const UnsupportedMediaType('a').hashCode);

    const same = AttachmentChecksumMismatch(
        attachmentId: 'a1', expected: 'x', found: 'y');
    expect(
        same,
        equals(const AttachmentChecksumMismatch(
            attachmentId: 'a1', expected: 'x', found: 'y')));
    expect(
        same,
        isNot(equals(const AttachmentChecksumMismatch(
            attachmentId: 'a2', expected: 'x', found: 'y'))));
    expect(same.attachmentId, 'a1');
    expect(same.hashCode, isA<int>());

    // A sealed AttachmentFailure switch is exhaustive without a default.
    String describe(AttachmentFailure f) => switch (f) {
          UnsupportedMediaType(:final mimeType) => 'unsupported:$mimeType',
          MediaProcessingFailed() => 'processing',
          BlobNotFound() => 'missing',
          BlobIoFailed() => 'io',
        };
    expect(describe(const UnsupportedMediaType('x/y')), 'unsupported:x/y');
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
