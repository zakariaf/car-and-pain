import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/pulse_motion.dart';
import '../theme/pulse_tokens.dart';
import '../theme/urgency.dart';

/// The scoped-temperature card. Carries **concentrated** warmth (the ache sits
/// here) via three redundant channels beyond colour: the left **stripe shape**
/// (solid → tightening dashes), the status the caller shows in [child]
/// (icon+label pill), and **position** (aching cards sort to the top). A `null`
/// [urgency] renders a plain calm surface. RTL-safe (stripe rides the start
/// edge, corner tint mirrors).
class PulseCard extends StatelessWidget {
  const PulseCard({
    required this.child,
    this.urgency,
    this.semanticsLabel,
    super.key,
  });

  final Widget child;
  final Urgency? urgency;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final pc = Theme.of(context).extension<PulseColorsExt>()!.c;
    final u = urgency;
    final tint = u == null ? null : PulseTokens.temp[u.index];

    final card = AnimatedContainer(
      duration: PulseMotion.cool,
      curve: PulseMotion.coolEase,
      decoration: BoxDecoration(
        color: pc.surface,
        borderRadius: BorderRadius.circular(PulseTokens.rCard),
        border: Border.all(
          color: tint == null ? pc.hairline : tint.withValues(alpha: 0.5),
        ),
      ),
      child: Stack(
        children: [
          if (u != null && u.index >= Urgency.soon.index)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _CornerTintPainter(tint!)),
              ),
            ),
          if (u != null)
            PositionedDirectional(
              start: 0,
              top: 14,
              bottom: 14,
              width: 4,
              child: CustomPaint(
                painter: UStripePainter(style: u.stripe, color: tint!),
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 16),
            child: child,
          ),
        ],
      ),
    );

    if (semanticsLabel == null) return card;
    return Semantics(container: true, label: semanticsLabel, child: card);
  }
}

/// Paints the redundant urgency stripe: a solid bar for calm states, then
/// tightening dashes as it warms — severity legible in shape alone.
class UStripePainter extends CustomPainter {
  UStripePainter({required this.style, required this.color});

  final StripeStyle style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    if (style.isSolid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      return;
    }
    final dash = style.dash!;
    final gap = style.gap!;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + dash, size.height)),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(UStripePainter old) =>
      old.style != style || old.color != color;
}

class _CornerTintPainter extends CustomPainter {
  _CornerTintPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        center: AlignmentDirectional.topStart.resolve(TextDirection.ltr),
        radius: 0.9,
        colors: [color.withValues(alpha: 0.14), color.withValues(alpha: 0)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_CornerTintPainter old) => old.color != color;
}
