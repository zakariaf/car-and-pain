import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/pulse_tokens.dart';

/// The firouzeh sequential ramp for chart *data*. Status hues
/// (saffron/ember/pomegranate) are reserved and never a data series.
const List<Color> pulseChartRamp = [
  Color(0xFF7FD4C8),
  Color(0xFF2FB8A8),
  Color(0xFF1F8F82),
];

/// A line/sparkline painter (F3-T7). No chart library. Baseline axis + polyline
/// + a labelled end dot; value-gated `shouldRepaint`, no per-frame allocation of
/// the geometry beyond the path.
class LineChartPainter extends CustomPainter {
  LineChartPainter({
    required this.series,
    required this.color,
    required this.hairline,
  });

  final List<double> series;
  final Color color;
  final Color hairline;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final maxV = series.reduce(math.max);
    final minV = series.reduce(math.min);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;

    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = hairline
        ..strokeWidth = 1,
    );

    double xOf(int i) =>
        series.length == 1 ? 0 : i / (series.length - 1) * size.width;
    double yOf(double v) =>
        size.height -
        ((v - minV) / range) * size.height * 0.86 -
        size.height * 0.07;

    final path = Path()..moveTo(xOf(0), yOf(series.first));
    for (var i = 1; i < series.length; i++) {
      path.lineTo(xOf(i), yOf(series[i]));
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      )
      ..drawCircle(
        Offset(xOf(series.length - 1) - 1, yOf(series.last)),
        4.5,
        Paint()..color = color,
      );
  }

  @override
  bool shouldRepaint(LineChartPainter old) =>
      old.series != series || old.color != color || old.hairline != hairline;
}

/// Ranked horizontal bars (F3-T7). The highlighted bar gets a **hatch** overlay
/// — the redundant, non-colour cue that survives greyscale.
class BarChartPainter extends CustomPainter {
  BarChartPainter({
    required this.values,
    required this.track,
    required this.highlightIndex,
    required this.textDirection,
  });

  final List<double> values;
  final Color track;
  final int highlightIndex;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce(math.max);
    final n = values.length;
    const barH = 12.0;
    final gap = n <= 1 ? 0.0 : (size.height - n * barH) / (n - 1);
    final rtl = textDirection == TextDirection.rtl;

    for (var i = 0; i < n; i++) {
      final y = i * (barH + gap);
      final trackRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, y, size.width, barH),
        const Radius.circular(6),
      );
      canvas.drawRRect(trackRect, Paint()..color = track);

      // Clamp: a negative value must never produce a negative-width Rect
      // (rendering anomaly / crash on some backends).
      final w =
          maxV <= 0 ? 0.0 : math.max<double>(0, values[i]) / maxV * size.width;
      // Fill grows from the start edge — right-to-left in RTL locales.
      final left = rtl ? size.width - w : 0.0;
      final fillRect = Rect.fromLTWH(left, y, w, barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, const Radius.circular(6)),
        Paint()..color = pulseChartRamp[i % pulseChartRamp.length],
      );
      if (i == highlightIndex && w > 0) {
        _drawHatch(canvas, fillRect);
      }
    }
  }

  void _drawHatch(Canvas canvas, Rect r) {
    final paint = Paint()
      ..color = const Color(0x59FFFFFF)
      ..strokeWidth = 1.5;
    canvas
      ..save()
      ..clipRect(r);
    for (var x = -r.height; x < r.width + r.height; x += 6) {
      canvas.drawLine(
        Offset(r.left + x, r.top + r.height),
        Offset(r.left + x + r.height, r.top),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BarChartPainter old) =>
      old.values != values ||
      old.highlightIndex != highlightIndex ||
      old.textDirection != textDirection;
}

/// A line chart with a `Semantics` textual summary (never colour-only). The
/// painter is decorative; [semanticsSummary] carries the trend in words.
class PulseLineChart extends StatelessWidget {
  const PulseLineChart({
    required this.series,
    required this.semanticsSummary,
    this.height = 80,
    super.key,
  });

  final List<double> series;
  final String semanticsSummary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pc = Theme.of(context).extension<PulseColorsExt>()!.c;
    return Semantics(
      label: semanticsSummary,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.fromHeight(height),
            painter: LineChartPainter(
              series: series,
              color: PulseTokens.temp[0],
              hairline: pc.hairline,
            ),
          ),
        ),
      ),
    );
  }
}

/// A ranked bar chart with a `Semantics` summary and a hatched largest bar.
class PulseBarChart extends StatelessWidget {
  const PulseBarChart({
    required this.values,
    required this.semanticsSummary,
    this.height = 120,
    super.key,
  });

  final List<double> values;
  final String semanticsSummary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pc = Theme.of(context).extension<PulseColorsExt>()!.c;
    var highlight = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[highlight]) highlight = i;
    }
    return Semantics(
      label: semanticsSummary,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.fromHeight(height),
            painter: BarChartPainter(
              values: values,
              track: pc.surface2,
              highlightIndex: highlight,
              textDirection: Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }
}
