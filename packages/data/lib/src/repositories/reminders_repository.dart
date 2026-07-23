import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../domain/reminder.dart';
import '../ledger/ledger_repository.dart';
import 'base_repository.dart';

/// The user-facing reminder CRUD boundary (M5-T1) over the F5 schedule primitives.
/// Returns Drift-free domain [Reminder]s and derives the live state
/// (upcoming/due-soon/overdue/snoozed/done) from the pure F5 [NextDueEngine] plus
/// the shared ledger. All methods return the sealed [Result]; no Drift/plugin type
/// leaks past the boundary. Scheduling itself stays in the F5 engine.
class RemindersRepository extends BaseRepository {
  RemindersRepository(super.db, {super.clock});

  LedgerRepository get _ledger => LedgerRepository(db);

  // ── reads ──────────────────────────────────────────────────────────────────

  /// A vehicle's reminders as a live stream (newest first), tombstone-filtered.
  Stream<List<Reminder>> watchByVehicle(String vehicleId) {
    final query = db.select(db.reminders)
      ..where((t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(toDomain).toList());
  }

  /// A vehicle's reminders with their derived live state — a live stream that
  /// re-emits on any reminder change and reads the current ledger for projection.
  /// (M5-T2 layers ledger-change reactivity on top via the app scheduler.)
  Stream<List<ReminderWithState>> watchLiveStates(
    String vehicleId, {
    int utcOffsetMinutes = 0,
  }) {
    final engine = NextDueEngine(clock: clock);
    return watchByVehicle(vehicleId).asyncMap((reminders) async {
      final odo = await _ledger.watchByVehicle(vehicleId).first;
      final now = Instant.fromEpochMillis(nowMillis());
      return [
        for (final r in reminders)
          _withState(r, engine, odo, now, utcOffsetMinutes),
      ];
    });
  }

  /// Snapshot of the live states for a vehicle (the same derivation as
  /// [watchLiveStates], one-shot).
  Future<List<ReminderWithState>> liveStatesFor(
    String vehicleId, {
    int utcOffsetMinutes = 0,
  }) async {
    final engine = NextDueEngine(clock: clock);
    final reminders = (await (db.select(db.reminders)
              ..where((t) =>
                  t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false)))
            .get())
        .map(toDomain)
        .toList();
    final odo = await _ledger.watchByVehicle(vehicleId).first;
    final now = Instant.fromEpochMillis(nowMillis());
    return [
      for (final r in reminders)
        _withState(r, engine, odo, now, utcOffsetMinutes),
    ];
  }

  /// A read-only `.ics` of the vehicle's reminders' projected due dates (M5-T6) —
  /// a sharing convenience for the device calendar that NEVER mutates engine
  /// state. [summary] localizes each event title at the edge (data stays
  /// l10n-free); [dtstamp] is the export instant. All-day events on the due date.
  Future<String> dueDatesIcs(
    String vehicleId, {
    required String Function(Reminder) summary,
    required Instant dtstamp,
    int utcOffsetMinutes = 0,
  }) async {
    final states =
        await liveStatesFor(vehicleId, utcOffsetMinutes: utcOffsetMinutes);
    final events = [
      for (final s in states)
        if (s.dueAt != null)
          IcsEvent(
            uid: '${s.reminder.id}@car-and-pain',
            summary: summary(s.reminder),
            date: s.dueAt!,
          ),
    ];
    return buildIcsCalendar(events, dtstamp: dtstamp);
  }

