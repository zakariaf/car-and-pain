import 'dart:typed_data';

/// Reads and unwraps the recoverable 256-bit master DB key on the **main
/// isolate** (background isolates receive the key passed in, never open the
/// keystore themselves).
///
/// TODO(F7): back this with `flutter_secure_storage` + the Argon2id
/// passphrase-KEK / one-time recovery-code unwrap. Placeholder for F1 so the
/// bootstrap sequence and provider seam exist ahead of the security epic.
abstract interface class SecureKeyStore {
  /// The unwrapped raw key bytes used to open the encrypted database.
  Future<Uint8List> readAndUnwrapDbKey();
}

/// A no-op key store returning an empty key, so the F1 shell boots before the
/// real recoverable-key scheme (F7) lands. Never ship this to production.
final class PlaceholderSecureKeyStore implements SecureKeyStore {
  const PlaceholderSecureKeyStore();

  @override
  Future<Uint8List> readAndUnwrapDbKey() async => Uint8List(0);
}
