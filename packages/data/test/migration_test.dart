import 'dart:io';

import 'package:data/data.dart';
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

  test('schemaVersion is 1 and a fresh DB builds the full schema', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    expect(db.schemaVersion, 1);

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
}
