import 'package:core/core.dart';

/// The platform-scheduling port. The real implementation wraps
/// `flutter_local_notifications` `zonedSchedule` and lives in the app (F5); the
/// pure scheduler and tests talk only to this interface.
abstract interface class NotificationGateway {
  /// Schedule (or reschedule) a notification. Returns a typed failure rather
  /// than throwing across the boundary.
  Future<Result<void, NotificationFailure>> schedule(
    ScheduledNotification notification,
  );

  /// Cancel a previously scheduled notification by id.
  Future<Result<void, NotificationFailure>> cancel(int id);

  /// The ids currently pending with the OS — the reconcile source of truth is
  /// the DB; this is the disposable cache to diff against.
  Future<List<int>> pendingIds();
}

/// A recording fake for unit tests (fake over mock). Deterministic, no plugins.
/// [scheduled] / [cancelled] record the full call history for assertions, while
/// [_live] models the OS's actual pending set — so a cancel-then-reschedule of
/// the same id (as reconcile does on a time change) leaves the entry live, just
/// like real `flutter_local_notifications`.
final class FakeNotificationGateway implements NotificationGateway {
  final List<ScheduledNotification> scheduled = [];
  final List<int> cancelled = [];
  final Map<int, ScheduledNotification> _live = {};

  @override
  Future<Result<void, NotificationFailure>> schedule(
    ScheduledNotification notification,
  ) async {
    scheduled.add(notification);
    _live[notification.id] = notification;
    return const Ok(null);
  }

  @override
  Future<Result<void, NotificationFailure>> cancel(int id) async {
    cancelled.add(id);
    _live.remove(id);
    return const Ok(null);
  }

  @override
  Future<List<int>> pendingIds() async => _live.keys.toList();
}
