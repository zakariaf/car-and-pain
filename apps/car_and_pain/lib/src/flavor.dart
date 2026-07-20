import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two build flavors. Flavors exist for **side-by-side install** and
/// **distinct notification channel ids / request-code ranges** — NOT for API
/// config (there is no backend). Never add a third `staging` flavor.
enum Flavor {
  dev('Car&Pain Dev', 'reminders_dev'),
  prod('Car & Pain', 'reminders_prod');

  const Flavor(this.displayName, this.notificationChannelId);

  /// User-visible app label per flavor.
  final String displayName;

  /// Distinct channel id so a dev build's reminders never collide with prod's.
  final String notificationChannelId;
}

/// Overridden at bootstrap with the compile-time flavor. Reading it before the
/// override is a clear error, never a silent default.
final flavorProvider = Provider<Flavor>(
  (ref) => throw UnimplementedError('override flavorProvider in bootstrap()'),
);
