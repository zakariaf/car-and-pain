import 'dart:async';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../../../routing/app_locations.dart';
import '../../../settings/locale_controller.dart';
import '../application/reminder_providers.dart';

/// The per-severity reminder view (M5-T3): live items grouped overdue → due-soon
/// → upcoming (snoozed + done trail), each a card whose status is encoded
/// redundantly (icon + label + shape + position, never colour alone). Snooze and
/// complete resolve items in place; completion plays the shared exhale (haptic +
/// one-notch cool + settle), honouring reduced-motion.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  int _exhale = 0; // bumped to play the settle on completion

  static const _order = [
    ReminderLiveState.overdue,
    ReminderLiveState.dueSoon,
    ReminderLiveState.upcoming,
    ReminderLiveState.snoozed,
    ReminderLiveState.done,
  ];

  Future<void> _complete(ReminderWithState item) async {
    final l10n = AppLocalizations.of(context);
    await Exhale.play(
      context,
      from: reminderUrgency(item.state),
      announce: l10n.reminderCompleted,
    );
    if (!mounted) return;
    setState(() => _exhale++);
    await ref.read(remindersRepositoryProvider).complete(item.reminder.id);
  }

  Future<void> _snooze(String id, Duration by) async {
    final until = Instant.fromEpochMillis(
      const SystemClock().nowUtc().add(by).millisecondsSinceEpoch,
    );
    await ref.read(remindersRepositoryProvider).snooze(id, until);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(activeNumeralFormatProvider);
    final cal = ref.watch(activeCalendarProvider);
    final items =
        ref.watch(reminderLiveStatesProvider(widget.vehicleId)).asData?.value ??
            const <ReminderWithState>[];

    final byState = <ReminderLiveState, List<ReminderWithState>>{};
    for (final it in items) {
      byState.putIfAbsent(it.state, () => []).add(it);
    }

    return PulseScaffold(
      title: l10n.reminderListTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.reminderAddTitle,
          onPressed: () =>
              context.push(AppLocations.newReminder(widget.vehicleId)),
        ),
      ],
      body: items.isEmpty
          ? Center(child: Text(l10n.reminderListEmpty))
          : ExhaleSettle(
              trigger: _exhale,
              child: ListView(
                padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
                children: [
                  for (final state in _order)
                    if (byState[state]?.isNotEmpty ?? false) ...[
                      SectionHeader(title: reminderStatusLabel(l10n, state)),
                      for (final it in byState[state]!)
                        _card(l10n, fmt, cal, it),
                      const SizedBox(height: PulseTokens.s2),
                    ],
                ],
              ),
            ),
    );
  }

  Widget _card(
    AppLocalizations l10n,
    NumeralFormat fmt,
    CalendarSystem cal,
    ReminderWithState it,
  ) {
    final r = it.reminder;
    final kind = Reminder.triggerKindFromName(r.triggerType);
    return PulseCard(
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusBadge(
                  status: reminderPulseStatus(it.state),
                  label: reminderStatusLabel(l10n, it.state),
                ),
              ],
            ),
            const SizedBox(height: PulseTokens.sHalf),
            Text(
              reminderKindLabel(l10n, kind),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (it.dueAt != null)
              Semantics(
                label: '${l10n.reminderNextDue}: '
                    '${formatDueDate(cal, fmt, it.dueAt!)}',
                child: Text(
                  '${l10n.reminderNextDue}: '
                  '${formatDueDate(cal, fmt, it.dueAt!)}'
                  '${it.isUncertain ? ' · ${l10n.reminderEstimateUncertain}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (it.state != ReminderLiveState.done)
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => unawaited(_complete(it)),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(l10n.reminderComplete),
                  ),
                  const SizedBox(width: PulseTokens.s1),
                  PopupMenuButton<Duration>(
                    tooltip: l10n.reminderSnooze,
                    onSelected: (by) => unawaited(_snooze(r.id, by)),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: const Duration(days: 1),
                        child: Text(l10n.reminderSnooze1Day),
                      ),
                      PopupMenuItem(
                        value: const Duration(days: 7),
                        child: Text(l10n.reminderSnooze1Week),
                      ),
                      PopupMenuItem(
                        value: const Duration(days: 30),
                        child: Text(l10n.reminderSnooze1Month),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: PulseTokens.s2,
                        vertical: PulseTokens.s1,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.snooze, size: 18),
                          const SizedBox(width: PulseTokens.sHalf),
                          Text(l10n.reminderSnooze),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
