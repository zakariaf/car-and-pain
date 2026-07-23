import 'dart:async';

import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../../../settings/locale_controller.dart';
import '../application/reminder_providers.dart';

/// A single reminder's detail (M5-T3) — the notification deep-link target. Shows
/// the live status (redundantly encoded), the projected due date, and the
/// snooze / complete / delete actions. Completion plays the shared exhale.
class ReminderDetailScreen extends ConsumerStatefulWidget {
  const ReminderDetailScreen({
    required this.vehicleId,
    required this.reminderId,
    super.key,
  });

  final String vehicleId;
  final String reminderId;

  @override
  ConsumerState<ReminderDetailScreen> createState() => _State();
}

class _State extends ConsumerState<ReminderDetailScreen> {
  int _exhale = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(activeNumeralFormatProvider);
    final cal = ref.watch(activeCalendarProvider);
    final items =
        ref.watch(reminderLiveStatesProvider(widget.vehicleId)).asData?.value ??
            const <ReminderWithState>[];
    ReminderWithState? item;
    for (final it in items) {
      if (it.reminder.id == widget.reminderId) item = it;
    }

    return PulseScaffold(
      title: l10n.reminderDetailTitle,
      body: item == null
          ? Center(child: Text(l10n.reminderNotFound))
          : ExhaleSettle(
              trigger: _exhale,
              child: ListView(
                padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
                children: [
                  PulseCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.reminder.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            StatusBadge(
                              status: reminderPulseStatus(item.state),
                              label: reminderStatusLabel(l10n, item.state),
                            ),
                          ],
                        ),
                        const SizedBox(height: PulseTokens.sHalf),
                        Text(
                          reminderKindLabel(
                            l10n,
                            Reminder.triggerKindFromName(
                                item.reminder.triggerType),
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (item.dueAt != null)
                          Text(
                            '${l10n.reminderNextDue}: '
                            '${formatDueDate(cal, fmt, item.dueAt!)}'
                            '${item.isUncertain ? ' · ${l10n.reminderEstimateUncertain}' : ''}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (item.reminder.notes != null) ...[
                          const SizedBox(height: PulseTokens.s1),
                          Text(item.reminder.notes!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: PulseTokens.s3),
                  PulseButton(
                    label: l10n.reminderComplete,
                    icon: Icons.check_circle_outline,
                    onPressed: () => unawaited(_complete(item!)),
                  ),
                  const SizedBox(height: PulseTokens.s2),
                  PulseButton(
                    label: l10n.reminderDelete,
                    icon: Icons.delete_outline,
                    variant: PulseButtonVariant.ghost,
                    onPressed: () => unawaited(_delete()),
                  ),
                ],
              ),
            ),
    );
  }

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
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    await ref.read(remindersRepositoryProvider).softDelete(widget.reminderId);
    if (mounted) context.pop();
  }
}
