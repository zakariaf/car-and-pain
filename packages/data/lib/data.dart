/// Car and Pain — `data`.
///
/// The single public entry point for the data layer: the encrypted Drift/
/// SQLCipher database, the isolate-safe open factory, the secure key store, the
/// repositories (emitting domain models with scoped `.watch()` streams), the
/// shared odometer ledger + rollups, soft-delete/trash, the custom taxonomy, and
/// the data-integrity validators. Zero network dependencies by construction.
library;

export 'src/db/app_database.dart' show AppDatabase;
export 'src/db/database_factory.dart' show openAppDatabase;
export 'src/db/migrations/snapshot_guard.dart' show SnapshotGuard;
export 'src/db/open_connection.dart'
    show ensureSqlCipherLoaded, openEncryptedExecutor;
export 'src/db/rekey.dart' show rekeyDatabaseFile;
export 'src/diagnostics/diagnostics_repository.dart'
    show AppDiagnosticsRepository, DiagnosticsRepository;
export 'src/domain/vehicle.dart' show Vehicle;
export 'src/infra/app_dirs.dart' show AppDirs;
export 'src/infra/app_time_zone.dart' show AppTimeZone;
export 'src/infra/secure_key_store.dart'
    show FakeSecureKeyStore, FlutterSecureKeyStore, SecureKeyStore;
export 'src/ledger/ledger_repository.dart' show LedgerRepository;
export 'src/notifications/notification_schedule_repository.dart'
    show NotificationScheduleRepository;
export 'src/providers.dart'
    show
        appDatabaseProvider,
        appDirsProvider,
        appTimeZoneProvider,
        diagnosticsRepositoryProvider,
        fuelRepositoryProvider,
        ledgerRepositoryProvider,
        notificationScheduleRepositoryProvider,
        secureKeyStoreProvider,
        settingsRepositoryProvider,
        taxonomyRepositoryProvider,
        trashRepositoryProvider,
        vehiclesRepositoryProvider;
export 'src/repositories/base_repository.dart' show BaseRepository, newId;
export 'src/repositories/fuel_repository.dart' show FuelRepository;
export 'src/repositories/rollup_service.dart'
    show RollupService, monthPeriodKey;
export 'src/repositories/vehicles_repository.dart' show VehiclesRepository;
export 'src/serialization/canonical_codec.dart' show CanonicalCodec;
export 'src/settings/settings_repository.dart' show SettingsRepository;
export 'src/taxonomy/taxonomy.dart' show Category, TaxonomyRepository;
export 'src/trash/trash_repository.dart' show TrashItem, TrashRepository;
export 'src/validation/validators.dart' show IntegrityValidators;
