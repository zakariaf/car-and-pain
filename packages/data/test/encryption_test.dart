import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Blocking encryption gate (F2-T1): the raw DB file must NOT begin with the
/// plaintext `SQLite format 3` header. SQLCipher is only present on-device /
/// on a CI lane with the native libs, so this **skips honestly** on a host
/// without the cipher rather than fabricating a pass.
void main() {
  test('encrypted DB file header is not `SQLite format 3`', () async {
    final dir = Directory.systemTemp.createTempSync('cap_enc');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'enc.sqlite');
    final hexKey = 'ab' * 32; // 64-hex raw key

    var cipherAvailable = false;
    final db = sqlite3.open(path)..execute('PRAGMA key = "x\'$hexKey\'";');
    try {
      cipherAvailable = db.select('PRAGMA cipher_version;').isNotEmpty;
      if (cipherAvailable) {
        db
          ..execute('CREATE TABLE t (x INTEGER);')
          ..execute('INSERT INTO t VALUES (1);');
      }
    } on Object {
      cipherAvailable = false;
    } finally {
      db.dispose();
    }

    if (!cipherAvailable) {
      markTestSkipped(
          'SQLCipher not linked on this host — device/CI lane only.');
      return;
    }

    final header = File(path).readAsBytesSync().sublist(0, 16);
    expect(
      utf8.decode(header, allowMalformed: true),
      isNot(startsWith('SQLite format 3')),
      reason: 'DB file is plaintext — SQLCipher did not encrypt it',
    );
  });
}
