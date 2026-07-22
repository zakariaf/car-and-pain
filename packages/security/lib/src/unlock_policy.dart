import 'dart:math' as math;

/// Persisted throttling state (F7-T4/T5). Survives restart so an attacker can't
/// reset the backoff by relaunching.
final class ThrottleState {
  const ThrottleState({this.failures = 0, this.lockedUntilMillis = 0});

  factory ThrottleState.fromJson(Map<String, dynamic> json) => ThrottleState(
        failures: (json['f'] as int?) ?? 0,
        lockedUntilMillis: (json['u'] as int?) ?? 0,
      );

  final int failures;
  final int lockedUntilMillis;

  Map<String, dynamic> toJson() => {'f': failures, 'u': lockedUntilMillis};

  @override
  bool operator ==(Object other) =>
      other is ThrottleState &&
      other.failures == failures &&
      other.lockedUntilMillis == lockedUntilMillis;

  @override
  int get hashCode => Object.hash(failures, lockedUntilMillis);
}

/// Pure PIN-attempt throttling (F7-T4): the first [freeAttempts] are free, then
/// each further failure locks for an exponentially-growing delay, capped at
/// [maxDelay]. Clock-injected (millis passed in) — fully deterministic.
final class PinThrottle {
  const PinThrottle({
    this.freeAttempts = 3,
    this.baseDelay = const Duration(seconds: 30),
    this.maxDelay = const Duration(minutes: 30),
  });

  final int freeAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  /// Whether an attempt is currently blocked.
  bool isLocked(ThrottleState s, int nowMillis) =>
      nowMillis < s.lockedUntilMillis;

  /// The new state after a **failed** attempt at [nowMillis].
  ThrottleState onFailure(ThrottleState s, int nowMillis) {
    final failures = s.failures + 1;
    if (failures <= freeAttempts) {
      return ThrottleState(failures: failures);
    }
    final over = failures - freeAttempts; // 1, 2, 3, …
    final grown = baseDelay.inMilliseconds * math.pow(2, over - 1);
    final delayMs = math.min(grown, maxDelay.inMilliseconds).toInt();
    return ThrottleState(
        failures: failures, lockedUntilMillis: nowMillis + delayMs);
  }

  /// A successful unlock clears the throttle.
  ThrottleState onSuccess() => const ThrottleState();
}

/// Pure lock-on-timeout policy (F7-T4): re-auth is required once the app has
/// been away/idle for [timeout]. Clock-injected.
final class LockPolicy {
  const LockPolicy(this.timeout);

  final Duration timeout;

  /// Whether the app must re-lock, given when it was last unlocked/foregrounded.
  bool shouldLock({required int lastActiveMillis, required int nowMillis}) =>
      nowMillis - lastActiveMillis >= timeout.inMilliseconds;
}
