import 'dart:math';

import 'package:core/core.dart';
import 'package:security/security.dart';
import 'package:test/test.dart';

/// A deterministic RNG so envelopes are reproducible where a test needs it.
class _SeededRandom implements Random {
  _SeededRandom(this._delegate);
  final Random _delegate;
  @override
  int nextInt(int max) => _delegate.nextInt(max);
  @override
  bool nextBool() => _delegate.nextBool();
  @override
  double nextDouble() => _delegate.nextDouble();
}

void main() {
  const fast = Argon2idParams.fast;
  final km = KeyManager(rng: _SeededRandom(Random(1)));

  test('generateMasterKey is 256 bits and hex is 64 chars', () {
    final key = km.generateMasterKey();
    expect(key, hasLength(32));
    expect(KeyManager.toHexKey(key), hasLength(64));
    expect(KeyManager.toHexKey(key), matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('wrap → unwrap round-trips the identical master key', () async {
    final key = km.generateMasterKey();
    final env = await km.wrap(key, 'correct horse battery', params: fast);
    final out = await km.unwrap(env, 'correct horse battery');
    expect(out.isOk, isTrue);
    expect(out.valueOrNull, key);
    // The envelope never contains the raw key.
    expect(env.ciphertext, isNot(key));
  });

  test('wrong passphrase fails the auth tag → WrongSecret (no key)', () async {
    final env = await km.wrap(km.generateMasterKey(), 'right', params: fast);
    final out = await km.unwrap(env, 'wrong');
    expect(out.isErr, isTrue);
    expect(out.failureOrNull, isA<WrongSecret>());
    expect(out.valueOrNull, isNull);
  });

  test('a tampered envelope (flipped ciphertext byte) → WrongSecret', () async {
    final env = await km.wrap(km.generateMasterKey(), 'pw', params: fast);
    final tampered = KeyEnvelope(
      version: env.version,
      kdf: env.kdf,
      params: env.params,
      salt: env.salt,
      nonce: env.nonce,
      ciphertext: [env.ciphertext.first ^ 0xff, ...env.ciphertext.skip(1)],
      mac: env.mac,
    );
    expect((await km.unwrap(tampered, 'pw')).failureOrNull, isA<WrongSecret>());
  });

  test('an unknown scheme version → EnvelopeCorrupt', () async {
    final env = await km.wrap(km.generateMasterKey(), 'pw', params: fast);
    final future = KeyEnvelope(
      version: 999,
      kdf: env.kdf,
      params: env.params,
      salt: env.salt,
      nonce: env.nonce,
      ciphertext: env.ciphertext,
      mac: env.mac,
    );
    expect(
        (await km.unwrap(future, 'pw')).failureOrNull, isA<EnvelopeCorrupt>());
  });

  test('passphrase change re-wraps the SAME key (no rekey)', () async {
    final key = km.generateMasterKey();
    final env = await km.wrap(key, 'old', params: fast);
    final changed = await km.changePassphrase(env, 'old', 'new', params: fast);
    expect(changed.isOk, isTrue);
    final rewrapped = changed.valueOrNull!;
    // New passphrase unwraps the same key; the old one no longer works.
    expect((await km.unwrap(rewrapped, 'new')).valueOrNull, key);
    expect(
        (await km.unwrap(rewrapped, 'old')).failureOrNull, isA<WrongSecret>());
  });

  test('a wrong old passphrase blocks the change', () async {
    final env = await km.wrap(km.generateMasterKey(), 'old', params: fast);
    final changed = await km.changePassphrase(env, 'nope', 'new', params: fast);
    expect(changed.failureOrNull, isA<WrongSecret>());
  });

  test('recovery code unwraps the SAME master key independently', () async {
    final key = km.generateMasterKey();
    final rec = await km.createRecovery(key, params: fast);
    expect(rec.code, isNotEmpty);
    expect(rec.code, contains('-')); // grouped for legibility
    expect((await km.unwrap(rec.envelope, rec.code)).valueOrNull, key);
    // A different code doesn't unwrap it.
    expect(
        (await km.unwrap(rec.envelope, 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE-F'))
            .failureOrNull,
        isA<WrongSecret>());
  });

  test('envelope JSON round-trips losslessly', () async {
    final env = await km.wrap(km.generateMasterKey(), 'pw', params: fast);
    final back = KeyEnvelope.tryFromJson(env.toJson());
    expect(back, isNotNull);
    expect(back!.version, env.version);
    expect(back.kdf, env.kdf);
    expect(back.params.memory, env.params.memory);
    expect(back.salt, env.salt);
    expect(back.nonce, env.nonce);
    expect(back.ciphertext, env.ciphertext);
    expect(back.mac, env.mac);
    // …and it still unwraps.
    expect((await km.unwrap(back, 'pw')).isOk, isTrue);
  });

  test('malformed JSON → null (maps to EnvelopeCorrupt)', () {
    expect(KeyEnvelope.tryFromJson({'v': 1}), isNull);
    expect(KeyEnvelope.tryFromJson({'v': 1, 'kdf': 'x', 'salt': '!!not-b64'}),
        isNull);
  });

  test('atLeastFloor raises weak params to the security floor', () {
    const weak = Argon2idParams(memory: 8, iterations: 1, parallelism: 1);
    final raised = weak.atLeastFloor();
    expect(raised.memory, Argon2idParams.floor.memory);
    expect(raised.iterations, Argon2idParams.floor.iterations);
  });
}
