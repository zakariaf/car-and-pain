import 'dart:io';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The vehicle columns added by the v4 → v5 (M2) migration step — dropped to
/// rewind a fresh DB below its introduction.
const _m2VehicleColumns = [
  'trim',
  'wheel_count',
  'axle_config',
  'license_plate',
  'plate_country',
  'vin',
  'vin_scanned',
  'vin_checksum_valid',
  'wmi_decoded',
  'paint_color',
  'paint_code',
  'secondary_energy_type',
  'secondary_tank_ml',
  'fuel_grade',
  'usable_capacity_joules',
  'connector_types',
  'distance_tracking_enabled',
  'status_changed_at',
  'sold_date',
  'sold_price_minor',
  'final_odometer_metres',
  'purchase_date',
  'purchase_price_minor',
  'purchase_currency',
  'current_value_minor',
  'group_id',
  'tags',
  'sort_order',
  'cover_photo_ref',
  'factory_specs',
  'consumption_unit',
];

/// The fuel_entries columns added by the v5 → v6 (M3) migration step.
const _m3FuelColumns = [
  'fuel_type',
  'octane_grade',
  'secondary_fuel_type',
  'volume_unit',
  'price_per_unit_thousandths',
  'is_free',
  'charger_type',
  'connector_type',
  'start_soc_pct',
  'end_soc_pct',
  'is_home_charge',
  'energy_from_wall_joules',
  'network',
  'station_id',
  'station_name',
  'payment_method',
  'trip_id',
  'tags',
  'receipt_attachment_id',
];

// The M4 (v8) header columns added to service_entries.
const _m4ServiceColumns = [
  'provider_id',
  'tax_minor',
  'discount_minor',
  'fees_minor',
  'labour_minutes',
  'labour_rate_minor',
  'tags',
  'source',
  'schedule_profile',
];

// The M4 (v8) interval-default columns added to categories.
const _m4CategoryColumns = [
  'default_interval_months',
  'default_interval_logic'
];

/// Rewind the M6 (v12) expense columns so a forward migration re-applies them.
Future<void> _dropM6(AppDatabase db) async {
  await db.customStatement('DROP TABLE financings');
  await db.customStatement('DROP TABLE budgets');
  // Drop the indexes that reference the M6 columns first — SQLite refuses to
  // DROP COLUMN while an index uses it.
  await db.customStatement('DROP INDEX IF EXISTS idx_expense_category');
  await db.customStatement('DROP INDEX IF EXISTS idx_expense_source');
  for (final c in [
    'driver_id',
    'fx_rate_thousandths',
    'fx_as_of',
    'base_amount_minor',
    'source_entity_type',
    'source_entity_id',
    'receipt_attachment_id',
    'tags',
    'entry_calendar',
  ]) {
    await db.customStatement('ALTER TABLE expenses DROP COLUMN $c');
  }
}

/// Rewind the M5 (v11) reminder columns so a forward migration re-applies them.
Future<void> _dropM5(AppDatabase db) async {
  await db.customStatement('ALTER TABLE reminders DROP COLUMN notes');
  await db.customStatement('ALTER TABLE reminders DROP COLUMN snooze_until');
}

/// Rewind the M4 (v8 + v9) additions on a freshly-built DB so a forward migration
/// can re-apply them. Drops leaf detail tables first, then line items and their
/// FK-bearing columns, then the parent table, then the taxonomy columns.
Future<void> _dropM4(AppDatabase db) async {
  // v10 (M4-T5) appointments.
  await db.customStatement('DROP TABLE service_appointments');
  // v9 (M4-T2) detail tables + workmanship-warranty columns.
  await db.customStatement('DROP TABLE parts_used');
  await db.customStatement('DROP TABLE fluids_used');
  await db.customStatement('DROP TABLE service_procedure_steps');
  await db.customStatement('ALTER TABLE service_line_items DROP COLUMN '
      'warranty_until_date');
  await db.customStatement('ALTER TABLE service_line_items DROP COLUMN '
      'warranty_until_mileage_metres');
  // v8 (M4-T1) line items, provider directory, header + taxonomy columns.
  await db.customStatement('DROP TABLE service_line_items');
  for (final c in _m4ServiceColumns) {
    await db.customStatement('ALTER TABLE service_entries DROP COLUMN $c');
  }
  await db.customStatement('DROP TABLE service_providers');
  for (final c in _m4CategoryColumns) {
    await db.customStatement('ALTER TABLE categories DROP COLUMN $c');
  }
}

