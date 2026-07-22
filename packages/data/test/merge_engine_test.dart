import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _row(
  String id,
  int updatedAt, {
  bool deleted = false,
  int revision = 0,
  String nickname = 'x',
}) =>
    {
      'id': id,
      'updatedAt': updatedAt,
      'isDeleted': deleted,
      'rowRevision': revision,
      'nickname': nickname,
    };

void main() {
  const engine = LwwMergeEngine();

  EntityMergeResult merge(
    List<Map<String, Object?>> local,
    List<Map<String, Object?>> incoming,
  ) =>
      engine.mergeEntity(
        entity: 'vehicles',
        local: {for (final r in local) r['id']! as String: r},
        incoming: incoming,
      );

  group('LwwMergeEngine', () {
    test('a newer incoming row wins; an older one is kept-local', () {
      final win = merge([_row('a', 100)], [_row('a', 200, nickname: 'new')]);
      expect(win.winners.single['nickname'], 'new');
      expect(win.stat.updated, 1);

      final lose = merge([_row('a', 200)], [_row('a', 100, nickname: 'old')]);
      expect(lose.winners, isEmpty);
      expect(lose.stat.keptLocal, 1);
    });

    test('an unseen id is added', () {
      final r = merge([], [_row('b', 50)]);
      expect(r.winners.single['id'], 'b');
      expect(r.stat.added, 1);
    });

    test('a tombstone beats a same-instant edit (no resurrection)', () {
      // Incoming delete at the SAME updatedAt as a local edit → delete wins.
      final r = merge([_row('a', 100)], [_row('a', 100, deleted: true)]);
      expect(r.winners.single['isDeleted'], true);
      expect(r.stat.tombstonesApplied, 1);
    });

    test('an older incoming edit does NOT resurrect a newer local tombstone',
        () {
      final r = merge(
        [_row('a', 200, deleted: true)],
        [_row('a', 100, nickname: 'zombie')],
      );
      expect(r.winners, isEmpty); // local tombstone (newer) stays
      expect(r.stat.keptLocal, 1);
    });

    test('the order is a deterministic total order, side-independent', () {
      // Same updatedAt + same tombstone + same revision → canonical-JSON breaks
      // the tie identically regardless of which side is "local".
      final x = _row('a', 100, nickname: 'alpha');
      final y = _row('a', 100, nickname: 'beta');
      final ab = merge([x], [y]).winners;
      final ba = merge([y], [x]).winners;
      // Whichever canonical-JSON is larger wins in BOTH directions.
      final winner = ab.isEmpty ? x : ab.single;
      final winner2 = ba.isEmpty ? y : ba.single;
      expect(winner['nickname'], winner2['nickname']);
    });

    test('report totals aggregate per-entity stats', () {
      final r = merge(
        [_row('a', 100), _row('c', 100)],
        [_row('a', 200), _row('b', 100)], // a updated, b added, c untouched
      );
      expect(r.stat.added, 1);
      expect(r.stat.updated, 1);
    });
  });

  group('CanonicalCodec.merge coordinator', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.memory());
    tearDown(() => db.close());

    test('merge is additive: newer wins, new added, local-only survives',
        () async {
      final t0 = DateTime.utc(2026).millisecondsSinceEpoch;
      final repo =
          VehiclesRepository(db, clock: FixedClock(DateTime.utc(2026)));
      final a = (await repo.add(nickname: 'Golf')).valueOrNull!;
      await repo.add(nickname: 'Civic'); // local-only C, absent from incoming

      final doc = await CanonicalCodec(db).export();
      final vehicles = (doc['entities'] as Map)['vehicles'] as List<dynamic>;
      final aRow = vehicles
          .cast<Map<String, dynamic>>()
          .firstWhere((v) => v['id'] == a.id);
      final incoming = {
        ...doc,
        'entities': {
          ...(doc['entities'] as Map).cast<String, dynamic>(),
          'vehicles': [
            {...aRow, 'nickname': 'Polo', 'updatedAt': t0 + 1000},
            {
              ...aRow,
              'id': 'new-b',
              'nickname': 'Model 3',
              'updatedAt': t0 + 1000
            },
          ],
        },
      };

      // Dry-run preview first — must NOT write, and must match the real merge.
      final preview =
          (await CanonicalCodec(db).mergePreview(incoming)).valueOrNull!;
      expect(preview.byEntity['vehicles']!.added, 1);
      expect(preview.byEntity['vehicles']!.updated, 1);
      expect((await repo.watchAll().first).map((v) => v.nickname).toSet(),
          {'Golf', 'Civic'}); // unchanged by the dry-run

      final report = (await CanonicalCodec(db).merge(incoming)).valueOrNull!;
      expect(report.totalAdded, preview.totalAdded);
      expect(report.totalUpdated, preview.totalUpdated);

      // A renamed (incoming won), C kept (additive), B added.
      expect((await repo.watchAll().first).map((v) => v.nickname).toSet(),
          {'Polo', 'Civic', 'Model 3'});
    });

    test('merge refuses a newer format version', () async {
      final r = await CanonicalCodec(db).merge({
        'formatVersion': 999,
        'entities': const <String, dynamic>{},
      });
      expect((r as Err).failure, isA<SchemaVersionMismatch>());
    });
  });
}
