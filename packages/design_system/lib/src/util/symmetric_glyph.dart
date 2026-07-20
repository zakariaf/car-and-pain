import 'package:flutter/widgets.dart';

/// Force [child] to render LTR so **symmetric glyphs** — the pulse-line, halo,
/// checkmark and logo — do NOT mirror under RTL (an ECG has no handedness). Only
/// the glyph geometry is pinned; the widget's *placement* still follows
/// directionality. Everything directional (chevrons, trend arrows) must NOT use
/// this. See docs/design/pulse/04-motion-rtl-accessibility.md §2.2.
Widget nonMirrored(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);
