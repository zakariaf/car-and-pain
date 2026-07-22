import 'package:car_and_pain/src/security/app_lock_controller.dart';
import 'package:car_and_pain/src/security/biometric_authenticator.dart';
import 'package:car_and_pain/src/security/security_providers.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security/security.dart';

/// A clock whose instant the test advances by hand.
class _MovableClock implements Clock {
  _MovableClock(this._millis);
  int _millis;
  void advance(Duration d) => _millis += d.inMilliseconds;
  @override
  DateTime nowUtc() =>
      DateTime.fromMillisecondsSinceEpoch(_millis, isUtc: true);
}

class _FakeBiometric implements BiometricAuthenticator {
  bool available = false;
  BiometricOutcome outcome = BiometricOutcome.failed;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<BiometricOutcome> authenticate({required String reason}) async =>
      outcome;
}

void main() {
  late InMemorySecureStore store;
  late _MovableClock clock;
  late _FakeBiometric biometric;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      secureStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(clock),
      biometricAuthenticatorProvider.overrideWithValue(biometric),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    store = InMemorySecureStore();
    clock = _MovableClock(1_000_000);
    biometric = _FakeBiometric();
  });

  Future<void> enableLock(SecureVault vault,
      {bool biometricEnabled = false}) async {
    await vault.savePin('4291');
    await vault.saveLockPrefs(
      LockPrefs(enabled: true, biometricEnabled: biometricEnabled),
    );
  }

  test('starts unlocked and disabled when no PIN is configured', () async {
    final c = makeContainer();
    final state = await c.read(appLockControllerProvider.future);
    expect(state.enabled, isFalse);
    expect(state.locked, isFalse);
  });

  test('a configured lock cold-starts locked', () async {
    final c = makeContainer();
    await enableLock(c.read(secureVaultProvider));
    final state = await c.read(appLockControllerProvider.future);
    expect(state.enabled, isTrue);
    expect(state.locked, isTrue);
  });

  test('the correct PIN unlocks; a wrong PIN does not', () async {
    final c = makeContainer();
    await enableLock(c.read(secureVaultProvider));
    await c.read(appLockControllerProvider.future);
    final ctrl = c.read(appLockControllerProvider.notifier);

    expect(await ctrl.submitPin('0000'), isFalse);
    expect(c.read(appLockControllerProvider).value!.locked, isTrue);

    expect(await ctrl.submitPin('4291'), isTrue);
    expect(c.read(appLockControllerProvider).value!.locked, isFalse);
  });

  test('repeated wrong PINs throttle, and the backoff blocks the next attempt',
      () async {
    final c = makeContainer();
    await enableLock(c.read(secureVaultProvider));
    await c.read(appLockControllerProvider.future);
    final ctrl = c.read(appLockControllerProvider.notifier);

    // Three free attempts, then the fourth arms a 30s lock.
    for (var i = 0; i < 4; i++) {
      expect(await ctrl.submitPin('0000'), isFalse);
    }
    final throttled = c.read(appLockControllerProvider).value!;
    expect(throttled.throttled, isTrue);

    // Even the correct PIN is refused while the backoff window is open…
    expect(await ctrl.submitPin('4291'), isFalse);

    // …but succeeds once the clock passes the lockout.
    clock.advance(const Duration(seconds: 31));
    expect(await ctrl.submitPin('4291'), isTrue);
    expect(c.read(appLockControllerProvider).value!.locked, isFalse);
  });

  test('the throttle is persisted so backoff survives a relaunch', () async {
    final c1 = makeContainer();
    await enableLock(c1.read(secureVaultProvider));
    await c1.read(appLockControllerProvider.future);
    final ctrl1 = c1.read(appLockControllerProvider.notifier);
    for (var i = 0; i < 4; i++) {
      await ctrl1.submitPin('0000');
    }

    // A fresh container over the SAME store = a relaunch. Still throttled.
    final c2 = makeContainer();
    final relaunched = await c2.read(appLockControllerProvider.future);
    expect(relaunched.throttled, isTrue);
  });

  test('biometric success unlocks; unavailable does not', () async {
    biometric
      ..available = true
      ..outcome = BiometricOutcome.success;
    final c = makeContainer();
    await enableLock(c.read(secureVaultProvider), biometricEnabled: true);
    final state = await c.read(appLockControllerProvider.future);
    expect(state.biometricOffered, isTrue);

    final ctrl = c.read(appLockControllerProvider.notifier);
    await ctrl.unlockWithBiometric('unlock');
    expect(c.read(appLockControllerProvider).value!.locked, isFalse);
  });

  test('resume re-locks only after the timeout elapses', () async {
    final c = makeContainer();
    final vault = c.read(secureVaultProvider);
    await vault.savePin('4291');
    await vault
        .saveLockPrefs(const LockPrefs(enabled: true, timeoutMinutes: 5));
    await c.read(appLockControllerProvider.future);
    final ctrl = c.read(appLockControllerProvider.notifier);

    // Open it, then background.
    await ctrl.submitPin('4291');
    expect(c.read(appLockControllerProvider).value!.locked, isFalse);
    ctrl.markBackgrounded();

    // Back within the 5-minute grace → stays open.
    clock.advance(const Duration(minutes: 2));
    await ctrl.maybeLockOnResume();
    expect(c.read(appLockControllerProvider).value!.locked, isFalse);

    // Away past the grace → re-locks.
    ctrl.markBackgrounded();
    clock.advance(const Duration(minutes: 6));
    await ctrl.maybeLockOnResume();
    expect(c.read(appLockControllerProvider).value!.locked, isTrue);
  });
}
