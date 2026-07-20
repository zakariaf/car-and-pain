import 'package:car_and_pain/src/app.dart';
import 'package:car_and_pain/src/flavor.dart';
import 'package:car_and_pain/src/startup/app_infra.dart';
import 'package:car_and_pain/src/startup/startup_initializer.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _dirs = AppDirs(
  supportDir: '/t',
  dbPath: '/t/app.db',
  backupsDir: '/t/backups',
  attachmentsDir: '/t/attachments',
);

/// A ready [AppInfra] built from placeholder infra — no plugins needed in tests.
AppInfra fakeInfra() => const AppInfra(
      dirs: _dirs,
      timeZone: AppTimeZone('UTC'),
      database: PlaceholderAppDatabase('/t/app.db'),
      keyStore: PlaceholderSecureKeyStore(),
    );

/// A fake initializer returning a fixed result — drives the ready and error
/// startup paths deterministically. Mutate [result] to simulate a retry.
class FakeStartupInitializer implements StartupInitializer {
  FakeStartupInitializer(this.result);

  Result<AppInfra, StartupFailure> result;
  int calls = 0;

  @override
  Future<Result<AppInfra, StartupFailure>> initialize(Flavor flavor) async {
    calls++;
    return result;
  }
}

/// Wraps the real [CarAndPainApp] with deterministic infra + a fake startup
/// initializer, so widget tests drive the whole shell without touching plugins.
Widget testApp(StartupInitializer initializer, {AppDatabase? database}) {
  return ProviderScope(
    overrides: [
      flavorProvider.overrideWithValue(Flavor.dev),
      startupInitializerProvider.overrideWithValue(initializer),
      appDatabaseProvider.overrideWithValue(
        database ?? const PlaceholderAppDatabase('/t/app.db'),
      ),
      secureKeyStoreProvider.overrideWithValue(
        const PlaceholderSecureKeyStore(),
      ),
      appDirsProvider.overrideWithValue(_dirs),
      appTimeZoneProvider.overrideWithValue(const AppTimeZone('UTC')),
    ],
    child: const CarAndPainApp(),
  );
}
