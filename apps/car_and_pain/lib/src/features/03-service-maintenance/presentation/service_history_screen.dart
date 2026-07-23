import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../../../routing/app_locations.dart';
import '../../../settings/locale_controller.dart';
import '../application/service_providers.dart';

/// The Service & Maintenance history (M4-T4): per-service-type last-done /
/// next-due status cards (status encoded redundantly — icon + label, never
/// colour alone) over the full visit timeline. All numerals + dates localize.
class ServiceHistoryScreen extends ConsumerWidget {
  const ServiceHistoryScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(activeNumeralFormatProvider);
    final cal = ref.watch(activeCalendarProvider);
    final visits =
        ref.watch(serviceHistoryProvider(vehicleId)).asData?.value ?? const [];
    final cards =
        ref.watch(serviceStatusProvider(vehicleId)).asData?.value ?? const [];

    return PulseScaffold(
      title: l10n.serviceHistoryTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.serviceAddTitle,
          onPressed: () => context.push(AppLocations.logService(vehicleId)),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          for (final card in cards) ...[
            _statusCard(context, l10n, fmt, cal, card),
            const SizedBox(height: PulseTokens.s2),
          ],
          if (visits.isEmpty)
            Center(child: Text(l10n.serviceHistoryEmpty))
          else
            for (final v in visits)
              ListTile(
                leading: Icon(
                  v.isDiy ? Icons.build_outlined : Icons.store_outlined,
                ),
                title: Text(_money(fmt, v)),
                subtitle: Text(
                  formatServiceDate(cal, fmt, v.servicedAt),
                ),
              ),
        ],
      ),
    );
  }

  Widget _statusCard(
    BuildContext context,
    AppLocalizations l10n,
    NumeralFormat fmt,
    CalendarSystem cal,
    ServiceStatusCard card,
  ) {
    final level = card.status?.level;
    final badge = switch (level) {
      ServiceDueLevel.ok => (PulseStatus.healthy, l10n.serviceStatusOk),
      ServiceDueLevel.dueSoon => (
          PulseStatus.dueSoon,
          l10n.serviceStatusDueSoon
        ),
      ServiceDueLevel.overdue => (
          PulseStatus.overdue,
          l10n.serviceStatusOverdue
        ),
      _ => null,
    };
    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  serviceTypeName(l10n, card.type),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (badge != null) StatusBadge(status: badge.$1, label: badge.$2),
            ],
          ),
          const SizedBox(height: PulseTokens.sHalf),
          if (card.lastDoneAt != null)
            Text(
              '${l10n.serviceLastDone}: '
              '${formatServiceDate(cal, fmt, card.lastDoneAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (card.status?.nextDueDate != null)
            Text(
              '${l10n.serviceNextDue}: '
              '${formatServiceDate(cal, fmt, card.status!.nextDueDate!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  String _money(NumeralFormat fmt, ServiceVisit v) {
    final exp = Currency.tryParse(v.currencyCode)?.exponent ?? 2;
    return '${fmt.formatScaled(v.totalCostMinor, exp)} ${v.currencyCode}';
  }
}
