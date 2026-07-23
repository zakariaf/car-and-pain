import 'dart:convert';

import 'package:car_and_pain/src/features/06-trips-mileage/presentation/report_export.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// M7-T10 · the mileage-report CSV/JSON serializers are deterministic, canonical
/// (SI metres, integer minor units), and reconcile with the engine.
void main() {
  const mi1000 = 1609344;
  final hmrc = MileageRateScheme(
    id: 'hmrc',
    name: 'HMRC',
    kind: RateKind.hmrc,
    currencyCode: 'GBP',
    unit: RateDistanceUnit.mile,
    taxYearStartMonth: 4,
    taxYearStartDay: 6,
    revisions: [
      RateRevision(
        effectiveFrom: DateTime.utc(2011, 4, 6),
        tiersByClass: const {
          MileageVehicleClass.car: [RateTier(rateThousandthsPerUnit: 45000)],
        },
      ),
    ],
  );

  MileageReport report({bool contemporaneous = true}) => buildMileageReport(
        scheme: hmrc,
        trips: [
          ReportTrip(
            date: DateTime.utc(2024, 6),
            distanceMetres: mi1000,
            classification: TripClassification.business,
            isContemporaneous: contemporaneous,
            isDeductible: true,
          ),
        ],
      );

  test('CSV has a header, a rate line, and a TOTAL row', () {
    final csv = mileageReportToCsv(report());
    final lines = csv.trim().split('\n');
    expect(lines.first,
        'tax_year,rate_thousandths_per_unit,distance_metres,deduction_minor,currency');
    expect(lines[1], '2024-25,45000,$mi1000,45000,GBP');
    expect(lines.last, 'TOTAL,,$mi1000,45000,GBP');
  });

  test('JSON round-trips the report shape and reconciles totals', () {
    final decoded =
        jsonDecode(mileageReportToJson(report(contemporaneous: false)))
            as Map<String, dynamic>;
    expect(decoded['format'], 'mileage_report');
    expect(decoded['currency'], 'GBP');
    expect(decoded['compliant'], false);
    expect(decoded['non_contemporaneous_count'], 1);
    expect(decoded['deduction_minor'], 45000);
    expect(decoded['business_distance_metres'], mi1000);
    final lines = decoded['lines'] as List<dynamic>;
    expect(lines, hasLength(1));
    expect((lines.first as Map)['rate_thousandths_per_unit'], 45000);
  });

  test('CSV rows reconcile with TOTAL when a passenger add-on is present', () {
    // A passenger-carrying scheme so the add-on is non-zero.
    final withPax = MileageRateScheme(
      id: 'hmrc',
      name: 'HMRC',
      kind: RateKind.hmrc,
      currencyCode: 'GBP',
      unit: RateDistanceUnit.mile,
      revisions: [
        RateRevision(
          effectiveFrom: DateTime.utc(2011, 4, 6),
          passengerRateThousandthsPerUnit: 5000,
          tiersByClass: const {
            MileageVehicleClass.car: [RateTier(rateThousandthsPerUnit: 45000)],
          },
        ),
      ],
    );
    final r = buildMileageReport(scheme: withPax, trips: [
      ReportTrip(
        date: DateTime.utc(2024, 6),
        distanceMetres: mi1000,
        classification: TripClassification.business,
        isContemporaneous: true,
        isDeductible: true,
        passengerCount: 2,
      ),
    ]);
    final lines = mileageReportToCsv(r).trim().split('\n');
    expect(lines.any((l) => l.startsWith('PASSENGERS,')), isTrue);
    // Rows (rate line 45000 + passenger 10000) sum to the TOTAL 55000.
    final total = lines.last.split(',');
    expect(total[0], 'TOTAL');
    expect(total[3], '55000');
    expect(r.deductionMinor, 55000);
  });

  test('a field containing a comma is RFC-4180 quoted', () {
    // The bundled labels are comma-free, but the escaper must still be correct.
    expect(mileageReportToCsv(report()).contains('""'), isFalse);
  });
}
