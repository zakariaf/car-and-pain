import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The four per-severity Android channels (F5-T1). Ids match
/// `ScheduledNotification.channelId`; iOS maps severity to interruption level in
/// the details builder. Names/descriptions are system-settings copy — English
/// here (TODO(F5): localize channel names via a device-locale lookup at init).
List<AndroidNotificationChannel> notificationChannels() => const [
      AndroidNotificationChannel(
        'overdue',
        'Overdue',
        description: 'Time-critical overdue reminders',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        'dueSoon',
        'Due soon',
        description: 'Upcoming service, documents and tasks',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'documents',
        'Documents',
        description: 'Document, insurance and legal expiries',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'info',
        'Info',
        description: 'General information and digests',
      ),
    ];

/// The channel for a severity id, defaulting to `info`.
AndroidNotificationChannel channelFor(String id) {
  final all = notificationChannels();
  return all.firstWhere((c) => c.id == id, orElse: () => all.last);
}
