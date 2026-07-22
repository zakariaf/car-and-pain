import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notifications/notifications.dart';

import 'notification_service.dart';

/// The notification façade — created and initialized once at bootstrap (prod),
/// where it's overridden with the real instance. Reading it before the override
/// is a clear, immediate error rather than a silent no-op.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => throw UnimplementedError(
    'override notificationServiceProvider in bootstrap()',
  ),
);

/// The pure [NotificationGateway] the scheduler/reconciler talk to — the real
/// FLN-backed gateway in prod, a [FakeNotificationGateway] in tests.
final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => ref.watch(notificationServiceProvider).gateway,
);
