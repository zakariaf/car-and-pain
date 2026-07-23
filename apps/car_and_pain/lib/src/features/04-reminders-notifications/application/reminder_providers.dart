import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

/// A vehicle's reminders with their live state (M5-T3) — reactive over the
/// reminders table (the F5 next-due engine + ledger derive the state).
final reminderLiveStatesProvider =
    StreamProvider.family<List<ReminderWithState>, String>(
  (ref, vehicleId) =>
      ref.watch(remindersRepositoryProvider).watchLiveStates(vehicleId),
);

/// One reminder by id (for the deep-link detail / edit), reactive over changes.
final reminderByIdProvider = FutureProvider.family<Reminder?, ReminderKey>(
  (ref, key) {
    ref.watch(reminderLiveStatesProvider(key.vehicleId));
    return ref.watch(remindersRepositoryProvider).byId(key.reminderId);
  },
);

/// Identity for [reminderByIdProvider] (vehicle + reminder id).
class ReminderKey {
  const ReminderKey(this.vehicleId, this.reminderId);
  final String vehicleId;
  final String reminderId;

  @override
  bool operator ==(Object other) =>
      other is ReminderKey &&
      other.vehicleId == vehicleId &&
      other.reminderId == reminderId;

  @override
  int get hashCode => Object.hash(vehicleId, reminderId);
}

/// Live state → the redundantly-encoded [PulseStatus] badge (icon + label,
/// never colour alone). Snoozed/upcoming/done read as calm.
PulseStatus reminderPulseStatus(ReminderLiveState s) => switch (s) {
      ReminderLiveState.overdue => PulseStatus.overdue,
      ReminderLiveState.dueSoon => PulseStatus.dueSoon,
      ReminderLiveState.upcoming => PulseStatus.healthy,
      ReminderLiveState.snoozed => PulseStatus.healthy,
      ReminderLiveState.done => PulseStatus.healthy,
    };

/// The urgency a live state maps to (drives the exhale's one-notch cool).
Urgency reminderUrgency(ReminderLiveState s) => switch (s) {
      ReminderLiveState.overdue => Urgency.overdue,
      ReminderLiveState.dueSoon => Urgency.soon,
      ReminderLiveState.upcoming => Urgency.scheduled,
      ReminderLiveState.snoozed => Urgency.scheduled,
      ReminderLiveState.done => Urgency.calm,
    };

/// Localized live-state label.
String reminderStatusLabel(AppLocalizations l10n, ReminderLiveState s) =>
    switch (s) {
      ReminderLiveState.upcoming => l10n.reminderStatusUpcoming,
      ReminderLiveState.dueSoon => l10n.reminderStatusDueSoon,
      ReminderLiveState.overdue => l10n.reminderStatusOverdue,
      ReminderLiveState.snoozed => l10n.reminderStatusSnoozed,
      ReminderLiveState.done => l10n.reminderStatusDone,
    };

/// Localized rule-kind label.
String reminderKindLabel(AppLocalizations l10n, TriggerKind k) => switch (k) {
      TriggerKind.date => l10n.reminderKindDate,
      TriggerKind.distance => l10n.reminderKindDistance,
      TriggerKind.engineHours => l10n.reminderKindEngineHours,
      TriggerKind.whicheverFirst => l10n.reminderKindWhicheverFirst,
    };

/// A localized calendar date for a due [when] — active calendar + numerals,
/// canonical UTC converted only for display.
String formatDueDate(CalendarSystem cal, NumeralFormat fmt, Instant when) {
  final d = CalendarDate.fromInstant(when, cal);
  return '${fmt.formatUngrouped(d.year)}/${fmt.formatUngrouped(d.month)}'
      '/${fmt.formatUngrouped(d.day)}';
}
