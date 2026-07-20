import 'dart:developer' as developer;
import 'dart:typed_data';

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

    // 3. Secure key store → the raw 256-bit DB key (F7 hardens recovery).
    final keyStore = FlutterSecureKeyStore();
    final Uint8List key;
    try {
      key = await keyStore.readAndUnwrapDbKey();
    } on Object catch (e, st) {
      developer.log('startup.key_store', error: e, stackTrace: st);
      return const Err(KeyStoreUnavailable());
    }

    // 4. Open the encrypted Drift/SQLCipher database and force the connection
    //    (a lazy open would defer the cipher assertion past the first frame).
    final AppDatabase database;
    try {
      database = await openAppDatabase(key: key, dbPath: dirs.dbPath);
      await database.customSelect('SELECT 1').get();
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
