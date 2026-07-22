import 'dart:math';

import 'package:core/core.dart';
import 'package:security/security.dart';
import 'package:test/test.dart';

// Weak/fast KDF: this suite exercises the lifecycle orchestration, not Argon2.
const _fast = Argon2idParams.fast;

MasterKeyService _service([InMemorySecureStore? store]) {
  final s = store ?? InMemorySecureStore();
  return MasterKeyService(
    vault: SecureVault(s, rng: Random(11)),
    rng: Random(12),
  );
}

List<int> _ok(Result<List<int>, SecurityFailure> r) =>
    (r as Ok<List<int>, SecurityFailure>).value;

void main() {
  test('setup mints a key, persists it, and opens with the same passphrase',
      () async {
    final svc = _service();
    expect((await svc.isConfigured()).valueOrNull, isFalse);

    final setup = await svc.setup(passphrase: 'garage-door-7', params: _fast);
    final s = (setup as Ok<MasterKeySetup, SecurityFailure>).value;
    expect(s.masterKey, hasLength(32));
    expect(s.recoveryCode, isNotEmpty);
    expect((await svc.isConfigured()).valueOrNull, isTrue);

    final unlocked = await svc.unlockWithPassphrase('garage-door-7');
    expect(_ok(unlocked), s.masterKey);
    // The hex handed to SQLCipher is the 64-char raw key.
    expect(MasterKeyService.toHexKey(_ok(unlocked)), hasLength(64));
  });

  test('a wrong passphrase is WrongSecret and yields no key material',
      () async {
    final svc = _service();
    await svc.setup(passphrase: 'correct horse', params: _fast);
    final r = await svc.unlockWithPassphrase('wrong horse');
    expect((r as Err).failure, isA<WrongSecret>());
  });

  test('the recovery code opens the same key, tolerant of formatting',
      () async {
    final svc = _service();
    final s = (await svc.setup(passphrase: 'pw', params: _fast)
            as Ok<MasterKeySetup, SecurityFailure>)
        .value;

    // Re-typed lowercase, without the dashes — still unlocks.
    final messy = s.recoveryCode.replaceAll('-', '').toLowerCase();
    final unlocked = await svc.unlockWithRecovery(messy);
    expect(_ok(unlocked), s.masterKey);
  });

  test('changing the passphrase re-keys without touching the master key',
      () async {
    final svc = _service();
    final s = (await svc.setup(passphrase: 'old-pw', params: _fast)
            as Ok<MasterKeySetup, SecurityFailure>)
        .value;

    final changed = await svc.changePassphrase(
      oldPassphrase: 'old-pw',
      newPassphrase: 'new-pw',
      params: _fast,
    );
    expect(changed.isOk, isTrue);

    // Old passphrase no longer works; new one returns the identical key.
    expect((await svc.unlockWithPassphrase('old-pw') as Err).failure,
        isA<WrongSecret>());
    expect(_ok(await svc.unlockWithPassphrase('new-pw')), s.masterKey);
    // The recovery code still opens the (unchanged) master key.
    expect(_ok(await svc.unlockWithRecovery(s.recoveryCode)), s.masterKey);
  });

  test('changing the passphrase with the wrong old one is refused', () async {
    final svc = _service();
    await svc.setup(passphrase: 'old-pw', params: _fast);
    final r = await svc.changePassphrase(
      oldPassphrase: 'not-old-pw',
      newPassphrase: 'new-pw',
      params: _fast,
    );
    expect((r as Err).failure, isA<WrongSecret>());
  });

  test('regenerating recovery invalidates the old code, keeps the key',
      () async {
    final svc = _service();
    final s = (await svc.setup(passphrase: 'pw', params: _fast)
            as Ok<MasterKeySetup, SecurityFailure>)
        .value;

    final fresh = await svc.regenerateRecovery('pw', params: _fast);
    final newCode = (fresh as Ok<String, SecurityFailure>).value;
    expect(newCode, isNot(s.recoveryCode));

    // The new code opens the same key; the old code no longer does.
    expect(_ok(await svc.unlockWithRecovery(newCode)), s.masterKey);
    expect((await svc.unlockWithRecovery(s.recoveryCode) as Err).failure,
        isA<WrongSecret>());
  });

  test('unlocking before setup is a corrupt/absent-state error, not wrong-key',
      () async {
    final svc = _service();
    expect((await svc.unlockWithPassphrase('pw') as Err).failure,
        isA<EnvelopeCorrupt>());
  });

  test('protectExistingKey wraps an already-open key without changing it',
      () async {
    final svc = _service();
    // A pre-existing DB key (e.g. from the F2 keystore), not minted by setup.
    final existing = List<int>.generate(32, (i) => (i * 7 + 1) % 256);

    final r = await svc.protectExistingKey(
      masterKey: existing,
      passphrase: 'pw',
      params: _fast,
    );
    final s = (r as Ok<MasterKeySetup, SecurityFailure>).value;
    // The key handed back is byte-identical — the DB stays openable.
    expect(s.masterKey, existing);

    // And it is now recoverable by passphrase and by the recovery code.
    expect(_ok(await svc.unlockWithPassphrase('pw')), existing);
    expect(_ok(await svc.unlockWithRecovery(s.recoveryCode)), existing);
  });
}
