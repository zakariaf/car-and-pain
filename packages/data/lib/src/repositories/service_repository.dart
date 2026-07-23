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

  /// The parts fitted in a line item, as entered.
  Future<List<PartUsed>> partsFor(String lineItemId) async {
    final rows = await (db.select(db.partsUsed)
          ..where((t) =>
              t.lineItemId.equals(lineItemId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_toPart).toList();
  }

  /// The fluids used in a line item.
  Future<List<FluidUsed>> fluidsFor(String lineItemId) async {
    final rows = await (db.select(db.fluidsUsed)
          ..where((t) =>
              t.lineItemId.equals(lineItemId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_toFluid).toList();
  }

  /// The DIY procedure steps for a line item, in order.
  Future<List<ProcedureStep>> procedureStepsFor(String lineItemId) async {
    final rows = await (db.select(db.serviceProcedureSteps)
          ..where((t) =>
              t.lineItemId.equals(lineItemId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.stepOrder)]))
        .get();
    return rows.map(_toStep).toList();
  }

  /// A reusable parts catalog for autocomplete (M4-T2): the most recent distinct
  /// prior part per (name, OEM number), optionally filtered by a case-insensitive
  /// [query] over name / brand / part numbers. Full orthographic search-folding is
  /// applied at the UI edge; this layer does the dedup + a light contains filter.
  Future<List<PartUsed>> partsCatalog({String? query, int limit = 20}) async {
    final rows = await (db.select(db.partsUsed)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    final needle = query?.trim().toLowerCase();
    final seen = <String>{};
    final out = <PartUsed>[];
    for (final r in rows) {
      final key = '${r.name.toLowerCase()}|${r.oemNumber ?? ''}';
      if (!seen.add(key)) continue; // keep only the newest per identity
      if (needle != null && needle.isNotEmpty) {
        final hay = [
          r.name,
          r.brand ?? '',
          r.oemNumber ?? '',
          r.aftermarketNumber ?? '',
        ].join(' ').toLowerCase();
        if (!hay.contains(needle)) continue;
      }
      out.add(_toPart(r));
      if (out.length >= limit) break;
    }
    return out;
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
          final lineItemId = newId();
          await db.into(db.serviceLineItems).insert(
                ServiceLineItemsCompanion.insert(
                  id: lineItemId,
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
                  warrantyUntilDate: Value(li.warrantyUntilDate),
                  warrantyUntilMileageMetres:
                      Value(li.warrantyUntilMileageMetres),
                ),
              );
          // Parts, fluids and procedure steps — same transaction (M4-T2).
          for (final p in li.parts) {
            await db.into(db.partsUsed).insert(
                  PartsUsedCompanion.insert(
                    id: newId(),
                    lineItemId: lineItemId,
                    name: p.name,
                    createdAt: now,
                    updatedAt: now,
                    brand: Value(p.brand),
                    oemNumber: Value(p.oemNumber),
                    aftermarketNumber: Value(p.aftermarketNumber),
                    quantity: Value(p.quantity),
                    unitCostMinor: Value(p.unitCostMinor),
                    supplier: Value(p.supplier),
                    warrantyUntilDate: Value(p.warrantyUntilDate),
                    warrantyUntilMileageMetres:
                        Value(p.warrantyUntilMileageMetres),
                  ),
                );
          }
          for (final f in li.fluids) {
            await db.into(db.fluidsUsed).insert(
                  FluidsUsedCompanion.insert(
                    id: newId(),
                    lineItemId: lineItemId,
                    fluidType: f.fluidType,
                    createdAt: now,
                    updatedAt: now,
                    spec: Value(f.spec),
                    quantityMl: Value(f.quantityMl),
                  ),
                );
          }
          var stepOrder = 0;
          for (final s in li.procedureSteps) {
            await db.into(db.serviceProcedureSteps).insert(
                  ServiceProcedureStepsCompanion.insert(
                    id: newId(),
                    lineItemId: lineItemId,
                    instruction: s.instruction,
                    createdAt: now,
                    updatedAt: now,
                    stepOrder: Value(stepOrder++),
                    torqueSpec: Value(s.torqueSpec),
                    notes: Value(s.notes),
                  ),
                );
          }
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

  /// Apply a bundled schedule [template] under [profile] to a vehicle (M4-T3):
  /// create one recurring reminder per entry, anchored to the vehicle's current
  /// odometer + [anchorDate], producing the initial next-due state. Distance and
  /// date rules re-anchor on completion (recurrence carried on date rules).
  /// [resolveTitle] localizes each service-type key at the app edge so the data
  /// layer stays l10n-free; a missing title falls back to the key. Every applied
  /// interval remains user-overridable (a plain reminder row). Returns the ids.
  Future<Result<List<String>, DbFailure>> applyTemplate(
    String vehicleId,
    ScheduleTemplate template, {
    required ScheduleProfile profile,
    required Instant anchorDate,
    int? anchorOdometerMetres,
    String Function(String serviceType)? resolveTitle,
  }) async {
    try {
      final now = nowMillis();
      var anchorOdo = anchorOdometerMetres;
      if (anchorOdo == null) {
        final veh = await (db.select(db.vehicles)
              ..where((t) => t.id.equals(vehicleId)))
            .getSingleOrNull();
        anchorOdo = veh?.currentOdometerMetres ?? 0;
      }
      final items = applyScheduleTemplate(
        template,
        profile: profile,
        anchorOdometerMetres: anchorOdo,
        anchorDate: anchorDate,
      );
      final ids = <String>[];
      await db.transaction(() async {
        for (final item in items) {
          final id = newId();
          ids.add(id);
          await db.into(db.reminders).insert(
                RemindersCompanion.insert(
                  id: id,
                  vehicleId: vehicleId,
                  title:
                      resolveTitle?.call(item.serviceType) ?? item.serviceType,
                  triggerType: _triggerFor(item.logic),
                  createdAt: now,
                  updatedAt: now,
                  dueDate: Value(item.nextDueDate?.epochMillis),
                  dueOdometerMetres: Value(item.nextDueOdometerMetres),
                  // A date/whichever-first rule re-anchors by its month interval.
                  recurrenceEvery: Value(item.intervalMonths),
                  recurrenceUnit:
                      Value(item.intervalMonths == null ? null : 'months'),
                ),
              );
        }
      });
      return Ok(ids);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'reminders'));
    }
  }

  String _triggerFor(ServiceIntervalLogic logic) => switch (logic) {
        ServiceIntervalLogic.time => 'date',
        ServiceIntervalLogic.distance => 'distance',
        ServiceIntervalLogic.whicheverFirst => 'whicheverFirst',
      };

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
        warrantyUntilDate: r.warrantyUntilDate,
        warrantyUntilMileageMetres: r.warrantyUntilMileageMetres,
      );

  PartUsed _toPart(PartUsedRow r) => PartUsed(
        id: r.id,
        lineItemId: r.lineItemId,
        name: r.name,
        brand: r.brand,
        oemNumber: r.oemNumber,
        aftermarketNumber: r.aftermarketNumber,
        quantity: r.quantity,
        unitCostMinor: r.unitCostMinor,
        supplier: r.supplier,
        warrantyUntilDate: r.warrantyUntilDate,
        warrantyUntilMileageMetres: r.warrantyUntilMileageMetres,
      );

  FluidUsed _toFluid(FluidUsedRow r) => FluidUsed(
        id: r.id,
        lineItemId: r.lineItemId,
        fluidType: r.fluidType,
        spec: r.spec,
        quantityMl: r.quantityMl,
      );

  ProcedureStep _toStep(ProcedureStepRow r) => ProcedureStep(
        id: r.id,
        lineItemId: r.lineItemId,
        stepOrder: r.stepOrder,
        instruction: r.instruction,
        torqueSpec: r.torqueSpec,
        notes: r.notes,
      );

  List<String> _decodeTags(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.cast<String>() : const [];
  }
}
