import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import '../../../shell/shell_state.dart';

/// The dashboard period filter (M8-T9). Ephemeral UI state; the KPI-layout
/// preference is what persists (M8-T5).
enum DashboardPeriod { thisMonth, thisYear, allTime }

/// The selected period (defaults to this month).
class DashboardPeriodNotifier extends Notifier<DashboardPeriod> {
  @override
  DashboardPeriod build() => DashboardPeriod.thisMonth;

  DashboardPeriod get value => state;

  set value(DashboardPeriod period) => state = period;
}

final dashboardPeriodProvider =
    NotifierProvider<DashboardPeriodNotifier, DashboardPeriod>(
        DashboardPeriodNotifier.new);

String _monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// The (sincePeriod, untilPeriod) rollup-key range for a period, computed off
/// the current wall clock. All-time is (null, null).
(String?, String?) _range(DashboardPeriod period, DateTime now) =>
    switch (period) {
      DashboardPeriod.thisMonth => (_monthKey(now), _monthKey(now)),
      DashboardPeriod.thisYear => (
          '${now.year}-01',
          '${now.year}-12',
        ),
      DashboardPeriod.allTime => (null, null),
    };

/// The currency map for the vehicles in the current scope.
final _scopeCurrenciesProvider = Provider<Map<String, String>>((ref) {
  final ids = ref.watch(scopedVehicleIdsProvider);
  final vehicles = ref.watch(activeVehiclesProvider);
  final byId = {for (final v in vehicles) v.id: v};
  return {
    for (final id in ids) id: byId[id]?.currencyCode ?? 'EUR',
  };
});

/// The scope + period KPIs (M8-T1/T9), live over the rollups.
final dashboardKpisProvider = StreamProvider<DashboardKpis>((ref) {
  final currencies = ref.watch(_scopeCurrenciesProvider);
  final period = ref.watch(dashboardPeriodProvider);
  final (since, until) = _range(period, DateTime.now().toUtc());
  return ref
      .watch(statsRepositoryProvider)
      .watchScopeKpis(currencies, sincePeriod: since, untilPeriod: until);
});

/// The active vehicle's monthly spend series for the cost-over-time chart.
final spendSeriesProvider = StreamProvider<List<int>>((ref) {
  final id = ref.watch(activeVehicleIdProvider);
  if (id == null) return Stream.value(const <int>[]);
  return ref.watch(statsRepositoryProvider).watchMonthlyMetric(id, 'costMinor');
});

/// The active vehicle's monthly distance series (distance-over-time chart).
final distanceSeriesProvider = StreamProvider<List<int>>((ref) {
  final id = ref.watch(activeVehicleIdProvider);
  if (id == null) return Stream.value(const <int>[]);
  return ref
      .watch(statsRepositoryProvider)
      .watchMonthlyMetric(id, 'distanceMetres');
});

/// A spend forecast for the next 30 days, or an insufficient-data result.
/// Samples = number of months with spend; span = months × ~30 days.
final spendForecastProvider = Provider<ForecastResult>((ref) {
  final series = ref.watch(spendSeriesProvider).asData?.value ?? const <int>[];
  final total = series.fold<int>(0, (s, v) => s + v);
  final months = series.where((v) => v != 0).length;
  return const ForecastEngine().spend(
    totalSpendMinor: total,
    samples: months,
    spanDays: months * 30,
    horizonDays: 30,
  );
});

/// Rule-based insights from the active vehicle's own monthly spend history:
/// the latest month vs the average of the earlier months (a spend spike).
final dashboardInsightsProvider = Provider<List<Insight>>((ref) {
  final series = ref.watch(spendSeriesProvider).asData?.value ?? const <int>[];
  if (series.length < 3) return const [];
  final latest = series.last;
  final earlier = series.sublist(0, series.length - 1);
  final avg = earlier.fold<int>(0, (s, v) => s + v) ~/ earlier.length;
  const engine = InsightEngine();
  return engine.evaluate([
    engine.spendAboveNorm(currentSpendMinor: latest, avgSpendMinor: avg),
  ]);
});

// ── display helpers (features never import each other → local, l10n-fed) ──────

String formatMoney(NumeralFormat fmt, int minorUnits, String currencyCode) {
  final exp = Currency.tryParse(currencyCode)?.exponent ?? 2;
  return '${fmt.formatScaled(minorUnits, exp)} $currencyCode';
}

String formatDistanceKm(NumeralFormat fmt, int metres) =>
    fmt.formatScaled((metres / 100).round(), 1); // metres → km, 1 decimal

/// L/100km from the scaled (×100) integer, or a dash.
String formatEconomy(NumeralFormat fmt, int? litresPer100kmScaled) =>
    litresPer100kmScaled == null
        ? '—'
        : fmt.formatScaled(litresPer100kmScaled, 2);

String formatKg(NumeralFormat fmt, int grams) =>
    fmt.formatScaled((grams / 10).round(), 2); // grams → kg (×100 scale)
