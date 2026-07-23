import 'dart:convert';

import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../domain/service_visit.dart';
import 'base_repository.dart';
import 'rollup_service.dart';

/// The transactional service-visit write (M4-T1): a visit header, its line items,
/// its odometer ledger row, the cached vehicle odometer, and the monthly cost
/// rollup are written in ONE transaction so one receipt maps to one visit and the
/// spine never desyncs. Service types resolve through the shared taxonomy — never
/// an enum. The visit total is computed by the pure [ServiceCostEngine].
class ServiceRepository extends BaseRepository {
  ServiceRepository(super.db, {super.clock});

  RollupService get _rollups => RollupService(db);

  // ── reads ────────────────────────────────────────────────────────────────

  /// A vehicle's visit history, newest first, tombstone-filtered. Optionally
  /// filtered by provider, DIY/shop, and a date window (all at the SQL level).
  /// Line items are loaded on demand via [lineItemsFor] / [visit].
  Stream<List<ServiceVisit>> watchByVehicle(
    String vehicleId, {
    String? providerId,
    bool? isDiy,
    int? sinceMillis,
    int? untilMillis,
  }) {
    final query = db.select(db.serviceEntries)
      ..where((t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false));
    if (providerId != null) {
      query.where((t) => t.providerId.equals(providerId));
    }
    if (isDiy != null) {
      query.where((t) => t.isDiy.equals(isDiy));
    }
    if (sinceMillis != null) {
      query.where((t) => t.servicedAt.isBiggerOrEqualValue(sinceMillis));
    }
    if (untilMillis != null) {
      query.where((t) => t.servicedAt.isSmallerOrEqualValue(untilMillis));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.servicedAt)]);
    return query
        .watch()
        .map((rows) => rows.map((r) => _toVisit(r, const [])).toList());
  }

  /// A visit's live line items, ordered as entered.
  Future<List<ServiceLineItem>> lineItemsFor(String visitId) async {
    final rows = await (db.select(db.serviceLineItems)
          ..where((t) => t.visitId.equals(visitId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_toLineItem).toList();
  }

  /// One visit with its line items, or null if missing/tombstoned.
  Future<ServiceVisit?> visit(String visitId) async {
    final row = await (db.select(db.serviceEntries)
          ..where((t) => t.id.equals(visitId) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    if (row == null) return null;
    return _toVisit(row, await lineItemsFor(visitId));
  }

  /// The resetting/non-resetting service events per service type for a vehicle —
  /// the input the pure [ServiceScheduleEngine] anchors last-done / next-due from.
  /// Keyed by `serviceTypeId`; line items without a type are ignored.
  Future<Map<String, List<ServiceEvent>>> serviceEventsByType(
    String vehicleId,
  ) async {
    final visits = await (db.select(db.serviceEntries)
          ..where(
              (t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false)))
        .get();
    final visitById = {for (final v in visits) v.id: v};
    final items = await (db.select(db.serviceLineItems)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    final result = <String, List<ServiceEvent>>{};
    for (final li in items) {
      final typeId = li.serviceTypeId;
      if (typeId == null) continue;
      final v = visitById[li.visitId];
      if (v == null) continue; // another vehicle, or a tombstoned visit
      (result[typeId] ??= []).add(
        ServiceEvent(
          doneAt: Instant.fromEpochMillis(v.servicedAt),
          odometerMetres: v.odometerMetres,
          resetsInterval: li.resetsInterval,
        ),
      );
    }
    return result;
  }

  // ── writes ───────────────────────────────────────────────────────────────

  /// Record a visit and its line items. The odometer, when captured, is written
  /// into the shared ledger in the same transaction (source `service`); the
  /// vehicle's cached odometer is only advanced when this reading is the newest,
  /// so a back-dated historical service never rewinds it. Returns the visit id.
  Future<Result<String, DbFailure>> add({
    required String vehicleId,
    required Instant servicedAt,
    required String currencyCode,
    List<ServiceLineItemDraft> lineItems = const [],
    int? odometerMetres,
    String? providerId,
    bool isDiy = false,
    int taxMinor = 0,
    int discountMinor = 0,
    int feesMinor = 0,
    int? labourMinutes,
    int? labourRateMinor,
    List<String> tags = const [],
    String source = 'manual',
    String? scheduleProfile,
    String? notes,
  }) async {
    try {
      final id = newId();
      final now = nowMillis();
      // Authoritative total from the pure cost engine (integer minor units).
      final total = const ServiceCostEngine().visitTotalMinor(
        VisitCost(
          lineItems: [
            for (final li in lineItems)
              ServiceLineItemCost(
                labourMinor: li.labourMinor,
                partsMinor: li.partsMinor,
              ),
          ],
          taxMinor: taxMinor,
          discountMinor: discountMinor,
          feesMinor: feesMinor,
        ),
      );
      await db.transaction(() async {
        await db.into(db.serviceEntries).insert(
              ServiceEntriesCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                servicedAt: servicedAt.epochMillis,
                totalCostMinor: total,
                currencyCode: currencyCode,
                createdAt: now,
                updatedAt: now,
                odometerMetres: Value(odometerMetres),
                isDiy: Value(isDiy),
                providerId: Value(providerId),
                taxMinor: Value(taxMinor),
                discountMinor: Value(discountMinor),
                feesMinor: Value(feesMinor),
                labourMinutes: Value(labourMinutes),
                labourRateMinor: Value(labourRateMinor),
                tags: Value(tags.isEmpty ? null : jsonEncode(tags)),
                source: Value(source),
                scheduleProfile: Value(scheduleProfile),
                notes: Value(notes),
              ),
            );
        var order = 0;
        for (final li in lineItems) {
          await db.into(db.serviceLineItems).insert(
                ServiceLineItemsCompanion.insert(
                  id: newId(),
                  visitId: id,
                  createdAt: now,
                  updatedAt: now,
                  serviceTypeId: Value(li.serviceTypeId),
                  labourMinor: Value(li.labourMinor),
                  partsMinor: Value(li.partsMinor),
                  resetsInterval: Value(li.resetsInterval),
                  isDiy: Value(li.isDiy),
                  intervalDistanceMetres: Value(li.intervalDistanceMetres),
                  intervalMonths: Value(li.intervalMonths),
                  intervalLogic: Value(li.intervalLogic),
                  sortOrder: Value(order++),
                  notes: Value(li.notes),
                ),
              );
        }
        // Ledger write — only when the odometer was captured at this visit.
        if (odometerMetres != null) {
          await db.into(db.odometerReadings).insert(
                OdometerReadingsCompanion.insert(
                  id: newId(),
                  vehicleId: vehicleId,
                  value: odometerMetres,
                  takenAt: servicedAt.epochMillis,
                  source: LedgerSource.service.name,
                  createdAt: now,
                  updatedAt: now,
                  sourceRecordId: Value(id),
                ),
              );
          await _cacheOdometerIfNewest(
              vehicleId, odometerMetres, servicedAt.epochMillis, now);
        }
        // The visit total feeds the same monthly cost rollup as fuel/expenses.
        await _rollups.bump(
          vehicleId: vehicleId,
          period: monthPeriodKey(servicedAt.epochMillis),
          metric: 'costMinor',
          delta: total,
          now: now,
        );
      });
      return Ok(id);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'service_entries'));
    }
  }

  /// Soft-delete a visit (and its owned line items) to trash — never a hard
  /// delete. The additive cost rollup this visit bumped is reversed so dashboards
  /// never count a trashed visit. The ledger row it wrote remains (audited).
  Future<Result<void, DbFailure>> softDelete(
    String id, {
    Duration retention = const Duration(days: 30),
  }) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.serviceEntries)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null || cur.isDeleted) return false;
        final expires = now + retention.inMilliseconds;
        await (db.update(db.serviceEntries)..where((t) => t.id.equals(id)))
            .write(
          ServiceEntriesCompanion(
            isDeleted: const Value(true),
            deletedAt: Value(now),
            trashExpiresAt: Value(expires),
            updatedAt: Value(now),
            rowRevision: Value(cur.rowRevision + 1),
          ),
        );
        // Tombstone the owned line items too, so per-item reads respect it and
        // P2P merge sees the delete (rowRevision bumped per row).
        final lineRows = await (db.select(db.serviceLineItems)
              ..where((t) => t.visitId.equals(id) & t.isDeleted.equals(false)))
            .get();
        for (final li in lineRows) {
          await (db.update(db.serviceLineItems)
                ..where((t) => t.id.equals(li.id)))
              .write(
            ServiceLineItemsCompanion(
              isDeleted: const Value(true),
              deletedAt: Value(now),
              trashExpiresAt: Value(expires),
              updatedAt: Value(now),
              rowRevision: Value(li.rowRevision + 1),
            ),
          );
        }
        await _rollups.bump(
          vehicleId: cur.vehicleId,
          period: monthPeriodKey(cur.servicedAt),
          metric: 'costMinor',
          delta: -cur.totalCostMinor,
          now: now,
        );
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('service_entry'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'service_entries'));
    }
  }

  // ── internals ──────────────────────────────────────────────────────────────

  /// Advance the vehicle's cached odometer only when [atMs] is at least as new as
  /// the last cached reading — so a back-dated service never rewinds it.
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

  ServiceVisit _toVisit(ServiceEntry r, List<ServiceLineItem> lineItems) =>
      ServiceVisit(
        id: r.id,
        vehicleId: r.vehicleId,
        servicedAt: Instant.fromEpochMillis(r.servicedAt),
        odometerMetres: r.odometerMetres,
        totalCostMinor: r.totalCostMinor,
        currencyCode: r.currencyCode,
        providerId: r.providerId,
        isDiy: r.isDiy,
        taxMinor: r.taxMinor,
        discountMinor: r.discountMinor,
        feesMinor: r.feesMinor,
        labourMinutes: r.labourMinutes,
        labourRateMinor: r.labourRateMinor,
        tags: _decodeTags(r.tags),
        source: r.source,
        scheduleProfile: r.scheduleProfile,
        notes: r.notes,
        lineItems: lineItems,
      );

  ServiceLineItem _toLineItem(ServiceLineItemRow r) => ServiceLineItem(
        id: r.id,
        visitId: r.visitId,
        serviceTypeId: r.serviceTypeId,
        labourMinor: r.labourMinor,
        partsMinor: r.partsMinor,
        resetsInterval: r.resetsInterval,
        isDiy: r.isDiy,
        intervalDistanceMetres: r.intervalDistanceMetres,
        intervalMonths: r.intervalMonths,
        intervalLogic: r.intervalLogic,
        sortOrder: r.sortOrder,
        notes: r.notes,
      );

  List<String> _decodeTags(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.cast<String>() : const [];
  }
}
