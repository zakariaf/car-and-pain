import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../../../routing/app_locations.dart';
import '../../../settings/locale_controller.dart';
import '../application/vehicle_enums.dart';
import '../application/vehicle_profile_providers.dart';

/// The A4 vehicle-profile screen (M2-T6): identity, powertrain specs, and the
/// estimated-current-odometer (last actual + avg_daily × days_since) with an
/// explicit "estimated" marker. Lifecycle status is redundantly encoded (icon +
/// label), never colour alone. Edit + lifecycle actions live in the app bar.
class VehicleProfileScreen extends ConsumerWidget {
  const VehicleProfileScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vehicle = ref.watch(vehicleProvider(vehicleId)).asData?.value;
    if (vehicle == null) {
      return PulseScaffold(
        title: pulseLabel(l10n, 'room.garage'),
        body: const SizedBox.shrink(),
      );
    }
    final readings =
        ref.watch(vehicleLedgerProvider(vehicleId)).asData?.value ??
            const <LedgerReading>[];
    final fmt = ref.watch(activeNumeralFormatProvider);

    return PulseScaffold(
      title: vehicle.nickname,
      actions: [
        IconButton(
          icon: const Icon(Icons.local_gas_station_outlined),
          tooltip: l10n.fuelHistoryTitle,
          onPressed: () => context.push(AppLocations.fuelHistory(vehicleId)),
        ),
        IconButton(
          icon: const Icon(Icons.route_outlined),
          tooltip: l10n.tripsTitle,
          onPressed: () => context.push(AppLocations.trips(vehicleId)),
        ),
        IconButton(
          icon: const Icon(Icons.insights_outlined),
          tooltip: l10n.dashboardTitle,
          onPressed: () => context.push(AppLocations.dashboard),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.vehicleEdit,
          onPressed: () => context.push(AppLocations.editVehicle(vehicleId)),
        ),
        _LifecycleMenu(vehicleId: vehicleId, status: vehicle.status),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          _StatusRow(status: vehicle.status),
          const SizedBox(height: PulseTokens.s3),
          InkWell(
            onTap: () => context.push(AppLocations.vehicleLedger(vehicleId)),
            child:
                _OdometerCard(vehicle: vehicle, readings: readings, fmt: fmt),
          ),
          const SizedBox(height: PulseTokens.s3),
          SectionHeader(title: l10n.vehicleSectionIdentity),
          _IdentityCard(vehicle: vehicle, fmt: fmt, l10n: l10n),
          const SizedBox(height: PulseTokens.s3),
          SectionHeader(title: l10n.vehicleSpecsSection),
          _SpecsCard(vehicle: vehicle, fmt: fmt, l10n: l10n),
        ],
      ),
    );
  }
}

String vehicleStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'archived' => l10n.vehicleStatusArchived,
      'sold' => l10n.vehicleStatusSold,
      'scrapped' => l10n.vehicleStatusScrapped,
      'stolen' => l10n.vehicleStatusStolen,
      'written_off' => l10n.vehicleStatusWrittenOff,
      _ => l10n.vehicleStatusActive,
    };

IconData _statusIcon(String status) => switch (status) {
      'archived' => Icons.inventory_2_outlined,
      'sold' => Icons.sell_outlined,
      'scrapped' => Icons.delete_forever_outlined,
      'stolen' => Icons.report_outlined,
      'written_off' => Icons.car_crash_outlined,
      _ => Icons.check_circle_outline,
    };

