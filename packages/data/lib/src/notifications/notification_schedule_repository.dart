import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../repositories/base_repository.dart';

/// The DB boundary for the notification engine (F5-T2): maps `reminders` rows to
/// pure [ReminderScheduleDef]s the engine evaluates, and loads/saves the
/// `scheduled_notifications` projection as [ScheduledNotification]s — so the app
/// orchestration never touches Drift.
class NotificationScheduleRepository extends BaseRepository {
  NotificationScheduleRepository(super.db);

  /// The active, non-deleted reminders as engine-ready definitions.
  Future<List<ReminderScheduleDef>> activeReminders({
    int utcOffsetMinutes = 0,
  }) async {
    final rows = await (db.select(db.reminders)
          ..where((t) => t.isDeleted.equals(false) & t.status.equals('active')))
        .get();
    return rows.map((r) => _defOf(r, utcOffsetMinutes)).toList();
  }

  /// The last-armed projection (the reconcile `current` set).
  Future<List<ScheduledNotification>> loadProjection() async {
    final rows = await db.select(db.scheduledNotifications).get();
    return rows
        .map((r) => ScheduledNotification(
              id: r.notifId,
              when: Instant.fromEpochMillis(r.fireAt),
              title: r.title,
              body: r.body,
              channelId: r.channel,
              groupKey: r.groupKey,
            ))
        .toList();
  }

  /// Replace the projection with the freshly-[armed] set (rebuildable, so a full
  /// swap is correct and keeps the table a pure projection).
  Future<void> saveProjection(List<ScheduledNotification> armed) async {
    await db.transaction(() async {
      await db.delete(db.scheduledNotifications).go();
      for (final n in armed) {
        await db.into(db.scheduledNotifications).insert(
              ScheduledNotificationsCompanion.insert(
                notifId: Value(n.id),
                fireAt: n.when.epochMillis,
                title: n.title,
                body: n.body,
                channel: Value(n.channelId),
                groupKey: Value(n.groupKey),
              ),
            );
      }
    });
  }

  ReminderScheduleDef _defOf(Reminder r, int offset) => ReminderScheduleDef(
        id: r.id,
        vehicleId: r.vehicleId,
        title: r.title,
        severity: r.severity,
        rule: ScheduleRule(
          kind: _kind(r.triggerType),
          dueDate: _instant(r.dueDate),
          completedAt: _instant(r.completedAt),
          recurrence: (r.recurrenceEvery != null && r.recurrenceUnit != null)
              ? Recurrence(r.recurrenceEvery!, _unit(r.recurrenceUnit!))
              : null,
          dueOdometerMetres: r.dueOdometerMetres,
          dueEngineMinutes: r.dueEngineMinutes,
          leadTime: Duration(minutes: r.leadMinutes),
          leadDistanceMetres: r.leadDistanceMetres,
          quietHours: (r.quietStartMinute != null && r.quietEndMinute != null)
              ? QuietHours(
                  startMinute: r.quietStartMinute!,
                  endMinute: r.quietEndMinute!,
                  deliverAtMinute: r.quietDeliverMinute,
                )
              : null,
          utcOffsetMinutes: offset,
        ),
      );

  static TriggerKind _kind(String t) => switch (t) {
        'distance' => TriggerKind.distance,
        'hours' => TriggerKind.engineHours,
        'whicheverFirst' => TriggerKind.whicheverFirst,
        _ => TriggerKind.date,
      };

  static RecurrenceUnit _unit(String u) => switch (u) {
        'weeks' => RecurrenceUnit.weeks,
        'months' => RecurrenceUnit.months,
        'years' => RecurrenceUnit.years,
        _ => RecurrenceUnit.days,
      };

  static Instant? _instant(int? ms) =>
      ms == null ? null : Instant.fromEpochMillis(ms);
}
