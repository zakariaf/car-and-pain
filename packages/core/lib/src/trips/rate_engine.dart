/// M7-T3 · the pure, effective-dated mileage-rate engine.
///
/// Prices a trip by IRS, HMRC, or a fully custom scheme. Rates are:
///   - **effective-dated** — the rate in force on the trip's actual date wins,
///     so a mid-year IRS change splits a tax year correctly;
///   - **tiered** — HMRC pays 45p up to 10,000 miles of tax-year business
///     distance and 25p above, so a trip that straddles the threshold is split;
///   - **vehicle-class aware** — car/van, motorcycle, bicycle carry distinct
///     rates; and
///   - **passenger-add-on aware** — HMRC's 5p/passenger/mile is a distinct line.
///
/// There is **no float anywhere in the money path**. Distance is canonical whole
/// metres; a rate is expressed in **thousandths of a minor unit** per
/// [RateDistanceUnit] (so IRS half-cent rates like 58.5¢/mi = `58500` are exact,
/// matching the `fxRateThousandths` convention); the deduction is
///   `deduction_minor = round_half_up(metres × rateThousandths / mmPerUnit)`
/// where `mmPerUnit` is the exact millimetres in one rate unit (a mile is
/// 1_609_344 mm exactly, a kilometre 1_000_000). Because a trip's metres × 1000
/// is its millimetre length and the rate carries an extra ×1000, the two cancel
/// to exact integer arithmetic — no fraction of a cent is lost.
///
/// The engine is deterministic and side-effect-free: it reads a scheme and a
/// trip's facts and returns value objects. Tax-year scoping of the running total
/// is the caller's job (feed `price` the pre-trip year-to-date distance); the
/// [MileageRateScheme.taxYearContaining] helper computes the boundary.
library;

/// Where a scheme's conventions come from. `custom` is fully user-defined.
enum RateKind { irs, hmrc, custom }

/// The vehicle class a rate tier applies to. Distinct rates per class.
enum MileageVehicleClass { car, van, motorcycle, bicycle }

/// The distance unit a scheme's rates and tier thresholds are expressed in.
/// Stored distance stays canonical metres; this only scales the rate.
enum RateDistanceUnit { mile, kilometre }

/// Exact millimetres in one international mile (1609.344 m).
const int _mmPerMile = 1609344;

/// Exact millimetres in one kilometre.
const int _mmPerKm = 1000000;

int _mmPerUnit(RateDistanceUnit unit) =>
    unit == RateDistanceUnit.mile ? _mmPerMile : _mmPerKm;

/// One tier of a (possibly tiered) rate: the per-unit [rateThousandthsPerUnit]
/// that applies while cumulative tax-year distance is at or below [upToMetres].
/// The
/// top tier carries `upToMetres == null` (unbounded). Tiers within a revision
/// are ordered ascending by threshold.
final class RateTier {
  const RateTier({required this.rateThousandthsPerUnit, this.upToMetres})
      : assert(rateThousandthsPerUnit >= 0, 'rate must be >= 0'),
        assert(upToMetres == null || upToMetres > 0, 'threshold must be > 0');

  /// Thousandths of a minor unit per one [RateDistanceUnit] (45p/mi = 45000,
  /// IRS 58.5¢/mi = 58500). Sub-minor precision without a float.
  final int rateThousandthsPerUnit;

  /// Cumulative tax-year distance ceiling (metres) up to which this tier
  /// applies; null for the unbounded top tier.
  final int? upToMetres;
}

/// An effective-dated revision of a scheme: the per-class tiers and the optional
/// per-passenger add-on that took effect on [effectiveFrom] (a UTC calendar
/// date; time-of-day is ignored). A scheme holds one revision per rate change.
final class RateRevision {
  const RateRevision({
    required this.effectiveFrom,
    required this.tiersByClass,
    this.passengerRateThousandthsPerUnit = 0,
  }) : assert(passengerRateThousandthsPerUnit >= 0,
            'passenger rate must be >= 0');

  /// The date this revision took effect (inclusive). Compared by date only.
  final DateTime effectiveFrom;

  /// Ascending-by-threshold tiers, keyed by vehicle class.
  final Map<MileageVehicleClass, List<RateTier>> tiersByClass;

