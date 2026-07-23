import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../attachments/storage_settings_screen.dart';
import '../backup/backup_recovery_screen.dart';
import '../backup/recovery_redeem_screen.dart';
import '../features/18-data-offline-backup/presentation/trash_screen.dart';
import '../gallery/pulse_gallery.dart';
import '../security/app_lock_controller.dart';
import '../security/app_lock_screen.dart';
import '../security/security_settings_screen.dart';
import '../settings/locale_controller.dart';
import '../settings/settings_screen.dart';
import '../shell/cockpit_screen.dart';
import '../shell/garage_screen.dart';
import '../shell/pitlane_screen.dart';
import '../shell/rooms_shell.dart';
import '../shell/shell_placeholders.dart';
import '../shell/shell_state.dart';
import '../startup/splash_screen.dart';
import '../startup/startup_controller.dart';
import '../startup/startup_error_screen.dart';
import 'app_locations.dart';
import 'app_redirect.dart';
import 'pending_location.dart';
import 'router_refresh.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _cockpitKey = GlobalKey<NavigatorState>(debugLabel: 'cockpit');
final _garageKey = GlobalKey<NavigatorState>(debugLabel: 'garage');
final _pitlaneKey = GlobalKey<NavigatorState>(debugLabel: 'pitlane');

/// The **single** GoRouter (invariant: go_router only). One
/// `StatefulShellRoute.indexedStack` over the three PULSE Rooms, full-screen
/// gate + flows above via `rootNavigatorKey`, `restorationScopeId`, and a
/// four-signal `refreshListenable` driving the pure [appRedirect] (startup →
/// error → lock → onboarding → home). The Provider is stable — it reads gate
/// state via `ref.read` inside the redirect, so it never rebuilds and never
/// loses nav state.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation:
        ref.read(pendingLocationProvider).location ?? AppLocations.cockpit,
    restorationScopeId: 'app_router',
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoomsShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _cockpitKey,
            routes: [
              GoRoute(
                path: AppLocations.cockpit,
                builder: (context, state) => const CockpitScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _garageKey,
            routes: [
              GoRoute(
                path: AppLocations.garage,
                builder: (context, state) => const GarageScreen(),
                routes: [
                  GoRoute(
                    path: ':vehicleId',
                    builder: (context, state) => VehicleDetailScreen(
                      vehicleId: state.pathParameters['vehicleId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'reminders/:reminderId',
                        builder: (context, state) => ReminderDetailScreen(
                          vehicleId: state.pathParameters['vehicleId']!,
                          reminderId: state.pathParameters['reminderId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _pitlaneKey,
            routes: [
              GoRoute(
                path: AppLocations.pitlane,
                builder: (context, state) => const PitlaneScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen gate flows (above the shell, on the root navigator) ─────
      GoRoute(
        path: AppLocations.splash,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppLocations.startupError,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const _StartupErrorRoute(),
      ),
      GoRoute(
        path: AppLocations.lock,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const AppLockScreen(),
      ),
      GoRoute(
        path: AppLocations.onboarding,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ── Full-screen feature flows (above the shell) ────────────────────────
      GoRoute(
        path: '/trash',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const TrashScreen(),
      ),
      GoRoute(
        path: '/gallery',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const PulseGallery(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/security',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SecuritySettingsScreen(),
      ),
      GoRoute(
        path: '/settings/storage',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const StorageSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/backup',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const BackupRecoveryScreen(),
      ),
      GoRoute(
        path: '/settings/recovery',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const RecoveryRedeemScreen(),
      ),
    ],
  );
});

/// Gather the gate booleans from providers and delegate the DECISION to the pure
/// [appRedirect]. DB-backed providers (lock/onboarding/vehicles) are read ONLY
/// after startup proves ready — reading them earlier would hit the placeholder
/// providers' `UnimplementedError`.
String? _redirect(Ref ref, String location) {
  final startup = ref.read(startupControllerProvider);
  final result = startup.asData?.value;
  final ready = result?.isOk ?? false;
  final error = startup.hasError || (result?.isErr ?? false);

  final pending = ref.read(pendingLocationProvider);
  final target = appRedirect(RedirectInput(
    startupLoading: startup.isLoading,
    startupError: error,
    locked:
        ready ? ref.read(appLockControllerProvider).asData?.value.locked : true,
    onboardingDone: ready &&
        (ref.read(settingsMapProvider).asData?.value ??
                const <String, String>{})[SettingsKeys.onboardingComplete] ==
            'true',
    hasVehicle: ready && ref.read(activeVehiclesProvider).isNotEmpty,
    location: location,
    pendingLocation: pending.location,
  ));

  // The lock gate is about to cover a real (non-gate) location — remember it so
  // unlock returns the user to their place instead of dumping them at the
  // Cockpit. A cold-start deep link (already pending) is never clobbered.
  if (target == AppLocations.lock &&
      pending.location == null &&
      !AppLocations.gateLocations.contains(location)) {
    pending.location = location;
  }

  // Consume the pending target once we've arrived at it — either the redirect
  // is sending us there now, or we're already sitting on it with nothing more
  // to do — so a later lock/unlock bounce never re-navigates to a stale target.
  if (pending.location != null &&
      (target == pending.location ||
          (target == null && location == pending.location))) {
    pending.take();
  }
  return target;
}

/// The startup-error surface as a route — it reads its typed failure from the
/// startup controller (a route can't restore `extra` after a cold start).
class _StartupErrorRoute extends ConsumerWidget {
  const _StartupErrorRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(startupControllerProvider).asData?.value;
    final failure = switch (result) {
      Err(:final failure) => failure,
      _ => const UnknownFailure(),
    };
    return StartupErrorScreen(
      failure: failure,
      onRetry: () => ref.invalidate(startupControllerProvider),
    );
  }
}
