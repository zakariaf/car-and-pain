import 'package:core/core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:security/security.dart';

import 'biometric_authenticator.dart';
import 'security_providers.dart';

part 'app_lock_controller.g.dart';

/// The app-lock state the shell watches (F7-T4). When [locked] is true the
/// unlock screen covers the app; the shell only mounts once it clears.
class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.locked,
    required this.biometricOffered,
    this.lockedUntilMillis,
    this.failures = 0,
  });

  /// App-lock is turned on (prefs enabled AND a PIN exists).
  final bool enabled;

  /// The unlock screen must be shown.
  final bool locked;

  /// Whether to offer the biometric button (available + allowed by prefs).
  final bool biometricOffered;

  /// When throttled, the epoch-millis until which attempts are blocked.
  final int? lockedUntilMillis;

  /// Consecutive failed attempts (for the UI to surface remaining tries).
  final int failures;

  bool get throttled => lockedUntilMillis != null;

  AppLockState copyWith({
    bool? enabled,
    bool? locked,
    bool? biometricOffered,
    int? lockedUntilMillis,
    bool clearLockedUntil = false,
    int? failures,
  }) =>
      AppLockState(
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
        biometricOffered: biometricOffered ?? this.biometricOffered,
        lockedUntilMillis: clearLockedUntil
            ? null
            : (lockedUntilMillis ?? this.lockedUntilMillis),
        failures: failures ?? this.failures,
      );
}

/// Orchestrates locking/unlocking over the pure policies (`PinThrottle`,
/// `LockPolicy`) and the vault. Cold start is always locked when enabled;
/// backgrounding records the time; resume re-locks past the timeout. PIN
/// verification and biometric prompts run here, but every *decision* is a pure,
/// already-tested policy — this class only wires them.
@riverpod
class AppLockController extends _$AppLockController {
  int _lastActiveMillis = 0;

  int get _now => ref.read(clockProvider).nowUtc().millisecondsSinceEpoch;

  @override
  Future<AppLockState> build() async {
    final vault = ref.watch(secureVaultProvider);
    final prefs =
        (await vault.loadLockPrefs()).valueOrNull ?? LockPrefs.disabled;
    final hasPin = (await vault.hasPin()).valueOrNull ?? false;
    final enabled = prefs.enabled && hasPin;

    final throttle =
        (await vault.loadThrottle()).valueOrNull ?? const ThrottleState();
    final now = _now;
    _lastActiveMillis = now;

    final biometricOffered = enabled &&
        prefs.biometricEnabled &&
        await ref.read(biometricAuthenticatorProvider).isAvailable();

    return AppLockState(
      enabled: enabled,
      locked: enabled, // a cold start is always locked when the lock is on
      biometricOffered: biometricOffered,
      lockedUntilMillis:
          throttle.lockedUntilMillis > now ? throttle.lockedUntilMillis : null,
      failures: throttle.failures,
    );
  }

  /// The app left the foreground — remember when, to measure idle time.
  void markBackgrounded() => _lastActiveMillis = _now;

  /// The app resumed — re-lock if it was away longer than the timeout.
  Future<void> maybeLockOnResume() async {
    final s = state.asData?.value;
    if (s == null || !s.enabled || s.locked) return;
    final prefs =
        (await ref.read(secureVaultProvider).loadLockPrefs()).valueOrNull ??
            LockPrefs.disabled;
    final shouldLock = LockPolicy(prefs.timeout).shouldLock(
      lastActiveMillis: _lastActiveMillis,
      nowMillis: _now,
    );
    if (shouldLock) state = AsyncData(s.copyWith(locked: true));
  }

  /// Prompt for biometric unlock. No-op while throttled or already open.
  Future<void> unlockWithBiometric(String reason) async {
    final s = state.asData?.value;
    if (s == null || !s.locked) return;
    if (s.lockedUntilMillis != null && _now < s.lockedUntilMillis!) return;

    final outcome = await ref
        .read(biometricAuthenticatorProvider)
        .authenticate(reason: reason);
    if (outcome == BiometricOutcome.success) {
      state = AsyncData(s.copyWith(locked: false, clearLockedUntil: true));
    }
  }

  /// Submit a PIN. Returns true on unlock; a wrong PIN advances the persisted
  /// throttle so backoff survives a relaunch.
  Future<bool> submitPin(String pin) async {
    final s = state.asData?.value;
    if (s == null || !s.locked) return false;

    final vault = ref.read(secureVaultProvider);
    final throttle = ref.read(pinThrottleProvider);
    final now = _now;
    final stored =
        (await vault.loadThrottle()).valueOrNull ?? const ThrottleState();

    if (throttle.isLocked(stored, now)) {
      state = AsyncData(s.copyWith(
        lockedUntilMillis: stored.lockedUntilMillis,
        failures: stored.failures,
      ));
      return false;
    }

    final ok = (await vault.verifyPin(pin)).valueOrNull ?? false;
    if (ok) {
      await vault.saveThrottle(throttle.onSuccess());
      state = AsyncData(
        s.copyWith(locked: false, clearLockedUntil: true, failures: 0),
      );
      return true;
    }

    final next = throttle.onFailure(stored, now);
    await vault.saveThrottle(next);
    state = AsyncData(s.copyWith(
      lockedUntilMillis:
          next.lockedUntilMillis > now ? next.lockedUntilMillis : null,
      failures: next.failures,
    ));
    return false;
  }
}
