import 'validation.dart';

/// The root of every typed failure in Car and Pain.
///
/// A [Failure] carries a **stable machine [code]** and typed, structured params
/// — **never** a user-facing or localized string. Six languages, Eastern-Arabic
/// /Persian numerals, and Gregorian/Jalali/Hijri calendars mean any baked-in
/// text would break translation, bidi mirroring, and numeral rendering. The UI
/// localizes from [code] at the presentation edge via gen-l10n.
///
/// Each boundary owns a `sealed` sub-family so the UI `switch`es exhaustively.
sealed class Failure {
  const Failure();

  /// Stable, localization-key-like identifier, e.g. `db.decrypt_failed`.
  String get code;
}

// ─────────────────────────────────────────────────────────────────────────
// Database boundary (packages/data repositories & DAOs).
// ─────────────────────────────────────────────────────────────────────────

/// Failures raised at the encrypted-database boundary.
sealed class DbFailure extends Failure {
  const DbFailure();
}

/// A UNIQUE/FK/CHECK constraint was violated on [table].
final class ConstraintViolation extends DbFailure {
  const ConstraintViolation(this.table);

  final String table;

  @override
  String get code => 'db.constraint_violation';

  @override
  bool operator ==(Object other) =>
      other is ConstraintViolation && other.table == table;

  @override
  int get hashCode => Object.hash(code, table);
}

/// A multi-table transaction was rolled back as a unit.
final class TransactionRolledBack extends DbFailure {
  const TransactionRolledBack();

  @override
  String get code => 'db.transaction_rolled_back';

  @override
  bool operator ==(Object other) => other is TransactionRolledBack;

  @override
  int get hashCode => code.hashCode;
}

/// The database could not be decrypted (wrong/lost key).
final class DecryptFailed extends DbFailure {
  const DecryptFailed();

  @override
  String get code => 'db.decrypt_failed';

  @override
  bool operator ==(Object other) => other is DecryptFailed;

  @override
  int get hashCode => code.hashCode;
}

/// A requested row was not found.
final class NotFound extends DbFailure {
  const NotFound(this.entity);

  final String entity;

  @override
  String get code => 'db.not_found';

  @override
  bool operator ==(Object other) => other is NotFound && other.entity == entity;

  @override
  int get hashCode => Object.hash(code, entity);
}

// ─────────────────────────────────────────────────────────────────────────
// Backup boundary (packages/data backup/export engine).
// ─────────────────────────────────────────────────────────────────────────

/// Failures raised while producing or verifying a backup.
sealed class BackupFailure extends Failure {
  const BackupFailure();
}

/// The WAL checkpoint / `VACUUM INTO` step failed.
final class BackupWriteFailed extends BackupFailure {
  const BackupWriteFailed();

  @override
  String get code => 'backup.write_failed';

  @override
  bool operator ==(Object other) => other is BackupWriteFailed;

  @override
  int get hashCode => code.hashCode;
}

/// The freshly written backup failed verify-by-reopen.
final class BackupVerifyFailed extends BackupFailure {
  const BackupVerifyFailed();

  @override
  String get code => 'backup.verify_failed';

  @override
  bool operator ==(Object other) => other is BackupVerifyFailed;

  @override
  int get hashCode => code.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────
// Import boundary (merge-aware import wizard).
// ─────────────────────────────────────────────────────────────────────────

/// Failures raised while importing an external archive.
sealed class ImportFailure extends Failure {
  const ImportFailure();
}

/// The archive bytes are corrupt or fail their checksum.
final class CorruptArchive extends ImportFailure {
  const CorruptArchive();

  @override
  String get code => 'import.corrupt_archive';

  @override
  bool operator ==(Object other) => other is CorruptArchive;

  @override
  int get hashCode => code.hashCode;
}

/// The archive's schema version does not match what this build can restore.
final class SchemaVersionMismatch extends ImportFailure {
  const SchemaVersionMismatch({required this.expected, required this.found});

  final int expected;
  final int found;

  @override
  String get code => 'import.schema_version_mismatch';

  @override
  bool operator ==(Object other) =>
      other is SchemaVersionMismatch &&
      other.expected == expected &&
      other.found == found;

  @override
  int get hashCode => Object.hash(code, expected, found);
}

// ─────────────────────────────────────────────────────────────────────────
// Notification boundary (packages/notifications scheduler/gateway).
// ─────────────────────────────────────────────────────────────────────────

/// Failures raised while scheduling local notifications.
sealed class NotificationFailure extends Failure {
  const NotificationFailure();
}

/// A local-notification schedule/cancel call failed at the platform boundary
/// (the plugin threw). Wraps the plugin error so no plugin type leaks past the
/// notification module.
final class NotificationScheduleFailed extends NotificationFailure {
  const NotificationScheduleFailed();

  @override
  String get code => 'notif.schedule_failed';

  @override
  bool operator ==(Object other) => other is NotificationScheduleFailed;

  @override
  int get hashCode => code.hashCode;
}

/// The user denied the notification permission.
final class PermissionDenied extends NotificationFailure {
  const PermissionDenied();

