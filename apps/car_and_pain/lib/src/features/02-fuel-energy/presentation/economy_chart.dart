import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// One plotted economy point: an already-projected display value (e.g. L/100km)
/// with a pre-formatted label for the accessibility summary.
class EconomyPoint {
  const EconomyPoint({required this.value, required this.label});
  final double value;
  final String label;
}

/// A built-in-first economy trend chart (M3-T5) — a CustomPainter line with an
/// area fill and an emphasized endpoint, no chart library. It mirrors under RTL
/// (the time axis inverts so the trend still reads oldest→newest), honours
/// reduced motion (static — there is no entry animation), and is wrapped in
/// [Semantics] exposing a readable summary + per-point values.
class EconomyChart extends StatelessWidget {
  const EconomyChart({
    required this.points,
    required this.semanticsSummary,
    this.height = 160,
    super.key,
  });

  final List<EconomyPoint> points;
  final String semanticsSummary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pc = Theme.of(context).extension<PulseColorsExt>()!.c;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      label: semanticsSummary,
      // The per-point values are announced through the summary; the painted
      // line is decorative to the a11y tree.
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _EconomyPainter(
              points: points,
              line: Theme.of(context).colorScheme.primary,
              fill:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              grid: pc.hairline,
              rtl: rtl,
            ),
          ),
        ),
      ),
    );
  }
}

class _EconomyPainter extends CustomPainter {
  _EconomyPainter({
    required this.points,
    required this.line,
    required this.fill,
    required this.grid,
    required this.rtl,
  });

  final List<EconomyPoint> points;
  final Color line;
  final Color fill;
  final Color grid;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final values = points.map((p) => p.value).toList();
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;

    // A faint baseline grid (3 lines).
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset at(int i) {
      final t = points.length == 1 ? 0.5 : i / (points.length - 1);
      final x = rtl ? size.width * (1 - t) : size.width * t; // invert for RTL
      final norm = (values[i] - minV) / span;
      final y = size.height - norm * size.height * 0.9 - size.height * 0.05;
      return Offset(x, y);
    }

    final path = Path();
    final area = Path();
    for (var i = 0; i < points.length; i++) {
      final p = at(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
        area
          ..moveTo(p.dx, size.height)
          ..lineTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
        area.lineTo(p.dx, p.dy);
      }
    }
    area
      ..lineTo(at(points.length - 1).dx, size.height)
      ..close();

    canvas
      ..drawPath(area, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      )
      // Emphasized latest endpoint (the newest interval).
      ..drawCircle(at(points.length - 1), 4, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_EconomyPainter old) =>
      old.points != points || old.rtl != rtl;
}
