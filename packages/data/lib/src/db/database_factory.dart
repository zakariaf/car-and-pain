import 'dart:typed_data';

import 'app_database.dart';
import 'migrations/snapshot_guard.dart';
import 'open_connection.dart';

/// The plain top-level factory both the app and background isolates call to open
/// the encrypted database. The DB key is read on the main isolate (from secure
/// storage) and **passed in** — the isolate never opens the keystore itself.
Future<AppDatabase> openAppDatabase({
  required Uint8List key,
  required String dbPath,
}) async {
  await ensureSqlCipherLoaded();
  final executor = openEncryptedExecutor(hexKey: _toHex(key), dbPath: dbPath);
  return AppDatabase(executor)..snapshotGuard = SnapshotGuard(dbPath);
}

String _toHex(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
