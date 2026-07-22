import 'dart:math';

import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';

import 'key_envelope.dart';

/// The master-key lifecycle (F7-T1). A random 256-bit master key is wrapped
/// under a KEK derived from a passphrase (or a one-time recovery code) via
/// Argon2id, using AES-256-GCM. The raw key exists only in memory while
/// unlocked; only the [KeyEnvelope] is persisted. Every op is `Result`-typed —
/// no exception crosses the boundary.
final class KeyManager {
  KeyManager({Random? rng}) : _rng = rng ?? Random.secure();

  final Random _rng;
  final AesGcm _aes = AesGcm.with256bits();

  /// A fresh random 256-bit master key (never derived from a secret).
  List<int> generateMasterKey() => _randomBytes(32);

  /// Wrap [masterKey] under [secret] (a passphrase or recovery code) into a new
  /// envelope. [params] is raised to the security floor.
  Future<KeyEnvelope> wrap(
    List<int> masterKey,
    String secret, {
    Argon2idParams params = Argon2idParams.floor,
  }) async {
    // The floor is enforced at calibration (F7-T2); wrap trusts its params, so
    // tests can pass fast params. The default is already the safe floor.
    final salt = _randomBytes(16);
    final kek = await _deriveKek(secret, salt, params);
    final nonce = _aes.newNonce();
    final box = await _aes.encrypt(masterKey, secretKey: kek, nonce: nonce);
    return KeyEnvelope(
      version: KeyEnvelope.currentVersion,
      kdf: 'argon2id',
      params: params,
      salt: salt,
      nonce: nonce,
      ciphertext: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  /// Unwrap the master key from [envelope] using [secret]. A wrong secret or a
  /// tampered envelope fails the GCM auth tag → `Err(WrongSecret)`; a malformed
  /// or unknown-version envelope → `Err(EnvelopeCorrupt)`. Never a partial key.
  Future<Result<List<int>, SecurityFailure>> unwrap(
    KeyEnvelope envelope,
    String secret,
  ) async {
    if (envelope.version != KeyEnvelope.currentVersion ||
        envelope.kdf != 'argon2id') {
      return const Err(EnvelopeCorrupt());
    }
    try {
      final kek = await _deriveKek(secret, envelope.salt, envelope.params);
      final box = SecretBox(
        envelope.ciphertext,
        nonce: envelope.nonce,
        mac: Mac(envelope.mac),
      );
      final key = await _aes.decrypt(box, secretKey: kek);
      return Ok(key);
    } on SecretBoxAuthenticationError {
      return const Err(WrongSecret());
    } on Object {
      return const Err(EnvelopeCorrupt());
    }
  }

  /// Re-wrap the SAME master key under a new passphrase — no DB rekey needed.
  Future<Result<KeyEnvelope, SecurityFailure>> changePassphrase(
    KeyEnvelope envelope,
    String oldSecret,
    String newSecret, {
    Argon2idParams params = Argon2idParams.floor,
  }) async {
    final unwrapped = await unwrap(envelope, oldSecret);
    return switch (unwrapped) {
      Ok(:final value) => Ok(await wrap(value, newSecret, params: params)),
      Err(:final failure) => Err(failure),
    };
  }

  /// Create a one-time recovery code and an envelope wrapping the SAME master
  /// key under it — an independent path for a forgotten passphrase.
  Future<({String code, KeyEnvelope envelope})> createRecovery(
    List<int> masterKey, {
    Argon2idParams params = Argon2idParams.floor,
  }) async {
    final code = _recoveryCode();
    final envelope = await wrap(masterKey, code, params: params);
    return (code: code, envelope: envelope);
  }

  /// The master key as a 64-char lowercase hex string for the SQLCipher raw key.
  static String toHexKey(List<int> masterKey) =>
      masterKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Future<SecretKey> _deriveKek(
    String secret,
    List<int> salt,
    Argon2idParams p,
  ) async {
    final argon2 = Argon2id(
      memory: p.memory,
      iterations: p.iterations,
      parallelism: p.parallelism,
      hashLength: 32,
    );
    return argon2.deriveKeyFromPassword(password: secret, nonce: salt);
  }

  List<int> _randomBytes(int n) => List.generate(n, (_) => _rng.nextInt(256));

  // Crockford-style alphabet (no I/L/O/U) for legible recovery codes.
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  String _recoveryCode() {
    final chars =
        List.generate(26, (_) => _alphabet[_rng.nextInt(_alphabet.length)]);
    final groups = <String>[];
    for (var i = 0; i < chars.length; i += 5) {
      final end = i + 5 > chars.length ? chars.length : i + 5;
      groups.add(chars.sublist(i, end).join());
    }
    return groups.join('-'); // ~130 bits, grouped in fives
  }
}
