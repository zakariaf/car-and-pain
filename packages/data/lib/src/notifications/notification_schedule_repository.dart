import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../repositories/base_repository.dart';
import '../repositories/reminders_repository.dart';

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

  // Reuse the single-source row→domain→rule mapping (M5-T1) so the F5 scheduler
  // and the user-facing repository can never diverge on how a rule is built.
  ReminderScheduleDef _defOf(ReminderRow r, int offset) {
    final rem = RemindersRepository.toDomain(r);
    return ReminderScheduleDef(
      id: rem.id,
      vehicleId: rem.vehicleId,
      title: rem.title,
      severity: rem.severity,
      rule: rem.toScheduleRule(utcOffsetMinutes: offset),
    );
  }
}
