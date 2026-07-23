import 'dart:convert';

import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../domain/expense.dart';
import 'base_repository.dart';
import 'rollup_service.dart';

/// The expense ledger boundary (M6-T1): the canonical store every cost writes
/// into. Enforces minor-units/UTC at the edge, returns sealed [Result], and
/// bumps the monthly cost rollup only for MANUAL rows (a projected fuel/service
/// row was already counted by its own module — never double-counted here).
class ExpensesRepository extends BaseRepository {
  ExpensesRepository(super.db, {super.clock});

  RollupService get _rollups => RollupService(db);

  // ── reads ──────────────────────────────────────────────────────────────────

  /// A vehicle's expenses, newest first, tombstone-filtered. Optional category +
  /// date-window filters at the SQL level (drives per-category / per-range views).
  Stream<List<Expense>> watchByVehicle(
    String vehicleId, {
    String? categoryId,
    int? sinceMillis,
    int? untilMillis,
  }) {
    final query = db.select(db.expenses)
      ..where((t) => t.vehicleId.equals(vehicleId) & t.isDeleted.equals(false));
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    }
    if (sinceMillis != null) {
      query.where((t) => t.spentAt.isBiggerOrEqualValue(sinceMillis));
    }
    if (untilMillis != null) {
      query.where((t) => t.spentAt.isSmallerOrEqualValue(untilMillis));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.spentAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Every live expense for a category across all vehicles (fleet analytics).
  Stream<List<Expense>> watchByCategory(String categoryId) {
    final query = db.select(db.expenses)
      ..where(
          (t) => t.categoryId.equals(categoryId) & t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.spentAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// One-shot snapshot for a vehicle within a date range — the TCO/budget input.
  Future<List<Expense>> inRange(
    String vehicleId, {
    required int sinceMillis,
    required int untilMillis,
  }) async {
    final rows = await (db.select(db.expenses)
          ..where((t) =>
              t.vehicleId.equals(vehicleId) &
              t.isDeleted.equals(false) &
              t.spentAt.isBiggerOrEqualValue(sinceMillis) &
              t.spentAt.isSmallerOrEqualValue(untilMillis)))
        .get();
    return rows.map(_toDomain).toList();
  }

  Future<Expense?> byId(String id) async {
    final row = await (db.select(db.expenses)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  // ── writes ───────────────────────────────────────────────────────────────

  /// Record a cost. When it carries a [sourceEntityType] it is a projection of
  /// another module's row and does NOT bump the rollup (avoiding a double-count).
  Future<Result<String, DbFailure>> add({
    required String vehicleId,
    required Instant spentAt,
    required int amountMinor,
    required String currencyCode,
    String? categoryId,
    int? odometerMetres,
    String? notes,
    String? driverId,
    int? fxRateThousandths,
    int? fxAsOf,
    int? baseAmountMinor,
    String? sourceEntityType,
    String? sourceEntityId,
    String? receiptAttachmentId,
    List<String> tags = const [],
    String? entryCalendar,
  }) async {
    try {
      final id = newId();
      final now = nowMillis();
      await db.transaction(() async {
        await db.into(db.expenses).insert(
              ExpensesCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                spentAt: spentAt.epochMillis,
                amountMinor: amountMinor,
                currencyCode: currencyCode,
                createdAt: now,
                updatedAt: now,
                categoryId: Value(categoryId),
                odometerMetres: Value(odometerMetres),
                notes: Value(notes),
                driverId: Value(driverId),
                fxRateThousandths: Value(fxRateThousandths),
                fxAsOf: Value(fxAsOf),
                baseAmountMinor: Value(baseAmountMinor),
                sourceEntityType: Value(sourceEntityType),
                sourceEntityId: Value(sourceEntityId),
                receiptAttachmentId: Value(receiptAttachmentId),
                tags: Value(tags.isEmpty ? null : jsonEncode(tags)),
                entryCalendar: Value(entryCalendar),
              ),
            );
        if (sourceEntityType == null) {
          await _rollups.bump(
            vehicleId: vehicleId,
            period: monthPeriodKey(spentAt.epochMillis),
            metric: 'costMinor',
            delta: baseAmountMinor ?? amountMinor,
            now: now,
          );
        }
      });
      return Ok(id);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'expenses'));
    }
  }

  /// Soft-delete to trash; reverses the rollup bump for a manual row.
  Future<Result<void, DbFailure>> softDelete(
    String id, {
    Duration retention = const Duration(days: 30),
  }) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.expenses)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null || cur.isDeleted) return false;
        await (db.update(db.expenses)..where((t) => t.id.equals(id))).write(
          ExpensesCompanion(
            isDeleted: const Value(true),
            deletedAt: Value(now),
            trashExpiresAt: Value(now + retention.inMilliseconds),
            updatedAt: Value(now),
            rowRevision: Value(cur.rowRevision + 1),
          ),
        );
        if (cur.sourceEntityType == null) {
          await _rollups.bump(
            vehicleId: cur.vehicleId,
            period: monthPeriodKey(cur.spentAt),
            metric: 'costMinor',
            delta: -(cur.baseAmountMinor ?? cur.amountMinor),
            now: now,
          );
        }
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('expense'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'expenses'));
    }
  }

  // ── mapping ────────────────────────────────────────────────────────────────

  Expense _toDomain(ExpenseRow r) => Expense(
        id: r.id,
        vehicleId: r.vehicleId,
        spentAt: Instant.fromEpochMillis(r.spentAt),
        amountMinor: r.amountMinor,
        currencyCode: r.currencyCode,
        categoryId: r.categoryId,
        odometerMetres: r.odometerMetres,
        notes: r.notes,
        driverId: r.driverId,
        fxRateThousandths: r.fxRateThousandths,
        fxAsOf: r.fxAsOf,
        baseAmountMinor: r.baseAmountMinor,
        sourceEntityType: r.sourceEntityType,
        sourceEntityId: r.sourceEntityId,
        receiptAttachmentId: r.receiptAttachmentId,
        tags: _decodeTags(r.tags),
        entryCalendar: r.entryCalendar,
      );

  List<String> _decodeTags(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.cast<String>() : const [];
  }
}
