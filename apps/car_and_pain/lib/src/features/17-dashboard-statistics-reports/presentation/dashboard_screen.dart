import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../../../routing/app_locations.dart';
import '../../../settings/locale_controller.dart';
import '../../../shell/shell_state.dart';
import '../application/dashboard_providers.dart';

/// The analytics dashboard (M8-T5/T9): active-vehicle header + scope toggle, a
/// period filter, KPI tiles, a cost-over-time CustomPainter chart, an honest
/// forecast (insufficient-data aware), rule-based insights, and quick-add — all
/// reading pre-aggregated rollups. CSV export copies canonical KPIs.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(activeNumeralFormatProvider);
    final vehicle = ref.watch(activeVehicleProvider);
    final scope = ref.watch(scopeProvider);
    final period = ref.watch(dashboardPeriodProvider);
    final kpis = ref.watch(dashboardKpisProvider).asData?.value;

    if (vehicle == null) {
      return PulseScaffold(
        title: l10n.dashboardTitle,
        body: Center(child: Text(l10n.dashboardNoVehicle)),
      );
    }

    return PulseScaffold(
      title: l10n.dashboardTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share),
          tooltip: l10n.reportExport,
          onPressed: kpis == null
              ? null
              : () => _exportCsv(context, l10n, kpis, scope),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          Text(vehicle.nickname, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: PulseTokens.s2),
          _ScopeToggle(scope: scope, l10n: l10n),
          const SizedBox(height: PulseTokens.s2),
          _PeriodToggle(period: period, l10n: l10n),
          const SizedBox(height: PulseTokens.s3),
          if (kpis == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            _KpiGrid(kpis: kpis, fmt: fmt, l10n: l10n),
            const SizedBox(height: PulseTokens.s3),
            SectionHeader(title: l10n.dashboardSpendTrend),
            _SpendChart(l10n: l10n, fmt: fmt),
            const SizedBox(height: PulseTokens.s3),
            _ForecastCard(l10n: l10n, fmt: fmt, currency: kpis.currencyCode),
            const SizedBox(height: PulseTokens.s3),
            _InsightsCard(l10n: l10n),
            const SizedBox(height: PulseTokens.s3),
            SectionHeader(title: l10n.dashboardQuickAdd),
            _QuickAdd(vehicleId: vehicle.id, l10n: l10n),
          ],
        ],
      ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    AppLocalizations l10n,
    DashboardKpis k,
    VehicleScope scope,
  ) async {
    final csv = StringBuffer()
      ..writeln('kpi,value,unit')
      ..writeln('spend_minor,${k.mixedCurrency ? '' : k.spendMinor},'
          '${k.currencyCode}')
      ..writeln('distance_metres,${k.distanceMetres},m')
      ..writeln('fuel_ml,${k.fuelMl},ml')
      ..writeln('cost_per_km_minor,${k.costPerKmMinor ?? ''},${k.currencyCode}')
      ..writeln('co2_grams,${k.co2Grams},g');
    await Clipboard.setData(ClipboardData(text: csv.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.reportCopied)));
  }
}

class _ScopeToggle extends ConsumerWidget {
  const _ScopeToggle({required this.scope, required this.l10n});
  final VehicleScope scope;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fleet folds into the all-vehicles segment for this toggle.
    final selected = scope == VehicleScope.perVehicle
        ? VehicleScope.perVehicle
        : VehicleScope.allVehicles;
    return SegmentedButton<VehicleScope>(
      segments: [
        ButtonSegment(
            value: VehicleScope.perVehicle,
            label: Text(l10n.dashboardScopeVehicle)),
        ButtonSegment(
            value: VehicleScope.allVehicles,
            label: Text(l10n.dashboardScopeAll)),
      ],
      selected: {selected},
      onSelectionChanged: (s) =>
          ref.read(shellStateControllerProvider).setScope(s.first),
    );
  }
}

