/// M7-T10 · the pure, jurisdiction-aware mileage-report generator.
///
/// Re-prices a filtered set of trips through the [MileageRateScheme] engine with
/// a running tax-year total, so a report **splits correctly** across an IRS
/// mid-year rate change and an HMRC 45p→25p tier crossing — the split is a
/// property of re-pricing in date order, not of any per-trip snapshot. It runs
/// the contemporaneous-record compliance check (flagging reconstructed trips),
/// and exposes totals that reconcile exactly with the engine and the YTD figures.
///
/// Pure and deterministic: value in, value out. CSV/JSON serialization is
/// hand-written (built-in-first, no dependency). PDF rendering is a presentation
/// concern left to the app/device lane.
library;

import 'rate_engine.dart';
import 'trip_classification.dart';

/// One trip as it enters the report — the facts the engine needs plus the
/// compliance flag. Feed these in **date order**.
final class ReportTrip {
  const ReportTrip({
    required this.date,
    required this.distanceMetres,
    required this.classification,
    required this.isContemporaneous,
    this.isDeductible = false,
    this.vehicleClass = MileageVehicleClass.car,
    this.passengerCount = 0,
  });

  final DateTime date;
  final int distanceMetres;
  final TripClassification classification;
  final bool isContemporaneous;
  final bool isDeductible;
  final MileageVehicleClass vehicleClass;
  final int passengerCount;
}

/// One aggregated report line: a distinct (tax-year, rate) bucket.
final class ReportLine {
  const ReportLine({
    required this.taxYearLabel,
    required this.rateThousandthsPerUnit,
    required this.distanceMetres,
    required this.deductionMinor,
  });

  final String taxYearLabel;
  final int rateThousandthsPerUnit;
  final int distanceMetres;
  final int deductionMinor;
}

/// The generated report.
final class MileageReport {
  const MileageReport({
    required this.currencyCode,
    required this.lines,
    required this.rollup,
    required this.nonContemporaneousCount,
    required this.passengerDeductionMinor,
  });

  final String currencyCode;

  /// Per (tax-year, rate) lines, ordered by tax year then descending rate.
  final List<ReportLine> lines;

  /// Distance/business-use/deduction rollup over the whole filtered set.
  final TripRollup rollup;

  /// How many deductible trips are reconstructed (non-contemporaneous) — the
  /// compliance flag an auditor cares about.
  final int nonContemporaneousCount;

  /// Passenger add-on total across the report (a distinct line from the tiers).
  final int passengerDeductionMinor;

  /// The distance-based deduction across all lines.
  int get baseDeductionMinor =>
      lines.fold(0, (sum, l) => sum + l.deductionMinor);

  /// The full claim: distance tiers + passenger add-on.
  int get deductionMinor => baseDeductionMinor + passengerDeductionMinor;

  /// A contemporaneous record is expected: true when nothing is reconstructed.
  bool get isCompliant => nonContemporaneousCount == 0;
}

/// Build a report by re-pricing [trips] (date-ordered) through [scheme]. Only
/// deductible, business-classified trips earn a deduction and enter the lines;
/// every trip counts toward the distance/business-use rollup. The running total
/// resets at each tax-year boundary so tiers restart correctly.
MileageReport buildMileageReport({
  required MileageRateScheme scheme,
  required List<ReportTrip> trips,
}) {
  final ytdByYear = <String, int>{};
  // (taxYear, rate) → accumulated (distance, deduction).
  final buckets = <(String, int), (int, int)>{};
  var nonContemporaneous = 0;
  var passengerTotal = 0;

  for (final t in trips) {
    if (!(t.isDeductible && t.classification == TripClassification.business)) {
      continue;
    }
    if (!t.isContemporaneous) nonContemporaneous++;
    final year = scheme.taxYearLabel(t.date);
    final ytd = ytdByYear[year] ?? 0;
    final priced = scheme.price(
      date: t.date,
      distanceMetres: t.distanceMetres,
      vehicleClass: t.vehicleClass,
      ytdDistanceMetres: ytd,
      passengerCount: t.passengerCount,
    );
    if (!priced.priced) continue;
    for (final tier in priced.tiers) {
      final key = (year, tier.rateThousandthsPerUnit);
      final cur = buckets[key] ?? (0, 0);
      buckets[key] =
          (cur.$1 + tier.distanceMetres, cur.$2 + tier.deductionMinor);
    }
    passengerTotal += priced.passengerDeductionMinor;
    ytdByYear[year] = ytd + t.distanceMetres;
  }

  final lines = buckets.entries
      .map((e) => ReportLine(
            taxYearLabel: e.key.$1,
            rateThousandthsPerUnit: e.key.$2,
            distanceMetres: e.value.$1,
            deductionMinor: e.value.$2,
          ))
      .toList()
    ..sort((a, b) {
      final byYear = a.taxYearLabel.compareTo(b.taxYearLabel);
      return byYear != 0
          ? byYear
          : b.rateThousandthsPerUnit.compareTo(a.rateThousandthsPerUnit);
    });

  final rollup = TripRollup.of(trips.map((t) => ClassifiedTrip(
        distanceMetres: t.distanceMetres,
        classification: t.classification,
        isDeductible: t.isDeductible,
      )));

  return MileageReport(
    currencyCode: scheme.currencyCode,
    lines: lines,
    rollup: rollup,
    nonContemporaneousCount: nonContemporaneous,
    passengerDeductionMinor: passengerTotal,
  );
}
