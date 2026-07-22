import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:security/security.dart';

import 'biometric_authenticator.dart';
import 'secure_store_adapter.dart';

/// The clock port (F7). `SystemClock` in prod; overridden with `FixedClock` in
/// tests so throttle/lock-timeout behaviour is deterministic.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// The platform secure-storage port. Overridden in tests with
/// `InMemorySecureStore` so the whole security stack runs without plugins.
final secureStoreProvider =
    Provider<SecureStore>((ref) => FlutterSecureStore());

/// The persistence vault over the secure store (envelopes, throttle, PIN
/// verifier, lock prefs).
final secureVaultProvider = Provider<SecureVault>(
  (ref) => SecureVault(ref.watch(secureStoreProvider)),
);

/// The master-key lifecycle service (setup / unlock / recovery / re-key).
final masterKeyServiceProvider = Provider<MasterKeyService>(
  (ref) => MasterKeyService(vault: ref.watch(secureVaultProvider)),
);

/// The PIN-attempt throttle policy — the default exponential backoff schedule.
final pinThrottleProvider = Provider<PinThrottle>((ref) => const PinThrottle());

/// The biometric-unlock port. Overridden in tests with a fake outcome.
final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => LocalAuthBiometric(),
);
