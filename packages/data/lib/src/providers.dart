import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/app_database.dart';
import 'diagnostics/diagnostics_repository.dart';
import 'infra/app_dirs.dart';
import 'infra/app_time_zone.dart';
import 'infra/secure_key_store.dart';
import 'ledger/ledger_repository.dart';
import 'repositories/fuel_repository.dart';
import 'repositories/vehicles_repository.dart';
import 'settings/settings_repository.dart';
import 'taxonomy/taxonomy.dart';
import 'trash/trash_repository.dart';

/// Placeholder root providers for async-initialized infrastructure.
///
/// Each throws until it is **overridden with a real instance in the
/// `ProviderScope` at bootstrap** (`main()`/`bootstrap.dart`). This is the
/// canonical Riverpod pattern for injecting things that require async
/// construction, and it doubles as the per-test override seam. Reading one
/// before bootstrap overrides it is a clear, immediate error — never a silent
/// null or a global singleton.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) =>
      throw UnimplementedError('override appDatabaseProvider in bootstrap()'),
);

final secureKeyStoreProvider = Provider<SecureKeyStore>(
  (ref) => throw UnimplementedError(
      'override secureKeyStoreProvider in bootstrap()'),
);

final appDirsProvider = Provider<AppDirs>(
  (ref) => throw UnimplementedError('override appDirsProvider in bootstrap()'),
);

final appTimeZoneProvider = Provider<AppTimeZone>(
  (ref) =>
      throw UnimplementedError('override appTimeZoneProvider in bootstrap()'),
);

/// A sample repository provider that consumes [appDatabaseProvider] **purely
/// through DI** — no globals, no service-locator. Proves the wiring end-to-end
/// in F1 and is the template every real repository provider follows in F2.
final diagnosticsRepositoryProvider = Provider<DiagnosticsRepository>(
  (ref) => AppDiagnosticsRepository(ref.watch(appDatabaseProvider)),
);

// ── Feature repositories (keepAlive by default via plain Provider) ──────────
final vehiclesRepositoryProvider = Provider<VehiclesRepository>(
  (ref) => VehiclesRepository(ref.watch(appDatabaseProvider)),
);

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(ref.watch(appDatabaseProvider)),
);

final fuelRepositoryProvider = Provider<FuelRepository>(
  (ref) => FuelRepository(ref.watch(appDatabaseProvider)),
);

final trashRepositoryProvider = Provider<TrashRepository>(
  (ref) => TrashRepository(ref.watch(appDatabaseProvider)),
);

final taxonomyRepositoryProvider = Provider<TaxonomyRepository>(
  (ref) => TaxonomyRepository(ref.watch(appDatabaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);