  /// One reminder by id, or null when missing/tombstoned.
  Future<Reminder?> byId(String id) async {
    final row = await (db.select(db.reminders)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    return row == null ? null : toDomain(row);
  }

  // ── writes ─────────────────────────────────────────────────────────────────

  /// Create a reminder. Distance thresholds are canonical metres, engine time
  /// whole minutes, instants UTC — the caller converts at the entry edge.
  Future<Result<String, DbFailure>> add({
    required String vehicleId,
    required String title,
    required TriggerKind kind,
    String? notes,
    Instant? dueDate,
    int? dueOdometerMetres,
    int? dueEngineMinutes,
    int? recurrenceEvery,
    RecurrenceUnit? recurrenceUnit,
    int leadMinutes = 0,
    int? leadDistanceMetres,
    String severity = 'info',
    int? quietStartMinute,
    int? quietEndMinute,
    int? quietDeliverMinute,
  }) async {
    try {
      final id = newId();
      final now = nowMillis();
      await db.into(db.reminders).insert(
            RemindersCompanion.insert(
              id: id,
              vehicleId: vehicleId,
              title: title,
              triggerType: Reminder.triggerNameFromKind(kind),
              createdAt: now,
              updatedAt: now,
              notes: Value(notes),
              dueDate: Value(dueDate?.epochMillis),
              dueOdometerMetres: Value(dueOdometerMetres),
              dueEngineMinutes: Value(dueEngineMinutes),
              recurrenceEvery: Value(recurrenceEvery),
              recurrenceUnit: Value(recurrenceUnit?.name),
              leadMinutes: Value(leadMinutes),
              leadDistanceMetres: Value(leadDistanceMetres),
              severity: Value(severity),
              quietStartMinute: Value(quietStartMinute),
              quietEndMinute: Value(quietEndMinute),
              quietDeliverMinute: Value(quietDeliverMinute),
            ),
          );
      return Ok(id);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'reminders'));
    }
  }

  /// Snooze a reminder until [until] (a data-triggered "snooze until next drive"
  /// is modelled by the caller passing the next projected instant).
  Future<Result<void, DbFailure>> snooze(String id, Instant until) => _mutate(
      id,
      (cur, now) => RemindersCompanion(
            snoozeUntil: Value(until.epochMillis),
            updatedAt: Value(now),
            rowRevision: Value(cur.rowRevision + 1),
          ));

  /// Clear a snooze.
  Future<Result<void, DbFailure>> unsnooze(String id) => _mutate(
      id,
      (cur, now) => RemindersCompanion(
            snoozeUntil: const Value(null),
            updatedAt: Value(now),
            rowRevision: Value(cur.rowRevision + 1),
          ));

  /// Complete a reminder. A recurring reminder re-anchors its next cycle to the
  /// **actual** completion instant (so it never drifts) and stays active; a
  /// one-off is marked done. Clears any snooze.
  Future<Result<void, DbFailure>> complete(
    String id, {
    Instant? at,
  }) =>
      _mutate(id, (cur, now) {
        final completedMs = (at ?? Instant.fromEpochMillis(now)).epochMillis;
        final recurring =
            cur.recurrenceEvery != null && cur.recurrenceUnit != null;
        return RemindersCompanion(
          completedAt: Value(completedMs),
          status: Value(recurring ? 'active' : 'done'),
          snoozeUntil: const Value(null),
          updatedAt: Value(now),
          rowRevision: Value(cur.rowRevision + 1),
        );
      });

  /// Soft-delete a reminder to trash (its OS entry is cleared on the next F5
  /// reconcile, since a deleted reminder is excluded from `activeReminders`).
  Future<Result<void, DbFailure>> softDelete(
    String id, {
    Duration retention = const Duration(days: 30),
  }) =>
      _mutate(
          id,
          (cur, now) => RemindersCompanion(
                isDeleted: const Value(true),
                deletedAt: Value(now),
                trashExpiresAt: Value(now + retention.inMilliseconds),
                updatedAt: Value(now),
                rowRevision: Value(cur.rowRevision + 1),
              ));

  // ── mapping + internals ─────────────────────────────────────────────────────

  /// Row → domain. Public + static so the F5 `NotificationScheduleRepository` can
  /// reuse it, keeping the row→[ScheduleRule] mapping single-source.
  static Reminder toDomain(ReminderRow r) => Reminder(
        id: r.id,
        vehicleId: r.vehicleId,
        title: r.title,
        notes: r.notes,
        triggerType: r.triggerType,
        dueDate: _instant(r.dueDate),
        dueOdometerMetres: r.dueOdometerMetres,
        dueEngineMinutes: r.dueEngineMinutes,
        completedAt: _instant(r.completedAt),
        recurrenceEvery: r.recurrenceEvery,
        recurrenceUnit: r.recurrenceUnit,
        leadMinutes: r.leadMinutes,
        leadDistanceMetres: r.leadDistanceMetres,
        severity: r.severity,
        quietStartMinute: r.quietStartMinute,
        quietEndMinute: r.quietEndMinute,
        quietDeliverMinute: r.quietDeliverMinute,
        status: r.status,
        snoozeUntil: _instant(r.snoozeUntil),
      );

  ReminderWithState _withState(
    Reminder r,
    NextDueEngine engine,
    List<LedgerReading> odo,
    Instant now,
    int utcOffsetMinutes,
  ) {
    final due = engine.evaluate(
      r.toScheduleRule(utcOffsetMinutes: utcOffsetMinutes),
      odometer: odo,
    );
    return ReminderWithState(
      reminder: r,
      state: classifyReminderState(r, due, now: now),
      due: due,
      next: due is Due ? due.next : null,
    );
  }

  Future<Result<void, DbFailure>> _mutate(
    String id,
    RemindersCompanion Function(ReminderRow cur, int now) build,
  ) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.reminders)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null || cur.isDeleted) return false;
        await (db.update(db.reminders)..where((t) => t.id.equals(id)))
            .write(build(cur, now));
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('reminder'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'reminders'));
    }
  }

  static Instant? _instant(int? ms) =>
      ms == null ? null : Instant.fromEpochMillis(ms);
}
