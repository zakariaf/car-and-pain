import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:security/security.dart';

/// The production [SecureStore] (F7-T5): security envelopes, throttle state, the
/// PIN verifier, and lock prefs persisted in the platform Keychain / Android
/// Keystore via `flutter_secure_storage`. The pure [SecureVault] talks only to
/// this port; tests use `InMemorySecureStore`.
///
/// Device-only: the round-trip through hardware-backed storage needs on-device
/// QA (TODO(F7): verify persistence across reinstall/OS-migration on a device).
class FlutterSecureStore implements SecureStore {
  FlutterSecureStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // Hardware-backed where available; survives app restart.
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
