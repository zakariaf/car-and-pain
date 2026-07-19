// The spine of PULSE: `urgency` is the canonical signal; colour is derived LAST
// and is never the source of truth. Every status carries FOUR redundant channels
// (icon + label + shape + position) so it survives greyscale, CVD and both themes.
import 'package:flutter/material.dart';
// import 'pulse_theme.dart';         // PulseTokens / PulseColors
// import '<l10n>/app_localizations.dart'; // labels routed through gen-l10n

enum Urgency { calm, watch, dueSoon, pressing, overdue } // u0..u4

/// A monotonic, greyscale-legible stripe: solid for cool states, tighter dashes
/// as it warms (channel 3 — shape).
class StripeStyle {
  final List<double>? dashGap; // null = solid
  const StripeStyle.solid() : dashGap = null;
  const StripeStyle.dashed({required double dash, required double gap})
      : dashGap = const [] , // (illustrative) real impl stores [dash, gap]
        assert(true);
}

extension UrgencyToken on Urgency {
  int get u => index;

  /// Channel 0 (support only) — DECORATION. Never read status from this.
  Color color(BuildContext c) => PulseTokens.temp[index];

  /// Channel 1 — the glyph. Shape differs per status → distinguishable in grey.
  IconData get icon => const [
        Icons.favorite,       // calm — steady pulse
        Icons.visibility,     // watch
        Icons.schedule,       // due soon — clock
        Icons.warning_amber,  // pressing — triangle
        Icons.priority_high,  // overdue — filled alert
      ][index];

  /// Channel 2 — the WORD (call site passes AppLocalizations; never hardcode).
  String label(dynamic l) => switch (this) {
        Urgency.calm     => l.uCalm,      // "Healthy"
        Urgency.watch    => l.uWatch,     // "Watch"
        Urgency.dueSoon  => l.uDueSoon,   // "Due soon"
        Urgency.pressing => l.uPressing,  // "Pressing"
        Urgency.overdue  => l.uOverdue,   // "Aching" / "Overdue"
      };

  /// Channel 3 — shape/pattern; tighter dashes = hotter.
  StripeStyle get stripe => index <= 1
      ? const StripeStyle.solid()
      : StripeStyle.dashed(
          dash: const [8, 5, 3][index - 2].toDouble(),
          gap: const [6, 4, 5][index - 2].toDouble());

  /// AA-safe TEXT tone for when the status hue must carry text on a surface.
  Color textTone(PulseColors c) => switch (this) {
        Urgency.calm || Urgency.watch => c.okText,
        Urgency.dueSoon               => c.warnText,
        Urgency.pressing || Urgency.overdue => c.critText,
      };

  /// THE CAP: the aggregate halo may never exceed saffron (u2). Cards do NOT clamp.
  Urgency get haloClamped => index > 2 ? Urgency.dueSoon : this;
}

// Channel 4 — POSITION: aching items sort to the top under an "Aching now"
// header; healthy items sink to the bottom. Sort order IS a redundant signal.
List<T> sortByUrgency<T>(List<T> items, Urgency Function(T) of) =>
    [...items]..sort((a, b) => of(b).u.compareTo(of(a).u));