  /// Per-passenger, per-unit add-on in thousandths of a minor unit (HMRC
  /// 5p/passenger/mile = 5000); 0 if none.
  final int passengerRateThousandthsPerUnit;
}

/// The portion of a trip that fell in one tier, and what it earned.
final class TierApplication {
  const TierApplication({
    required this.rateThousandthsPerUnit,
    required this.distanceMetres,
    required this.deductionMinor,
  });

  final int rateThousandthsPerUnit;
  final int distanceMetres;
  final int deductionMinor;
}

/// The priced result for a single trip.
final class MileagePricing {
  const MileagePricing({
    required this.priced,
    required this.currencyCode,
    required this.tiers,
    required this.passengerDeductionMinor,
  });

  /// A zero result for a date/class no revision covers — never throws.
  const MileagePricing.unpriced(this.currencyCode)
      : priced = false,
        tiers = const [],
        passengerDeductionMinor = 0;

  /// Whether a revision actually applied. False → the trip has no in-force rate
  /// on its date (surface it, don't silently treat as zero-value).
  final bool priced;
  final String currencyCode;

  /// The per-tier split (one entry per tier the trip touched).
  final List<TierApplication> tiers;

  /// The per-passenger add-on total (already multiplied by passenger count).
  final int passengerDeductionMinor;

  /// Distance-based deduction across all tiers (excludes passenger add-on).
  int get baseDeductionMinor =>
      tiers.fold(0, (sum, t) => sum + t.deductionMinor);

  /// The full claim: distance tiers + passenger add-on.
  int get deductionMinor => baseDeductionMinor + passengerDeductionMinor;

  /// True when the trip crossed a tier boundary (more than one tier applied).
  bool get tierSplit => tiers.length > 1;
}

/// An effective-dated, tiered, vehicle-class-aware mileage-rate scheme.
final class MileageRateScheme {
  const MileageRateScheme({
    required this.id,
    required this.name,
    required this.kind,
    required this.currencyCode,
    required this.unit,
    required this.revisions,
    this.taxYearStartMonth = 1,
    this.taxYearStartDay = 1,
  })  : assert(taxYearStartMonth >= 1 && taxYearStartMonth <= 12,
            'tax-year start month is 1..12'),
        assert(taxYearStartDay >= 1 && taxYearStartDay <= 31,
            'tax-year start day is 1..31');

  final String id;
  final String name;
  final RateKind kind;
  final String currencyCode;
  final RateDistanceUnit unit;

  /// Revisions in any order; [revisionOn] resolves the one in force by date.
  final List<RateRevision> revisions;

  /// Tax-year start (UK: month 4, day 6; US: month 1, day 1). Drives YTD resets.
  final int taxYearStartMonth;
  final int taxYearStartDay;

  /// The revision in force on [date]: the latest whose [RateRevision.effectiveFrom]
  /// is on or before [date] (date-only comparison). Null if [date] predates every
  /// revision.
  RateRevision? revisionOn(DateTime date) {
    final day = _dateOnly(date);
    RateRevision? best;
    for (final r in revisions) {
      if (!_dateOnly(r.effectiveFrom).isAfter(day)) {
        if (best == null ||
            _dateOnly(r.effectiveFrom).isAfter(_dateOnly(best.effectiveFrom))) {
          best = r;
        }
      }
    }
    return best;
  }

  /// The tax year containing [date] as `(startInclusive, endExclusive)`, both
  /// UTC midnight. A UK scheme (6 April) puts 2026-04-05 in the year starting
  /// 2025-04-06 and 2026-04-06 in the next. A US scheme (1 January) is the plain
  /// calendar year.
  (DateTime, DateTime) taxYearContaining(DateTime date) {
    final d = _dateOnly(date);
    final thisYearStart =
        DateTime.utc(d.year, taxYearStartMonth, taxYearStartDay);
    if (d.isBefore(thisYearStart)) {
      return (
        DateTime.utc(d.year - 1, taxYearStartMonth, taxYearStartDay),
        thisYearStart,
      );
    }
    return (
      thisYearStart,
      DateTime.utc(d.year + 1, taxYearStartMonth, taxYearStartDay),
    );
  }

