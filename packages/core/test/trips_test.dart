import 'package:core/core.dart';
import 'package:test/test.dart';

/// M7-T8 · exhaustive table-driven tests for the trip engines: effective-dated
/// tiered rate math, gap reconciliation, classification rollup, road-trip P&L,
/// and on-device GPS distance. Distances use exact 125-mile multiples
/// (1 mi = 1609.344 m, so 125 mi = 201_168 m exactly) to keep money assertions
/// exact — no float in the tax path.
void main() {
  // 125 miles = 201_168 m exactly; 1000 mi = 1_609_344 m; 10_000 mi = 16_093_440.
  const mi125 = 201168;
  const mi1000 = 1609344;
  const mi10k = 16093440;

  DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

  group('MileageRateScheme — flat IRS', () {
    final irs = MileageRateScheme(
      id: 'irs',
      name: 'IRS',
      kind: RateKind.irs,
      currencyCode: 'USD',
      unit: RateDistanceUnit.mile,
      revisions: [
        RateRevision(
          effectiveFrom: day(2024, 1, 1),
          tiersByClass: {
            MileageVehicleClass.car: [
              const RateTier(rateThousandthsPerUnit: 67000), // 67¢/mi
            ],
          },
        ),
      ],
    );

    test(r'1000 mi at 67¢ = $670.00, single tier, not split', () {
      final p = irs.price(date: day(2024, 5, 1), distanceMetres: mi1000);
      expect(p.priced, isTrue);
      expect(p.deductionMinor, 67000);
      expect(p.baseDeductionMinor, 67000);
      expect(p.tiers, hasLength(1));
      expect(p.tierSplit, isFalse);
      expect(p.currencyCode, 'USD');
    });

    test('zero/negative distance and pre-revision dates are unpriced', () {
      expect(
          irs.price(date: day(2024, 5, 1), distanceMetres: 0).priced, isFalse);
      expect(
          irs.price(date: day(2024, 5, 1), distanceMetres: -5).priced, isFalse);
      // Before the earliest revision → no rate in force.
      expect(irs.price(date: day(2023, 1, 1), distanceMetres: mi1000).priced,
          isFalse);
      expect(
          irs
              .price(date: day(2023, 1, 1), distanceMetres: mi1000)
              .deductionMinor,
          0);
    });
  });

  group('MileageRateScheme — half-cent effective-dating (mid-year change)', () {
    // IRS 2022: 58.5¢ Jan–Jun, 62.5¢ Jul–Dec. Half-cents prove the thousandths
    // precision (58.5¢ = 58500), and the date picks the in-force revision.
    final irs2022 = MileageRateScheme(
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

    test('a March trip uses 58.5¢, an August trip uses 62.5¢', () {
      expect(
          irs2022
              .price(date: day(2022, 3, 15), distanceMetres: mi1000)
              .deductionMinor,
          58500);
      expect(
          irs2022
              .price(date: day(2022, 8, 1), distanceMetres: mi1000)
              .deductionMinor,
          62500);
    });

    test('a trip on the exact effective date takes the new rate (inclusive)',
        () {
      expect(
          irs2022
              .price(date: day(2022, 7, 1), distanceMetres: mi1000)
              .deductionMinor,
          62500);
    });
  });

  group('MileageRateScheme — HMRC tiered + passengers + vehicle class', () {
    final hmrc = MileageRateScheme(
      id: 'hmrc',
      name: 'HMRC AMAP',
      kind: RateKind.hmrc,
      currencyCode: 'GBP',
      unit: RateDistanceUnit.mile,
      taxYearStartMonth: 4,
      taxYearStartDay: 6,
      revisions: [
        RateRevision(
          effectiveFrom: day(2011, 4, 6),
          passengerRateThousandthsPerUnit: 5000, // 5p/passenger/mi
          tiersByClass: {
            MileageVehicleClass.car: [
              const RateTier(rateThousandthsPerUnit: 45000, upToMetres: mi10k),
              const RateTier(rateThousandthsPerUnit: 25000),
            ],
            MileageVehicleClass.motorcycle: [
              const RateTier(rateThousandthsPerUnit: 24000),
            ],
          },
        ),
      ],
    );

    test('a trip straddling 10,000 mi splits 45p / 25p on the tax-year total',
        () {
      // YTD 9875 mi, then a 250 mi trip: 125 mi at 45p + 125 mi at 25p.
      final p = hmrc.price(
        date: day(2024, 6, 1),
        distanceMetres: mi125 * 2, // 250 mi
        ytdDistanceMetres: mi125 * 79, // 9875 mi
      );
      expect(p.tiers, hasLength(2));
      expect(p.tierSplit, isTrue);
      expect(p.tiers[0].rateThousandthsPerUnit, 45000);
      expect(p.tiers[0].distanceMetres, mi125); // 125 mi below threshold
      expect(p.tiers[0].deductionMinor, 5625); // 125 mi × 45p
      expect(p.tiers[1].rateThousandthsPerUnit, 25000);
      expect(p.tiers[1].distanceMetres, mi125);
      expect(p.tiers[1].deductionMinor, 3125); // 125 mi × 25p
      expect(p.deductionMinor, 8750);
    });

    test('below the threshold everything is at 45p (single tier)', () {
      final p = hmrc.price(date: day(2024, 6, 1), distanceMetres: mi1000);
      expect(p.tiers, hasLength(1));
      expect(p.deductionMinor, 45000);
    });

    test('passenger add-on is a distinct line (5p × 2 × 1000 mi)', () {
      final p = hmrc.price(
        date: day(2024, 6, 1),
        distanceMetres: mi1000,
        passengerCount: 2,
      );
      expect(p.baseDeductionMinor, 45000);
      expect(p.passengerDeductionMinor, 10000); // 5p × 2 × 1000
      expect(p.deductionMinor, 55000);
    });

    test('vehicle class selects its own rate (motorcycle 24p)', () {
      final p = hmrc.price(
        date: day(2024, 6, 1),
        distanceMetres: mi1000,
        vehicleClass: MileageVehicleClass.motorcycle,
      );
      expect(p.deductionMinor, 24000);
    });

    test('UK tax-year boundary is 6 April; label spans two years', () {
      final (start, end) = hmrc.taxYearContaining(day(2026, 4, 5));
      expect(start, day(2025, 4, 6));
      expect(end, day(2026, 4, 6));
      expect(hmrc.taxYearLabel(day(2026, 4, 5)), '2025-26');
      expect(hmrc.taxYearLabel(day(2026, 4, 6)), '2026-27');
    });

    test('distance above a bounded top tier reports a zero-rate remainder', () {
      final capped = MileageRateScheme(
        id: 'capped',
        name: 'capped',
        kind: RateKind.custom,
        currencyCode: 'GBP',
        unit: RateDistanceUnit.mile,
        revisions: [
          RateRevision(
            effectiveFrom: day(2020, 1, 1),
            tiersByClass: {
              MileageVehicleClass.car: [
                const RateTier(
                    rateThousandthsPerUnit: 45000, upToMetres: mi10k),
              ],
            },
          ),
        ],
      );
      // YTD already at 16_000_000 m; a further mi125*2 crosses the cap.
      final p = capped.price(
        date: day(2024, 1, 1),
        distanceMetres: mi125 * 2,
        ytdDistanceMetres: 16000000,
      );
      expect(p.tiers, hasLength(2));
      expect(p.tiers.last.rateThousandthsPerUnit, 0);
      expect(p.tiers.fold<int>(0, (s, t) => s + t.distanceMetres), mi125 * 2);
    });
  });

  group('US tax-year label', () {
    final irs = MileageRateScheme(
      id: 'irs',
      name: 'IRS',
      kind: RateKind.irs,
      currencyCode: 'USD',
      unit: RateDistanceUnit.mile,
      revisions: [
        RateRevision(effectiveFrom: day(2020, 1, 1), tiersByClass: const {}),
      ],
    );
    test('US year is the plain calendar year', () {
      expect(irs.taxYearLabel(day(2026, 7, 1)), '2026');
      final (start, end) = irs.taxYearContaining(day(2026, 7, 1));
      expect(start, day(2026, 1, 1));
      expect(end, day(2027, 1, 1));
    });
  });

  group('GapReconciler', () {
    const r = GapReconciler();
    test('continuous / missing / regression classification', () {
      expect(
          r
              .between(
                  prevEndOdometerMetres: 1000, nextStartOdometerMetres: 1000)
              .kind,
          GapKind.continuous);
      final missing =
          r.between(prevEndOdometerMetres: 1000, nextStartOdometerMetres: 1500);
      expect(missing.kind, GapKind.missingDistance);
      expect(missing.gapMetres, 500);
      final regression =
          r.between(prevEndOdometerMetres: 1500, nextStartOdometerMetres: 1000);
      expect(regression.kind, GapKind.regression);
      expect(regression.gapMetres, -500);
    });

    test('reconcile marks the first trip null then the preceding gaps', () {
      final gaps = r.reconcile([(0, 100), (100, 250), (400, 500)]);
      expect(gaps[0], isNull);
      expect(gaps[1]!.isContinuous, isTrue);
      expect(gaps[2]!.isMissing, isTrue);
      expect(gaps[2]!.gapMetres, 150);
    });

    test('tolerance absorbs sub-threshold noise', () {
      const tol = GapReconciler(toleranceMetres: 50);
      expect(
          tol
              .between(
                  prevEndOdometerMetres: 1000, nextStartOdometerMetres: 1030)
              .kind,
          GapKind.continuous);
      expect(
          tol
              .between(
                  prevEndOdometerMetres: 1000, nextStartOdometerMetres: 1100)
              .kind,
          GapKind.missingDistance);
    });
  });

  group('Trip classification & rollup', () {
    test('deductibility & business-use defaults per category', () {
      expect(TripClassification.business.isDeductibleByDefault, isTrue);
      expect(TripClassification.commute.isDeductibleByDefault, isFalse);
      expect(TripClassification.personal.isDeductibleByDefault, isFalse);
      expect(TripClassification.business.countsAsBusinessUse, isTrue);
      // Commute is business context but excluded from deductible business use.
      expect(TripClassification.commute.countsAsBusinessUse, isFalse);
    });

    test('rollup: business-use %, deduction sum, unclassified count', () {
      final rollup = TripRollup.of(const [
        ClassifiedTrip(
          distanceMetres: 6000,
          classification: TripClassification.business,
          deductionMinor: 400,
          isDeductible: true,
        ),
        ClassifiedTrip(
          distanceMetres: 2000,
          classification: TripClassification.commute,
          deductionMinor: 999, // not deductible → excluded
        ),
        ClassifiedTrip(
          distanceMetres: 2000,
          classification: TripClassification.personal,
        ),
        ClassifiedTrip(
          distanceMetres: 500,
          classification: TripClassification.unclassified,
        ),
      ]);
      expect(rollup.totalDistanceMetres, 10500);
      expect(rollup.businessDistanceMetres, 6000);
      expect(rollup.deductionMinor, 400); // only the deductible business trip
      expect(rollup.unclassifiedCount, 1);
      // 6000 / 10500 = 5714 bps (57.14%).
      expect(rollup.businessUseBasisPoints, 5714);
    });

    test('empty rollup has a null business-use percentage', () {
      expect(TripRollup.of(const []).businessUseBasisPoints, isNull);
    });
  });

  group('RoadTripPnl', () {
    test('totals, daily average, per-person share, cost per km', () {
      final pnl = RoadTripPnl.of(const RoadTripInput(
        currencyCode: 'EUR',
        legDistancesMetres: [100000, 200000, 100000], // 400 km
        fuelCostMinor: 12000,
        expenseCostMinor: 8000,
        spanDays: 4,
        companionCount: 2,
      ));
      expect(pnl.distanceMetres, 400000);
      expect(pnl.totalCostMinor, 20000);
      expect(pnl.avgCostPerDayMinor, 5000); // 20000 / 4
      expect(pnl.perPersonShareMinor, 10000); // 20000 / 2
      expect(pnl.costPerKmMinor, 50); // 20000 × 1000 / 400000
    });

    test('no distance yet → null cost-per-km, still safe totals', () {
      final pnl = RoadTripPnl.of(const RoadTripInput(currencyCode: 'EUR'));
      expect(pnl.distanceMetres, 0);
      expect(pnl.costPerKmMinor, isNull);
      expect(pnl.perPersonShareMinor, 0);
    });
  });

  group('GpsTrackReducer', () {
    const reducer = GpsTrackReducer();

    test('haversine ~1112 m for 0.01° of latitude', () {
      const a = GpsFix(epochMillis: 0, latitude: 0, longitude: 0);
      const b = GpsFix(epochMillis: 60000, latitude: 0.01, longitude: 0);
      expect(GpsTrackReducer.haversineMetres(a, b), closeTo(1112, 3));
    });

    test('fewer than two fixes → zero distance', () {
      expect(reducer.distanceMetres(const []), 0);
      expect(
          reducer.distanceMetres(
              const [GpsFix(epochMillis: 0, latitude: 0, longitude: 0)]),
          0);
    });

    test('sums plausible steps, drops an impossible jump', () {
      final track = [
        const GpsFix(epochMillis: 0, latitude: 0, longitude: 0),
        const GpsFix(
            epochMillis: 60000, latitude: 0.01, longitude: 0), // ~1112m
        // A 5°-longitude jump in 1 s (~556 km/s) → GPS glitch, dropped.
        const GpsFix(epochMillis: 61000, latitude: 0.01, longitude: 5),
      ];
      expect(reducer.distanceMetres(track), closeTo(1112, 5));
    });

    test('sub-step jitter is coalesced (a parked phone accrues nothing)', () {
      final jitter = [
        const GpsFix(epochMillis: 0, latitude: 0, longitude: 0),
        const GpsFix(epochMillis: 1000, latitude: 0.00001, longitude: 0), // ~1m
        const GpsFix(epochMillis: 2000, latitude: 0, longitude: 0.00001),
      ];
      expect(reducer.distanceMetres(jitter), 0);
    });

    test('OS-killed fragments merge into one distance', () {
      final f1 = [
        const GpsFix(epochMillis: 0, latitude: 0, longitude: 0),
        const GpsFix(epochMillis: 60000, latitude: 0.01, longitude: 0),
      ];
      final f2 = [
        const GpsFix(epochMillis: 120000, latitude: 0.02, longitude: 0),
        const GpsFix(epochMillis: 180000, latitude: 0.03, longitude: 0),
      ];
      final merged = reducer.mergeFragments([f1, f2]);
      // ~1112 m per 0.01° leg × 3 legs (two within-fragment + one seam).
      expect(merged, closeTo(3336, 10));
    });
  });
}
