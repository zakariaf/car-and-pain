import 'dart:math';

import 'package:core/core.dart';
import 'package:security/security.dart';

/// Seals/unseals an archive payload under a **passphrase**, reusing the master-
/// key hierarchy's Argon2id KEK derivation + AES-256-GCM (no second crypto
/// system). The salt lives in the archive header; the nonce + GCM tag live
/// inside the self-describing `SealedBlob` payload.
class ArchiveCipher {
  ArchiveCipher({KeyManager? keyManager, BlobSealer? sealer, Random? rng})
      : _km = keyManager ?? KeyManager(),
        _sealer = sealer ?? BlobSealer(),
        _rng = rng ?? Random.secure();

  final KeyManager _km;
  final BlobSealer _sealer;
  final Random _rng;

  /// Derive a KEK from [passphrase] + a fresh salt under [params], seal
  /// [payload], and return the salt (for the header) + the sealed bytes.
  Future<({List<int> salt, List<int> sealed})> seal(
    List<int> payload,
    String passphrase,
    Argon2idParams params,
  ) async {
    final salt = List<int>.generate(16, (_) => _rng.nextInt(256));
    final kek = await _km.deriveKek(passphrase, salt, params);
    final blob = await _sealer.seal(payload, kek);
    return (salt: salt, sealed: blob.toBytes());
  }

  /// Re-derive the KEK from [passphrase] + [salt] + [params] and unseal. A wrong
  /// passphrase or tampered payload fails the GCM tag → `Err(WrongSecret)`; a
  /// malformed payload → `Err(EnvelopeCorrupt)`.
  Future<Result<List<int>, SecurityFailure>> unseal(
    List<int> sealed,
    String passphrase,
    List<int> salt,
    Argon2idParams params,
  ) async {
    final blob = SealedBlob.fromBytes(sealed);
    if (blob == null) return const Err(EnvelopeCorrupt());
    final kek = await _km.deriveKek(passphrase, salt, params);
    return _sealer.unseal(blob, kek);
  }
}
