import 'dart:async';

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

  /// Payloads of notifications tapped **while the app is alive** (M1-T6). The
  /// app subscribes and maps each to a route via `mapNotificationPayload`; a
  /// cold-start tap comes through [launchPayload] instead. Broadcast so late
  /// subscribers don't error, and closed on [dispose].
  final _taps = StreamController<String?>.broadcast();
  Stream<String?> get taps => _taps.stream;

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
        // A foreground/background tap surfaces its deep-link payload here.
        onDidReceiveNotificationResponse: (response) =>
            _taps.add(response.payload),
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

  /// The payload of the notification that **cold-launched** the app, if any
  /// (M1-T6). `bootstrap` reads it before the first frame to seed the router's
  /// initial location. Returns `null` on a normal launch or on any plugin
  /// error — a deep link is never allowed to break startup.
  Future<String?> launchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return details?.notificationResponse?.payload;
      }
      return null;
    } on Object {
      return null;
    }
  }

  /// Release the tap stream (app teardown). The plugin has no dispose.
  Future<void> dispose() => _taps.close();
}
