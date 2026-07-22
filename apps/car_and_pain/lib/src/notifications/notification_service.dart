import 'package:core/core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:notifications/notifications.dart';

import 'fln_gateway.dart';
import 'notification_channels.dart';

/// The one façade over the OS notification plugin (F5-T1): initialize the
/// plugin, create the per-severity channels idempotently, and expose the pure
/// [NotificationGateway] the scheduler talks to. Everything returns a typed
/// [Result]; no plugin type leaks to callers.
final class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// The port the pure scheduler/reconciler use.
  late final NotificationGateway gateway = FlnNotificationGateway(_plugin);

  /// Initialize the plugin and (re)create the channels. Idempotent — re-running
  /// neither duplicates channels nor throws (the OS de-dupes by channel id).
  Future<Result<void, NotificationFailure>> init() async {
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // Permission is requested explicitly, behind a rationale (F5-T6).
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      for (final channel in notificationChannels()) {
        await android?.createNotificationChannel(channel);
      }
      return const Ok(null);
    } on Object {
      return const Err(NotificationScheduleFailed());
    }
  }
}
