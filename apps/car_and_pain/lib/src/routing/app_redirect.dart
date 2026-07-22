import 'app_locations.dart';

/// The boolean state the redirect decides over (M1-T1). Gathered from providers
/// by the router; the DECISION is this pure, table-tested function.
class RedirectInput {
  const RedirectInput({
    required this.startupLoading,
    required this.startupError,
    required this.locked,
    required this.onboardingDone,
    required this.hasVehicle,
    required this.location,
  });

  final bool startupLoading;
  final bool startupError;

  /// The app-lock state: null while resolving (treated as still-locked so no
  /// protected content ever paints before the lock decides).
  final bool? locked;

  final bool onboardingDone;
  final bool hasVehicle;
  final String location;
}

/// The pure, idempotent redirect precedence (M1-T1): startup → error → lock →
/// onboarding → home. Each step EXCLUDES its own target (returns null when
/// already there) so there is never an infinite redirect loop. Returns the
/// location to redirect to, or null to stay.
String? appRedirect(RedirectInput input) {
  if (input.startupLoading) return _to(input.location, AppLocations.splash);
  if (input.startupError) {
    return _to(input.location, AppLocations.startupError);
  }
  // App-lock gate — a null (still-resolving) lock is treated as locked.
  if (input.locked ?? true) return _to(input.location, AppLocations.lock);
  // First run: no vehicle and onboarding not yet completed → onboarding.
  if (!input.onboardingDone && !input.hasVehicle) {
    return _to(input.location, AppLocations.onboarding);
  }
  // Everything passed. If we're parked on a gate route, go home.
  if (AppLocations.gateLocations.contains(input.location)) {
    return AppLocations.cockpit;
  }
  return null;
}

String? _to(String location, String target) =>
    location == target ? null : target;
