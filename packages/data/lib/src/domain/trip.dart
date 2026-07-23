import 'package:core/core.dart';

/// A trip logbook entry as the repository emits it (Drift-free, M7-T1). Distance
/// is canonical whole metres; money integer minor units; instants UTC epoch
/// millis. [classification] drives deductibility; [gapMetres] carries the
/// odometer-gap reconciliation verdict against the previous trip.
class Trip {
  const Trip({
    required this.id,
    required this.vehicleId,
    required this.tripAt,
    required this.distanceMetres,
    required this.classification,
    required this.isDeductible,
    required this.isContemporaneous,
    required this.autoDetected,
    required this.vehicleClass,
    required this.passengerCount,
    required this.billable,
    this.endAt,
    this.startOdometerMetres,
    this.endOdometerMetres,
    this.purpose,
    this.categoryId,
    this.clientId,
    this.projectId,
    this.costCentre,
    this.driverId,
    this.fromLocationId,
    this.toLocationId,
    this.gpxRef,
    this.rateSchemeId,
    this.applicableRateThousandths,
    this.tierApplied,
    this.computedAmountMinor,
    this.currencyCode,
    this.gapMetres,
    this.roadtripId,
    this.legSequence,
    this.linkedFillupIds = const [],
    this.linkedExpenseIds = const [],
    this.fuelUsedMl,
    this.energyUsedWh,
    this.costMinor,
    this.tags = const [],
    this.notes,
    this.entryCalendar,
  });

  final String id;
  final String vehicleId;
  final Instant tripAt;
  final Instant? endAt;
  final int? startOdometerMetres;
  final int? endOdometerMetres;
  final int distanceMetres;
  final String? purpose;
  final TripClassification classification;
  final bool isDeductible;
  final bool isContemporaneous;
  final bool autoDetected;
  final String vehicleClass;
  final String? categoryId;
  final String? clientId;
  final String? projectId;
  final String? costCentre;
  final bool billable;
  final String? driverId;
  final String? fromLocationId;
  final String? toLocationId;
  final String? gpxRef;
  final String? rateSchemeId;
  final int? applicableRateThousandths;
  final String? tierApplied;
  final int passengerCount;
  final int? computedAmountMinor;
  final String? currencyCode;
  final int? gapMetres;
  final String? roadtripId;
  final int? legSequence;
  final List<String> linkedFillupIds;
  final List<String> linkedExpenseIds;
  final int? fuelUsedMl;
  final int? energyUsedWh;
  final int? costMinor;
  final List<String> tags;
  final String? notes;
  final String? entryCalendar;

  /// A missing-distance gap precedes this trip (a forgotten journey to review).
  bool get hasGapWarning => gapMetres != null && gapMetres! > 0;

  /// The odometer went backwards before this trip — the ledger must explain it.
  bool get hasRegressionWarning => gapMetres != null && gapMetres! < 0;

  /// Still in the unclassified backlog awaiting a one-tap tag.
  bool get isUnclassified => classification == TripClassification.unclassified;

  /// This trip's contribution to a [TripRollup].
  ClassifiedTrip toClassified() => ClassifiedTrip(
        distanceMetres: distanceMetres,
        classification: classification,
        deductionMinor: computedAmountMinor ?? 0,
        isDeductible: isDeductible,
      );
}

/// A reusable named place in the trip address book (M7-T9). Coordinates are
/// integer micro-degrees (degrees × 1e6), so the float path is never touched at
/// rest; convert only for the haversine at the edge.
class SavedLocation {
  const SavedLocation({
    required this.id,
    required this.name,
    required this.kind,
    this.latitudeMicro,
    this.longitudeMicro,
    this.mapPinRef,
    this.notes,
  });

  final String id;
  final String name;
  final String kind; // home | work | client | generic
  final int? latitudeMicro;
  final int? longitudeMicro;
  final String? mapPinRef;
  final String? notes;

  bool get isHome => kind == 'home';
  bool get isWork => kind == 'work';
  bool get hasCoordinates => latitudeMicro != null && longitudeMicro != null;

  /// Decimal-degree latitude for the haversine edge, or null.
  double? get latitude => latitudeMicro == null ? null : latitudeMicro! / 1e6;
  double? get longitude =>
      longitudeMicro == null ? null : longitudeMicro! / 1e6;
}

/// A multi-day road-trip container grouping legs into one P&L (M7-T4).
class Roadtrip {
  const Roadtrip({
    required this.id,
    required this.vehicleId,
    required this.title,
    required this.startAt,
    required this.currencyCode,
    required this.companionCount,
    this.endAt,
    this.notes,
  });

  final String id;
  final String vehicleId;
  final String title;
  final Instant startAt;
  final Instant? endAt;
  final int companionCount;
  final String currencyCode;
  final String? notes;
}
