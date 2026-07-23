import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../domain/financing.dart';
import 'base_repository.dart';

/// Loan/lease + budget persistence (M6-T3/T4). Terms are stored; the amortization
/// schedule + budget evaluation are recomputed by the pure engines (never stored
/// as lossy duplicates). Typed [Result]; no Drift leaks past the boundary.
class FinancingRepository extends BaseRepository {
  FinancingRepository(super.db, {super.clock});

  // ── financing ──────────────────────────────────────────────────────────────

  Stream<List<Financing>> watchByVehicle(String vehicleId) {
    final q = db.select(db.financings)
      ..where((t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.startDate)]);
    return q.watch().map((rows) => rows.map(_toFinancing).toList());
  }

  Future<Financing?> financingById(String id) async {
    final r = await (db.select(db.financings)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    return r == null ? null : _toFinancing(r);
  }

  Future<Result<String, DbFailure>> addFinancing({
    required String vehicleId,
    required String kind,
    required int principalMinor,
    required String currencyCode,
    required int aprBps,
    required int termMonths,
    required Instant startDate,
    int residualMinor = 0,
    String? refinancedFromId,
    String? notes,
  }) async {
    try {
      final id = newId();
      final now = nowMillis();
      await db.into(db.financings).insert(
            FinancingsCompanion.insert(
              id: id,
              vehicleId: vehicleId,
              kind: kind,
              principalMinor: principalMinor,
              currencyCode: currencyCode,
              aprBps: aprBps,
              termMonths: termMonths,
              startDate: startDate.epochMillis,
              createdAt: now,
              updatedAt: now,
              residualMinor: Value(residualMinor),
              refinancedFromId: Value(refinancedFromId),
              notes: Value(notes),
            ),
          );
      return Ok(id);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'financings'));
    }
  }

  /// Mark a financing closed (paid off or refinanced) at [at].
  Future<Result<void, DbFailure>> closeFinancing(String id, Instant at) async {
    try {
      final now = nowMillis();
      final n = await (db.update(db.financings)
            ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
          .write(FinancingsCompanion(
        closedAt: Value(at.epochMillis),
        updatedAt: Value(now),
      ));
      return n == 0 ? const Err(NotFound('financing')) : const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'financings'));
    }
  }

  Future<Result<void, DbFailure>> softDeleteFinancing(String id) async {
    try {
      final now = nowMillis();
      final cur = await (db.select(db.financings)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (cur == null || cur.isDeleted) return const Err(NotFound('financing'));
      await (db.update(db.financings)..where((t) => t.id.equals(id))).write(
        FinancingsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          updatedAt: Value(now),
          rowRevision: Value(cur.rowRevision + 1),
        ),
      );
      return const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'financings'));
    }
  }

  Financing _toFinancing(FinancingRow r) => Financing(
        id: r.id,
        vehicleId: r.vehicleId,
        kind: r.kind,
        principalMinor: r.principalMinor,
        currencyCode: r.currencyCode,
        aprBps: r.aprBps,
        termMonths: r.termMonths,
        startDate: Instant.fromEpochMillis(r.startDate),
        residualMinor: r.residualMinor,
        refinancedFromId: r.refinancedFromId,
        closedAt:
            r.closedAt == null ? null : Instant.fromEpochMillis(r.closedAt!),
        notes: r.notes,
      );
}
