import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

/// Force the **SQLCipher** native library (not a plaintext `sqlite3` that could
/// win the native link and silently ship an unencrypted DB). Call before any
/// open — on the main isolate and inside the background DB isolate.
Future<void> ensureSqlCipherLoaded() async {
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  // Guards a known crash opening SQLCipher on older Android system libraries.
  await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
  // iOS/macOS: SQLCipher is statically linked by sqlcipher_flutter_libs.
}

/// The encrypted open sequence — **PRAGMA key FIRST, cipher ASSERTED, WAL on,
/// foreign keys on**. This flow must never be reordered: running any query
/// first, or keying after open, silently yields an unusable or *plaintext* DB.
QueryExecutor openEncryptedExecutor({
  required String hexKey,
  required String dbPath,
}) {
  return LazyDatabase(() async {
    final file = File(dbPath);
    return NativeDatabase.createInBackground(
      file,
      isolateSetup: ensureSqlCipherLoaded,
      setup: (raw) {
        // 1. KEY FIRST — raw 64-hex, no per-open KDF.
        raw.execute('PRAGMA key = "x\'$hexKey\'";');
        // 2. ASSERT the cipher is real — empty on stock sqlite3 => plaintext.
        final cipher = raw.select('PRAGMA cipher_version;');
        if (cipher.isEmpty) {
          throw StateError(
            'Encryption library missing — refusing to open a plaintext DB',
          );
        }
        // 3. WAL (side files inherit the cipher) + foreign keys.
        raw
          ..execute('PRAGMA journal_mode = WAL;')
          ..execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}
