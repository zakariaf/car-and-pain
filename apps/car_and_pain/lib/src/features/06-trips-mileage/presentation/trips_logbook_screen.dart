import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../../../routing/app_locations.dart';
import '../../../settings/locale_controller.dart';
import '../../01-vehicles-garage/application/vehicle_profile_providers.dart';
import '../application/trip_providers.dart';
import 'trip_ui.dart';

/// The trip logbook (M7-T5): a live list of a vehicle's trips with a fast
/// one-tap classification toggle to clear the unclassified backlog, and a
/// summary strip (distance, business-use %, YTD deduction) over the set. Every
/// status is redundantly encoded (icon + text label + shape), never colour only.
class TripsLogbookScreen extends ConsumerWidget {
  const TripsLogbookScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final trips =
        ref.watch(tripHistoryProvider(vehicleId)).asData?.value ?? const [];
    final rollup = ref.watch(tripRollupProvider(vehicleId));
    final fmt = ref.watch(activeNumeralFormatProvider);
    final cal = ref.watch(activeCalendarProvider);
    final vehicle = ref.watch(vehicleProvider(vehicleId)).asData?.value;
    final unit = distanceUnitOf(vehicle?.distanceUnit);

    return PulseScaffold(
      title: l10n.tripsTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.summarize_outlined),
          tooltip: l10n.mileageReportTitle,
          onPressed: () => context.push(AppLocations.mileageReport(vehicleId)),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.tripAddTitle,
          onPressed: () => context.push(AppLocations.logTrip(vehicleId)),
        ),
      ],
      body: trips.isEmpty
          ? Center(child: Text(l10n.tripsEmpty))
          : ListView(
              padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
              children: [
                _SummaryStrip(rollup: rollup, unit: unit, fmt: fmt, l10n: l10n),
                const SizedBox(height: PulseTokens.s3),
                for (final t in trips)
                  _TripCard(
                    trip: t,
                    unit: unit,
                    fmt: fmt,
                    cal: cal,
                    l10n: l10n,
                    onClassify: (c) => _classify(ref, context, t, c),
                    onOpen: () =>
                        context.push(AppLocations.editTrip(vehicleId, t.id)),
                  ),
              ],
            ),
    );
  }

  Future<void> _classify(
    WidgetRef ref,
    BuildContext context,
    Trip trip,
    TripClassification c,
  ) async {
    final result = await ref.read(tripsRepositoryProvider).classify(trip.id, c);
    if (!context.mounted) return;
    if (result.isErr) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tripSaveFailed)),
      );
    }
  }
}

/// The filtered-set summary: total distance, business-use %, YTD deduction.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.rollup,
    required this.unit,
    required this.fmt,
    required this.l10n,
  });

  final TripRollup rollup;
  final DistanceUnit unit;
  final NumeralFormat fmt;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PulseCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          StatTile(
            value: formatDistance(fmt, rollup.totalDistanceMetres, unit),
            label: l10n.tripSummaryDistance,
          ),
          StatTile(
            value: formatBusinessUse(fmt, rollup.businessUseBasisPoints) ??
                l10n.tripSummaryNoData,
            label: l10n.tripSummaryBusinessUse,
          ),
          StatTile(
            value: fmt.formatInt(rollup.unclassifiedCount),
            label: l10n.tripSummaryUnclassified,
          ),
        ],
      ),
    );
  }
}

/// One trip row: redundant status (icon + label), distance, date, gap warning,
/// and a one-tap classify menu.
class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.unit,
    required this.fmt,
    required this.cal,
    required this.l10n,
    required this.onClassify,
    required this.onOpen,
  });

  final Trip trip;
  final DistanceUnit unit;
  final NumeralFormat fmt;
  final CalendarSystem cal;
  final AppLocalizations l10n;
  final ValueChanged<TripClassification> onClassify;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = classificationBadge(l10n, trip.classification);
    return PulseCard(
      // A transparent Material so the tap ink paints above the card's fill.
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: onOpen,
          leading: Icon(icon),
          title: Text(formatDistance(fmt, trip.distanceMetres, unit)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatTripDate(cal, fmt, trip.tripAt)),
              const SizedBox(height: PulseTokens.sHalf),
              Wrap(
                spacing: PulseTokens.s2,
                runSpacing: PulseTokens.sHalf,
                children: [
                  _Badge(icon: icon, label: label),
                  if (!trip.isContemporaneous)
                    _Badge(
                      icon: Icons.history_edu_outlined,
                      label: l10n.tripReconstructed,
                    ),
                  if (trip.hasGapWarning)
                    _Badge(
                      icon: Icons.warning_amber_outlined,
                      label: l10n.tripGapWarning,
                    ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<TripClassification>(
            icon: const Icon(Icons.label_outline),
            tooltip: l10n.tripClassifyTooltip,
            onSelected: onClassify,
            itemBuilder: (context) => [
              for (final c in TripClassification.values)
                PopupMenuItem(
                  value: c,
                  child: Text(classificationBadge(l10n, c).$2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A redundant status chip: icon (distinct shape) + text label, never colour
/// alone.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: PulseTokens.sHalf),
        Text(label, style: style),
      ],
    );
  }
}
