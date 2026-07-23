import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../domain/rate_scheme.dart';
import '../domain/trip.dart';
import 'base_repository.dart';

/// The saved-locations address book (M7-T9). Named places reused across trips;
/// `home`/`work` drive automatic commute exclusion. Coordinates ride as integer
/// micro-degrees so nothing floats at rest.
class SavedLocationsRepository extends BaseRepository {
  SavedLocationsRepository(super.db, {super.clock});

  Stream<List<SavedLocation>> watchAll() {
    final query = db.select(db.savedLocations)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<SavedLocation?> byId(String id) async {
    final row = await (db.select(db.savedLocations)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<Result<String, DbFailure>> add({
    required String name,
    String kind = 'generic',
    int? latitudeMicro,
    int? longitudeMicro,
    String? mapPinRef,
    String? notes,
  }) async {
    try {
      final id = newId();
      final now = nowMillis();
      await db.into(db.savedLocations).insert(
            SavedLocationsCompanion.insert(
              id: id,
              name: name,
              createdAt: now,
              updatedAt: now,
              kind: Value(kind),
              latitudeMicro: Value(latitudeMicro),
              longitudeMicro: Value(longitudeMicro),
              mapPinRef: Value(mapPinRef),
              notes: Value(notes),
            ),
          );
      return Ok(id);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'saved_locations'));
    }
  }

  Future<Result<void, DbFailure>> softDelete(
    String id, {
    Duration retention = const Duration(days: 30),
  }) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.savedLocations)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null || cur.isDeleted) return false;
        await (db.update(db.savedLocations)..where((t) => t.id.equals(id)))
            .write(
          SavedLocationsCompanion(
            isDeleted: const Value(true),
            deletedAt: Value(now),
            trashExpiresAt: Value(now + retention.inMilliseconds),
            updatedAt: Value(now),
            rowRevision: Value(cur.rowRevision + 1),
          ),
        );
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('saved_location'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'saved_locations'));
    }
  }

  SavedLocation _toDomain(SavedLocationRow r) => SavedLocation(
        id: r.id,
        name: r.name,
        kind: r.kind,
        latitudeMicro: r.latitudeMicro,
        longitudeMicro: r.longitudeMicro,
        mapPinRef: r.mapPinRef,
        notes: r.notes,
      );
}

/// Persisted mileage-rate schemes (M7-T3). Rehydrates the pure engine on read.
class RateSchemesRepository extends BaseRepository {
  RateSchemesRepository(super.db, {super.clock});

  Stream<List<RateScheme>> watchAll() {
    final query = db.select(db.rateSchemes)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<RateScheme?> byId(String id) async {
    final row = await (db.select(db.rateSchemes)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// The rehydrated engine for a scheme id, or null if absent.
  Future<MileageRateScheme?> engineFor(String id) async {
    final scheme = await byId(id);
    return scheme?.toEngine();
  }

  Future<Result<String, DbFailure>> add({
    required String name,
    required String kind,
    required String currencyCode,
    required String unit,
    required List<RateRevision> revisions,
    int taxYearStartMonth = 1,
    int taxYearStartDay = 1,
    bool isBuiltIn = false,
  }) async {
    try {
      final id = newId();
      final now = nowMillis();
      await db.into(db.rateSchemes).insert(
            RateSchemesCompanion.insert(
              id: id,
              name: name,
              kind: kind,
              currencyCode: currencyCode,
              unit: unit,
              revisionsJson: RateScheme.encodeRevisions(revisions),
              createdAt: now,
              updatedAt: now,
              taxYearStartMonth: Value(taxYearStartMonth),
              taxYearStartDay: Value(taxYearStartDay),
              isBuiltIn: Value(isBuiltIn),
            ),
          );
      return Ok(id);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'rate_schemes'));
    }
  }

  Future<Result<void, DbFailure>> softDelete(
    String id, {
    Duration retention = const Duration(days: 30),
  }) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.rateSchemes)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null || cur.isDeleted) return false;
        await (db.update(db.rateSchemes)..where((t) => t.id.equals(id))).write(
          RateSchemesCompanion(
            isDeleted: const Value(true),
            deletedAt: Value(now),
            trashExpiresAt: Value(now + retention.inMilliseconds),
            updatedAt: Value(now),
            rowRevision: Value(cur.rowRevision + 1),
          ),
        );
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('rate_scheme'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'rate_schemes'));
    }
  }

  RateScheme _toDomain(RateSchemeRow r) => RateScheme(
        id: r.id,
        name: r.name,
        kind: r.kind,
        currencyCode: r.currencyCode,
        unit: r.unit,
        taxYearStartMonth: r.taxYearStartMonth,
        taxYearStartDay: r.taxYearStartDay,
        revisionsJson: r.revisionsJson,
        isBuiltIn: r.isBuiltIn,
      );
}

/// Road-trip containers (M7-T4). The P&L is aggregated by [RoadTripPnl] over the
/// container's legs; this repo owns the container lifecycle only.
class RoadtripsRepository extends BaseRepository {
  RoadtripsRepository(super.db, {super.clock});

  Stream<List<Roadtrip>> watchByVehicle(String vehicleId) {
    final query = db.select(db.roadtrips)
      ..where((t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.startAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<Roadtrip?> byId(String id) async {
    final row = await (db.select(db.roadtrips)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<Result<String, DbFailure>> add({
    required String vehicleId,
    required String title,
    required Instant startAt,
    required String currencyCode,
    Instant? endAt,
    int companionCount = 1,
    String? notes,
  }) async {
    try {
      final id = newId();
      final now = nowMillis();
      await db.into(db.roadtrips).insert(
            RoadtripsCompanion.insert(
              id: id,
              vehicleId: vehicleId,
              title: title,
              startAt: startAt.epochMillis,
              currencyCode: currencyCode,
              createdAt: now,
              updatedAt: now,
              endAt: Value(endAt?.epochMillis),
              companionCount: Value(companionCount),
              notes: Value(notes),
            ),
          );
      return Ok(id);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'roadtrips'));
    }
  }

  Future<Result<void, DbFailure>> softDelete(
    String id, {
    Duration retention = const Duration(days: 30),
  }) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.roadtrips)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null || cur.isDeleted) return false;
        await (db.update(db.roadtrips)..where((t) => t.id.equals(id))).write(
          RoadtripsCompanion(
            isDeleted: const Value(true),
            deletedAt: Value(now),
            trashExpiresAt: Value(now + retention.inMilliseconds),
            updatedAt: Value(now),
            rowRevision: Value(cur.rowRevision + 1),
          ),
        );
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('roadtrip'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'roadtrips'));
    }
  }

  Roadtrip _toDomain(RoadtripRow r) => Roadtrip(
        id: r.id,
        vehicleId: r.vehicleId,
        title: r.title,
        startAt: Instant.fromEpochMillis(r.startAt),
        endAt: r.endAt == null ? null : Instant.fromEpochMillis(r.endAt!),
        companionCount: r.companionCount,
        currencyCode: r.currencyCode,
        notes: r.notes,
      );
}
