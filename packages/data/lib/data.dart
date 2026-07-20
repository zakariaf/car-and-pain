/// Car and Pain — `data`.
///
/// The single public entry point for the data layer. For F1 this exposes the
/// placeholder root infra providers (overridden at bootstrap) and the DI seam;
/// the encrypted Drift/SQLCipher database, DAOs, repositories, ledger/rollups,
/// and backup engine arrive in F2+.
library;

export 'src/diagnostics/diagnostics_repository.dart'
    show AppDiagnosticsRepository, DiagnosticsRepository;
export 'src/infra/app_database.dart' show AppDatabase, PlaceholderAppDatabase;
export 'src/infra/app_dirs.dart' show AppDirs;
export 'src/infra/app_time_zone.dart' show AppTimeZone;
export 'src/infra/secure_key_store.dart'
    show PlaceholderSecureKeyStore, SecureKeyStore;
export 'src/providers.dart'
    show
        appDatabaseProvider,
        appDirsProvider,
        appTimeZoneProvider,
        diagnosticsRepositoryProvider,
        secureKeyStoreProvider;
