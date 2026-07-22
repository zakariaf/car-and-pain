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

  test('schemaVersion is 2 and a fresh DB builds the full schema', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    expect(db.schemaVersion, 2);

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

  test('v1 → v2 forward migration creates settings and preserves data',
      () async {
    final dir = Directory.systemTemp.createTempSync('cap_mig2');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.sqlite';

    // Build a v2 DB, seed a vehicle, then rewind the on-disk schema to v1
    // (drop settings + set user_version = 1) to simulate an existing install.
    final setup = AppDatabase(NativeDatabase(File(path)));
    final v =
        (await VehiclesRepository(setup).add(nickname: 'Keeper')).valueOrNull!;
    await setup.customStatement('DROP TABLE settings');
    await setup.customStatement('PRAGMA user_version = 1');
    await setup.close();

    // Reopen: drift sees v1 < v2 and runs the guarded forward migration.
    final upgraded = AppDatabase(NativeDatabase(File(path)));
    addTearDown(upgraded.close);
    final created = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='settings'",
        )
        .get();
    expect(created, hasLength(1), reason: 'migration created settings');

    // The pre-existing vehicle survived the upgrade untouched.
    final rows = await upgraded.customSelect(
      'SELECT id FROM vehicles WHERE id = ?',
      variables: [Variable<String>(v.id)],
    ).get();
    expect(rows, hasLength(1));

    // …and the new table is immediately usable.
    final settings = SettingsRepository(upgraded);
    expect((await settings.set('locale', 'fa')).isOk, isTrue);
    expect(await settings.get('locale'), 'fa');
  });
}
