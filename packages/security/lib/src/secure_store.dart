/// The key/value persistence port for security items (F7-T5). The real
/// implementation wraps `flutter_secure_storage` (Keychain / Android Keystore)
/// in the app; the pure vault + tests talk only to this interface.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Wipe every item — the security factory-reset path.
  Future<void> deleteAll();
}

/// An in-memory [SecureStore] for tests — deterministic, no plugins. Set
/// [failing] to simulate a platform read/write failure.
final class InMemorySecureStore implements SecureStore {
  final Map<String, String> _items = {};
  bool failing = false;

  @override
  Future<String?> read(String key) async {
    if (failing) throw StateError('secure store unavailable');
    return _items[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failing) throw StateError('secure store unavailable');
    _items[key] = value;
  }

  @override
  Future<void> delete(String key) async => _items.remove(key);

  @override
  Future<void> deleteAll() async => _items.clear();
}
