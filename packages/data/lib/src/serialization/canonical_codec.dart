import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';

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
          .insert(FuelEntry.fromJson(j), mode: InsertMode.insertOrReplace),
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
          .insert(Attachment.fromJson(j), mode: InsertMode.insertOrReplace),
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
}
