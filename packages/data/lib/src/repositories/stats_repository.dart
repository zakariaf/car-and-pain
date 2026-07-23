import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'base_repository.dart';

/// The dashboard read layer (M8-T1). Serves scope KPIs by reading the
/// pre-aggregated `Rollups` table — never a raw-record scan — so a multi-year
/// history resolves instantly. Period buckets are the `YYYY-MM` month keys the
/// rollups maintain (lexicographically range-filterable). Each vehicle's spend
/// carries its own currency, so [DashboardKpis.of] flags a mixed-currency scope
/// instead of adding across currencies.
class StatsRepository extends BaseRepository {
  StatsRepository(super.db, {super.clock});

  /// Live KPIs for one vehicle over an optional inclusive period-key range.
  Stream<DashboardKpis> watchVehicleKpis(
    String vehicleId,
    String currencyCode, {
    String? sincePeriod,
    String? untilPeriod,
  }) {
    return _scopedRollups({vehicleId: currencyCode},
        sincePeriod: sincePeriod, untilPeriod: untilPeriod);
  }

  /// Live KPIs across a set of vehicles (all-vehicles / fleet), each with its own
  /// currency. A scope spanning more than one currency is surfaced as mixed.
  Stream<DashboardKpis> watchScopeKpis(
    Map<String, String> vehicleCurrencies, {
    String? sincePeriod,
    String? untilPeriod,
  }) {
    if (vehicleCurrencies.isEmpty) {
      return Stream.value(DashboardKpis.of(const []));
    }
    return _scopedRollups(vehicleCurrencies,
        sincePeriod: sincePeriod, untilPeriod: untilPeriod);
  }

  /// The fill count for a vehicle in an optional time window — an indexed count,
  /// not a scan of the whole ledger. (Fill count is an event tally, not an
  /// additive rollup.)
  Future<int> fillCount(
    String vehicleId, {
    int? sinceMillis,
    int? untilMillis,
  }) async {
    final q = db.selectOnly(db.fuelEntries)
      ..addColumns([db.fuelEntries.id.count()])
      ..where(db.fuelEntries.vehicleId.equals(vehicleId) &
          db.fuelEntries.isDeleted.equals(false));
    if (sinceMillis != null) {
      q.where(db.fuelEntries.filledAt.isBiggerOrEqualValue(sinceMillis));
    }
    if (untilMillis != null) {
      q.where(db.fuelEntries.filledAt.isSmallerOrEqualValue(untilMillis));
    }
    final row = await q.getSingle();
    return row.read(db.fuelEntries.id.count()) ?? 0;
  }

  Stream<DashboardKpis> _scopedRollups(
    Map<String, String> vehicleCurrencies, {
    String? sincePeriod,
    String? untilPeriod,
  }) {
    final ids = vehicleCurrencies.keys.toList();
    final query = db.select(db.rollups)..where((t) => t.vehicleId.isIn(ids));
    if (sincePeriod != null) {
      query.where((t) => t.periodKey.isBiggerOrEqualValue(sincePeriod));
    }
    if (untilPeriod != null) {
      query.where((t) => t.periodKey.isSmallerOrEqualValue(untilPeriod));
    }
    return query.watch().map((rows) => _fold(vehicleCurrencies, rows));
  }

  DashboardKpis _fold(Map<String, String> currencies, List<Rollup> rows) {
    // Sum each vehicle's additive metrics, then build one contribution per
    // vehicle so the aggregator can flag mixed currencies.
    final cost = <String, int>{};
    final fuel = <String, int>{};
    final distance = <String, int>{};
    for (final r in rows) {
      switch (r.metric) {
        case 'costMinor':
          cost[r.vehicleId] = (cost[r.vehicleId] ?? 0) + r.value;
        case 'fuelMl':
          fuel[r.vehicleId] = (fuel[r.vehicleId] ?? 0) + r.value;
        case 'distanceMetres':
          distance[r.vehicleId] = (distance[r.vehicleId] ?? 0) + r.value;
      }
    }
    return DashboardKpis.of([
      for (final id in currencies.keys)
        KpiContribution(
          currencyCode: currencies[id]!,
          spendMinor: cost[id] ?? 0,
          fuelMl: fuel[id] ?? 0,
          distanceMetres: distance[id] ?? 0,
        ),
    ]);
  }
}
