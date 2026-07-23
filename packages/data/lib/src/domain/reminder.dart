import 'package:core/core.dart';

/// The user-facing live state of a reminder (M5-T1), derived from the F5 next-due
/// output + the shared ledger. Encoded redundantly downstream (icon+label+shape+
/// position), never colour alone.
enum ReminderLiveState { upcoming, dueSoon, overdue, snoozed, done }

/// A reminder as the repository emits it — Drift-free. Rule dimensions are each
/// nullable so a whichever-first rule can mix any subset (a single-dimension rule
/// is a degenerate whichever-first). Distance is canonical metres, engine time
/// whole minutes, instants UTC; conversion happens only at the edge.
class Reminder {
  const Reminder({
    required this.id,
    required this.vehicleId,
    required this.title,
    required this.triggerType,
    this.notes,
    this.dueDate,
    this.dueOdometerMetres,
    this.dueEngineMinutes,
    this.completedAt,
    this.recurrenceEvery,
    this.recurrenceUnit,
    this.leadMinutes = 0,
    this.leadDistanceMetres,
    this.severity = 'info',
    this.quietStartMinute,
    this.quietEndMinute,
    this.quietDeliverMinute,
    this.status = 'active',
    this.snoozeUntil,
  });

  final String id;
  final String vehicleId;
  final String title;
  final String? notes;

  /// date | distance | hours | whicheverFirst.
  final String triggerType;
  final Instant? dueDate;
  final int? dueOdometerMetres;
  final int? dueEngineMinutes;
  final Instant? completedAt;
  final int? recurrenceEvery;

  /// days | weeks | months | years.
  final String? recurrenceUnit;
  final int leadMinutes;
  final int? leadDistanceMetres;

  /// overdue | dueSoon | documents | info.
  final String severity;
  final int? quietStartMinute;
  final int? quietEndMinute;
  final int? quietDeliverMinute;

  /// active | done.
  final String status;
  final Instant? snoozeUntil;

  bool get isRecurring => recurrenceEvery != null && recurrenceUnit != null;

  /// The canonical [ScheduleRule] the F5 next-due engine evaluates. Single source
  /// of the reminder-row → rule mapping (the F5 schedule repository delegates to
  /// this so the two paths can never diverge).
  ScheduleRule toScheduleRule({int utcOffsetMinutes = 0}) => ScheduleRule(
        kind: triggerKindFromName(triggerType),
        dueDate: dueDate,
        completedAt: completedAt,
        recurrence: isRecurring
            ? Recurrence(
                recurrenceEvery!, recurrenceUnitFromName(recurrenceUnit!))
            : null,
        dueOdometerMetres: dueOdometerMetres,
        dueEngineMinutes: dueEngineMinutes,
        leadTime: Duration(minutes: leadMinutes),
        leadDistanceMetres: leadDistanceMetres,
        quietHours: (quietStartMinute != null && quietEndMinute != null)
            ? QuietHours(
                startMinute: quietStartMinute!,
                endMinute: quietEndMinute!,
                deliverAtMinute: quietDeliverMinute,
              )
            : null,
        utcOffsetMinutes: utcOffsetMinutes,
      );

  /// The trigger-type string ← [TriggerKind] (the write direction).
  static String triggerNameFromKind(TriggerKind kind) => switch (kind) {
        TriggerKind.date => 'date',
        TriggerKind.distance => 'distance',
        TriggerKind.engineHours => 'hours',
        TriggerKind.whicheverFirst => 'whicheverFirst',
      };

  /// [TriggerKind] ← the trigger-type string (defaults to date).
  static TriggerKind triggerKindFromName(String t) => switch (t) {
        'distance' => TriggerKind.distance,
        'hours' => TriggerKind.engineHours,
        'whicheverFirst' => TriggerKind.whicheverFirst,
        _ => TriggerKind.date,
      };

  /// [RecurrenceUnit] ← the recurrence-unit string (defaults to days).
  static RecurrenceUnit recurrenceUnitFromName(String u) => switch (u) {
        'weeks' => RecurrenceUnit.weeks,
        'months' => RecurrenceUnit.months,
        'years' => RecurrenceUnit.years,
        _ => RecurrenceUnit.days,
      };
}

/// A reminder paired with its derived live state + next-due projection — the
/// model behind a reminder card. [next] carries the projected fire/due instants
/// and the confidence (so the UI can show "estimate uncertain").
class ReminderWithState {
  const ReminderWithState({
    required this.reminder,
    required this.state,
    required this.due,
    this.next,
  });

  final Reminder reminder;
  final ReminderLiveState state;
  final DueResult due;
  final NextDue? next;

  /// The projected/absolute due instant, or null when nothing is scheduled.
  Instant? get dueAt => next?.dueAt;

  /// True when the projection is a soft estimate — either not enough ledger data
  /// to project a date yet ([InsufficientData] → "estimate pending"), or a stale
  /// projection ([DueConfidence.uncertain]). The UI surfaces this honestly rather
  /// than showing a confident date.
  bool get isUncertain =>
      due is InsufficientData || next?.confidence == DueConfidence.uncertain;
}

/// Classify a reminder's live state (M5-T1) from the pure next-due [due] result
/// plus [now]. Snooze and done take precedence; otherwise the due instant grades
/// overdue / due-soon (past its lead-time, or within [dueSoonWindow]) / upcoming.
/// An insufficient-data projection reads as upcoming (an estimate is pending).
ReminderLiveState classifyReminderState(
  Reminder reminder,
  DueResult due, {
  required Instant now,
  Duration dueSoonWindow = const Duration(days: 3),
}) {
  if (reminder.status == 'done') return ReminderLiveState.done;
  final snooze = reminder.snoozeUntil;
  if (snooze != null && snooze.epochMillis > now.epochMillis) {
    return ReminderLiveState.snoozed;
  }
  return switch (due) {
    Due(:final next) => () {
        if (next.dueAt.epochMillis <= now.epochMillis) {
          return ReminderLiveState.overdue;
        }
        final soonBy = next.dueAt.epochMillis - now.epochMillis;
        if (next.fireAt.epochMillis <= now.epochMillis ||
            soonBy <= dueSoonWindow.inMilliseconds) {
          return ReminderLiveState.dueSoon;
        }
        return ReminderLiveState.upcoming;
      }(),
    InsufficientData() => ReminderLiveState.upcoming,
    NoDue() => ReminderLiveState.done,
  };
}
