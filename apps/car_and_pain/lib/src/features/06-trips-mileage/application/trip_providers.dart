import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

/// A vehicle's trip logbook, newest first (live).
final tripHistoryProvider = StreamProvider.family<List<Trip>, String>(
  (ref, id) => ref.watch(tripsRepositoryProvider).watchByVehicle(id),
);

/// The saved-locations address book (live).
final savedLocationsProvider = StreamProvider<List<SavedLocation>>(
  (ref) => ref.watch(savedLocationsRepositoryProvider).watchAll(),
);

/// A vehicle's road-trip containers (live).
final roadtripListProvider = StreamProvider.family<List<Roadtrip>, String>(
  (ref, id) => ref.watch(roadtripsRepositoryProvider).watchByVehicle(id),
);

/// The legs (trips) linked to a road-trip container (live), leg-ordered.
final roadtripLegsProvider = StreamProvider.family<List<Trip>, String>(
  (ref, roadtripId) =>
      ref.watch(tripsRepositoryProvider).watchByRoadtrip(roadtripId),
);

/// A road-trip container's rolled-up P&L from its legs + linked expense costs.
/// Fuel-fill cost aggregation rides the linked-fills path (deferred); the
/// engine's full-to-full economy is not double-counted here.
RoadTripPnl roadtripPnl(Roadtrip container, List<Trip> legs) {
  final spanDays = container.endAt == null
      ? 1
      : (container.endAt!.epochMillis - container.startAt.epochMillis) ~/
              Duration.millisecondsPerDay +
          1;
  return RoadTripPnl.of(RoadTripInput(
    currencyCode: container.currencyCode,
    legDistancesMetres: [for (final t in legs) t.distanceMetres],
    expenseCostMinor: legs.fold(0, (sum, t) => sum + (t.costMinor ?? 0)),
    spanDays: spanDays < 1 ? 1 : spanDays,
    companionCount: container.companionCount,
  ));
}

/// The distance/business-use/deduction rollup over a vehicle's whole logbook.
/// Recomputes when the trips change.
final tripRollupProvider = Provider.family<TripRollup, String>((ref, id) {
  final trips = ref.watch(tripHistoryProvider(id)).asData?.value ?? const [];
  return TripRollup.of(trips.map((t) => t.toClassified()));
});

/// Which bundled jurisdiction a mileage report is priced under. Bundled offline
/// so a report works with no setup; the `rate_schemes` table backs custom ones.
enum ReportJurisdiction { irs, hmrc }

/// The mileage report for a vehicle under [ReportJurisdiction], re-priced through
/// the engine with running YTD. Family keyed by "vehicleId|jurisdiction".
final mileageReportProvider =
    Provider.family<MileageReport, ({String vehicleId, ReportJurisdiction j})>(
        (ref, args) {
  final trips = ref.watch(tripHistoryProvider(args.vehicleId)).asData?.value ??
      const <Trip>[];
  // Date-ordered oldest-first so the running YTD accumulates correctly.
  final ordered = [...trips]
    ..sort((a, b) => a.tripAt.epochMillis.compareTo(b.tripAt.epochMillis));
  final reportTrips = ordered
      .map((t) => ReportTrip(
            date: DateTime.fromMillisecondsSinceEpoch(t.tripAt.epochMillis,
                isUtc: true),
            distanceMetres: t.distanceMetres,
            classification: t.classification,
            isContemporaneous: t.isContemporaneous,
            isDeductible: t.isDeductible,
            vehicleClass: _vehicleClassOf(t.vehicleClass),
            passengerCount: t.passengerCount,
          ))
      .toList();
  return buildMileageReport(
    scheme: bundledScheme(args.j),
    trips: reportTrips,
  );
});

MileageVehicleClass _vehicleClassOf(String s) => switch (s) {
      'van' => MileageVehicleClass.van,
      'motorcycle' => MileageVehicleClass.motorcycle,
      'bicycle' => MileageVehicleClass.bicycle,
      _ => MileageVehicleClass.car,
    };

/// A bundled, effective-dated default scheme for the jurisdiction — the offline
/// dataset so a report needs no account or network. Custom schemes (persisted in
/// `rate_schemes`) override these later.
MileageRateScheme bundledScheme(ReportJurisdiction j) => switch (j) {
      ReportJurisdiction.irs => MileageRateScheme(
          id: 'bundled-irs',
          name: 'IRS',
          kind: RateKind.irs,
          currencyCode: 'USD',
          unit: RateDistanceUnit.mile,
          revisions: [
            // Standard business mileage rate (whole/half cents per mile).
            RateRevision(
              effectiveFrom: DateTime.utc(2023),
              tiersByClass: const {
                MileageVehicleClass.car: [
                  RateTier(rateThousandthsPerUnit: 65500), // 65.5¢
                ],
              },
            ),
            RateRevision(
              effectiveFrom: DateTime.utc(2024),
              tiersByClass: const {
                MileageVehicleClass.car: [
                  RateTier(rateThousandthsPerUnit: 67000), // 67¢
                ],
              },
            ),
          ],
        ),
      ReportJurisdiction.hmrc => MileageRateScheme(
          id: 'bundled-hmrc',
          name: 'HMRC',
          kind: RateKind.hmrc,
          currencyCode: 'GBP',
          unit: RateDistanceUnit.mile,
          taxYearStartMonth: 4,
          taxYearStartDay: 6,
          revisions: [
            RateRevision(
              effectiveFrom: DateTime.utc(2011, 4, 6),
              passengerRateThousandthsPerUnit: 5000, // 5p/passenger/mi
              tiersByClass: const {
                MileageVehicleClass.car: [
                  RateTier(rateThousandthsPerUnit: 45000, upToMetres: 16093440),
                  RateTier(rateThousandthsPerUnit: 25000),
                ],
                MileageVehicleClass.motorcycle: [
                  RateTier(rateThousandthsPerUnit: 24000),
                ],
                MileageVehicleClass.bicycle: [
                  RateTier(rateThousandthsPerUnit: 20000),
                ],
              },
            ),
          ],
        ),
    };

// ── display helpers (features never import each other → local, l10n-fed) ──────

/// Format integer minor units as major amount + ISO code, keyed to the real
/// currency exponent (never a hardcoded 2 decimals).
String formatMoney(NumeralFormat fmt, int minorUnits, String currencyCode) {
  final exp = Currency.tryParse(currencyCode)?.exponent ?? 2;
  return '${fmt.formatScaled(minorUnits, exp)} $currencyCode';
}

/// Format canonical metres into the display unit (mi/km) at one decimal,
/// converting only at the edge; the stored value stays SI-canonical.
String formatDistance(NumeralFormat fmt, int metres, DistanceUnit unit) {
  final tenths = (Distance.metres(metres).toDisplay(unit) * 10).round();
  return fmt.formatScaled(tenths, 1);
}

/// Format an instant per the active calendar + numerals as `Y/M/D`.
String formatTripDate(CalendarSystem cal, NumeralFormat fmt, Instant when) {
  final d = CalendarDate.fromInstant(when, cal);
  return '${fmt.formatUngrouped(d.year)}/${fmt.formatUngrouped(d.month)}'
      '/${fmt.formatUngrouped(d.day)}';
}

/// Business-use percentage (0–100, one decimal) from basis points, or null.
String? formatBusinessUse(NumeralFormat fmt, int? basisPoints) =>
    basisPoints == null
        ? null
        : '${fmt.formatScaled((basisPoints / 10).round(), 1)}%';
