import 'notification_gateway.dart';

/// A deterministic 32-bit-safe notification id from a stable [key] such as
/// `"$reminderId#$occurrence"` (FNV-1a). Same key → same id across reboots, so
/// reconcile never orphans or duplicates OS entries.
int stableNotificationId(String key) {
  var h = 0x811c9dc5;
  for (final c in key.codeUnits) {
    h = (h ^ c) & 0xffffffff;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff; // positive 31-bit — safe for FLN ids on both platforms
}

/// The outcome of a reconcile pass.
final class ReconcileResult {
  const ReconcileResult({
    required this.effective,
    required this.armed,
    required this.rescheduled,
    required this.cancelled,
    required this.unchanged,
    required this.deferred,
  });

  /// The notifications now believed armed with the OS (persist as the next
  /// `current`).
  final List<ScheduledNotification> effective;
  final int armed;
  final int rescheduled;
  final int cancelled;
  final int unchanged;

  /// Desired entries beyond the [Reconciler.maxPending] window — not armed this
  /// pass; the next reconcile picks them up as sooner ones fire.
  final int deferred;

  int get mutations => armed + rescheduled + cancelled;
}

/// Reconciles the OS notification queue to be a pure projection of the DB
/// (F5-T2). Pure and gateway-driven: it diffs the freshly-`desired` set against
/// the last-armed `current` set (and the OS's actual pending ids), applies the
/// minimal changes, and windows to the soonest [maxPending] to respect the iOS
/// 64-pending cap. Idempotent — identical inputs produce zero OS mutations.
final class Reconciler {
  const Reconciler({this.maxPending = 64});

  /// The most entries armed at once (iOS caps pending local notifications at 64).
  final int maxPending;

  Future<ReconcileResult> reconcile({
    required List<ScheduledNotification> desired,
    required List<ScheduledNotification> current,
    required NotificationGateway gateway,
  }) async {
    final sorted = [...desired]
      ..sort((a, b) => a.when.epochMillis.compareTo(b.when.epochMillis));
    final window = sorted.take(maxPending).toList();
    final deferred = sorted.length - window.length;

    final windowById = {for (final n in window) n.id: n};
    final currentById = {for (final n in current) n.id: n};
    final pending = (await gateway.pendingIds()).toSet();

    var armed = 0;
    var rescheduled = 0;
    var cancelled = 0;
    var unchanged = 0;

    // Cancel anything previously armed that's no longer desired (or fell out of
    // the window), including OS entries the DB no longer knows about.
    final toCancel = {...currentById.keys, ...pending}
      ..removeWhere(windowById.containsKey);
    for (final id in toCancel) {
      await gateway.cancel(id);
      cancelled++;
    }

    for (final n in window) {
      final prev = currentById[n.id];
      final isPending = pending.contains(n.id);
      if (prev == null || !isPending) {
        // New, or lost from the OS (e.g. after a reboot) → arm it.
        await gateway.schedule(n);
        armed++;
      } else if (_changed(prev, n)) {
        await gateway.cancel(n.id);
        await gateway.schedule(n);
        rescheduled++;
      } else {
        unchanged++;
      }
    }

    return ReconcileResult(
      effective: window,
      armed: armed,
      rescheduled: rescheduled,
      cancelled: cancelled,
      unchanged: unchanged,
      deferred: deferred,
    );
  }

  static bool _changed(ScheduledNotification a, ScheduledNotification b) =>
      a.when != b.when ||
      a.titleCode != b.titleCode ||
      a.bodyCode != b.bodyCode;
}
