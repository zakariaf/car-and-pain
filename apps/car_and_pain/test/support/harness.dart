import 'package:car_and_pain/src/app.dart';
import 'package:car_and_pain/src/flavor.dart';
import 'package:car_and_pain/src/notifications/notification_providers.dart';
import 'package:car_and_pain/src/routing/deep_link_listener.dart';
import 'package:car_and_pain/src/routing/pending_location.dart';
import 'package:car_and_pain/src/security/biometric_authenticator.dart';
import 'package:car_and_pain/src/security/security_providers.dart';
import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:car_and_pain/src/shell/shell_state.dart';
import 'package:car_and_pain/src/startup/app_infra.dart';
import 'package:car_and_pain/src/startup/startup_initializer.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:security/security.dart';

const _dirs = AppDirs(
  supportDir: '/t',
  dbPath: '/t/app.db',
  backupsDir: '/t/backups',
  attachmentsDir: '/t/attachments',
);

/// A ready [AppInfra] built from an in-memory DB + fake key store — no plugins.
AppInfra fakeInfra() => AppInfra(
      dirs: _dirs,
      timeZone: const AppTimeZone('UTC'),
      database: AppDatabase.memory(),
      keyStore: const FakeSecureKeyStore(),
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
/// Pass [secureStore] pre-seeded to exercise the app-lock gate.
Widget testApp(
  StartupInitializer initializer, {
  AppDatabase? database,
  SecureStore? secureStore,
  List<Vehicle> vehicles = const [],
  Map<String, String> settings = const {},
  bool reduceMotion = false,
  String? pendingLocation,
  Stream<String?>? deepLinkTaps,
}) {
  return ProviderScope(
    overrides: [
      flavorProvider.overrideWithValue(Flavor.dev),
      startupInitializerProvider.overrideWithValue(initializer),
      if (pendingLocation != null)
        pendingLocationProvider
            .overrideWithValue(PendingDeepLink(pendingLocation)),
      // Warm-app notification taps are fed off a controllable stream so the
      // deep-link path is drivable without the OS plugin.
      if (deepLinkTaps != null)
        notificationTapProvider.overrideWith((ref) => deepLinkTaps),
      appDatabaseProvider.overrideWithValue(database ?? AppDatabase.memory()),
      secureKeyStoreProvider.overrideWithValue(const FakeSecureKeyStore()),
      appDirsProvider.overrideWithValue(_dirs),
      appTimeZoneProvider.overrideWithValue(const AppTimeZone('UTC')),
      // Security stack over an in-memory store (no Keychain/Keystore plugin):
      // with no PIN configured the app-lock gate resolves straight to unlocked.
      secureStoreProvider
          .overrideWithValue(secureStore ?? InMemorySecureStore()),
      // A no-hardware biometric fake so the gate never reaches the local_auth
      // plugin channel (which would make resolution non-deterministic in tests).
      biometricAuthenticatorProvider.overrideWithValue(const _NoBiometric()),
      // Feed localization + the vehicle list off synchronous fixed streams so
      // widget tests don't open a Drift .watch() (which leaves a pending timer
      // at teardown). The router redirect and shell read these directly.
      // `settings` drives locale/scope/onboarding-complete deterministically.
      settingsMapProvider.overrideWith((ref) => Stream.value(settings)),
      vehiclesStreamProvider.overrideWith((ref) => Stream.value(vehicles)),
    ],
    // Force the app-level reduce-motion preference on for deterministic pumps
    // of the breathing hero (which otherwise repeats forever → pumpAndSettle
    // never returns). The scope sits above MaterialApp but inherited widgets
    // still reach every descendant.
    child: ReducedMotionScope(
      reduce: reduceMotion,
      child: deepLinkTaps == null
          ? const CarAndPainApp()
          : const DeepLinkListener(child: CarAndPainApp()),
    ),
  );
}

/// A biometric authenticator that reports no hardware — keeps widget tests off
/// the `local_auth` platform channel.
class _NoBiometric implements BiometricAuthenticator {
  const _NoBiometric();
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<BiometricOutcome> authenticate({required String reason}) async =>
      BiometricOutcome.unavailable;
}
