import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// M3-T9: the saved-stations library persists name/brand/GPS, streams them
/// name-ordered, soft-deletes to trash, and rides backup/export.
void main() {
  late AppDatabase db;
  late StationsRepository stations;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    stations = StationsRepository(db);
  });
  tearDown(() => db.close());

  test('add + watchAll (name-ordered)', () async {
    await stations.add(
        name: 'Shell', brand: 'Shell', latMicro: 52520008, lngMicro: 13404954);
    await stations.add(name: 'Aral');
    final all = await stations.watchAll().first;
    expect(all.map((s) => s.name), ['Aral', 'Shell']); // alphabetical
    expect(all.firstWhere((s) => s.name == 'Shell').latMicro, 52520008);
  });

  test('soft-delete hides the station', () async {
    final id = (await stations.add(name: 'Esso')).valueOrNull!;
    expect((await stations.softDelete(id)).isOk, isTrue);
    expect(await stations.watchAll().first, isEmpty);
  });

  test('saved stations round-trip through the backup (export→import)',
      () async {
    await stations.add(name: 'BP', brand: 'BP', latMicro: 1, lngMicro: 2);
    final doc = await CanonicalCodec(db).export();
    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    expect((await CanonicalCodec(db2).import(doc)).isOk, isTrue);
    final restored = await StationsRepository(db2).watchAll().first;
    expect(restored.single.name, 'BP');
    expect(restored.single.latMicro, 1);
  });
}
