import 'dart:math';

import 'package:core/core.dart';
import 'package:security/security.dart';
import 'package:test/test.dart';

List<int> _key(int seed) {
  final rng = Random(seed);
  return List<int>.generate(32, (_) => rng.nextInt(256));
}

List<int> _ok(Result<List<int>, SecurityFailure> r) =>
    (r as Ok<List<int>, SecurityFailure>).value;

void main() {
  final sealer = BlobSealer();
  final key = _key(1);

  test('round-trips a blob byte-for-byte under the master key', () async {
    final plaintext = List<int>.generate(5000, (i) => i % 256);
    final sealed = await sealer.seal(plaintext, key);
    expect(_ok(await sealer.unseal(sealed, key)), plaintext);
  });

  test('an empty blob round-trips', () async {
    final sealed = await sealer.seal(const [], key);
    expect(_ok(await sealer.unseal(sealed, key)), isEmpty);
  });

  test('ciphertext on disk reveals nothing of the plaintext', () async {
    final plaintext = List<int>.filled(1000, 0x41); // 'A' repeated
    final sealed = await sealer.seal(plaintext, key);
    // Same-byte plaintext must NOT produce a same-byte ciphertext.
    expect(sealed.ciphertext.toSet().length, greaterThan(1));
    expect(sealed.ciphertext, isNot(plaintext));
    expect(sealed.nonce, hasLength(12));
    expect(sealed.mac, hasLength(16));
  });

  test('each seal uses a fresh nonce (no reuse)', () async {
    final a = await sealer.seal(const [1, 2, 3], key);
    final b = await sealer.seal(const [1, 2, 3], key);
    expect(a.nonce, isNot(b.nonce));
    expect(a.ciphertext, isNot(b.ciphertext));
  });

  test('the wrong key fails the auth tag → WrongSecret, no plaintext',
      () async {
    final sealed = await sealer.seal(const [9, 8, 7], key);
    final r = await sealer.unseal(sealed, _key(2));
    expect((r as Err).failure, isA<WrongSecret>());
  });

  test('a bit-flip in the ciphertext is detected as tamper (WrongSecret)',
      () async {
    final sealed = await sealer.seal(List<int>.generate(64, (i) => i), key);
    final tampered = SealedBlob(
      version: sealed.version,
      nonce: sealed.nonce,
      ciphertext: [...sealed.ciphertext]..[0] ^= 0x01,
      mac: sealed.mac,
    );
    expect((await sealer.unseal(tampered, key) as Err).failure,
        isA<WrongSecret>());
  });

  test('a bit-flip in the auth tag is detected (WrongSecret)', () async {
    final sealed = await sealer.seal(const [1, 2, 3, 4], key);
    final tampered = SealedBlob(
      version: sealed.version,
      nonce: sealed.nonce,
      ciphertext: sealed.ciphertext,
      mac: [...sealed.mac]..[0] ^= 0x01,
    );
    expect((await sealer.unseal(tampered, key) as Err).failure,
        isA<WrongSecret>());
  });

  test('the on-disk byte layout round-trips through fromBytes', () async {
    final plaintext = List<int>.generate(300, (i) => i % 256);
    final sealed = await sealer.seal(plaintext, key);
    final parsed = SealedBlob.fromBytes(sealed.toBytes())!;
    expect(_ok(await sealer.unseal(parsed, key)), plaintext);
  });

  test('truncated or unknown-version bytes parse to null', () async {
    expect(SealedBlob.fromBytes(const [1, 2, 3]), isNull); // too short
    final sealed = await sealer.seal(const [1, 2, 3], key);
    final bad = sealed.toBytes()..[0] = 99; // unknown version
    expect(SealedBlob.fromBytes(bad), isNull);
  });

  test('an unknown scheme version unseals to EnvelopeCorrupt', () async {
    final sealed = await sealer.seal(const [1, 2, 3], key);
    final future = SealedBlob(
      version: 99,
      nonce: sealed.nonce,
      ciphertext: sealed.ciphertext,
      mac: sealed.mac,
    );
    expect((await sealer.unseal(future, key) as Err).failure,
        isA<EnvelopeCorrupt>());
  });
}