class _PeriodToggle extends ConsumerWidget {
  const _PeriodToggle({required this.period, required this.l10n});
  final DashboardPeriod period;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<DashboardPeriod>(
      segments: [
        ButtonSegment(
            value: DashboardPeriod.thisMonth,
            label: Text(l10n.dashboardPeriodMonth)),
        ButtonSegment(
            value: DashboardPeriod.thisYear,
            label: Text(l10n.dashboardPeriodYear)),
        ButtonSegment(
            value: DashboardPeriod.allTime,
            label: Text(l10n.dashboardPeriodAll)),
      ],
      selected: {period},
      onSelectionChanged: (s) =>
          ref.read(dashboardPeriodProvider.notifier).value = s.first,
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis, required this.fmt, required this.l10n});
  final DashboardKpis kpis;
  final NumeralFormat fmt;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PulseCard(
      child: Wrap(
        spacing: PulseTokens.s3,
        runSpacing: PulseTokens.s3,
        alignment: WrapAlignment.spaceAround,
        children: [
          StatTile(
            value: kpis.mixedCurrency
                ? l10n.dashboardMixedCurrency
                : formatMoney(fmt, kpis.spendMinor, kpis.currencyCode),
            label: l10n.dashboardKpiSpend,
          ),
          StatTile(
            value: formatDistanceKm(fmt, kpis.distanceMetres),
            label: l10n.dashboardKpiDistance,
          ),
          StatTile(
            value: kpis.costPerKmMinor == null || kpis.mixedCurrency
                ? '—'
                : formatMoney(fmt, kpis.costPerKmMinor!, kpis.currencyCode),
            label: l10n.dashboardKpiCostPerKm,
          ),
          StatTile(
            value: formatEconomy(fmt, kpis.litresPer100kmScaled),
            label: l10n.dashboardKpiEconomy,
          ),
          StatTile(
            value: formatKg(fmt, kpis.co2Grams),
            label: l10n.dashboardKpiCo2,
          ),
        ],
      ),
    );
  }
}

class _SpendChart extends ConsumerWidget {
  const _SpendChart({required this.l10n, required this.fmt});
  final AppLocalizations l10n;
  final NumeralFormat fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(spendSeriesProvider).asData?.value ?? const [];
    if (series.isEmpty) {
      return PulseCard(child: Text(l10n.dashboardNoData));
    }
    return PulseCard(
      child: PulseBarChart(
        values: [for (final v in series) v.toDouble()],
        semanticsSummary: l10n.dashboardSpendTrendSemantics(
          fmt.formatInt(series.length),
        ),
      ),
    );
  }
}

class _ForecastCard extends ConsumerWidget {
  const _ForecastCard({
    required this.l10n,
    required this.fmt,
    required this.currency,
  });
  final AppLocalizations l10n;
  final NumeralFormat fmt;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(spendForecastProvider);
    final (icon, text) = switch (forecast) {
      SpendForecast(:final projectedSpendMinor) => (
          Icons.trending_up,
          l10n.dashboardForecastSpend(
              formatMoney(fmt, projectedSpendMinor, currency)),
        ),
      ForecastInsufficient() => (
          Icons.hourglass_empty,
          l10n.dashboardForecastInsufficient,
        ),
      _ => (Icons.help_outline, l10n.dashboardNoData),
    };
    return PulseCard(
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: PulseTokens.s2),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _InsightsCard extends ConsumerWidget {
  const _InsightsCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(dashboardInsightsProvider);
    if (insights.isEmpty) {
      return PulseCard(
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline),
            const SizedBox(width: PulseTokens.s2),
            Expanded(child: Text(l10n.dashboardNoInsights)),
          ],
        ),
      );
    }
    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in insights)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: PulseTokens.s1),
              child: Row(
                children: [
                  const Icon(Icons.insights_outlined, size: 18),
                  const SizedBox(width: PulseTokens.s2),
                  Expanded(child: Text(_insightText(l10n, i))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _insightText(AppLocalizations l10n, Insight i) => switch (i.kind) {
        InsightKind.spendSpike => l10n.insightSpendSpike,
        InsightKind.economyDrop => l10n.insightEconomyDrop,
        InsightKind.odometerGap => l10n.insightOdometerGap,
        InsightKind.odometerRegression => l10n.insightOdometerRegression,
        InsightKind.duplicateEntry => l10n.insightDuplicate,
      };
}

class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.vehicleId, required this.l10n});
  final String vehicleId;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PulseButton(
            label: l10n.dashboardAddFuel,
            icon: Icons.local_gas_station_outlined,
            variant: PulseButtonVariant.ghost,
            onPressed: () => context.push(AppLocations.logFuel(vehicleId)),
          ),
        ),
        const SizedBox(width: PulseTokens.s2),
        Expanded(
          child: PulseButton(
            label: l10n.dashboardAddExpense,
            icon: Icons.receipt_long_outlined,
            variant: PulseButtonVariant.ghost,
            onPressed: () => context.push(AppLocations.logExpense(vehicleId)),
          ),
        ),
        const SizedBox(width: PulseTokens.s2),
        Expanded(
          child: PulseButton(
            label: l10n.dashboardAddTrip,
            icon: Icons.route_outlined,
            variant: PulseButtonVariant.ghost,
            onPressed: () => context.push(AppLocations.logTrip(vehicleId)),
          ),
        ),
      ],
    );
  }
}
