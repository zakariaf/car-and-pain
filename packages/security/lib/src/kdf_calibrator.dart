import 'key_envelope.dart';

/// Picks Argon2id parameters for *this device* (F7-T2): scale the KDF up until a
/// derive costs about as long as the owner will tolerate at unlock — strong on
/// a fast phone, still bounded on a weak one — but **never below the security
/// `Argon2idParams.floor`**. Responsiveness may bend; the floor never does.
///
/// The search is pure over a `measure` oracle (the app passes a real native
/// Argon2id timing; tests pass a synthetic cost), so the algorithm is unit-
/// tested without touching a KDF. Only `memory` is scaled — the cheapest,
/// most linear cost knob — with iterations/parallelism held at the floor.
final class KdfCalibrator {
  const KdfCalibrator({
    this.floor = Argon2idParams.floor,
    this.maxMemory = 262144, // 256 MiB — guard low-RAM devices from OOM
    this.toleranceKib = 1024,
  });

  /// The hard minimum; calibration never returns anything weaker.
  final Argon2idParams floor;

  /// Upper bound on memory (KiB) regardless of speed — an OOM guard.
  final int maxMemory;

  /// Stop the binary search once the bracket is this narrow (KiB).
  final int toleranceKib;

  /// Return the strongest params whose measured derive-time is within [budget],
  /// clamped to `[floor, maxMemory]`. If even the floor is slower than [budget],
  /// the floor still wins — security outranks the time target.
  Future<Argon2idParams> calibrate({
    required Duration budget,
    required Future<Duration> Function(Argon2idParams) measure,
  }) async {
    final floorTime = await measure(floor);
    // Floor is the hard minimum: if it already exceeds the budget we keep it.
    if (floorTime >= budget) return floor;

    // Exponential probe upward to bracket the budget.
    var lo = floor.memory; // known within budget
    var probe = floor.memory * 2;
    var hi = -1; // first memory known to exceed budget
    while (probe <= maxMemory) {
      final t = await measure(floor.copyWith(memory: probe));
      if (t <= budget) {
        lo = probe;
        probe *= 2;
      } else {
        hi = probe;
        break;
      }
    }
    // Doubling never bracketed the budget within the cap. The cap itself may
    // still fit — if so it's the answer; otherwise search up to it.
    if (hi < 0) {
      final capped = floor.copyWith(memory: maxMemory);
      if (await measure(capped) <= budget) return capped;
      hi = maxMemory;
    }

    // Binary-search the largest memory still within budget.
    while (hi - lo > toleranceKib) {
      final mid = lo + (hi - lo) ~/ 2;
      final t = await measure(floor.copyWith(memory: mid));
      if (t <= budget) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return floor.copyWith(memory: lo);
  }
}
