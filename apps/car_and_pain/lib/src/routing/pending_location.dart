import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A deep-link location captured from a cold-start notification tap (M1-T6),
/// seeded by `bootstrap` from `getNotificationAppLaunchDetails` via an
/// `overrideWithValue`. The router's `initialLocation` reads it so a
/// notification cold-start lands on its target even while the redirect bounces
/// through `/splash` and `/lock` first. Defaults to `null` (no deep link).
final pendingLocationProvider = Provider<String?>((ref) => null);
