// A complete boundary: a sealed DbFailure family, a convert-at-the-boundary
// repository method, and an exhaustive UI switch. Illustrative — import paths
// are placeholders (packages/core, gen-l10n, drift).

import 'package:core/core.dart'; // Result, Ok, Err, Failure, DbFailure...
import 'package:drift/drift.dart' show SqliteException;
import 'package:flutter/widgets.dart';

// --- packages/core: the sealed failure family (codes + typed params, NO strings) ---

sealed class DbFailure extends Failure {
  const DbFailure();
}

final class ConstraintViolation extends DbFailure {
  const ConstraintViolation(this.table);
  final String table;
  @override
  String get code => 'db.constraint_violation';
}

final class DecryptFailed extends DbFailure {
  const DecryptFailed();
  @override
  String get code => 'db.decrypt_failed';
}

final class TransactionRolledBack extends DbFailure {
  const TransactionRolledBack();
  @override
  String get code => 'db.transaction_rolled_back';
}

// --- packages/data: convert-at-the-boundary. Log the original, then return typed. ---

class VehicleRepository {
  VehicleRepository(this._dao, this._log);
  final VehicleDao _dao;
  final AppLog _log;

  Future<Result<Vehicle, DbFailure>> insertVehicle(VehicleDraft d) async {
    try {
      final row = await _dao.insert(d);
      return Ok(row.toDomain());
    } on SqliteException catch (e, st) {
      _log.error('db.insert_vehicle', e, st); // local rotating log FIRST
      return Err(_mapDbException(e)); // then the typed, string-free failure
    }
  }

  DbFailure _mapDbException(SqliteException e) => switch (e.resultCode) {
        19 /* SQLITE_CONSTRAINT */ => ConstraintViolation(e.tableName ?? 'unknown'),
        26 /* SQLITE_NOTADB (bad key / corruption) */ => const DecryptFailed(),
        _ => const TransactionRolledBack(),
      };
}

// --- apps: presentation. Sealed => NO default:; localize from the code. ---

Widget buildDbError(BuildContext context, DbFailure f) {
  final l10n = AppLocalizations.of(context);
  return switch (f) {
    ConstraintViolation(:final table) =>
      ErrorBanner(l10n.dbConstraintViolation(table)),
    DecryptFailed() => ErrorBanner(l10n.dbDecryptFailed),
    TransactionRolledBack() => ErrorBanner(l10n.dbTransactionRolledBack),
    // Adding a new DbFailure subtype makes THIS switch a compile error until handled.
  };
}
