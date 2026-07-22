import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';

/// A sealed attachment blob (F8-T4): AES-256-GCM ciphertext plus the per-blob
/// random nonce and the 128-bit auth tag. The on-disk layout is self-describing
/// — `[version | nonce(12) | ciphertext | mac(16)]` — so a stored file needs no
/// extra DB columns to be decrypted, only the `is_encrypted` flag to know it is
/// sealed at all.
final class SealedBlob {
  const SealedBlob({
    required this.version,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  /// Current on-disk scheme version.
  static const int currentVersion = 1;
  static const int _nonceLen = 12; // AES-GCM 96-bit nonce
  static const int _macLen = 16; // 128-bit GCM tag
  static const int _headerLen = 1 + _nonceLen; // version + nonce
  static const int _minLen = _headerLen + _macLen;

  final int version;
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> mac;

  /// The self-describing on-disk byte layout.
  Uint8List toBytes() =>
      Uint8List.fromList([version, ...nonce, ...ciphertext, ...mac]);

  /// Parse the on-disk layout; null when truncated or of an unknown version.
  static SealedBlob? fromBytes(List<int> bytes) {
    if (bytes.length < _minLen) return null;
    if (bytes[0] != currentVersion) return null;
    final nonce = bytes.sublist(1, _headerLen);
    final macStart = bytes.length - _macLen;
    final ciphertext = bytes.sublist(_headerLen, macStart);
    final mac = bytes.sublist(macStart);
    return SealedBlob(
      version: bytes[0],
      nonce: nonce,
      ciphertext: ciphertext,
      mac: mac,
    );
  }
}

/// Seals/unseals attachment blobs with the **F2/F7 master key** — no second key
/// system, no key derivation. The raw 32-byte key (from the keystore or a
/// `MasterKeyService` unlock) is passed per call. A per-blob random 96-bit nonce
/// is generated on `seal`; any tamper (bit-flip in nonce, ciphertext or tag)
/// fails the GCM auth tag on `unseal` and surfaces as a typed `WrongSecret`,
/// never partial plaintext.
final class BlobSealer {
  BlobSealer();

  final AesGcm _aes = AesGcm.with256bits();

  /// Encrypt [plaintext] under the raw [key] (32 bytes). Cannot fail for valid
  /// input, so it returns a plain [SealedBlob] (mirrors `KeyManager.wrap`).
  Future<SealedBlob> seal(List<int> plaintext, List<int> key) async {
    final nonce = _aes.newNonce();
    final box = await _aes.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    return SealedBlob(
      version: SealedBlob.currentVersion,
      nonce: nonce,
      ciphertext: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  /// Decrypt a [blob] under the raw [key]. A tampered blob or wrong key fails
  /// the GCM auth tag → `Err(WrongSecret)`; an unknown version → `Err(
  /// EnvelopeCorrupt)`. Never returns partial plaintext.
  Future<Result<List<int>, SecurityFailure>> unseal(
    SealedBlob blob,
    List<int> key,
  ) async {
    if (blob.version != SealedBlob.currentVersion) {
      return const Err(EnvelopeCorrupt());
    }
    try {
      final box = SecretBox(
        blob.ciphertext,
        nonce: blob.nonce,
        mac: Mac(blob.mac),
      );
      return Ok(await _aes.decrypt(box, secretKey: SecretKey(key)));
    } on SecretBoxAuthenticationError {
      return const Err(WrongSecret());
    } on Object {
      return const Err(EnvelopeCorrupt());
    }
  }
}
