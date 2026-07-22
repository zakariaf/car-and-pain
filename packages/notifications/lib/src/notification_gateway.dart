import 'package:core/core.dart';

/// A request to schedule one local notification at an absolute [when].
///
/// The scheduler resolves recurrences/projections to a concrete [Instant] and
/// localizes the copy (via the F4 i18n layer) *before* handing it to the gateway
/// — the OS queue stores the fired strings, so the gateway does no time or text
/// math. A locale change simply re-arms with fresh strings on the next reconcile.
final class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    this.channelId = 'info',
    this.groupKey,
  });

  /// A deterministic id so reconcile is idempotent across reboots.
  final int id;

  /// The absolute instant to fire.
  final Instant when;

  /// Already-localized copy (built through F4; never a raw key).
  final String title;
  final String body;

  /// The severity channel: `overdue` | `dueSoon` | `documents` | `info`.
  final String channelId;

  /// Digest grouping key; entries sharing a key collapse into one summary.
  final String? groupKey;
}

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
