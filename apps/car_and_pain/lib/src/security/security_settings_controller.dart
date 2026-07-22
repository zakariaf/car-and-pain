import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:security/security.dart';

import 'app_lock_controller.dart';
import 'security_providers.dart';

part 'security_settings_controller.g.dart';

/// A snapshot of the security-settings surface (F7-T7).
class SecuritySettingsSnapshot {
  const SecuritySettingsSnapshot({
    required this.prefs,
    required this.hasPin,
    required this.biometricAvailable,
    required this.recoveryConfigured,
  });

  final LockPrefs prefs;
  final bool hasPin;
  final bool biometricAvailable;

  /// Whether a recovery envelope exists (data is recoverable-by-default).
  final bool recoveryConfigured;
}

/// Reads and mutates the security settings (F7-T7). Every mutation writes
/// through the vault and then refreshes both this snapshot and the app-lock
/// controller, so a change (enable lock, set PIN, adjust timeout) takes effect
/// immediately.
@riverpod
class SecuritySettingsController extends _$SecuritySettingsController {
  @override
  Future<SecuritySettingsSnapshot> build() => _snapshot();

  Future<SecuritySettingsSnapshot> _snapshot() async {
    final vault = ref.read(secureVaultProvider);
    final prefs =
        (await vault.loadLockPrefs()).valueOrNull ?? LockPrefs.disabled;
    final hasPin = (await vault.hasPin()).valueOrNull ?? false;
    final recovery = (await vault.loadRecovery()).valueOrNull != null;
    final bioAvailable =
        await ref.read(biometricAuthenticatorProvider).isAvailable();
    return SecuritySettingsSnapshot(
      prefs: prefs,
      hasPin: hasPin,
      biometricAvailable: bioAvailable,
      recoveryConfigured: recovery,
    );
  }

  Future<void> _refresh() async {
    state = AsyncData(await _snapshot());
    ref.invalidate(appLockControllerProvider);
  }

  LockPrefs get _prefs => state.asData?.value.prefs ?? LockPrefs.disabled;

  /// Set the app-lock PIN and enable the lock.
  Future<void> setPin(String pin) async {
    final vault = ref.read(secureVaultProvider);
    await vault.savePin(pin);
    await vault.saveLockPrefs(_prefs.copyWith(enabled: true));
    await _refresh();
  }

  /// Re-enable the lock using the existing PIN (no re-prompt).
  Future<void> enableLock() async {
    await ref
        .read(secureVaultProvider)
        .saveLockPrefs(_prefs.copyWith(enabled: true));
    await _refresh();
  }

  /// Turn the lock off (the PIN verifier is kept for a quick re-enable).
  Future<void> disableLock() async {
    await ref
        .read(secureVaultProvider)
        .saveLockPrefs(_prefs.copyWith(enabled: false));
    await _refresh();
  }

  Future<void> setBiometricEnabled({required bool enabled}) async {
    await ref
        .read(secureVaultProvider)
        .saveLockPrefs(_prefs.copyWith(biometricEnabled: enabled));
    await _refresh();
  }

  Future<void> setTimeoutMinutes(int minutes) async {
    await ref
        .read(secureVaultProvider)
        .saveLockPrefs(_prefs.copyWith(timeoutMinutes: minutes));
    await _refresh();
  }

  /// Make the DB key recoverable: wrap the existing key under [passphrase] +
  /// a one-time recovery code. Returns the code to show once (null on failure).
  Future<String?> setupRecovery(String passphrase) async {
    final key = await ref.read(secureKeyStoreProvider).readAndUnwrapDbKey();
    final result = await ref.read(masterKeyServiceProvider).protectExistingKey(
          masterKey: key,
          passphrase: passphrase,
        );
    await _refresh();
    return switch (result) {
      Ok(:final value) => value.recoveryCode,
      Err() => null,
    };
  }
}
