import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

/// M10-T3 · the demo vehicle seeds real history and tears down cleanly with no
/// orphans; seed/teardown/re-seed are idempotent.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<int> count(TableInfo<Table, dynamic> table) async {
    final rows = await db.customSelect(
      'SELECT COUNT(*) AS c FROM ${table.actualTableName}',
      readsFrom: {table},
    ).getSingle();
    return rows.read<int>('c');
  }

  test('seed creates a demo vehicle with linked fuel + expense history',
      () async {
    final seeder = DemoSeeder(db);
    final r = await seeder.seed();
    expect(r.isOk, isTrue);
    expect(await seeder.isActive(), isTrue);

    final veh = await (db.select(db.vehicles)
          ..where((t) => t.id.equals(r.valueOrNull!)))
        .getSingle();
    expect(veh.isDemo, isTrue);
    expect(await count(db.fuelEntries), 3); // full, partial, full
    expect(await count(db.expenses), 1);
    // The fuel writes also seeded the shared odometer ledger.
    expect(await count(db.odometerReadings), greaterThanOrEqualTo(3));
  });

  test('seed is idempotent — a second call returns the same vehicle', () async {
    final seeder = DemoSeeder(db);
    final first = (await seeder.seed()).valueOrNull!;
    final second = (await seeder.seed()).valueOrNull!;
    expect(second, first);
    expect(await count(db.vehicles), 1);
    expect(await count(db.fuelEntries), 3); // not re-seeded
  });

  test('teardown removes the vehicle and every linked record (no orphans)',
      () async {
    final seeder = DemoSeeder(db);
    await seeder.seed();
    final removed = await seeder.teardown();
    expect(removed.valueOrNull, 1);
    expect(await seeder.isActive(), isFalse);
    // FK cascade cleared every child — zero orphans.
    expect(await count(db.vehicles), 0);
    expect(await count(db.fuelEntries), 0);
    expect(await count(db.expenses), 0);
    expect(await count(db.odometerReadings), 0);

    // Re-seed after teardown works (idempotent).
    expect((await seeder.seed()).isOk, isTrue);
    expect(await seeder.isActive(), isTrue);
  });
}
