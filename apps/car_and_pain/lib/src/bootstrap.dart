import 'dart:async';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'flavor.dart';
import 'logging/app_log.dart';
import 'startup/app_infra.dart';
import 'startup/startup_controller.dart';

/// The shared composition root. Both flavor entrypoints call this.
///
/// Installs the global error trio (all local, never a crash SaaS), then runs the
/// app inside a guarded zone. The async infra (DB, key store, dirs, timezone) is
/// resolved by the startup gate in the widget tree; once it succeeds, the
/// placeholder `data` providers are overridden to read the resolved instances —
/// so a startup failure surfaces as a retry screen, never a crash before the
/// first frame.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  const log = AppLog();

  // Sync framework errors — keep the console/red-screen in debug, log locally.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    log.error('flutter', details.exception, details.stack ?? StackTrace.empty);
  };

  // Async / platform-channel errors NOT caught by FlutterError.onError.
  PlatformDispatcher.instance.onError = (error, stack) {
    log.error('platform', error, stack);
    return true;
  };

  runZonedGuarded(
    () => runApp(
      ProviderScope(
        overrides: [
          flavorProvider.overrideWithValue(flavor),
          // Wire the resolved infrastructure into the placeholder `data`
          // providers. Read only after the startup gate reaches its ready
          // state (the shell mounts after AsyncData(Ok)).
          appDatabaseProvider.overrideWith((ref) => _infra(ref).database),
          secureKeyStoreProvider.overrideWith((ref) => _infra(ref).keyStore),
          appDirsProvider.overrideWith((ref) => _infra(ref).dirs),
          appTimeZoneProvider.overrideWith((ref) => _infra(ref).timeZone),
        ],
        child: const CarAndPainApp(),
      ),
    ),
    (error, stack) => log.error('zone', error, stack),
  );
}

AppInfra _infra(Ref ref) {
  final result = ref.watch(startupControllerProvider).requireValue;
  return switch (result) {
    Ok(:final value) => value,
    Err() => throw StateError('infra read before startup succeeded'),
  };
}