DistanceUnit _distanceUnitOf(Vehicle v) => switch (v.distanceUnit) {
      'mile' => DistanceUnit.mile,
      'metre' => DistanceUnit.metre,
      _ => DistanceUnit.kilometre,
    };

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Redundant encoding: icon + text label together (never colour alone).
    return Row(
      children: [
        Icon(_statusIcon(status)),
        const SizedBox(width: PulseTokens.s1),
        Text(vehicleStatusLabel(l10n, status),
            style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _OdometerCard extends StatelessWidget {
  const _OdometerCard({
    required this.vehicle,
    required this.readings,
    required this.fmt,
  });

  final Vehicle vehicle;
  final List<LedgerReading> readings;
  final NumeralFormat fmt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const engine = LedgerEngine();
    final unit = _distanceUnitOf(vehicle);

    // Prefer the freshest actual reading; fall back to a flagged estimate.
    final lastActual = readings.isEmpty
        ? null
        : readings
            .reduce((a, b) =>
                a.takenAt.epochMillis >= b.takenAt.epochMillis ? a : b)
            .lifetimeValue;
    final estimated = engine.estimatedValueNow(readings);
    final showEstimate =
        estimated != null && lastActual != null && estimated > lastActual;
    final value = showEstimate ? estimated : lastActual;

    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.vehicleOdometer,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: PulseTokens.sHalf),
          if (value == null)
            Text(l10n.vehicleNoReadings)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  fmt.formatInt(Distance.metres(value).toDisplay(unit).round()),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(width: PulseTokens.s1),
                if (showEstimate)
                  StatusBadge(
                    status: PulseStatus.dueSoon,
                    label: l10n.vehicleEstimated,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard(
      {required this.vehicle, required this.fmt, required this.l10n});
  final Vehicle vehicle;
  final NumeralFormat fmt;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PulseCard(
      child: Column(
        children: [
          if (vehicle.displayModel.isNotEmpty)
            _Row(l10n.vehicleMake, Text(vehicle.displayModel)),
          if (vehicle.modelYear != null)
            _Row(l10n.vehicleYear,
                Text(fmt.formatUngrouped(vehicle.modelYear!))),
          if (vehicle.vin != null) _Row(l10n.vehicleVin, LtrText(vehicle.vin!)),
          if (vehicle.licensePlate != null)
            _Row(l10n.vehiclePlate, LtrText(vehicle.licensePlate!)),
        ],
      ),
    );
  }
}

class _SpecsCard extends StatelessWidget {
  const _SpecsCard(
      {required this.vehicle, required this.fmt, required this.l10n});
  final Vehicle vehicle;
  final NumeralFormat fmt;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final energy = energyTypeFromCode(vehicle.energyType);
    return PulseCard(
      child: Column(
        children: [
          _Row(
              l10n.vehicleTypeLabel,
              Text(vehicleTypeLabel(
                  l10n, vehicleTypeFromCode(vehicle.vehicleType)))),
          if (energy != null)
            _Row(l10n.vehicleEnergyLabel, Text(energyTypeLabel(l10n, energy))),
          if (vehicle.tankCapacityMl != null)
            _Row(l10n.vehicleTankCapacity,
                Text(fmt.formatScaled(vehicle.tankCapacityMl!, 3))),
          if (vehicle.batteryCapacityJoules != null)
            _Row(
              l10n.vehicleBatteryCapacity,
              Text(fmt.formatScaled(
                (Energy.joules(vehicle.batteryCapacityJoules!)
                            .toDisplay(EnergyUnit.kilowattHour) *
                        1000)
                    .round(),
                3,
              )),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final pc = Theme.of(context).extension<PulseColorsExt>()!.c;
    return Padding(
      padding:
          const EdgeInsetsDirectional.symmetric(vertical: PulseTokens.sHalf),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: pc.text2)),
          const SizedBox(width: PulseTokens.s2),
          Flexible(
              child: Align(
                  alignment: AlignmentDirectional.centerEnd, child: value)),
        ],
      ),
    );
  }
}

/// The lifecycle actions (M2-T5): archive / mark-sold / restore, wired to the
/// repository's `setStatus`.
class _LifecycleMenu extends ConsumerWidget {
  const _LifecycleMenu({required this.vehicleId, required this.status});
  final String vehicleId;
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.watch(vehiclesRepositoryProvider);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (v) => repo.setStatus(vehicleId, v),
      itemBuilder: (context) => [
        if (status != 'active')
          PopupMenuItem(
              value: 'active', child: Text(l10n.vehicleRestoreActive)),
        if (status != 'archived')
          PopupMenuItem(value: 'archived', child: Text(l10n.vehicleArchive)),
        if (status != 'sold')
          PopupMenuItem(value: 'sold', child: Text(l10n.vehicleMarkSold)),
      ],
    );
  }
}
