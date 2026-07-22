import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notification_providers.dart';
import 'app_router.dart';
import 'notification_deep_link.dart';
import 'pending_location.dart';

/// Routes notification taps that arrive **while the app is alive** (M1-T6).
///
/// Watches [notificationTapProvider]; each tapped payload is validated by the
/// pure [mapNotificationPayload] and, if safe, routed through the **same gated
/// path as a cold-start deep link**: it is seeded as the pending location
/// *before* navigating, so the router redirect owns lock enforcement. If the
/// app is (or is re-locking on resume) locked, the redirect covers the target
/// with `/lock` and the pending link is applied only after the user unlocks —
/// never bypassing the lock, never silently lost. Mounted once around the app.
class DeepLinkListener extends ConsumerWidget {
  const DeepLinkListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationTapProvider, (_, next) {
      final location = mapNotificationPayload(next.asData?.value);
      if (location == null) return;
      // Seed first so the lock gate can defer it; the redirect consumes it on
      // arrival (or restores it after unlock).
      ref.read(pendingLocationProvider).location = location;
      ref.read(appRouterProvider).go(location);
    });
    return child;
  }
}
