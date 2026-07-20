import 'dart:io';

/// Takes a **mandatory pre-migration snapshot** of the DB file and restores it
/// if a forward migration fails. SQLite has no true down-migration, so
/// "rollback" == restore the snapshot (F2-T5).
///
/// F2 uses a file-copy snapshot taken while the migration holds an exclusive
/// lock (no concurrent writes).
/// TODO(F2-F): upgrade to `wal_checkpoint(TRUNCATE)` + `VACUUM INTO` for a fully
/// consistent copy under WAL, matching the backup primitive.
class SnapshotGuard {
  const SnapshotGuard(this.dbPath);

  final String dbPath;

  /// Copy the live DB to a sibling `.premigration` file; returns its path.
  Future<String> take() async {
    final src = File(dbPath);
    final snapshotPath = '$dbPath.premigration';
    if (src.existsSync()) {
      await src.copy(snapshotPath);
    }
    return snapshotPath;
  }

  /// Restore a previously-taken snapshot over the live DB, then remove it.
  ///
  /// The stale `-wal`/`-shm` sidecars MUST be removed too: SQLite would
  /// otherwise recover their frames on top of the restored main file on the
  /// next open, re-applying the very writes the restore is meant to undo (a
  /// silent corruption of a data-custody DB). Deleting them forces a clean
  /// reopen against the restored file alone.
  Future<void> restore(String snapshotPath) async {
    final snap = File(snapshotPath);
    if (snap.existsSync()) {
      await snap.copy(dbPath);
      await snap.delete();
      for (final sidecar in ['$dbPath-wal', '$dbPath-shm']) {
        final f = File(sidecar);
        if (f.existsSync()) await f.delete();
      }
    }
  }
}
