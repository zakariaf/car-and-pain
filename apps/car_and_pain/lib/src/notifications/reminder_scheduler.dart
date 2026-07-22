import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:notifications/notifications.dart';

import '../routing/app_locations.dart';

/// Builds the localized title/body for a due reminder and for a grouped digest.
/// Injected so the orchestration stays testable without the l10n runtime; the
/// real implementation resolves the active locale/calendar/numeral (F5-T5).
abstract interface class NotificationCopy {
  ({String title, String body}) forReminder(
    String vehicleName,
    ReminderScheduleDef def,
    NextDue due,
  );

  ({String title, String body}) forDigest(
    List<(String vehicleName, ReminderScheduleDef def)> group,
  );
}

/// Orchestrates the DB → engine → reconcile pipeline (F5-T2/T5): recompute the
/// desired notification set from every active reminder + the ledger, collapse a
/// delivery window into one digest, reconcile the OS queue, and persist the
/// projection — so the OS queue is always a pure projection of the DB. No Drift
/// here; all DB access goes through the injected data repositories.
final class ReminderScheduler {
  ReminderScheduler({
    required this.schedules,
    required this.ledger,
    required this.vehicles,
    required this.gateway,
    required this.copy,
    this.engine = const NextDueEngine(),
    this.reconciler = const Reconciler(),
    this.utcOffsetMinutes = 0,
  });

  final NotificationScheduleRepository schedules;
  final LedgerRepository ledger;
  final VehiclesRepository vehicles;
  final NotificationGateway gateway;
  final NotificationCopy copy;
  final NextDueEngine engine;
  final Reconciler reconciler;
  final int utcOffsetMinutes;

  static const int _msPerDay = Duration.millisecondsPerDay;

  /// Recompute + reconcile everything. Idempotent via the pure [Reconciler].
  Future<ReconcileResult> reconcileAll() async {
    final defs = await schedules.activeReminders(
      utcOffsetMinutes: utcOffsetMinutes,
    );

    final dueItems = <(String, ReminderScheduleDef, NextDue)>[];
    for (final def in defs) {
      final history = await ledger.watchByVehicle(def.vehicleId).first;
      final result = engine.evaluate(
        def.rule,
        odometer: history,
        hours: history, // odometer & engine-hours share the ledger timeline
      );
      if (result is Due) {
        final v = (await vehicles.getById(def.vehicleId)).valueOrNull;
        dueItems.add((v?.nickname ?? '', def, result.next));
      }
    }

    final desired = _buildDesired(dueItems);
    final current = await schedules.loadProjection();
    final result = await reconciler.reconcile(
      desired: desired,
      current: current,
      gateway: gateway,
    );
    await schedules.saveProjection(result.effective);
    return result;
  }

  /// Collapse each local delivery day with >1 due item into a single digest;
  /// a lone item delivers ungrouped, on its own severity channel.
  List<ScheduledNotification> _buildDesired(
    List<(String, ReminderScheduleDef, NextDue)> items,
  ) {
    final byDay = <int, List<(String, ReminderScheduleDef, NextDue)>>{};
    for (final item in items) {
      final localMs = item.$3.fireAt.epochMillis + utcOffsetMinutes * 60000;
      byDay.putIfAbsent(localMs ~/ _msPerDay, () => []).add(item);
    }

    final out = <ScheduledNotification>[];
    byDay.forEach((day, group) {
      if (group.length == 1) {
        final (name, def, due) = group.first;
        final c = copy.forReminder(name, def, due);
        out.add(ScheduledNotification(
          id: stableNotificationId('${def.id}#$day'),
          when: due.fireAt,
          title: c.title,
          body: c.body,
          channelId: def.severity,
          // Tapping a single reminder deep-links to its detail (M1-T6).
          payload: AppLocations.reminderDetail(def.vehicleId, def.id),
        ));
      } else {
        group.sort((a, b) =>
            a.$3.fireAt.epochMillis.compareTo(b.$3.fireAt.epochMillis));
        final c = copy.forDigest(
          group.map((e) => (e.$1, e.$2)).toList(),
        );
        out.add(ScheduledNotification(
          id: stableNotificationId('digest#$day'),
          when: group.first.$3.fireAt, // the earliest item's fire time
          title: c.title,
          body: c.body,
          groupKey: 'digest#$day',
          // A digest spans several reminders → land on the Pit-lane (what's due).
          payload: AppLocations.pitlane,
        ));
      }
    });
    return out;
  }
}
