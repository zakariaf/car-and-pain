import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notification_providers.dart';
import 'app_router.dart';
import 'notification_deep_link.dart';

/// Routes notification taps that arrive **while the app is alive** (M1-T6).
///
/// Watches [notificationTapProvider]; each tapped payload is validated by the
/// pure [mapNotificationPayload] and, if it maps to a safe location, navigated
/// via the single router. Mounted once around the app so it survives every
/// route change. (A cold-start tap is handled earlier by `bootstrap` seeding
/// the router's initial location — this only covers the running app.)
class DeepLinkListener extends ConsumerWidget {
  const DeepLinkListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationTapProvider, (_, next) {
      final location = mapNotificationPayload(next.asData?.value);
      if (location != null) ref.read(appRouterProvider).go(location);
    });
    return child;
  }
}
