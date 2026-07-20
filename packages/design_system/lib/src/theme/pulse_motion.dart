import 'package:flutter/animation.dart';

/// PULSE has exactly four authored motions (+ haptics). Durations/curves are
/// tokens — reference them, never inline a magic number.
/// See docs/design/pulse/04-motion-rtl-accessibility.md §1.
abstract final class PulseMotion {
  // ── Durations ─────────────────────────────────────────────────────────
  static const Duration breathe = Duration(milliseconds: 4000);
  static const Duration exhale = Duration(milliseconds: 420);
  static const Duration cool = Duration(milliseconds: 520);
  static const Duration countUp = Duration(milliseconds: 600);
  static const Duration room = Duration(milliseconds: 320);
  static const Duration halo = Duration(milliseconds: 600);

  // ── Curves ────────────────────────────────────────────────────────────
  static const Cubic breatheEase = Cubic(0.37, 0, 0.63, 1); // symmetric
  static const Cubic exhaleEase = Cubic(0.2, 0.7, 0.2, 1); // decel, soft
  static const Cubic coolEase = Cubic(0.4, 0, 0.2, 1);
  static const Cubic countUpEase = Cubic(0, 0, 0.2, 1); // ease-out
  static const Cubic roomEase = Cubic(0.2, 0, 0, 1); // emphasized decelerate
}
