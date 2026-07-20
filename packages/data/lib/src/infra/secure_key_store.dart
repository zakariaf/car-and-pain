import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Reads and unwraps the recoverable 256-bit master DB key on the **main
/// isolate** (background isolates receive the key passed in, never open the
/// keystore themselves).
abstract interface class SecureKeyStore {
  /// The raw 32-byte key used to open the encrypted database.
  Future<Uint8List> readAndUnwrapDbKey();
}

/// F2 key store: a random 256-bit key generated on first run and persisted in
/// the platform Keystore/Keychain via `flutter_secure_storage`.
///
/// TODO(F7): wrap this key with a passphrase-derived Argon2id KEK + a one-time
/// recovery code so it is **recoverable by default** — "key only in secure
/// storage" is the risky mode, not the default.
class FlutterSecureKeyStore implements SecureKeyStore {
  FlutterSecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;
  static const _keyName = 'car_and_pain.db_key_hex';

  @override
  Future<Uint8List> readAndUnwrapDbKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.length == 64) {
      return _fromHex(existing);
    }
    final key = _randomBytes(32);
    await _storage.write(key: _keyName, value: _toHex(key));
    return key;
  }

  static Uint8List _randomBytes(int n) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(n, (_) => rng.nextInt(256)),
    );
  }

  static String _toHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Uint8List _fromHex(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}

/// A deterministic in-memory key store for tests (fixed key, no plugins).
class FakeSecureKeyStore implements SecureKeyStore {
  const FakeSecureKeyStore();

  @override
  Future<Uint8List> readAndUnwrapDbKey() async =>
      Uint8List.fromList(List<int>.filled(32, 7));
}
