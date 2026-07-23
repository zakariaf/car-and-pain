import 'package:core/core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:notifications/notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_channels.dart';

/// The real `flutter_local_notifications`-backed [NotificationGateway] (F5-T1).
/// Wraps `zonedSchedule` / `cancel` / `pendingNotificationRequests` behind the
/// pure port so no plugin type leaks past the module, and returns a typed
/// [Result] instead of throwing. Fires at the exact UTC instant rendered in the
/// device zone (`tz.local`, set at startup). Delivery is device-only to verify.
final class FlnNotificationGateway implements NotificationGateway {
  const FlnNotificationGateway(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<Result<void, NotificationFailure>> schedule(
    ScheduledNotification n,
  ) async {
    try {
      await _plugin.zonedSchedule(
        n.id,
        n.title,
        n.body,
        tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, n.when.epochMillis),
        _detailsFor(n),
        // Time-critical items fire exactly; low-priority tolerate Doze batching.
        androidScheduleMode: n.channelId == 'overdue'
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        // The deep-link target survives the reboot/Doze boundary with the OS
        // notification; the tap handler maps it back to a route (M1-T6).
        payload: n.payload,
      );
      return const Ok(null);
    } on Object {
      return const Err(NotificationScheduleFailed());
    }
  }

  @override
  Future<Result<void, NotificationFailure>> cancel(int id) async {
    try {
      await _plugin.cancel(id);
      return const Ok(null);
    } on Object {
      return const Err(NotificationScheduleFailed());
    }
  }

  @override
  Future<List<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((p) => p.id).toList();
  }

  NotificationDetails _detailsFor(ScheduledNotification n) {
    final channel = channelFor(n.channelId);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        // Per-severity priority (M5-T4) so heads-up matches the channel.
        priority: androidPriorityFor(n.channelId),
        groupKey: n.groupKey,
      ),
      // Per-severity iOS interruption level (M5-T4): overdue breaks through Focus.
      iOS: DarwinNotificationDetails(
        threadIdentifier: n.groupKey,
        interruptionLevel: iosInterruptionFor(n.channelId),
      ),
    );
  }
}
