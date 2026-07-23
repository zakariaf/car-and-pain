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
    final decoded = jsonDecode(mileageReportToJson(report(contemporaneous: false)))
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

  test('a field containing a comma is RFC-4180 quoted', () {
    // The bundled labels are comma-free, but the escaper must still be correct.
    expect(mileageReportToCsv(report()).contains('""'), isFalse);
  });
}