/// Rewind the M7 (v13→v14) trip additions so a forward migration re-applies
/// them. Drop the index over trips.roadtrip_id first (SQLite refuses DROP COLUMN
/// while an index uses it), then the trip columns, then the referenced support
/// tables (safe only after the FK-bearing trip columns are gone).
Future<void> _dropM7(AppDatabase db) async {
  await db.customStatement('DROP INDEX IF EXISTS idx_trip_roadtrip');
  for (final c in [
    'end_at',
    'classification',
    'is_deductible',
    'is_contemporaneous',
    'auto_detected',
    'vehicle_class',
    'category_id',
    'client_id',
    'project_id',
    'cost_centre',
    'billable',
    'driver_id',
    'from_location_id',
    'to_location_id',
    'gpx_ref',
    'rate_scheme_id',
    'applicable_rate_thousandths',
    'tier_applied',
    'passenger_count',
    'computed_amount_minor',
    'currency_code',
    'gap_metres',
    'roadtrip_id',
    'leg_sequence',
    'linked_fillup_ids',
    'linked_expense_ids',
    'fuel_used_ml',
    'energy_used_wh',
    'cost_minor',
    'tags',
    'notes',
    'entry_calendar',
  ]) {
    await db.customStatement('ALTER TABLE trips DROP COLUMN $c');
  }
  await db.customStatement('DROP TABLE roadtrips');
  await db.customStatement('DROP TABLE rate_schemes');
  await db.customStatement('DROP TABLE saved_locations');
}

