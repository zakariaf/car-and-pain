// A multi-table write in ONE Drift/SQLCipher transaction over WAL.
// Record + odometer ledger + rollup invalidation land atomically or not at all.
// Note: everything that is NOT a synchronous txn DB call is done BEFORE the txn.

import 'package:clock/clock.dart';
import 'package:core/core.dart'; // Result, Ok, Err, DbFailure, TransactionRolledBack

class FillRepository {
  FillRepository(this._db, this._fillDao, this._ledgerDao, this._rollupDao,
      this._log, {Clock clock = const Clock()})
      : _clock = clock;

  final AppDatabase _db;
  final FillDao _fillDao;
  final LedgerDao _ledgerDao;
  final RollupDao _rollupDao;
  final AppLog _log;
  final Clock _clock;

  Future<Result<void, DbFailure>> logFill(FillDraft raw) async {
    // 1) PREP OUTSIDE the transaction: resolve the clock, run pure canonical-unit
    //    conversion + validation. Never do this inside the txn body.
    final at = _clock.now().toUtc();
    final d = raw.canonicalize(at: at); // Volume/Distance/Money -> minor units, SI, UTC

    try {
      // 2) The transaction body: SYNCHRONOUS txn.* DB calls ONLY.
      //    No awaiting unrelated futures, no re-entering the DB, no secure-storage reads.
      await _db.transaction(() async {
        final id = await _fillDao.insert(d); // journal_mode=WAL, foreign_keys=ON
        await _ledgerDao.appendOdometer(d.odometer, sourceId: id);
        await _rollupDao.bumpRevision(d.vehicleId, d.period); // invalidate rollup key
      });
      return const Ok(null);
    } on Object catch (e, st) {
      _log.error('db.log_fill', e, st);
      // A FK/constraint throw here rolled the WHOLE unit back — nothing partial landed.
      return const Err(TransactionRolledBack());
    }
  }
}
