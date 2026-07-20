import 'dart:developer' as developer;

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../flavor.dart';
import 'app_infra.dart';

/// Async-initializes the app's infrastructure at startup, returning a typed
/// [Result] rather than throwing across the boundary. Overridable in tests to
/// force the ready and error paths.
abstract interface class StartupInitializer {
  Future<Result<AppInfra, StartupFailure>> initialize(Flavor flavor);
}

/// The production initializer. Each step maps any exception to a typed
/// [StartupFailure] (logged locally first) so bootstrap never crashes or hangs.
///
/// F1 resolves real app directories and opens **placeholder** infra; the real
/// SQLCipher DB (F2), device timezone (F5), and recoverable key (F7) slot in
/// behind the same seam.
class AppStartupInitializer implements StartupInitializer {
  const AppStartupInitializer();

  @override
  Future<Result<AppInfra, StartupFailure>> initialize(Flavor flavor) async {
    // 1. App-private directories, flavor-scoped so dev never touches prod data.
    final AppDirs dirs;
    try {
      final support = await getApplicationSupportDirectory();
      final dbName = 'car_and_pain_${flavor.name}.db';
      dirs = AppDirs(
        supportDir: support.path,
        dbPath: '${support.path}/$dbName',
        backupsDir: '${support.path}/backups',
        attachmentsDir: '${support.path}/attachments',
      );
    } on Object catch (e, st) {
      developer.log('startup.app_dirs', error: e, stackTrace: st);
      return const Err(AppDirsUnavailable());
    }

    // 2. Timezone. TODO(F5): query the device zone + init the timezone database.
    const timeZone = AppTimeZone('UTC');

    // 3. Secure key store (recoverable master key). TODO(F7).
    final SecureKeyStore keyStore;
    try {
      keyStore = const PlaceholderSecureKeyStore();
      await keyStore.readAndUnwrapDbKey();
    } on Object catch (e, st) {
      developer.log('startup.key_store', error: e, stackTrace: st);
      return const Err(KeyStoreUnavailable());
    }

    // 4. Encrypted database. TODO(F2): open the real Drift/SQLCipher database.
    final AppDatabase database;
    try {
      database = PlaceholderAppDatabase(dirs.dbPath);
    } on Object catch (e, st) {
      developer.log('startup.database', error: e, stackTrace: st);
      return const Err(DatabaseOpenFailed());
    }

    return Ok(
      AppInfra(
        dirs: dirs,
        timeZone: timeZone,
        database: database,
        keyStore: keyStore,
      ),
    );
  }
}

/// The initializer used at runtime — overridden in tests to inject a fake that
/// returns `Ok`/`Err` on demand.
final startupInitializerProvider = Provider<StartupInitializer>(
  (ref) => const AppStartupInitializer(),
);
