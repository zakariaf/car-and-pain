import 'package:local_auth/local_auth.dart';

/// The outcome of a biometric / device-credential unlock attempt.
enum BiometricOutcome {
  /// The user authenticated successfully.
  success,

  /// Hardware present but the attempt was rejected (wrong face/finger).
  failed,

  /// No enrolled biometric / not supported → fall back to the PIN.
  unavailable,

  /// The user dismissed the system prompt.
  canceled,
}

/// The biometric-unlock port (F7-T4). Injected so the app-lock controller is
/// testable with a fake; the real implementation drives `local_auth`.
abstract interface class BiometricAuthenticator {
  /// Whether a biometric (or device credential) can be prompted right now.
  Future<bool> isAvailable();

  /// Prompt for biometric / device-credential auth with [reason] shown by the
  /// OS. Never throws — platform errors map to a [BiometricOutcome].
  Future<BiometricOutcome> authenticate({required String reason});
}

/// The production authenticator over `local_auth`. Device-only: the actual
/// prompt requires hardware, so this path needs on-device QA (TODO(F7)).
class LocalAuthBiometric implements BiometricAuthenticator {
  LocalAuthBiometric([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } on Object {
      return false;
    }
  }

  @override
  Future<BiometricOutcome> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true, // survive app backgrounding mid-prompt
          // biometricOnly stays false (default): allow the device PIN/pattern
          // as a fallback for users without an enrolled biometric.
        ),
      );
      return ok ? BiometricOutcome.success : BiometricOutcome.canceled;
    } on Object {
      // PlatformException (no hardware, lockout, user-cancel) → PIN fallback.
      return BiometricOutcome.unavailable;
    }
  }
}