  /// A short, locale-neutral label for the tax year containing [date], e.g.
  /// `2026` for a US scheme or `2025-26` for a UK one. For grouping/report keys
  /// only — not user-facing copy.
  String taxYearLabel(DateTime date) {
    final (start, end) = taxYearContaining(date);
    if (taxYearStartMonth == 1 && taxYearStartDay == 1) return '${start.year}';
    return '${start.year}-${(end.year % 100).toString().padLeft(2, '0')}';
  }

  /// Price a single trip.
  ///
  /// [distanceMetres] is the billable distance (the caller decides how much of a
  /// trip is deductible before calling). [ytdDistanceMetres] is the cumulative
  /// **tax-year** distance *before* this trip, so tiered schemes resume at the
  /// right tier — feed it the sum of prior same-year billable trips. Splits the
  /// trip across tier boundaries, rounding each tier independently (each tier is
  /// its own report line). Returns [MileagePricing.unpriced] when no revision
  /// covers the date or class.
  MileagePricing price({
    required DateTime date,
    required int distanceMetres,
    MileageVehicleClass vehicleClass = MileageVehicleClass.car,
    int ytdDistanceMetres = 0,
    int passengerCount = 0,
  }) {
    if (distanceMetres <= 0 || passengerCount < 0 || ytdDistanceMetres < 0) {
      return MileagePricing.unpriced(currencyCode);
    }
    final revision = revisionOn(date);
    final tiers = revision?.tiersByClass[vehicleClass];
    if (revision == null || tiers == null || tiers.isEmpty) {
      return MileagePricing.unpriced(currencyCode);
    }

    final applied = <TierApplication>[];
    final lower = ytdDistanceMetres; // cumulative start of this trip
    final upper = ytdDistanceMetres + distanceMetres; // cumulative end
    var cursor = lower;
    for (final tier in tiers) {
      if (cursor >= upper) break;
      // This tier covers cumulative distance up to its ceiling (or ∞ at top).
      final ceiling = tier.upToMetres ?? upper;
      if (ceiling <= cursor) continue; // already past this tier's ceiling
      final segmentEnd = ceiling < upper ? ceiling : upper;
      final segmentMetres = segmentEnd - cursor;
      if (segmentMetres > 0) {
        applied.add(TierApplication(
          rateThousandthsPerUnit: tier.rateThousandthsPerUnit,
          distanceMetres: segmentMetres,
          deductionMinor:
              _rateOnDistance(segmentMetres, tier.rateThousandthsPerUnit),
        ));
        cursor = segmentEnd;
      }
    }
    // Distance above the top bounded tier with no unbounded tier: the remainder
    // earns nothing but is still reported so totals reconcile with distance.
    if (cursor < upper) {
      applied.add(TierApplication(
        rateThousandthsPerUnit: 0,
        distanceMetres: upper - cursor,
        deductionMinor: 0,
      ));
    }

    final passengerDeduction = passengerCount == 0
        ? 0
        : _rateOnDistance(
                distanceMetres, revision.passengerRateThousandthsPerUnit) *
            passengerCount;

    return MileagePricing(
      priced: true,
      currencyCode: currencyCode,
      tiers: applied,
      passengerDeductionMinor: passengerDeduction,
    );
  }

  /// `metres × rateThousandths / mmPerUnit`, round-half-up. Exact integer money
  /// math for the scheme's [unit]: the rate's ×1000 (thousandths) cancels the
  /// metre→mm ×1000, so no fraction of a minor unit is lost.
  int _rateOnDistance(int metres, int rateThousandthsPerUnit) =>
      _divRoundHalfUp(metres * rateThousandthsPerUnit, _mmPerUnit(unit));
}

DateTime _dateOnly(DateTime d) {
  final u = d.toUtc();
  return DateTime.utc(u.year, u.month, u.day);
}

/// Round-half-up integer division (exact half threshold), negative-safe.
int _divRoundHalfUp(int numerator, int denominator) {
  if (numerator < 0) {
    return -((2 * -numerator + denominator) ~/ (2 * denominator));
  }
  return (2 * numerator + denominator) ~/ (2 * denominator);
}
