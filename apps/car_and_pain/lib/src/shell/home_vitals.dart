import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shell_state.dart';

/// The one readiness vital for the active scope (M1-T4/T5). Evaluates each
/// scoped reminder's next-due — date rules resolve directly; distance/hour rules
/// with no ledger read insufficient-data (excluded → calm) — then aggregates via
/// the pure `aggregateReadiness`. An empty scope reads perfectly calm.
///
/// A `FutureProvider` keyed on the scope: it recomputes when the active vehicle
/// or scope changes. (Live per-reminder reactivity arrives with M5's reminder
/// watch stream; M1 has no reminders, so this reads calm.)
final homeReadinessProvider = FutureProvider<ReadinessSummary>((ref) async {
  final scopedIds = ref.watch(scopedVehicleIdsProvider);
  if (scopedIds.isEmpty) return ReadinessSummary.calm;

  final defs =
      await ref.read(notificationScheduleRepositoryProvider).activeReminders();
  final scoped = defs.where((d) => scopedIds.contains(d.vehicleId)).toList();
  if (scoped.isEmpty) return ReadinessSummary.calm;

  const engine = NextDueEngine();
  final ledgers = <String, List<LedgerReading>>{};
  final reminders = <ReminderDue>[];
  for (final d in scoped) {
    final ledger = ledgers[d.vehicleId] ??= await ref
        .read(ledgerRepositoryProvider)
        .watchByVehicle(d.vehicleId)
        .first;
    reminders.add(ReminderDue(
      reminderId: d.id,
      title: d.title,
      // Odometer & engine-hours share the ledger timeline — pass both, matching
      // the notification scheduler, so hour-based rules aren't silently calm.
      due: engine.evaluate(d.rule, odometer: ledger, hours: ledger),
    ));
  }

  final now = Instant.fromDateTime(const SystemClock().nowUtc());
  return aggregateReadiness(now: now, reminders: reminders);
});
