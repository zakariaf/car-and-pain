/// Car and Pain — `core`.
///
/// The single public entry point for the pure-Dart foundation: the sealed
/// `Result`/`Failure` kernel, the canonical value objects (`Money`, `Distance`,
/// `Volume`, `EngineHours`), the temporal types, and the `Clock` port.
///
/// Everything under `src/` is private by convention — import only this barrel.
library;

export 'src/ledger/ledger.dart' show LedgerEngine, LedgerReading, LedgerSource;
export 'src/money/currency.dart' show Currency;
export 'src/money/fx.dart'
    show FxConverter, FxRate, FxStaleness, FxTable, RoundingMode;
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
        FxFailure,
        ImportFailure,
        KeyStoreUnavailable,
        NoFxRate,
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
export 'src/scheduling/next_due_engine.dart' show NextDueEngine;
export 'src/scheduling/schedule_rule.dart'
    show
        Due,
        DueConfidence,
        DueResult,
        InsufficientData,
        NextDue,
        NoDue,
        QuietHours,
        Recurrence,
        RecurrenceUnit,
        ScheduleRule,
        TriggerKind;
export 'src/time/clock.dart' show Clock, FixedClock, SystemClock;
export 'src/time/temporal.dart' show Instant, WallClockDateTime;
export 'src/units/distance.dart' show Distance, DistanceUnit;
export 'src/units/energy.dart' show Energy, EnergyUnit;
export 'src/units/engine_hours.dart' show EngineHours;
export 'src/units/pressure.dart' show Pressure, PressureUnit;
export 'src/units/temperature.dart' show Temperature, TemperatureUnit;
export 'src/units/unit_preference.dart' show UnitPreferences, resolveUnit;
export 'src/units/volume.dart' show Volume, VolumeUnit;
