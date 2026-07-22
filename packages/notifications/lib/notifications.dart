/// Car and Pain — `notifications`.
///
/// The single public entry point for the notification engine. For F1 this is the
/// `NotificationGateway` port + a `FakeNotificationGateway`; the pure
/// clock-injected `ReminderScheduler`, boot/exact-alarm handling, and the real
/// `flutter_local_notifications`-backed gateway arrive in F5.
library;

export 'src/notification_gateway.dart'
    show FakeNotificationGateway, NotificationGateway, ScheduledNotification;
export 'src/reconciler.dart'
    show ReconcileResult, Reconciler, stableNotificationId;
