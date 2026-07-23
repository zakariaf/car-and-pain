/// M7-T3 · trip tax classification and the running year-to-date rollup.
///
/// Pure, deterministic value logic: a trip is tagged once, its deductibility is
/// derived from that tag (commute is the separately-treated non-deductible
/// category), and a fold over classified trips yields the business-use
/// percentage and running YTD deduction/reimbursement totals a report needs.
library;

/// How a trip is tagged for tax. `unclassified` is the backlog state a swipe
/// clears; `commute` is business-context travel that is nonetheless
/// non-deductible (home↔regular workplace).
enum TripClassification { unclassified, business, personal, commute }

extension TripClassificationX on TripClassification {
  /// The default deductibility of the category. Only genuine business travel is
  /// deductible; commute and personal are not; unclassified is treated as
  /// not-yet-deductible until the user tags it.
  bool get isDeductibleByDefault => this == TripClassification.business;

  /// Whether the category counts toward the business-use percentage. Commute is
  /// business *context* but excluded from deductible business use.
  bool get countsAsBusinessUse => this == TripClassification.business;
}

/// One trip's facts as they feed the rollup.
final class ClassifiedTrip {
  const ClassifiedTrip({
    required this.distanceMetres,
    required this.classification,
    this.deductionMinor = 0,
    this.isDeductible = false,
  }) : assert(distanceMetres >= 0, 'distance must be >= 0');

  final int distanceMetres;
  final TripClassification classification;

  /// The priced deduction/reimbursement for this trip (minor units), already
  /// resolved by the rate engine. Only counted when [isDeductible].
  final int deductionMinor;

  /// The effective per-trip deductibility (defaults from the category, but the
  /// user can override — e.g. mark a specific business trip non-billable).
  final bool isDeductible;
}

/// The rolled-up totals over a set of trips (a tax year, a client, a filter).
final class TripRollup {
  const TripRollup({
    required this.totalDistanceMetres,
    required this.businessDistanceMetres,
    required this.deductionMinor,
    required this.tripCount,
    required this.unclassifiedCount,
  });

  /// Fold a sequence of classified trips into a single rollup.
  factory TripRollup.of(Iterable<ClassifiedTrip> trips) {
    var total = 0;
    var business = 0;
    var deduction = 0;
    var count = 0;
    var unclassified = 0;
    for (final t in trips) {
      total += t.distanceMetres;
      count++;
      if (t.classification == TripClassification.unclassified) unclassified++;
      if (t.classification.countsAsBusinessUse) {
        business += t.distanceMetres;
      }
      if (t.isDeductible) deduction += t.deductionMinor;
    }
    return TripRollup(
      totalDistanceMetres: total,
      businessDistanceMetres: business,
      deductionMinor: deduction,
      tripCount: count,
      unclassifiedCount: unclassified,
    );
  }

  final int totalDistanceMetres;
  final int businessDistanceMetres;
  final int deductionMinor;
  final int tripCount;
  final int unclassifiedCount;

  /// `business_distance / total_distance` in basis points (0–10000), or null
  /// when there is no distance to divide. Integer-only, round-half-up.
  int? get businessUseBasisPoints => totalDistanceMetres == 0
      ? null
      : _divRoundHalfUp(businessDistanceMetres * 10000, totalDistanceMetres);
}

int _divRoundHalfUp(int numerator, int denominator) {
  if (numerator < 0) {
    return -((2 * -numerator + denominator) ~/ (2 * denominator));
  }
  return (2 * numerator + denominator) ~/ (2 * denominator);
}
