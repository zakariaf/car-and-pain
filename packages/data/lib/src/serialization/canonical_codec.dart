import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../merge/lww_merge_engine.dart';

typedef _JsonRow = Map<String, dynamic>;

class _Entity {
  const _Entity(this.name, this.exportRows, this.importRow);
  final String name;
  final Future<List<_JsonRow>> Function() exportRows;
  final Future<void> Function(_JsonRow json) importRow;
}

/// Versioned **canonical** export/import for the data layer (F2-T12).
///
/// Every foundation entity round-trips as canonical JSON (SI base units,
/// integer minor-unit money, UTC epoch millis — never display-converted), with
/// tombstones and cluster-swap offsets preserved so a restore never resurrects
/// trashed data or breaks ledger continuity. This is the boundary the F6 backup
/// engine and later household sync build on. (F2 is a full replace-restore;
/// merge-aware import is F6.)
class CanonicalCodec {
  CanonicalCodec(this.db);

  final AppDatabase db;

  /// The canonical archive format version (independent of the DB schema
  /// version). An older build refuses a newer archive.
  static const int formatVersion = 1;

  // Insertion (FK-safe) order: parents before children. Delete runs reversed.
  late final List<_Entity> _entities = [
    _Entity(
      'vehicles',
      () async =>
          (await db.select(db.vehicles).get()).map((r) => r.toJson()).toList(),
      (j) => db
          .into(db.vehicles)
          .insert(VehicleRow.fromJson(j), mode: InsertMode.insertOrReplace),
    ),
    // Vehicle child tables (M2) — after vehicles (FK-safe), keyed by vehicle_id.
    _Entity(
      'plate_history',
      () async => (await db.select(db.plateHistory).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db.into(db.plateHistory).insert(PlateHistoryRow.fromJson(j),
          mode: InsertMode.insertOrReplace),
    ),
    _Entity(
      'valuation_history',
      () async => (await db.select(db.valuationHistory).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db
          .into(db.valuationHistory)
          .insert(ValuationRow.fromJson(j), mode: InsertMode.insertOrReplace),
    ),
    _Entity(
      'state_of_health_log',
      () async => (await db.select(db.stateOfHealthLog).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db.into(db.stateOfHealthLog).insert(StateOfHealthRow.fromJson(j),
          mode: InsertMode.insertOrReplace),
    ),
    _Entity(
      'categories',
      () async => (await db.select(db.categories).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db
          .into(db.categories)
          .insert(CategoryRow.fromJson(j), mode: InsertMode.insertOrReplace),
    ),
    _Entity(
      'odometer_readings',
      () async => (await db.select(db.odometerReadings).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db.into(db.odometerReadings).insert(OdometerReading.fromJson(j),
          mode: InsertMode.insertOrReplace),
    ),
    _Entity(
      'fuel_entries',
      () async => (await db.select(db.fuelEntries).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db
          .into(db.fuelEntries)
          .insert(FuelEntryRow.fromJson(j), mode: InsertMode.insertOrReplace),
    ),
    // Service provider directory (M4-T1) — global, FK-free; before service
    // visits, which reference it via provider_id.
    _Entity(
      'service_providers',
      () async => (await db.select(db.serviceProviders).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db.into(db.serviceProviders).insert(
            ServiceProviderRow.fromJson(j),
            mode: InsertMode.insertOrReplace,
          ),
    ),
    _Entity(
      'service_entries',
      () async => (await db.select(db.serviceEntries).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db
          .into(db.serviceEntries)
          .insert(ServiceEntry.fromJson(j), mode: InsertMode.insertOrReplace),
    ),
    // Service line items (M4-T1) — after service visits (FK visit_id) and
    // categories (FK service_type_id), both registered above.
    _Entity(
      'service_line_items',
      () async => (await db.select(db.serviceLineItems).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db.into(db.serviceLineItems).insert(
            ServiceLineItemRow.fromJson(j),
            mode: InsertMode.insertOrReplace,
          ),
    ),
    // Line-item detail (M4-T2) — after service_line_items (FK line_item_id).
    _Entity(
      'parts_used',
      () async =>
          (await db.select(db.partsUsed).get()).map((r) => r.toJson()).toList(),
      (j) => db.into(db.partsUsed).insert(
            PartUsedRow.fromJson(j),
            mode: InsertMode.insertOrReplace,
          ),
    ),
    _Entity(
      'fluids_used',
      () async => (await db.select(db.fluidsUsed).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db.into(db.fluidsUsed).insert(
            FluidUsedRow.fromJson(j),
            mode: InsertMode.insertOrReplace,
          ),
    ),
    _Entity(
      'service_procedure_steps',
      () async => (await db.select(db.serviceProcedureSteps).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db.into(db.serviceProcedureSteps).insert(
            ProcedureStepRow.fromJson(j),
            mode: InsertMode.insertOrReplace,
          ),
    ),
    _Entity(
      'expenses',
      () async =>
          (await db.select(db.expenses).get()).map((r) => r.toJson()).toList(),
      (j) => db
          .into(db.expenses)
          .insert(Expense.fromJson(j), mode: InsertMode.insertOrReplace),
    ),
    _Entity(
      'trips',
      () async =>
          (await db.select(db.trips).get()).map((r) => r.toJson()).toList(),
      (j) => db
          .into(db.trips)
          .insert(Trip.fromJson(j), mode: InsertMode.insertOrReplace),
    ),
    _Entity(
      'reminders',
      () async =>
          (await db.select(db.reminders).get()).map((r) => r.toJson()).toList(),
      (j) => db
          .into(db.reminders)
          .insert(Reminder.fromJson(j), mode: InsertMode.insertOrReplace),
    ),
    _Entity(
      'rollups',
      () async =>
          (await db.select(db.rollups).get()).map((r) => r.toJson()).toList(),
      (j) => db
          .into(db.rollups)
          .insert(Rollup.fromJson(j), mode: InsertMode.insertOrReplace),
    ),
    _Entity(
      'attachments',
      () async => (await db.select(db.attachments).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db
          .into(db.attachments)
          .insert(AttachmentRow.fromJson(j), mode: InsertMode.insertOrReplace),
    ),
    // App-global localization/display preferences (F4-T10). Additive and
    // FK-free: an older archive that predates it simply omits the key, and the
    // import's `?? const []` leaves the restored app at first-run resolution.
    // Values are canonical (locale codes / enum names), never display strings.
    _Entity(
      'settings',
      // Transient UI drafts (`draft:*`) are never exported — a backup captures
      // saved data, not half-typed forms.
      () async => (await (db.select(db.settings)
                ..where((t) => t.key.like('draft:%').not()))
              .get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db
          .into(db.settings)
          .insert(SettingRow.fromJson(j), mode: InsertMode.insertOrReplace),
    ),
    // The saved-stations library (M3-T9) — FK-free, rides backup/export.
    _Entity(
      'saved_stations',
      () async => (await db.select(db.savedStations).get())
          .map((r) => r.toJson())
          .toList(),
      (j) => db.into(db.savedStations).insert(SavedStationRow.fromJson(j),
          mode: InsertMode.insertOrReplace),
    ),
  ];

  /// Export the whole DB to a canonical, versioned document (JSON-encodable).
  Future<Map<String, dynamic>> export() async {
    final entities = <String, dynamic>{};
    for (final e in _entities) {
      entities[e.name] = await e.exportRows();
    }
    return {
      'formatVersion': formatVersion,
      'schemaVersion': db.schemaVersion,
      'entities': entities,
    };
  }

  /// Replace-restore the DB from a canonical document, re-inserting every entity
  /// in FK-safe order. Refuses a newer archive with a typed [ImportFailure].
  Future<Result<void, ImportFailure>> import(Map<String, dynamic> doc) async {
    final fmt = doc['formatVersion'];
    if (fmt is! int) return const Err(CorruptArchive());
    if (fmt != formatVersion) {
      return Err(SchemaVersionMismatch(expected: formatVersion, found: fmt));
    }
    final entities = doc['entities'];
    if (entities is! Map) return const Err(CorruptArchive());

    try {
      await db.transaction(() async {
        // Wipe children → parents, then insert parents → children.
        for (final e in _entities.reversed) {
          await db.customStatement('DELETE FROM ${e.name};');
        }
        for (final e in _entities) {
          final rows = (entities[e.name] as List?) ?? const <dynamic>[];
          for (final row in rows) {
            await e.importRow((row as Map).cast<String, dynamic>());
          }
        }
      });
      return const Ok(null);
    } on Object {
      return const Err(CorruptArchive());
    }
  }

  /// Compute the merge reconciliation WITHOUT writing (F6-T5 dry-run). Identical
  /// inputs give an identical report to [merge].
  Future<Result<MergeReport, ImportFailure>> mergePreview(
    Map<String, dynamic> doc,
  ) =>
      _merge(doc, apply: false);

  /// Merge-aware import (F6-T6): additively upsert incoming rows that WIN the
  /// deterministic LWW contest; losers are left untouched (never a wipe, unlike
  /// [import]). Settings (no `updated_at`) are device-local and kept as-is.
  /// Returns the same reconciliation report the dry-run produced.
  Future<Result<MergeReport, ImportFailure>> merge(Map<String, dynamic> doc) =>
      _merge(doc, apply: true);

  Future<Result<MergeReport, ImportFailure>> _merge(
    Map<String, dynamic> doc, {
    required bool apply,
  }) async {
    final fmt = doc['formatVersion'];
    if (fmt is! int) return const Err(CorruptArchive());
    if (fmt != formatVersion) {
      return Err(SchemaVersionMismatch(expected: formatVersion, found: fmt));
    }
    final entities = doc['entities'];
    if (entities is! Map) return const Err(CorruptArchive());

    const engine = LwwMergeEngine();
    final byEntity = <String, EntityStat>{};
    final conflicts = <MergeConflict>[];
    final winnersByEntity = <_Entity, List<Map<String, Object?>>>{};

    try {
      for (final e in _entities) {
        final incoming = [
          for (final r in (entities[e.name] as List?) ?? const <dynamic>[])
            (r as Map).cast<String, Object?>(),
        ];
        // Rows without `updatedAt` (settings) aren't LWW-mergeable — keep local.
        if (incoming.isEmpty || !incoming.first.containsKey('updatedAt')) {
          continue;
        }
        final localRows = await e.exportRows();
        final localIndex = <String, Map<String, Object?>>{
          for (final r in localRows)
            r['id'] as String: r.cast<String, Object?>(),
        };
        final result = engine.mergeEntity(
          entity: e.name,
          local: localIndex,
          incoming: incoming,
        );
        byEntity[e.name] = result.stat;
        conflicts.addAll(result.conflicts);
        winnersByEntity[e] = result.winners;
      }

      if (apply) {
        await db.transaction(() async {
          for (final e in _entities) {
            for (final w
                in winnersByEntity[e] ?? const <Map<String, Object?>>[]) {
              await e.importRow(w.cast<String, dynamic>());
            }
          }
        });
      }
      return Ok(MergeReport(byEntity: byEntity, conflicts: conflicts));
    } on Object {
      return const Err(CorruptArchive());
    }
  }
}
