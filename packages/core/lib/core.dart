/// Car and Pain — `core`.
///
/// The single public entry point for the pure-Dart foundation: the sealed
/// `Result`/`Failure` kernel, the canonical value objects (`Money`, `Distance`,
/// `Volume`, `EngineHours`), the temporal types, and the `Clock` port.
///
/// Everything under `src/` is private by convention — import only this barrel.
library;

export 'src/dashboard/readiness.dart'
    show
        AcuteAche,
        ReadinessSummary,
        ReminderDue,
        aggregateReadiness,
        urgencyForDue;
export 'src/energy/economy_engine.dart'
    show ConsumptionInterval, EconomyEngine, EconomyReport, EnergyFill;
export 'src/energy/economy_units.dart'
    show
        EconomyMode,
        kmPerLitre,
        kwhPer100km,
        litresPer100km,
        miPerKwh,
        mpgUk,
        mpgUs,
        projectElectric,
        projectLiquid,
        whPerKm;
export 'src/energy/energy_calc.dart' show FillAmounts, completeFill;
export 'src/energy/ev_calc.dart'
    show
        blendedCostPerMetre,
        breakEvenMonths,
        chargeCostMinor,
        energyFromSocJoules,
        wallEnergyJoules;
export 'src/energy/fuel_projection.dart'
    show fuelRangeMetres, nextFillOdometreMetres, risingConsumptionAnomaly;
export 'src/energy/price_memory.dart' show PriceMemory, PriceObservation;
export 'src/finance/amortization.dart'
    show
        AmortizationEngine,
        AmortizationRow,
        AmortizationSchedule,
        FinancingKind,
        LoanTerms,
        PayoffQuote;
export 'src/finance/budget.dart' show BudgetEngine, BudgetPeriod, BudgetStatus;
export 'src/finance/cost_validation.dart' show CostValidators, ExpenseKey;
export 'src/finance/depreciation.dart'
    show DepreciationCurve, DepreciationMethod, EquityPosition;
export 'src/finance/recurring_bill.dart' show LumpAmortizer, RecurringBill;
export 'src/finance/tco.dart' show TcoCostItem, TcoEngine, TcoReport;
export 'src/ledger/ledger.dart' show LedgerEngine, LedgerReading, LedgerSource;
export 'src/money/currency.dart' show Currency;
export 'src/money/fx.dart'
    show FxConverter, FxRate, FxStaleness, FxTable, RoundingMode;
export 'src/money/money.dart' show Money, RialTomanView;
export 'src/result/failures.dart'
    show
        AppDirsUnavailable,
        AttachmentChecksumMismatch,
        AttachmentFailure,
        BackupFailure,
        BackupVerifyFailed,
        BackupWriteFailed,
        BlobIoFailed,
        BlobNotFound,
        ComputeFailure,
        ConstraintViolation,
        CorruptArchive,
        DatabaseOpenFailed,
        DbFailure,
        DecryptFailed,
        EnvelopeCorrupt,
        ExactAlarmDenied,
        Failure,
        FxFailure,
        ImportFailure,
        KeyStoreUnavailable,
        MediaProcessingFailed,
        NoFxRate,
        NotFound,
        NotificationFailure,
        NotificationScheduleFailed,
        PendingCapExceeded,
        PermissionDenied,
        SchemaVersionMismatch,
        SecureStorageFailed,
        SecurityFailure,
        StartupFailure,
        TimezoneInitFailed,
        TransactionRolledBack,
        UnknownFailure,
        UnlockThrottled,
        UnsupportedMediaType,
        ValidationFailure,
        WrongBackupPassphrase,
        WrongSecret;
export 'src/result/result.dart' show Err, Ok, Result, ResultX;
export 'src/result/validation.dart' show FieldError, Validation;
export 'src/scheduling/ics_export.dart'
    show IcsAppointment, IcsEvent, buildAppointmentIcs, buildIcsCalendar;
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
export 'src/scheduling/scheduled_notification.dart'
    show ReminderScheduleDef, ScheduledNotification;
export 'src/service/schedule_template.dart'
    show
        AppliedScheduleItem,
        ScheduleProfile,
        ScheduleTemplate,
        ScheduleTemplateEntry,
        applyScheduleTemplate;
export 'src/service/service_cost.dart'
    show
        RunningCost,
        ServiceCostEngine,
        ServiceCostPoint,
        ServiceLineItemCost,
        VisitCost;
export 'src/service/service_schedule.dart'
    show
        ServiceDueLevel,
        ServiceDueStatus,
        ServiceEvent,
        ServiceInterval,
        ServiceIntervalLogic,
        ServiceScheduleEngine;
export 'src/time/clock.dart' show Clock, FixedClock, SystemClock;
export 'src/time/temporal.dart' show Instant, WallClockDateTime;
export 'src/units/byte_size.dart' show ByteSize, ByteSizeUnit;
export 'src/units/distance.dart' show Distance, DistanceUnit;
export 'src/units/energy.dart' show Energy, EnergyUnit;
export 'src/units/engine_hours.dart' show EngineHours;
export 'src/units/pressure.dart' show Pressure, PressureUnit;
export 'src/units/temperature.dart' show Temperature, TemperatureUnit;
export 'src/units/unit_preference.dart' show UnitPreferences, resolveUnit;
export 'src/units/volume.dart' show Volume, VolumeUnit;
export 'src/vehicle/powertrain.dart'
    show EnergyType, PowertrainProfile, VehicleField, VehicleType;
export 'src/vin/vin_decoder.dart' show VinDecodeResult, VinDecoder, VinRegion;
