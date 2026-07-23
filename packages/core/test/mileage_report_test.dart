import 'package:core/core.dart';
import 'package:test/test.dart';

/// M7-T10 · the report generator splits across a tax-year tier crossing and a
/// mid-year rate change, flags reconstructed trips, and reconciles with the
/// rate engine. 125 mi = 201_168 m exactly keeps the money assertions exact.
void main() {
  const mi125 = 201168;
  const mi1000 = 1609344;
  const mi10k = 16093440;
  DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

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
        effectiveFrom: day(2011, 4, 6),
        passengerRateThousandthsPerUnit: 5000,
        tiersByClass: {
          MileageVehicleClass.car: [
            const RateTier(rateThousandthsPerUnit: 45000, upToMetres: mi10k),
            const RateTier(rateThousandthsPerUnit: 25000),
          ],
        },
      ),
    ],
  );

  ReportTrip trip(DateTime d, int metres,
          {bool contemporaneous = true, int passengers = 0}) =>
      ReportTrip(
        date: d,
        distanceMetres: metres,
        classification: TripClassification.business,
        isContemporaneous: contemporaneous,
        isDeductible: true,
        passengerCount: passengers,
      );

  test('a tier crossing splits into two lines across the tax-year total', () {
    // 9875 mi already, then a 250 mi trip → 125 mi at 45p + 125 mi at 25p.
    final report = buildMileageReport(
      scheme: hmrc,
      trips: [
        // One prior trip banking 9875 mi at 45p.
        trip(day(2024, 5, 1), mi125 * 79),
        trip(day(2024, 6, 1), mi125 * 2),
      ],
    );
    // Two rate buckets in the 2024-25 year: 45p and 25p.
    expect(report.lines, hasLength(2));
    final at45 =
        report.lines.firstWhere((l) => l.rateThousandthsPerUnit == 45000);
    final at25 =
        report.lines.firstWhere((l) => l.rateThousandthsPerUnit == 25000);
    // 9875 + 125 = 10000 mi at 45p.
    expect(at45.distanceMetres, mi125 * 80);
    expect(at25.distanceMetres, mi125); // 125 mi over the threshold
    expect(at25.deductionMinor, 3125);
    // Totals reconcile with the engine.
    expect(report.deductionMinor, report.baseDeductionMinor);
    expect(report.rollup.businessUseBasisPoints, 10000); // all business
  });

  test('reconstructed trips are flagged; a clean report is compliant', () {
    final compliant = buildMileageReport(
        scheme: hmrc, trips: [trip(day(2024, 6, 1), mi1000)]);
    expect(compliant.isCompliant, isTrue);
    expect(compliant.nonContemporaneousCount, 0);

    final reconstructed = buildMileageReport(scheme: hmrc, trips: [
      trip(day(2024, 6, 1), mi1000),
      trip(day(2024, 6, 2), mi1000, contemporaneous: false),
    ]);
    expect(reconstructed.isCompliant, isFalse);
    expect(reconstructed.nonContemporaneousCount, 1);
  });

  test('mid-year rate change lands trips in the right rate bucket', () {
    final irs = MileageRateScheme(
      id: 'irs22',
      name: 'IRS 2022',
      kind: RateKind.irs,
      currencyCode: 'USD',
      unit: RateDistanceUnit.mile,
      revisions: [
        RateRevision(
          effectiveFrom: day(2022, 1, 1),
          tiersByClass: {
            MileageVehicleClass.car: [
              const RateTier(rateThousandthsPerUnit: 58500),
            ],
          },
        ),
        RateRevision(
          effectiveFrom: day(2022, 7, 1),
          tiersByClass: {
            MileageVehicleClass.car: [
              const RateTier(rateThousandthsPerUnit: 62500),
            ],
          },
        ),
      ],
    );
    final report = buildMileageReport(scheme: irs, trips: [
      trip(day(2022, 3, 1), mi1000), // 58.5¢
      trip(day(2022, 8, 1), mi1000), // 62.5¢
    ]);
    // Same tax year (US = calendar 2022), two rate buckets.
    expect(report.lines, hasLength(2));
    expect(report.lines.every((l) => l.taxYearLabel == '2022'), isTrue);
    expect(report.deductionMinor, 58500 + 62500);
  });

  test('passenger add-on is carried as a distinct total', () {
    final report = buildMileageReport(
      scheme: hmrc,
      trips: [trip(day(2024, 6, 1), mi1000, passengers: 2)],
    );
    expect(report.passengerDeductionMinor, 10000); // 5p × 2 × 1000 mi
    expect(report.deductionMinor, 45000 + 10000);
  });

  test('non-deductible and personal trips count for distance, not deduction',
      () {
    final report = buildMileageReport(scheme: hmrc, trips: [
      trip(day(2024, 6, 1), mi1000), // business, deductible
      ReportTrip(
        date: day(2024, 6, 1),
        distanceMetres: mi1000,
        classification: TripClassification.personal,
        isContemporaneous: true,
      ),
    ]);
    expect(report.rollup.totalDistanceMetres, mi1000 * 2);
    expect(report.rollup.businessDistanceMetres, mi1000);
    expect(report.deductionMinor, 45000); // only the business trip
  });
}
