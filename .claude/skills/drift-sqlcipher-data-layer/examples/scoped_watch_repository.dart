// Illustrative — a repository exposing a vehicle + time-window-scoped .watch
// stream that maps Drift rows to core DOMAIN models. Feature code and Riverpod
// stream providers subscribe to this; they never touch DAOs or Drift row types.
//
// Rules shown: filter is_deleted = 0 in the base query; scope by vehicle +
// window; map canonical int columns to core value objects; keyset (seek)
// pagination, never OFFSET.

import 'package:core/core.dart'; // FuelEntry (domain), Money, Volume, Distance, Currency
import 'package:drift/drift.dart';

class FuelReadRepository {
  FuelReadRepository(this.db);
  final AppDatabase db;

  /// Reactive stream of this vehicle's fuel entries within [window], newest first.
  /// Emits DOMAIN models — never generated row classes.
  Stream<List<FuelEntry>> watchForVehicle(String vehicleId, DateTimeRange window) {
    final q = db.select(db.fuelEntries)
      ..where((t) =>
          t.vehicleId.equals(vehicleId) &
          t.isDeleted.equals(false) & // ALWAYS filter soft-deletes
          t.filledAt.isBetweenValues(
              window.start.millisecondsSinceEpoch,
              window.end.millisecondsSinceEpoch))
      ..orderBy([(t) => OrderingTerm.desc(t.filledAt)]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Keyset (seek) pagination — pass the previous page's last filledAt as cursor.
  /// NEVER use OFFSET on the ledger; it degrades on large histories.
  Future<List<FuelEntry>> pageBefore(String vehicleId, int cursorMs, int pageSize) async {
    final q = db.select(db.fuelEntries)
      ..where((t) =>
          t.vehicleId.equals(vehicleId) &
          t.isDeleted.equals(false) &
          t.filledAt.isSmallerThanValue(cursorMs))
      ..orderBy([(t) => OrderingTerm.desc(t.filledAt)])
      ..limit(pageSize);
    return (await q.get()).map(_toDomain).toList();
  }

  // Row -> domain mapping happens ONLY here, at the repository boundary.
  FuelEntry _toDomain(FuelEntriesData r) => FuelEntry(
        id: r.id,
        vehicleId: r.vehicleId,
        filledAt: DateTime.fromMillisecondsSinceEpoch(r.filledAt, isUtc: true),
        volume: Volume.millilitres(r.volumeMl),
        totalCost: Money(r.amountMinor, Currency.tryParse(r.currencyCode)!),
        isFullTank: r.isFullTank,
        isPartial: r.isPartial,
        isMissedPrevious: r.isMissedPrevious,
      );
}
