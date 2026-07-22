import 'dart:math';

import 'package:core/core.dart';
import 'package:security/security.dart';
import 'package:test/test.dart';

// A weak/fast KDF so the persistence tests never pay the real Argon2 cost —
// this suite exercises the vault, not the KDF (covered in key_manager_test).
const _fast = Argon2idParams.fast;

Future<KeyEnvelope> _envelope() async {
  final km = KeyManager(rng: Random(3));
  return km.wrap(km.generateMasterKey(), 'pass', params: _fast);
}

void main() {
  late SecureVault vault;
  late InMemorySecureStore store;

  setUp(() {
    store = InMemorySecureStore();
    vault = SecureVault(store, rng: Random(7));
  });

  test('a fresh vault is unconfigured and loadEnvelope is Ok(null)', () async {
    expect((await vault.isConfigured()).valueOrNull, isFalse);
    final loaded = await vault.loadEnvelope();
    expect(loaded, isA<Ok<KeyEnvelope?, SecurityFailure>>());
    expect((loaded as Ok).value, isNull);
  });

  test('envelope round-trips byte-for-byte through the store', () async {
    final env = await _envelope();
    expect((await vault.saveEnvelope(env)).isOk, isTrue);
    expect((await vault.isConfigured()).valueOrNull, isTrue);

    final loaded = (await vault.loadEnvelope() as Ok).value as KeyEnvelope;
    expect(loaded.toJson(), env.toJson());
  });

  test('recovery envelope persists independently of the passphrase envelope',
      () async {
    final km = KeyManager(rng: Random(5));
    final master = km.generateMasterKey();
    final pass = await km.wrap(master, 'pass', params: _fast);
    final rec = (await km.createRecovery(master, params: _fast)).envelope;

    await vault.saveEnvelope(pass);
    await vault.saveRecovery(rec);

    expect((await vault.loadEnvelope() as Ok).value, isNotNull);
    expect(((await vault.loadRecovery() as Ok).value as KeyEnvelope).toJson(),
        rec.toJson());
  });

  test('a present-but-garbage envelope is EnvelopeCorrupt, not missing',
      () async {
    await store.write('sec.envelope', 'not json at all');
    expect((await vault.loadEnvelope() as Err).failure, isA<EnvelopeCorrupt>());
  });

  test('a platform read failure surfaces as SecureStorageFailed', () async {
    store.failing = true;
    expect((await vault.loadEnvelope() as Err).failure,
        isA<SecureStorageFailed>());
    expect((await vault.isConfigured() as Err).failure,
        isA<SecureStorageFailed>());
  });

  test('throttle state persists and defaults to empty when absent', () async {
    expect((await vault.loadThrottle() as Ok).value, const ThrottleState());

    const state = ThrottleState(failures: 4, lockedUntilMillis: 123456);
    await vault.saveThrottle(state);
    expect((await vault.loadThrottle() as Ok).value, state);
  });

  test('PIN is stored as a salted verifier and checked constant-time',
      () async {
    await vault.savePin('4291');
    expect((await vault.verifyPin('4291') as Ok).value, isTrue);
    expect((await vault.verifyPin('0000') as Ok).value, isFalse);

    // Never the PIN itself, and salted (verifier differs from the raw digits).
    final stored = await store.read('sec.pin_verifier');
    expect(stored, isNotNull);
    expect(stored, isNot(contains('4291')));
  });

  test('verifyPin is Ok(false) when no PIN has been set', () async {
    expect((await vault.verifyPin('4291') as Ok).value, isFalse);
  });

  test('hasPin reflects whether a PIN verifier exists', () async {
    expect((await vault.hasPin() as Ok).value, isFalse);
    await vault.savePin('4291');
    expect((await vault.hasPin() as Ok).value, isTrue);
  });

  test('lock prefs persist and default to disabled', () async {
    expect((await vault.loadLockPrefs() as Ok).value, LockPrefs.disabled);
    const prefs =
        LockPrefs(enabled: true, biometricEnabled: false, timeoutMinutes: 5);
    await vault.saveLockPrefs(prefs);
    expect((await vault.loadLockPrefs() as Ok).value, prefs);
  });

  test('reset wipes every security item (factory reset)', () async {
    await vault.saveEnvelope(await _envelope());
    await vault.savePin('4291');
    await vault.saveThrottle(const ThrottleState(failures: 2));

    await vault.reset();

    expect((await vault.isConfigured()).valueOrNull, isFalse);
    expect((await vault.verifyPin('4291') as Ok).value, isFalse);
    expect((await vault.loadThrottle() as Ok).value, const ThrottleState());
  });
}
