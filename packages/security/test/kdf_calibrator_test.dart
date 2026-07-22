import 'package:security/security.dart';
import 'package:test/test.dart';

// A synthetic device: derive-time is linear in memory (KiB → microseconds via
// [usPerKib]) with a fixed [overhead]. Lets the search be tested with no KDF.
Future<Duration> Function(Argon2idParams) _linear({
  required double usPerKib,
  Duration overhead = Duration.zero,
}) =>
    (p) async => Duration(
          microseconds: overhead.inMicroseconds + (p.memory * usPerKib).round(),
        );

void main() {
  const floor = Argon2idParams.floor;

  test('scales memory up to fill the budget, above the floor', () async {
    const cal = KdfCalibrator();
    // 10 µs/KiB → floor (19456 KiB) ≈ 195 ms. Budget 500 ms ⇒ ~50000 KiB.
    final p = await cal.calibrate(
      budget: const Duration(milliseconds: 500),
      measure: _linear(usPerKib: 10),
    );
    expect(p.memory, greaterThan(floor.memory));
    expect(p.iterations, floor.iterations);
    expect(p.parallelism, floor.parallelism);
    // The chosen params come in at or under budget…
    final chosen = await _linear(usPerKib: 10)(p);
    expect(chosen.inMilliseconds, lessThanOrEqualTo(500));
    // …and are close to it (within one tolerance step of the true target).
    expect(p.memory, closeTo(50000, 2000));
  });

  test('a slow device that blows the budget at the floor keeps the floor',
      () async {
    const cal = KdfCalibrator();
    // 100 µs/KiB → floor already ≈ 1.9 s, well over a 500 ms budget.
    final p = await cal.calibrate(
      budget: const Duration(milliseconds: 500),
      measure: _linear(usPerKib: 100),
    );
    expect(p, floor); // security wins over responsiveness
  });

  test('a very fast device is clamped at the memory cap, not run away',
      () async {
    const cal = KdfCalibrator(maxMemory: 131072);
    // 0.1 µs/KiB → even the 128 MiB cap is ~13 ms, far under a 2 s budget.
    final p = await cal.calibrate(
      budget: const Duration(seconds: 2),
      measure: _linear(usPerKib: 0.1),
    );
    expect(p.memory, 131072);
  });

  test('the result is always at least the floor', () async {
    const cal = KdfCalibrator();
    for (final us in [0.5, 5.0, 50.0, 500.0]) {
      final p = await cal.calibrate(
        budget: const Duration(milliseconds: 250),
        measure: _linear(usPerKib: us),
      );
      expect(p.memory, greaterThanOrEqualTo(floor.memory));
      expect(p.iterations, greaterThanOrEqualTo(floor.iterations));
    }
  });
}
