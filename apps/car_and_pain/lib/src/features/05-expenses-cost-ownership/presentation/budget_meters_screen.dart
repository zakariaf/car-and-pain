import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import '../../../settings/locale_controller.dart';
import '../application/expense_providers.dart';

/// Budget meters (M6-T6): per-budget current / limit / projected, over-budget
/// shown by icon + label + shape (StatusBadge), never colour alone. A projected
/// overspend shows the due-soon warning; being within budget reads calm.
class BudgetMetersScreen extends ConsumerWidget {
  const BudgetMetersScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(budgetMetersProvider(vehicleId));
    final fmt = ref.watch(activeNumeralFormatProvider);

    return PulseScaffold(
      title: l10n.budgetsTitle,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.budgetsError)),
        data: (meters) => meters.isEmpty
            ? Center(child: Text(l10n.budgetsEmpty))
            : ListView(
                padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
                children: [
                  for (final m in meters) _meterCard(context, l10n, fmt, m)
                ],
              ),
      ),
    );
  }

  Widget _meterCard(
    BuildContext context,
    AppLocalizations l10n,
    NumeralFormat fmt,
    BudgetMeter m,
  ) {
    final (status, label) = m.status.isOverBudget
        ? (PulseStatus.overdue, l10n.budgetOverLabel)
        : m.status.isProjectedOver
            ? (PulseStatus.dueSoon, l10n.budgetProjectedOverLabel)
            : (PulseStatus.healthy, l10n.budgetWithinLabel);
    final ccy = m.budget.currencyCode;
    final pct = (m.status.percentUsed / 100).clamp(0.0, 1.0);

    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.budgetPeriodLabel(m.budget.period),
                  style: Theme.of(context).textTheme.titleMedium),
              StatusBadge(status: status, label: label),
            ],
          ),
          const SizedBox(height: PulseTokens.s2),
          // A non-colour-only meter: the bar's fill AND the numeric labels convey
          // usage; the badge above conveys the state redundantly.
          ClipRRect(
            borderRadius: BorderRadius.circular(PulseTokens.rPill),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              semanticsLabel: label,
            ),
          ),
          const SizedBox(height: PulseTokens.s2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatTile(
                value: formatMoney(fmt, m.status.spentMinor, ccy),
                label: l10n.budgetCurrent,
              ),
              StatTile(
                value: formatMoney(fmt, m.status.targetMinor, ccy),
                label: l10n.budgetLimit,
              ),
              StatTile(
                value: formatMoney(fmt, m.status.projectedMinor, ccy),
                label: l10n.budgetProjected,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
