import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../../../routing/app_locations.dart';
import '../../../settings/locale_controller.dart';
import '../../01-vehicles-garage/application/vehicle_enums.dart';
import '../../01-vehicles-garage/application/vehicle_profile_providers.dart';
import '../application/fuel_providers.dart';
import 'economy_chart.dart';

/// The Fuel & Economy history (M3-T5): the economy trend chart (CustomPainter),
/// a lifetime-economy stat, and the fill/charge timeline. Economy is projected
/// into the vehicle's display mode (L/100km, or MPG when the vehicle uses
/// miles). All numerals localize; the chart mirrors under RTL.
class FuelHistoryScreen extends ConsumerWidget {
  const FuelHistoryScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries =
        ref.watch(fuelHistoryProvider(vehicleId)).asData?.value ?? const [];
    final report = ref.watch(fuelEconomyProvider(vehicleId)).asData?.value;
    final fmt = ref.watch(activeNumeralFormatProvider);
    final vehicle = ref.watch(vehicleProvider(vehicleId)).asData?.value;
    final useMpg =
        distanceUnitFromCode(vehicle?.distanceUnit) == DistanceUnit.mile;

    String economyText(double mlPerMetre) {
      final value = useMpg ? mpgUs(mlPerMetre) : litresPer100km(mlPerMetre);
      final unit = useMpg ? l10n.economyUnitMpg : l10n.economyUnitL100km;
      return '${fmt.formatScaled((value * 10).round(), 1)} $unit';
    }

    final points = <EconomyPoint>[
      for (final i in report?.intervals ?? const <ConsumptionInterval>[])
        EconomyPoint(
          value: useMpg ? mpgUs(i.mlPerMetre) : litresPer100km(i.mlPerMetre),
          label: economyText(i.mlPerMetre),
        ),
    ];

    return PulseScaffold(
      title: l10n.fuelHistoryTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.fuelAddTitle,
          onPressed: () => context.push(AppLocations.logFuel(vehicleId)),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          PulseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.fuelEconomyLifetime,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: PulseTokens.sHalf),
                Text(
                  report == null || report.pending
                      ? l10n.fuelEconomyPending
                      : economyText(report.lifetimeMlPerMetre!),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (points.length >= 2) ...[
                  const SizedBox(height: PulseTokens.s2),
                  EconomyChart(
                    points: points,
                    semanticsSummary:
                        '${l10n.fuelHistoryTitle}: ${points.map((p) => p.label).join(', ')}',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: PulseTokens.s3),
          if (entries.isEmpty)
            Center(child: Text(l10n.fuelHistoryEmpty))
          else
            for (final e in entries)
              ListTile(
                leading: Icon(e.isCharge
                    ? Icons.ev_station_outlined
                    : Icons.local_gas_station_outlined),
                title: Text(_money(fmt, e)),
                subtitle: e.stationName == null ? null : Text(e.stationName!),
              ),
        ],
      ),
    );
  }

  String _money(NumeralFormat fmt, FuelEntry e) {
    final exp = Currency.tryParse(e.currencyCode)?.exponent ?? 2;
    return '${fmt.formatScaled(e.totalCostMinor, exp)} ${e.currencyCode}';
  }
}
