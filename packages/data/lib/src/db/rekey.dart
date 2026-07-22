import 'package:sqlite3/sqlite3.dart';

import 'open_connection.dart';

/// Rotate the raw SQLCipher key of the database file (F7-T3).
///
/// This is a **whole-DB re-encryption** (`PRAGMA rekey` rewrites every page), so
/// it is reserved for a deliberate key rotation — NOT a passphrase change, which
/// only re-wraps the unchanged master key (see `MasterKeyService`). The DB must
/// be closed before calling. Verified by re-opening with the new key before
/// returning; a failure leaves the file on its old key.
///
/// Device-only: needs the SQLCipher native library loaded, so this path is
/// exercised in on-device QA (TODO(F7)).
Future<void> rekeyDatabaseFile({
  required String dbPath,
  required String oldHexKey,
  required String newHexKey,
}) async {
  await ensureSqlCipherLoaded();

  final db = sqlite3.open(dbPath);
  try {
    // Key with the CURRENT key first, assert the cipher is real, then rekey.
    db.execute('PRAGMA key = "x\'$oldHexKey\'";');
    if (db.select('PRAGMA cipher_version;').isEmpty) {
      throw StateError('Encryption library missing — refusing to rekey');
    }
    db.execute('PRAGMA rekey = "x\'$newHexKey\'";');
  } finally {
    db.dispose();
  }

  // Verify: the file must now open under the NEW key (and not the old one).
  final verify = sqlite3.open(dbPath);
  try {
    verify
      ..execute('PRAGMA key = "x\'$newHexKey\'";')
      ..select('SELECT count(*) FROM sqlite_master;');
  } finally {
    verify.dispose();
  }
}
