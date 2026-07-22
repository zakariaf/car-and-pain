import 'dart:async';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'flavor.dart';
import 'logging/app_log.dart';
import 'notifications/notification_providers.dart';
import 'notifications/notification_reconciler.dart';
import 'notifications/notification_service.dart';
import 'routing/deep_link_listener.dart';
import 'routing/notification_deep_link.dart';
import 'routing/pending_location.dart';
import 'security/app_lock_lifecycle.dart';
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
  registerFontLicenses(); // surface bundled OFL fonts on the licenses page
  const log = AppLog();

  // Initialize the OS notification plugin + per-severity channels once (F5-T1);
  // a failure degrades to no notifications, never a crashed startup.
  final notifications = NotificationService();
  final notifInit = await notifications.init();
  if (notifInit case Err(:final failure)) {
    log.error('notifications.init', failure, StackTrace.current);
  }

  // If a notification cold-launched the app, seed the router's initial location
  // with its (validated) deep-link target so it lands there once the gates clear
  // (M1-T6). A normal launch or a malformed payload leaves this null.
  final launchLocation =
      mapNotificationPayload(await notifications.launchPayload());

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
          notificationServiceProvider.overrideWithValue(notifications),
          if (launchLocation != null)
            pendingLocationProvider.overrideWithValue(launchLocation),
          // Wire the resolved infrastructure into the placeholder `data`
          // providers. Read only after the startup gate reaches its ready
          // state (the shell mounts after AsyncData(Ok)).
          appDatabaseProvider.overrideWith((ref) => _infra(ref).database),
          secureKeyStoreProvider.overrideWith((ref) => _infra(ref).keyStore),
          appDirsProvider.overrideWith((ref) => _infra(ref).dirs),
          appTimeZoneProvider.overrideWith((ref) => _infra(ref).timeZone),
        ],
        // The lock lifecycle observer and deep-link listener live for the whole
        // session, above the router but under the scope (M1-T1/T6).
        child: const AppLockLifecycleObserver(
          child: DeepLinkListener(
            child: NotificationReconciler(child: CarAndPainApp()),
          ),
        ),
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
