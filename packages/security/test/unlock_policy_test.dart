import 'package:security/security.dart';
import 'package:test/test.dart';

void main() {
  group('PinThrottle backoff (F7-T4)', () {
    const throttle = PinThrottle(); // 3 free, base 30s, cap 30min
    const t0 = 1000000;

    test('the first three failures are free (no lock)', () {
      var s = const ThrottleState();
      for (var i = 0; i < 3; i++) {
        s = throttle.onFailure(s, t0);
        expect(throttle.isLocked(s, t0), isFalse, reason: 'attempt ${i + 1}');
      }
      expect(s.failures, 3);
    });

    test('the 4th failure locks for 30s, and unlocks after it passes', () {
      var s = const ThrottleState(failures: 3);
      s = throttle.onFailure(s, t0);
      expect(s.lockedUntilMillis, t0 + 30000);
      expect(throttle.isLocked(s, t0), isTrue);
      expect(throttle.isLocked(s, t0 + 29999), isTrue);
      expect(throttle.isLocked(s, t0 + 30000), isFalse);
    });

    test('the delay doubles each further failure, capped at 30 min', () {
      int lockMsAfter(int failures) =>
          throttle
              .onFailure(ThrottleState(failures: failures - 1), t0)
              .lockedUntilMillis -
          t0;
      expect(lockMsAfter(4), 30000); // 30s (over=1 → 2^0)
      expect(lockMsAfter(5), 60000); // 60s
      expect(lockMsAfter(6), 120000); // 120s
      expect(lockMsAfter(8), 480000); // 8 min (over=5 → 2^4)
      expect(lockMsAfter(9), 960000); // 16 min
      expect(lockMsAfter(10), 1800000); // 2^6 → capped at 30 min
      expect(lockMsAfter(20), 1800000); // still capped
    });

    test('a success clears the throttle', () {
      expect(throttle.onSuccess(), const ThrottleState());
    });

    test('state survives a JSON round-trip (persists across restart)', () {
      const s = ThrottleState(failures: 5, lockedUntilMillis: 123456);
      expect(ThrottleState.fromJson(s.toJson()), s);
    });
  });

  group('LockPolicy timeout (F7-T4)', () {
    const policy = LockPolicy(Duration(minutes: 5));

    test('locks once idle past the timeout, not before', () {
      const fiveMin = 5 * 60 * 1000;
      expect(policy.shouldLock(lastActiveMillis: 0, nowMillis: fiveMin - 1),
          isFalse);
      expect(
          policy.shouldLock(lastActiveMillis: 0, nowMillis: fiveMin), isTrue);
      expect(policy.shouldLock(lastActiveMillis: 0, nowMillis: fiveMin + 1),
          isTrue);
    });
  });
}
