// Optimistic soft-delete with a SnackBar Undo, plus the shared filtered read.
// The row is never hard-deleted on tap; it fails the is_deleted=0 filter and
// disappears from EVERY read surface at once (lists, analytics, TCO, charts).

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- packages/data: the ONE shared filter every active read composes. ---
// A Drift view is the alternative:  CREATE VIEW fills_active AS
//   SELECT * FROM fills WHERE is_deleted = 0;

extension ActiveOnly on $FillsTable {
  Expression<bool> get active => isDeleted.equals(false);
}

class FillDao extends DatabaseAccessor<AppDatabase> {
  FillDao(super.db);

  // Records list, analytics, TCO, and chart datasets ALL read through this.
  Future<List<Fill>> activeFills(int vehicleId) =>
      (select(fills)..where((t) => t.vehicleId.equals(vehicleId) & t.active)).get();

  Future<void> softDelete(int id, {required DateTime at}) => (update(fills)
        ..where((t) => t.id.equals(id)))
      .write(FillsCompanion(isDeleted: const Value(true), deletedAt: Value(at)));

  Future<void> restore(int id) => (update(fills)..where((t) => t.id.equals(id)))
      .write(const FillsCompanion(isDeleted: Value(false), deletedAt: Value(null)));
}

// --- apps: optimistic delete + SnackBar Undo via Riverpod. ---

class FillsController extends Notifier<void> {
  @override
  void build() {}

  Future<void> delete(BuildContext context, int id) async {
    final l10n = AppLocalizations.of(context);
    final dao = ref.read(fillDaoProvider);

    await dao.softDelete(id, at: clock.now().toUtc()); // package:clock
    ref.invalidate(activeFillsProvider); // list drops the row immediately (optimistic)

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.recordDeleted),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            await dao.restore(id); // clears is_deleted/deleted_at — exact restore
            ref.invalidate(activeFillsProvider);
          },
        ),
      ),
    );
  }
}
