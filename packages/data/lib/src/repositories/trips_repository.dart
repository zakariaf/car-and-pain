import 'dart:convert';

import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../domain/trip.dart';
import 'base_repository.dart';

/// The trip logbook boundary (M7-T1). Owns manual trip entry by odometer, by
/// direct distance, or by from/to saved locations; writes start/end odometer
/// into the shared per-vehicle ledger (source-tagged `trip`); runs odometer-gap
/// reconciliation against the previous trip; and returns sealed [Result] —
/// [ValidationFailure] for a bad distance, [DbFailure] for a store error — never
/// throwing across the edge.
class TripsRepository extends BaseRepository {
  TripsRepository(super.db, {super.clock});

  static const _gap = GapReconciler();

  // ── reads ──────────────────────────────────────────────────────────────────

  /// A vehicle's trips, newest first, tombstone-filtered. Optional classification
  /// and date-window filters at the SQL level.
  Stream<List<Trip>> watchByVehicle(
    String vehicleId, {
    TripClassification? classification,
    int? sinceMillis,
    int? untilMillis,
  }) {
    final query = db.select(db.trips)
      ..where((t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false));
    if (classification != null) {
      query.where((t) => t.classification.equals(classification.name));
    }
    if (sinceMillis != null) {
      query.where((t) => t.tripAt.isBiggerOrEqualValue(sinceMillis));
    }
    if (untilMillis != null) {
      query.where((t) => t.tripAt.isSmallerOrEqualValue(untilMillis));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.tripAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Live trips belonging to a road-trip container, ordered by leg then time.
  Stream<List<Trip>> watchByRoadtrip(String roadtripId) {
    final query = db.select(db.trips)
      ..where(
          (t) => t.roadtripId.equals(roadtripId) & t.isDeleted.equals(false))
      ..orderBy([
        (t) => OrderingTerm.asc(t.legSequence),
        (t) => OrderingTerm.asc(t.tripAt),
      ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// One-shot snapshot in a date range — the report/rollup input.
  Future<List<Trip>> inRange(
    String vehicleId, {
    required int sinceMillis,
    required int untilMillis,
  }) async {
    final rows = await (db.select(db.trips)
          ..where((t) =>
              t.vehicleId.equals(vehicleId) &
              t.isDeleted.equals(false) &
              t.tripAt.isBiggerOrEqualValue(sinceMillis) &
              t.tripAt.isSmallerOrEqualValue(untilMillis)))
        .get();
    return rows.map(_toDomain).toList();
  }

  Future<Trip?> byId(String id) async {
    final row = await (db.select(db.trips)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  // ── writes ───────────────────────────────────────────────────────────────

  /// Record a trip. Distance resolves from the odometer delta when both readings
  /// are given, else from [directDistanceMetres]; a missing or non-positive
  /// distance is a typed [ValidationFailure]. When a start odometer is present it
  /// is reconciled against the previous trip's end (the gap is stored) and both
  /// readings are written to the shared ledger.
  Future<Result<String, Failure>> add({
    required String vehicleId,
    required Instant tripAt,
    Instant? endAt,
    int? startOdometerMetres,
    int? endOdometerMetres,
    int? directDistanceMetres,
    TripClassification classification = TripClassification.unclassified,
    bool? isDeductible,
    bool isContemporaneous = true,
    bool autoDetected = false,
    String vehicleClass = 'car',
    String? purpose,
    String? categoryId,
    String? clientId,
    String? projectId,
    String? costCentre,
    bool billable = false,
    String? driverId,
    String? fromLocationId,
    String? toLocationId,
    String? gpxRef,
    String? rateSchemeId,
    int? applicableRateThousandths,
    String? tierApplied,
    int passengerCount = 0,
    int? computedAmountMinor,
    String? currencyCode,
    String? roadtripId,
    int? legSequence,
    List<String> linkedFillupIds = const [],
    List<String> linkedExpenseIds = const [],
    int? fuelUsedMl,
    int? energyUsedWh,
    int? costMinor,
    List<String> tags = const [],
    String? notes,
    String? entryCalendar,
  }) async {
    // Resolve and validate the distance before touching the store.
    final int distance;
    if (startOdometerMetres != null && endOdometerMetres != null) {
      distance = endOdometerMetres - startOdometerMetres;
    } else if (directDistanceMetres != null) {
      distance = directDistanceMetres;
    } else {
      return const Err(ValidationFailure([FieldError('distance', 'required')]));
    }
    if (distance <= 0) {
      return const Err(
          ValidationFailure([FieldError('distance', 'non_positive')]));
    }

    try {
      final id = newId();
      final now = nowMillis();
      final deductible = isDeductible ?? classification.isDeductibleByDefault;

      // Gap reconciliation against the previous trip that closed with an
      // odometer reading (chronologically before this one).
      int? gapMetres;
      if (startOdometerMetres != null) {
        final prev = await (db.select(db.trips)
              ..where((t) =>
                  t.vehicleId.equals(vehicleId) &
                  t.isDeleted.equals(false) &
                  t.endOdometerMetres.isNotNull() &
                  t.tripAt.isSmallerThanValue(tripAt.epochMillis))
              ..orderBy([(t) => OrderingTerm.desc(t.tripAt)])
              ..limit(1))
            .getSingleOrNull();
        if (prev?.endOdometerMetres != null) {
          gapMetres = _gap
              .between(
                prevEndOdometerMetres: prev!.endOdometerMetres!,
                nextStartOdometerMetres: startOdometerMetres,
              )
              .gapMetres;
        }
      }

      await db.transaction(() async {
        await db.into(db.trips).insert(
              TripsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                tripAt: tripAt.epochMillis,
                distanceMetres: distance,
                createdAt: now,
                updatedAt: now,
                endAt: Value(endAt?.epochMillis),
                startOdometerMetres: Value(startOdometerMetres),
                endOdometerMetres: Value(endOdometerMetres),
                purpose: Value(purpose),
                classification: Value(classification.name),
                isDeductible: Value(deductible),
                isContemporaneous: Value(isContemporaneous),
                autoDetected: Value(autoDetected),
                vehicleClass: Value(vehicleClass),
                categoryId: Value(categoryId),
                clientId: Value(clientId),
                projectId: Value(projectId),
                costCentre: Value(costCentre),
                billable: Value(billable),
                driverId: Value(driverId),
                fromLocationId: Value(fromLocationId),
                toLocationId: Value(toLocationId),
                gpxRef: Value(gpxRef),
                rateSchemeId: Value(rateSchemeId),
                applicableRateThousandths: Value(applicableRateThousandths),
                tierApplied: Value(tierApplied),
                passengerCount: Value(passengerCount),
                computedAmountMinor: Value(computedAmountMinor),
                currencyCode: Value(currencyCode),
                gapMetres: Value(gapMetres),
                roadtripId: Value(roadtripId),
                legSequence: Value(legSequence),
                linkedFillupIds: Value(_encodeList(linkedFillupIds)),
                linkedExpenseIds: Value(_encodeList(linkedExpenseIds)),
                fuelUsedMl: Value(fuelUsedMl),
                energyUsedWh: Value(energyUsedWh),
                costMinor: Value(costMinor),
                tags: Value(_encodeList(tags)),
                notes: Value(notes),
                entryCalendar: Value(entryCalendar),
              ),
            );

        // Ledger writes — source-tagged, back-referenced to this trip.
        if (startOdometerMetres != null) {
          await _appendReading(
              vehicleId, startOdometerMetres, tripAt.epochMillis, id, now);
        }
        if (endOdometerMetres != null) {
          await _appendReading(vehicleId, endOdometerMetres,
              (endAt ?? tripAt).epochMillis, id, now);
        }
        // Advance the cached odometer only if this is the newest reading.
        final newest = endOdometerMetres ?? startOdometerMetres;
        final newestAt =
            (endOdometerMetres != null ? (endAt ?? tripAt) : tripAt)
                .epochMillis;
        if (newest != null) {
          await _cacheOdometerIfNewest(vehicleId, newest, newestAt, now);
        }
      });
      return Ok(id);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'trips'));
    }
  }

  /// One-tap (re)classification for the backlog: updates the tag and its default
  /// deductibility unless [isDeductible] pins it explicitly.
  Future<Result<void, DbFailure>> classify(
    String id,
    TripClassification classification, {
    bool? isDeductible,
  }) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.trips)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null || cur.isDeleted) return false;
        await (db.update(db.trips)..where((t) => t.id.equals(id))).write(
          TripsCompanion(
            classification: Value(classification.name),
            isDeductible:
                Value(isDeductible ?? classification.isDeductibleByDefault),
            updatedAt: Value(now),
            rowRevision: Value(cur.rowRevision + 1),
          ),
        );
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('trip'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'trips'));
    }
  }

  /// Soft-delete to trash. The historical odometer readings stay in the ledger
  /// (a deleted trip does not unmake a reading), matching the fuel/service
  /// precedent.
  Future<Result<void, DbFailure>> softDelete(
    String id, {
    Duration retention = const Duration(days: 30),
  }) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.trips)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null || cur.isDeleted) return false;
        await (db.update(db.trips)..where((t) => t.id.equals(id))).write(
          TripsCompanion(
            isDeleted: const Value(true),
            deletedAt: Value(now),
            trashExpiresAt: Value(now + retention.inMilliseconds),
            updatedAt: Value(now),
            rowRevision: Value(cur.rowRevision + 1),
          ),
        );
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('trip'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'trips'));
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<void> _appendReading(
    String vehicleId,
    int value,
    int takenAt,
    String tripId,
    int now,
  ) async {
    await db.into(db.odometerReadings).insert(
          OdometerReadingsCompanion.insert(
            id: newId(),
            vehicleId: vehicleId,
            value: value,
            takenAt: takenAt,
            source: LedgerSource.trip.name,
            createdAt: now,
            updatedAt: now,
            sourceRecordId: Value(tripId),
          ),
        );
  }

  Future<void> _cacheOdometerIfNewest(
    String vehicleId,
    int odometerMetres,
    int atMs,
    int now,
  ) async {
    final veh = await (db.select(db.vehicles)
          ..where((t) => t.id.equals(vehicleId)))
        .getSingleOrNull();
    if (veh == null) return;
    if (veh.currentOdometerAt != null && veh.currentOdometerAt! >= atMs) return;
    await (db.update(db.vehicles)..where((t) => t.id.equals(vehicleId))).write(
      VehiclesCompanion(
        currentOdometerMetres: Value(odometerMetres),
        currentOdometerAt: Value(atMs),
        updatedAt: Value(now),
      ),
    );
  }

  Trip _toDomain(TripRow r) => Trip(
        id: r.id,
        vehicleId: r.vehicleId,
        tripAt: Instant.fromEpochMillis(r.tripAt),
        endAt: r.endAt == null ? null : Instant.fromEpochMillis(r.endAt!),
        startOdometerMetres: r.startOdometerMetres,
        endOdometerMetres: r.endOdometerMetres,
        distanceMetres: r.distanceMetres,
        purpose: r.purpose,
        classification: _classFrom(r.classification),
        isDeductible: r.isDeductible,
        isContemporaneous: r.isContemporaneous,
        autoDetected: r.autoDetected,
        vehicleClass: r.vehicleClass,
        categoryId: r.categoryId,
        clientId: r.clientId,
        projectId: r.projectId,
        costCentre: r.costCentre,
        billable: r.billable,
        driverId: r.driverId,
        fromLocationId: r.fromLocationId,
        toLocationId: r.toLocationId,
        gpxRef: r.gpxRef,
        rateSchemeId: r.rateSchemeId,
        applicableRateThousandths: r.applicableRateThousandths,
        tierApplied: r.tierApplied,
        passengerCount: r.passengerCount,
        computedAmountMinor: r.computedAmountMinor,
        currencyCode: r.currencyCode,
        gapMetres: r.gapMetres,
        roadtripId: r.roadtripId,
        legSequence: r.legSequence,
        linkedFillupIds: _decodeList(r.linkedFillupIds),
        linkedExpenseIds: _decodeList(r.linkedExpenseIds),
        fuelUsedMl: r.fuelUsedMl,
        energyUsedWh: r.energyUsedWh,
        costMinor: r.costMinor,
        tags: _decodeList(r.tags),
        notes: r.notes,
        entryCalendar: r.entryCalendar,
      );

  static TripClassification _classFrom(String s) => switch (s) {
        'business' => TripClassification.business,
        'personal' => TripClassification.personal,
        'commute' => TripClassification.commute,
        _ => TripClassification.unclassified,
      };

  static String? _encodeList(List<String> xs) =>
      xs.isEmpty ? null : jsonEncode(xs);

  static List<String> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.cast<String>() : const [];
  }
}
