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
  Future<void> restore(String snapshotPath) async {
    final snap = File(snapshotPath);
    if (snap.existsSync()) {
      await snap.copy(dbPath);
      await snap.delete();
    }
  }
}
