import 'dart:convert';

/// A row where incoming won a close contest — surfaced for the dry-run preview /
/// manual-override UI (both sides edited near the same instant).
class MergeConflict {
  const MergeConflict({
    required this.entity,
    required this.id,
    required this.localUpdatedAt,
    required this.incomingUpdatedAt,
  });

  final String entity;
  final String id;
  final int localUpdatedAt;
  final int incomingUpdatedAt;
}

/// Per-entity reconciliation counts.
class EntityStat {
  const EntityStat({
    required this.entity,
    required this.scanned,
    required this.added,
    required this.updated,
    required this.tombstonesApplied,
    required this.keptLocal,
    required this.conflicts,
  });

  final String entity;
  final int scanned;
  final int added;
  final int updated;
  final int tombstonesApplied;
  final int keptLocal;
  final int conflicts;
}

/// The result of merging one entity — the winning rows to upsert plus stats.
class EntityMergeResult {
  const EntityMergeResult({
    required this.entity,
    required this.winners,
    required this.stat,
    required this.conflicts,
  });

  final String entity;
  final List<Map<String, Object?>> winners;
  final EntityStat stat;
  final List<MergeConflict> conflicts;
}

/// The whole-merge reconciliation report — matches the dry-run preview exactly
/// for identical inputs (the merge is deterministic + side-effect-free until
/// commit).
class MergeReport {
  const MergeReport({
    required this.byEntity,
    required this.conflicts,
  });

  final Map<String, EntityStat> byEntity;
  final List<MergeConflict> conflicts;

  int get totalAdded => byEntity.values.fold(0, (a, s) => a + s.added);
  int get totalUpdated => byEntity.values.fold(0, (a, s) => a + s.updated);
  int get totalTombstonesApplied =>
      byEntity.values.fold(0, (a, s) => a + s.tombstonesApplied);
  int get totalKeptLocal => byEntity.values.fold(0, (a, s) => a + s.keptLocal);
  int get totalConflicts => conflicts.length;
}

/// The deterministic last-write-wins merge engine (F6-T6), shared by import and
/// (later) household sync. Pure: Flutter-free, DB-free, no clock — it decides
/// over row maps (the codec's camelCase `toJson` shape) and returns winners to
/// upsert. Keys on `id` (stable UUIDv7); resolves by newest `updatedAt`;
/// tombstone-aware (a deletion beats a stale same-instant edit); ties broken by
/// a canonical-JSON total order so the outcome is independent of which side is
/// "local" and identical every run.
class LwwMergeEngine {
  const LwwMergeEngine();

  EntityMergeResult mergeEntity({
    required String entity,
    required Map<String, Map<String, Object?>> local,
    required List<Map<String, Object?>> incoming,
  }) {
    final winners = <Map<String, Object?>>[];
    final conflicts = <MergeConflict>[];
    var added = 0;
    var updated = 0;
    var tombstones = 0;
    var keptLocal = 0;

    for (final inc in incoming) {
      final id = inc['id']! as String;
      final cur = local[id];
      if (cur == null) {
        winners.add(inc);
        added++;
        if (_tomb(inc)) tombstones++;
        continue;
      }
      if (_order(cur, inc) < 0) {
        // Incoming is newer → it wins.
        winners.add(inc);
        updated++;
        if (_tomb(inc) && !_tomb(cur)) tombstones++;
        // A near-simultaneous edit on both sides is worth surfacing.
        if ((_at(inc) - _at(cur)).abs() == 0) {
          conflicts.add(MergeConflict(
            entity: entity,
            id: id,
            localUpdatedAt: _at(cur),
            incomingUpdatedAt: _at(inc),
          ));
        }
      } else {
        keptLocal++;
      }
    }

    return EntityMergeResult(
      entity: entity,
      winners: winners,
      stat: EntityStat(
        entity: entity,
        scanned: incoming.length,
        added: added,
        updated: updated,
        tombstonesApplied: tombstones,
        keptLocal: keptLocal,
        conflicts: conflicts.length,
      ),
      conflicts: conflicts,
    );
  }

  /// A deterministic TOTAL order, independent of side. Returns <0 if [a] loses
  /// to [b] (b is the winner), >0 if a wins, 0 only for identical rows.
  int _order(Map<String, Object?> a, Map<String, Object?> b) {
    final t = _at(a).compareTo(_at(b)); // 1) last-write-wins by updated_at
    if (t != 0) return t;
    final ta = _tomb(a);
    final tb = _tomb(b);
    if (ta != tb) return ta ? 1 : -1; // 2) a delete beats a same-instant edit
    final r = _rev(a).compareTo(_rev(b)); // 3) higher revision (advisory)
    if (r != 0) return r;
    // 4) canonical JSON — a stable, side-independent final tiebreak.
    return _canonical(a).compareTo(_canonical(b));
  }

  int _at(Map<String, Object?> r) => (r['updatedAt'] as int?) ?? 0;
  int _rev(Map<String, Object?> r) => (r['rowRevision'] as int?) ?? 0;
  bool _tomb(Map<String, Object?> r) => r['isDeleted'] == true;

  String _canonical(Map<String, Object?> r) {
    final sorted = <String, Object?>{};
    for (final k in r.keys.toList()..sort()) {
      sorted[k] = r[k];
    }
    return jsonEncode(sorted);
  }
}
