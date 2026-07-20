/// Car and Pain — `core`.
///
/// The single public entry point for the pure-Dart foundation: the sealed
/// `Result`/`Failure` kernel, the canonical value objects (`Money`, `Distance`,
/// `Volume`, `EngineHours`), the temporal types, and the `Clock` port.
///
/// Everything under `src/` is private by convention — import only this barrel.
library;

export 'src/money/currency.dart' show Currency;
export 'src/money/money.dart' show Money, RialTomanView;
export 'src/result/failures.dart'
    show
        AppDirsUnavailable,
        BackupFailure,
        BackupVerifyFailed,
        BackupWriteFailed,
        ComputeFailure,
        ConstraintViolation,
        CorruptArchive,
        DatabaseOpenFailed,
        DbFailure,
        DecryptFailed,
        ExactAlarmDenied,
        Failure,
        ImportFailure,
        KeyStoreUnavailable,
        NotFound,
        NotificationFailure,
        PendingCapExceeded,
        PermissionDenied,
        SchemaVersionMismatch,
        StartupFailure,
        TimezoneInitFailed,
        TransactionRolledBack,
        UnknownFailure,
        ValidationFailure;
export 'src/result/result.dart' show Err, Ok, Result, ResultX;
export 'src/result/validation.dart' show FieldError, Validation;
export 'src/time/clock.dart' show Clock, FixedClock, SystemClock;
export 'src/time/temporal.dart' show Instant, WallClockDateTime;
export 'src/units/distance.dart' show Distance;
export 'src/units/engine_hours.dart' show EngineHours;
export 'src/units/volume.dart' show Volume;
