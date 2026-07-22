import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A one-shot holder for a cold-start deep-link location (M1-T6), seeded by
/// `bootstrap` from `getNotificationAppLaunchDetails` via `overrideWithValue`.
///
/// The router reads [location] for its `initialLocation` and the redirect
/// re-targets it once the gates clear; [take] consumes it so a later unlock
/// bounce doesn't re-navigate to the (stale) deep link. Defaults to empty.
class PendingDeepLink {
  PendingDeepLink([this.location]);

  String? location;

  /// Read and clear the pending location (single-use).
  String? take() {
    final value = location;
    location = null;
    return value;
  }
}

final pendingLocationProvider =
    Provider<PendingDeepLink>((ref) => PendingDeepLink());
