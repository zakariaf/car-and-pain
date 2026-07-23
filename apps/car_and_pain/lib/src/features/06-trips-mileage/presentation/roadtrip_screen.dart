import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import '../../../settings/locale_controller.dart';
import '../../01-vehicles-garage/application/vehicle_profile_providers.dart';
import '../application/trip_providers.dart';
import 'trip_ui.dart';

/// Road-trip mode (M7-T4): multi-day containers grouping legs into one live P&L
/// (distance, spend, daily average, per-person share, cost/km). With no offline
/// map available (the Tier-2 module is absent), waypoints degrade HONESTLY to a
/// clear "map unavailable" affordance — never a blank or fabricated map.
class RoadtripScreen extends ConsumerWidget {
  const RoadtripScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final containers =
        ref.watch(roadtripListProvider(vehicleId)).asData?.value ?? const [];
    final fmt = ref.watch(activeNumeralFormatProvider);
    final vehicle = ref.watch(vehicleProvider(vehicleId)).asData?.value;
    final unit = distanceUnitOf(vehicle?.distanceUnit);

    return PulseScaffold(
      title: l10n.roadtripsTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.roadtripAdd,
          onPressed: () =>
              _create(context, ref, vehicle?.currencyCode ?? 'EUR'),
        ),
      ],
      body: containers.isEmpty
          ? Center(child: Text(l10n.roadtripsEmpty))
          : ListView(
              padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
              children: [
                for (final c in containers)
                  _RoadtripCard(container: c, unit: unit, fmt: fmt, l10n: l10n),
              ],
            ),
    );
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    String currencyCode,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.roadtripAdd),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.roadtripName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.tripCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.tripSave),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty || !context.mounted) return;
    await ref.read(roadtripsRepositoryProvider).add(
          vehicleId: vehicleId,
          title: title,
          startAt: Instant.fromDateTime(const SystemClock().nowUtc()),
          currencyCode: currencyCode,
        );
  }
}

class _RoadtripCard extends ConsumerWidget {
  const _RoadtripCard({
    required this.container,
    required this.unit,
    required this.fmt,
    required this.l10n,
  });

  final Roadtrip container;
  final DistanceUnit unit;
  final NumeralFormat fmt;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legs =
        ref.watch(roadtripLegsProvider(container.id)).asData?.value ?? const [];
    final pnl = roadtripPnl(container, legs);
    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(container.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: PulseTokens.s2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatTile(
                value: formatDistance(fmt, pnl.distanceMetres, unit),
                label: l10n.tripSummaryDistance,
              ),
              StatTile(
                value: formatMoney(
                    fmt, pnl.totalCostMinor, container.currencyCode),
                label: l10n.roadtripSpend,
              ),
              StatTile(
                value: formatMoney(
                    fmt, pnl.perPersonShareMinor, container.currencyCode),
                label: l10n.roadtripPerPerson,
              ),
            ],
          ),
          const SizedBox(height: PulseTokens.s2),
          // Offline-honesty: no map module present → a clear unavailable state.
          Row(
            children: [
              const Icon(Icons.map_outlined, size: 16),
              const SizedBox(width: PulseTokens.sHalf),
              Expanded(child: Text(l10n.roadtripMapUnavailable)),
            ],
          ),
        ],
      ),
    );
  }
}