  @override
  String get code => 'notif.permission_denied';

  @override
  bool operator ==(Object other) => other is PermissionDenied;

  @override
  int get hashCode => code.hashCode;
}

/// The user denied the exact-alarm permission (Android 13+).
final class ExactAlarmDenied extends NotificationFailure {
  const ExactAlarmDenied();

  @override
  String get code => 'notif.exact_alarm_denied';

  @override
  bool operator ==(Object other) => other is ExactAlarmDenied;

  @override
  int get hashCode => code.hashCode;
}

/// Scheduling would exceed iOS's silent 64-pending cap.
final class PendingCapExceeded extends NotificationFailure {
  const PendingCapExceeded(this.requested);

  final int requested;

  @override
  String get code => 'notif.pending_cap_exceeded';

  @override
  bool operator ==(Object other) =>
      other is PendingCapExceeded && other.requested == requested;

  @override
  int get hashCode => Object.hash(code, requested);
}

// ─────────────────────────────────────────────────────────────────────────
// Startup boundary (apps/car_and_pain bootstrap composition root).
// ─────────────────────────────────────────────────────────────────────────

/// Failures raised while async-initializing infrastructure at bootstrap.
///
/// These surface into a retry-capable error screen instead of crashing or
/// hanging silently before the first frame (F1-T7).
sealed class StartupFailure extends Failure {
  const StartupFailure();
}

/// The encrypted database could not be opened.
final class DatabaseOpenFailed extends StartupFailure {
  const DatabaseOpenFailed();

  @override
  String get code => 'startup.database_open_failed';

  @override
  bool operator ==(Object other) => other is DatabaseOpenFailed;

  @override
  int get hashCode => code.hashCode;
}

/// The secure key store could not be read.
final class KeyStoreUnavailable extends StartupFailure {
  const KeyStoreUnavailable();

  @override
  String get code => 'startup.key_store_unavailable';

  @override
  bool operator ==(Object other) => other is KeyStoreUnavailable;

  @override
  int get hashCode => code.hashCode;
}

/// The timezone database could not be initialized.
final class TimezoneInitFailed extends StartupFailure {
  const TimezoneInitFailed();

  @override
  String get code => 'startup.timezone_init_failed';

  @override
  bool operator ==(Object other) => other is TimezoneInitFailed;

  @override
  int get hashCode => code.hashCode;
}

/// The app's private directories could not be resolved.
final class AppDirsUnavailable extends StartupFailure {
  const AppDirsUnavailable();

  @override
  String get code => 'startup.app_dirs_unavailable';

  @override
  bool operator ==(Object other) => other is AppDirsUnavailable;

  @override
  int get hashCode => code.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────
// FX boundary (currency conversion with dated, user-entered rates).
// ─────────────────────────────────────────────────────────────────────────

/// Failures raised while converting between currencies.
sealed class FxFailure extends Failure {
  const FxFailure();
}

/// No user-entered rate exists for the requested currency pair (offline; rates
/// are never fetched). The UI prompts the user to enter one.
final class NoFxRate extends FxFailure {
  const NoFxRate({required this.from, required this.to});

  final String from;
  final String to;

  @override
  String get code => 'fx.no_rate';

  @override
  bool operator ==(Object other) =>
      other is NoFxRate && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(code, from, to);
}

// ─────────────────────────────────────────────────────────────────────────
// Compute boundary (Isolate.run / compute engines).
// ─────────────────────────────────────────────────────────────────────────

/// A heavy off-thread computation (TCO/analytics/import) failed.
final class ComputeFailure extends Failure {
  const ComputeFailure();

  @override
  String get code => 'compute.failed';

  @override
  bool operator ==(Object other) => other is ComputeFailure;

  @override
  int get hashCode => code.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────
// Validation boundary (parse/normalize form input).
// ─────────────────────────────────────────────────────────────────────────

/// One or more field-level validation errors, accumulated (not fail-fast).
///
/// [fieldErrors] is never empty for a real failure. See [FieldError].
final class ValidationFailure extends Failure {
  const ValidationFailure(this.fieldErrors);

  final List<FieldError> fieldErrors;

  @override
  String get code => 'validation.field_errors';

  @override
  bool operator ==(Object other) =>
      other is ValidationFailure && _listEquals(other.fieldErrors, fieldErrors);

  @override
  int get hashCode => Object.hashAll(fieldErrors);
}

// ─────────────────────────────────────────────────────────────────────────
// Catch-all.
// ─────────────────────────────────────────────────────────────────────────

/// A failure that does not fit any typed family — an escape hatch of last
/// resort. Prefer a specific family; every real boundary should map into one.
final class UnknownFailure extends Failure {
  const UnknownFailure([this.detail]);

  /// A non-localized diagnostic hint (never shown verbatim to the user).
  final String? detail;

  @override
  String get code => 'unknown';

  @override
  bool operator ==(Object other) =>
      other is UnknownFailure && other.detail == detail;

  @override
  int get hashCode => Object.hash(code, detail);
}

bool _listEquals<E>(List<E> a, List<E> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
