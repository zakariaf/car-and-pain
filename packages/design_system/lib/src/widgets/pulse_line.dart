import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/pulse_motion.dart';
import '../theme/pulse_tokens.dart';
import '../theme/urgency.dart';
import '../util/reduced_motion.dart';

/// The breathing ECG-like pulse-line painter (F3-T3). Direction-agnostic — the
/// waveform is symmetric and NOT mirrored in RTL. The line is identity (stays
/// cool); aggregate urgency modulates breath *amplitude* — a redundant,
/// non-colour urgency cue. Paint objects are static (no per-frame allocation).
class PulseLinePainter extends CustomPainter {
  PulseLinePainter({
    required this.phase,
    required this.urgency,
    required this.color,
  });

  /// 0..1 from the 4s controller (fixed when reduced-motion).
  final double phase;

  /// 0..4 aggregate → amplitude (not just colour).
  final int urgency;
  final Color color;

  static final Paint _glow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  static final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final breath =
        1 + 0.06 * math.sin(phase * 2 * math.pi) * (0.6 + urgency * 0.1);
    final mid = size.height / 2;
    const samples = 48;
    final amp = size.height * 0.32 * breath;
    final path = Path()..moveTo(0, mid);
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final x = t * size.width;
      final wave =
          math.sin(t * math.pi * 6) * 0.28 + math.sin(t * math.pi * 2) * 0.12;
      final spike = (i % 12 == 6) ? 0.7 : 0.0;
      path.lineTo(x, mid - (wave + spike) * amp);
    }
    canvas
      ..drawPath(path, _glow..color = color.withValues(alpha: 0.4))
      ..drawPath(path, _line..color = color);
  }

  @override
  bool shouldRepaint(PulseLinePainter old) =>
      old.phase != phase || old.urgency != urgency || old.color != color;
}

/// The single breathing vital. Wraps the painter in a `RepaintBoundary`, drives
/// it from one controller, and falls back to a **static** frame under
/// reduced-motion (same conveyed state). The waveform is decorative
/// (`ExcludeSemantics`); [semanticsLabel] carries the textual state.
class VitalHero extends StatefulWidget {
  const VitalHero({
    required this.semanticsLabel,
    this.aggregate = Urgency.calm,
    this.height = 120,
    super.key,
  });

  final String semanticsLabel;
  final Urgency aggregate;
  final double height;

  @override
  State<VitalHero> createState() => _VitalHeroState();
}

class _VitalHeroState extends State<VitalHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: PulseMotion.breathe);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller
        ..stop()
        ..value = 0.25; // resting amplitude
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The line stays cool (identity, not signal); mood lives in the halo.
    final accent = PulseTokens.temp[Urgency.calm.index];
    return Semantics(
      label: widget.semanticsLabel,
      liveRegion: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: widget.height,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(
                size: Size.infinite,
                painter: PulseLinePainter(
                  phase: _controller.value,
                  urgency: widget.aggregate.haloClamped.index,
                  color: accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The always-on ambient halo — an inset edge glow **capped at saffron (u2)**.
/// Fed by [aggregateHalo]; never renders hotter than the calm ceiling.
class AmbientHalo extends StatelessWidget {
  const AmbientHalo({required this.open, required this.child, super.key});

  /// The set of open item urgencies; the halo uses their clamped aggregate.
  final Iterable<Urgency> open;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final haloColor = PulseTokens.temp[aggregateHalo(open).index];
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _HaloPainter(haloColor)),
          ),
        ),
        child,
      ],
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 1.1,
        colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.color != color;
}
