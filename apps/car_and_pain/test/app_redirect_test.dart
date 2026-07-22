import 'package:car_and_pain/src/routing/app_locations.dart';
import 'package:car_and_pain/src/routing/app_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

RedirectInput _in({
  bool startupLoading = false,
  bool startupError = false,
  bool? locked = false,
  bool onboardingDone = true,
  bool hasVehicle = true,
  String location = AppLocations.cockpit,
  String? pendingLocation,
}) =>
    RedirectInput(
      startupLoading: startupLoading,
      startupError: startupError,
      locked: locked,
      onboardingDone: onboardingDone,
      hasVehicle: hasVehicle,
      location: location,
      pendingLocation: pendingLocation,
    );

void main() {
  group('appRedirect precedence', () {
    test('startup loading routes to splash', () {
      expect(appRedirect(_in(startupLoading: true)), AppLocations.splash);
    });

    test('startup error routes to the error screen', () {
      expect(appRedirect(_in(startupError: true)), AppLocations.startupError);
    });

    test('a locked (or still-resolving) app routes to lock', () {
      expect(appRedirect(_in(locked: true)), AppLocations.lock);
      expect(appRedirect(_in(locked: null)), AppLocations.lock); // resolving
    });

    test('first run (no vehicle, onboarding not done) routes to onboarding',
        () {
      expect(appRedirect(_in(onboardingDone: false, hasVehicle: false)),
          AppLocations.onboarding);
    });

    test('a ready + unlocked + onboarded session stays put', () {
      expect(appRedirect(_in(location: AppLocations.garage)), isNull);
    });

    test('a fully-passed session parked on a gate route goes home', () {
      // Everything passed (unlocked, onboarded) but sitting on a gate route →
      // sent to the Cockpit home.
      expect(appRedirect(_in(location: AppLocations.splash)),
          AppLocations.cockpit);
      expect(
          appRedirect(_in(location: AppLocations.lock)), AppLocations.cockpit);
    });

    test('is idempotent — each step excludes its own target (no loop)', () {
      expect(
          appRedirect(_in(startupLoading: true, location: AppLocations.splash)),
          isNull);
      expect(
          appRedirect(
              _in(startupError: true, location: AppLocations.startupError)),
          isNull);
      expect(
          appRedirect(_in(locked: true, location: AppLocations.lock)), isNull);
      expect(
          appRedirect(_in(
              onboardingDone: false,
              hasVehicle: false,
              location: AppLocations.onboarding)),
          isNull);
    });

    test('having a vehicle skips onboarding even if the flag is unset', () {
      // hasVehicle defaults true; only onboardingDone is toggled off here.
      expect(appRedirect(_in(onboardingDone: false)), isNull);
    });

    test('a pending deep link wins over home when a gate route clears', () {
      // The cold-start deep link survives the splash bounce (M1-T6): clearing
      // the splash gate targets the pending location, not the Cockpit.
      expect(
        appRedirect(_in(
          location: AppLocations.splash,
          pendingLocation: '/garage/v1/reminders/r7',
        )),
        '/garage/v1/reminders/r7',
      );
    });

    test('a pending deep link never overrides an active gate', () {
      // While still locked, the lock gate wins — the deep link waits.
      expect(
        appRedirect(_in(
          locked: true,
          pendingLocation: '/garage/v1/reminders/r7',
        )),
        AppLocations.lock,
      );
    });

    test('a pending gate-location deep link is ignored (falls back home)', () {
      // Defensive: a pending value that is itself a gate route can never be a
      // deep-link destination — home wins.
      expect(
        appRedirect(_in(
          location: AppLocations.splash,
          pendingLocation: AppLocations.lock,
        )),
        AppLocations.cockpit,
      );
    });
  });
}
