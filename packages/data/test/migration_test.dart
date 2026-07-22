import 'dart:io';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('schemaVersion is 3 and a fresh DB builds the full schema', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    expect(db.schemaVersion, 3);

    // A query forces onCreate (createAll + indexes); no throw = schema built.
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll(<String>[
        'vehicles',
        'odometer_readings',
        'fuel_entries',
        'service_entries',
        'expenses',
        'trips',
        'reminders',
        'categories',
        'rollups',
        'attachments',
        'settings',
        'scheduled_notifications',
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

  test('v1 → v3 forward migration adds settings + schedule schema, keeps data',
      () async {
    final dir = Directory.systemTemp.createTempSync('cap_mig2');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.sqlite';

    // Build a fresh (v3) DB, seed a vehicle, then rewind the on-disk schema to
    // v1 — drop the v2/v3 additions (settings, scheduled_notifications, and the
    // F5 reminder columns) and set user_version = 1 — to simulate an old install.
    final setup = AppDatabase(NativeDatabase(File(path)));
    final v =
        (await VehiclesRepository(setup).add(nickname: 'Keeper')).valueOrNull!;
    await setup.customStatement('DROP TABLE settings');
    await setup.customStatement('DROP TABLE scheduled_notifications');
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
    await setup.customStatement('PRAGMA user_version = 1');
    await setup.close();

    // Reopen: drift sees v1 < v3 and runs both guarded forward steps.
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
}