void main() {
  test('SnapshotGuard takes a pre-migration snapshot and restores on failure',
      () async {
    final dir = Directory.systemTemp.createTempSync('cap_mig');
    addTearDown(() => dir.deleteSync(recursive: true));
    final dbPath = '${dir.path}/app.sqlite';
    File(dbPath).writeAsStringSync('ORIGINAL');

    final guard = SnapshotGuard(dbPath);
    final snapshot = await guard.take();
    expect(File(snapshot).existsSync(), isTrue);

    // Simulate a failed migration that corrupts the DB and leaves stale WAL
    // sidecars behind, then restore.
    File(dbPath).writeAsStringSync('CORRUPT');
    File('$dbPath-wal').writeAsStringSync('STALE_WAL');
    File('$dbPath-shm').writeAsStringSync('STALE_SHM');
    await guard.restore(snapshot);

    expect(File(dbPath).readAsStringSync(), 'ORIGINAL');
    expect(File(snapshot).existsSync(), isFalse); // snapshot cleaned up
    // Stale sidecars must be gone — otherwise SQLite recovers their frames on
    // the next open and re-applies the writes the restore just undid.
    expect(File('$dbPath-wal').existsSync(), isFalse);
    expect(File('$dbPath-shm').existsSync(), isFalse);
  });

  test('schemaVersion is 14 and a fresh DB builds the full schema', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    expect(db.schemaVersion, 14);

    // A query forces onCreate (createAll + indexes); no throw = schema built.
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll(<String>[
        'vehicles',
        'plate_history',
        'valuation_history',
        'state_of_health_log',
        'odometer_readings',
        'fuel_entries',
        'service_entries',
        'service_providers',
        'service_line_items',
        'parts_used',
        'fluids_used',
        'service_procedure_steps',
        'service_appointments',
        'expenses',
        'financings',
        'budgets',
        'saved_locations',
        'rate_schemes',
        'roadtrips',
        'trips',
        'reminders',
        'categories',
        'rollups',
        'attachments',
        'settings',
        'scheduled_notifications',
        'saved_stations',
      ]),
    );

    // The index plan is present.
    final indexes = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
        .get();
    final indexNames = indexes.map((r) => r.read<String>('name')).toSet();
    expect(indexNames, contains('idx_odo_vehicle_time'));

    // The rollup key index is UNIQUE — one row per (vehicle, period, metric),
    // so RollupService.getSingleOrNull() can never trip on a duplicate.
    final rollupIdx = await db
        .customSelect(
          "SELECT name, \"unique\" AS uq FROM pragma_index_list('rollups')",
        )
        .get();
    final key =
        rollupIdx.firstWhere((r) => r.read<String>('name') == 'idx_rollup_key');
    expect(key.read<int>('uq'), 1);
  });

  test('v1 → v14 forward migration adds all later schema, keeps data',
      () async {
    final dir = Directory.systemTemp.createTempSync('cap_mig2');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.sqlite';

    // Build a fresh (v5) DB, seed a vehicle, then rewind the on-disk schema to
    // v1 — drop the v2..v5 additions (settings, scheduled_notifications, the F5
    // reminder columns, the F8 attachment columns, and the M2 vehicle columns +
    // child tables) and set user_version = 1 — to simulate an old install.
    final setup = AppDatabase(NativeDatabase(File(path)));
    final v =
        (await VehiclesRepository(setup).add(nickname: 'Keeper')).valueOrNull!;
    await setup.customStatement('DROP TABLE settings');
    await setup.customStatement('DROP TABLE scheduled_notifications');
    await setup.customStatement('DROP TABLE plate_history');
    await setup.customStatement('DROP TABLE valuation_history');
    await setup.customStatement('DROP TABLE state_of_health_log');
    await setup.customStatement('DROP TABLE saved_stations');
    const f5Columns = [
      'due_engine_minutes',
      'completed_at',
      'recurrence_every',
      'recurrence_unit',
      'lead_minutes',
      'lead_distance_metres',
      'severity',
      'quiet_start_minute',
      'quiet_end_minute',
      'quiet_deliver_minute',
    ];
    for (final c in f5Columns) {
      await setup.customStatement('ALTER TABLE reminders DROP COLUMN $c');
    }
    for (final c in ['size_bytes', 'thumbnail_relative_path', 'is_encrypted']) {
      await setup.customStatement('ALTER TABLE attachments DROP COLUMN $c');
    }
    // The M2 (v5) vehicle columns.
    for (final c in _m2VehicleColumns) {
      await setup.customStatement('ALTER TABLE vehicles DROP COLUMN $c');
    }
    // The M3 (v6) fuel_entries columns.
    for (final c in _m3FuelColumns) {
      await setup.customStatement('ALTER TABLE fuel_entries DROP COLUMN $c');
    }
    // The M4 (v8) service line items, provider directory, and header/taxonomy
    // columns.
    await _dropM7(setup);
    await _dropM6(setup);
    await _dropM5(setup);
    await _dropM4(setup);
    await setup.customStatement('PRAGMA user_version = 1');
    await setup.close();

    // Reopen: drift sees v1 < v6 and runs all guarded forward steps.
    final upgraded = AppDatabase(NativeDatabase(File(path)));
    addTearDown(upgraded.close);

    Future<int> tableCount(String name) async => (await upgraded
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='$name'",
            )
            .get())
        .length;
    expect(await tableCount('settings'), 1);
    expect(await tableCount('scheduled_notifications'), 1);
    // The M2 child tables are re-created.
    expect(await tableCount('plate_history'), 1);
    expect(await tableCount('valuation_history'), 1);
    expect(await tableCount('state_of_health_log'), 1);
    // A re-added M2 vehicle column is usable (smoke insert reads a plate back).
    await upgraded.customStatement(
      "UPDATE vehicles SET license_plate = 'ABC-123' WHERE id = ?",
      [v.id],
    );
    final plate = await upgraded.customSelect(
        'SELECT license_plate AS p FROM vehicles WHERE id = ?',
        variables: [Variable<String>(v.id)]).get();
    expect(plate.single.read<String>('p'), 'ABC-123');

    // The re-added reminder columns are back (a smoke insert with an F5 column).
    await upgraded.customStatement(
      'INSERT INTO reminders (id, created_at, updated_at, vehicle_id, title, '
      "trigger_type, severity) VALUES ('rem1', 0, 0, ?, 'x', 'date', 'overdue')",
      [v.id],
    );
    final rem = await upgraded
        .customSelect("SELECT severity FROM reminders WHERE id = 'rem1'")
        .get();
    expect(rem.single.read<String>('severity'), 'overdue');

    // The pre-existing vehicle survived the upgrade untouched.
    final rows = await upgraded.customSelect(
      'SELECT id FROM vehicles WHERE id = ?',
      variables: [Variable<String>(v.id)],
    ).get();
    expect(rows, hasLength(1));

    // …and the new settings table is immediately usable.
    expect(
        (await SettingsRepository(upgraded).set('locale', 'fa')).isOk, isTrue);
  });

  test('v3 → v4 adds attachment size/thumbnail/encryption columns, keeps rows',
      () async {
    final dir = Directory.systemTemp.createTempSync('cap_mig3');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.sqlite';

    // Fresh (v5) DB, seed an attachment row, then rewind to v3 by dropping the
    // F8 attachment columns AND the M2 (v5) additions and setting
    // user_version = 3 to simulate a pre-F8 install.
    final setup = AppDatabase(NativeDatabase(File(path)));
    await setup.customStatement(
      'INSERT INTO attachments (id, created_at, updated_at, sha256, '
      'relative_path, mime_type, linked_entity_type, linked_entity_id) '
      "VALUES ('att1', 0, 0, 'abc', 'a/b.jpg', 'image/jpeg', 'vehicle', 'v1')",
    );
    for (final c in ['size_bytes', 'thumbnail_relative_path', 'is_encrypted']) {
      await setup.customStatement('ALTER TABLE attachments DROP COLUMN $c');
    }
    await setup.customStatement('DROP TABLE plate_history');
    await setup.customStatement('DROP TABLE valuation_history');
    await setup.customStatement('DROP TABLE state_of_health_log');
    await setup.customStatement('DROP TABLE saved_stations');
    for (final c in _m2VehicleColumns) {
      await setup.customStatement('ALTER TABLE vehicles DROP COLUMN $c');
    }
    for (final c in _m3FuelColumns) {
      await setup.customStatement('ALTER TABLE fuel_entries DROP COLUMN $c');
    }
    await _dropM7(setup);
    await _dropM6(setup);
    await _dropM5(setup);
    await _dropM4(setup);
    await setup.customStatement('PRAGMA user_version = 3');
    await setup.close();

    // Reopen: drift sees v3 < v6 and runs the guarded forward steps (3→4…5→6).
    final upgraded = AppDatabase(NativeDatabase(File(path)));
    addTearDown(upgraded.close);

    // The pre-existing attachment row survived, and the new columns exist with
    // their defaults (size 0, thumbnail null, not encrypted).
    final repo = AttachmentsRepository(upgraded);
    final row = (await repo.getById('att1')).valueOrNull;
    expect(row, isNotNull);
    expect(row!.size, const ByteSize(0));
    expect(row.thumbnailRelativePath, isNull);
    expect(row.isEncrypted, isFalse);

    // …and a new attachment can be written using the F8 columns.
    final added = await repo.add(
      linkedEntityType: AttachmentOwner.vehicle,
      linkedEntityId: 'v1',
      sha256: 'def',
      relativePath: 'c/d.png',
      mimeType: 'image/png',
      sizeBytes: 2048,
      isEncrypted: true,
    );
    expect(added.valueOrNull?.size, const ByteSize(2048));
    expect(added.valueOrNull?.isEncrypted, isTrue);
  });
}
