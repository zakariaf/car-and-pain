/// Car and Pain — `data`.
///
/// The single public entry point for the data layer: the encrypted Drift/
/// SQLCipher database, the isolate-safe open factory, the secure key store, the
/// DI seam, and (as F2 fleshes out) repositories, trash, taxonomy, and rollups.
/// Zero network dependencies by construction.
library;

export 'src/db/app_database.dart' show AppDatabase;
export 'src/db/database_factory.dart' show openAppDatabase;
export 'src/db/migrations/snapshot_guard.dart' show SnapshotGuard;
export 'src/db/open_connection.dart'
    show ensureSqlCipherLoaded, openEncryptedExecutor;
export 'src/diagnostics/diagnostics_repository.dart'
    show AppDiagnosticsRepository, DiagnosticsRepository;
export 'src/infra/app_dirs.dart' show AppDirs;
export 'src/infra/app_time_zone.dart' show AppTimeZone;
export 'src/infra/secure_key_store.dart'
    show FakeSecureKeyStore, FlutterSecureKeyStore, SecureKeyStore;
export 'src/providers.dart'
    show
        appDatabaseProvider,
        appDirsProvider,
        appTimeZoneProvider,
        diagnosticsRepositoryProvider,
        secureKeyStoreProvider;
