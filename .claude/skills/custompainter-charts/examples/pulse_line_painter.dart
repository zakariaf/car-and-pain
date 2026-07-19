// Car and Pain — PULSE breathing vitals hero.
//
// The signature hand-painted chart: an ECG-like seismograph that breathes on a shared 4s
// controller, with a left-to-right sweep dot. It is DECORATIVE (ExcludeSemantics) — the answer is
// spoken by a sibling Semantics node. The line stays firouzeh in EVERY state (identity, not signal);
// aggregate urgency only widens the breath amplitude (a redundant, non-colour cue) and never warms
// the colour. Not mirrored in RTL. No chart package — pure Canvas/Path/Paint.
//
// Tokens (PulseTokens, PulseMotion) come from the pulse-design-system skill.

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// One app-wide breathing controller. Share it across every hero so there is a single ticker,
/// not N. Create it once (e.g. in a Notifier or an InheritedWidget) and pass its `.view` down.
/// Reduced motion: do NOT call `repeat()`; leave it at 0.5 so `phase` resolves to a static line.
class BreathController {
  BreathController(TickerProvider vsync, {required bool reduceMotion})
      : controller = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 4000)) {
    if (!reduceMotion) controller.repeat();
  }
  final AnimationController controller;
  void dispose() => controller.dispose();
}

/// The hero widget: RepaintBoundary + ExcludeSemantics around the painter, with the semantic node
/// carried by the caller (it owns the readiness value + status label).
class PulseLineHero extends StatelessWidget {
  const PulseLineHero({
    required this.samples, // pre-computed waveform, display-ready; NOT mirrored in RTL
    required this.breath, // the shared controller's animation (0..1)
    required this.urgency, // 0..4 aggregate — widens amplitude only, never the colour
    required this.accent, // firouzeh, from PulseTokens — the hero line is ALWAYS this
    super.key,
  });

  final List<double> samples;
  final Animation<double> breath;
  final int urgency;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: breath,
          builder: (context, _) => CustomPaint(
            size: const Size.fromHeight(120), // 80 compact / first-run
            painter: PulseLinePainter(
              samples: samples,
              phase: breath.value,
              urgency: urgency,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }
}

class PulseLinePainter extends CustomPainter {
  PulseLinePainter({
    required this.samples,
    required this.phase, // 0..1 from the 4s controller (fixed 0.5 when reduced)
    required this.urgency, // 0..4 aggregate → amplitude, NOT colour
    required this.color, // firouzeh, always
  });

  final List<double> samples; // normalized -1..1 waveform, baseline at 0
  final double phase;
  final int urgency;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    // Breath scales amplitude ±6%, widened slightly by urgency. Baseline stays put so the hero
    // numeral above never jitters. The COLOUR never changes with urgency.
    final breath = 1 + 0.06 * math.sin(phase * 2 * math.pi) * (0.6 + urgency * 0.1);
    final baseline = size.height / 2;
    final dx = size.width / (samples.length - 1);

    final path = Path()..moveTo(0, baseline - samples.first * baseline * breath);
    for (var i = 1; i < samples.length; i++) {
      path.lineTo(dx * i, baseline - samples[i] * baseline * breath);
    }

    // Glow pass first, then the crisp line (round caps/joins).
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = color.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);

    // Sweep dot travels L->R across the 4s cycle. Direction-agnostic: NOT mirrored in RTL.
    final sweepX = size.width * phase;
    final sweepIdx = (phase * (samples.length - 1)).round().clamp(0, samples.length - 1);
    final sweepY = baseline - samples[sweepIdx] * baseline * breath;
    canvas.drawCircle(Offset(sweepX, sweepY), 3, Paint()..color = color);
  }

  // Compare every field — NEVER `=> true` (that repaints every frame regardless).
  @override
  bool shouldRepaint(PulseLinePainter old) =>
      old.phase != phase ||
      old.urgency != urgency ||
      old.color != color ||
      !identical(old.samples, samples);
}
