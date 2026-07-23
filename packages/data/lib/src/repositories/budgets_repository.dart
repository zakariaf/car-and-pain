import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../domain/financing.dart';
import 'base_repository.dart';

/// Budget persistence (M6-T3). Targets are stored; spend-to-date + projection are
/// recomputed by the pure [BudgetEngine]. Alert de-dup state (highest threshold
/// fired + its period key) lives here so each crossing notifies once per period.
class BudgetsRepository extends BaseRepository {
  BudgetsRepository(super.db, {super.clock});

  /// Budgets for a vehicle plus the all-vehicles (vehicleId null) budgets.
  Stream<List<Budget>> watchForVehicle(String vehicleId) {
    final q = db.select(db.budgets)
      ..where((t) =>
          (t.vehicleId.equals(vehicleId) | t.vehicleId.isNull()) &
          t.isDeleted.equals(false));
    return q.watch().map((rows) => rows.map(_toBudget).toList());
  }

  Future<Budget?> byId(String id) async {
    final r = await (db.select(db.budgets)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    return r == null ? null : _toBudget(r);
  }

  /// Create a budget. The target must be positive (validated by the caller via
  /// CostValidators); a non-positive target is refused with a ConstraintViolation.
  Future<Result<String, DbFailure>> add({
    required String period,
    required int targetMinor,
    required String currencyCode,
    String? vehicleId,
    String? categoryId,
    String basis = 'cash',
  }) async {
    if (targetMinor <= 0) {
      return const Err(ConstraintViolation('budgets'));
    }
    try {
      final id = newId();
      final now = nowMillis();
      await db.into(db.budgets).insert(
            BudgetsCompanion.insert(
              id: id,
              period: period,
              targetMinor: targetMinor,
              currencyCode: currencyCode,
              createdAt: now,
              updatedAt: now,
              vehicleId: Value(vehicleId),
              categoryId: Value(categoryId),
              basis: Value(basis),
            ),
          );
      return Ok(id);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'budgets'));
    }
  }

  /// Record that [threshold] was alerted for [periodKey] (M6-T3 de-dup).
  Future<Result<void, DbFailure>> recordAlert(
    String id, {
    required int threshold,
    required String periodKey,
  }) async {
    try {
      final now = nowMillis();
      final n = await (db.update(db.budgets)
            ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
          .write(BudgetsCompanion(
        lastAlertThreshold: Value(threshold),
        lastAlertPeriod: Value(periodKey),
        updatedAt: Value(now),
      ));
      return n == 0 ? const Err(NotFound('budget')) : const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'budgets'));
    }
  }

  Future<Result<void, DbFailure>> softDelete(String id) async {
    try {
      final now = nowMillis();
      final cur = await (db.select(db.budgets)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (cur == null || cur.isDeleted) return const Err(NotFound('budget'));
      await (db.update(db.budgets)..where((t) => t.id.equals(id))).write(
        BudgetsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
          updatedAt: Value(now),
          rowRevision: Value(cur.rowRevision + 1),
        ),
      );
      return const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'budgets'));
    }
  }

  Budget _toBudget(BudgetRow r) => Budget(
        id: r.id,
        vehicleId: r.vehicleId,
        categoryId: r.categoryId,
        period: r.period,
        targetMinor: r.targetMinor,
        currencyCode: r.currencyCode,
        basis: r.basis,
        lastAlertThreshold: r.lastAlertThreshold,
        lastAlertPeriod: r.lastAlertPeriod,
      );
}
