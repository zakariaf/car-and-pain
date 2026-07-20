import 'package:flutter/material.dart';

import 'pulse_tokens.dart';

/// The single emotional-temperature scale (u0..u4). `index` is the ordered
/// severity. Colour is decoration; the redundant channels (stripe/icon/label/
/// position) carry the meaning.
enum Urgency { calm, scheduled, soon, pressing, overdue }

/// The redundant, colour-blind-safe left-stripe shape: solid for calm states,
/// then tightening dashes as it warms (severity legible without hue).
@immutable
class StripeStyle {
  const StripeStyle.solid()
      : dash = null,
        gap = null;
  const StripeStyle.dashed({required this.dash, required this.gap});

  final double? dash;
  final double? gap;

  bool get isSolid => dash == null;

  @override
  bool operator ==(Object other) =>
      other is StripeStyle && other.dash == dash && other.gap == gap;

  @override
  int get hashCode => Object.hash(dash, gap);
}

/// The full non-colour encoding bundle for an urgency level.
@immutable
class UrgencyStyle {
  const UrgencyStyle({
    required this.urgency,
    required this.color,
    required this.stripe,
    required this.icon,
    required this.labelKey,
  });

  final Urgency urgency;

  /// Decoration only — never the sole signal.
  final Color color;

  /// Shape channel (solid → tightening dashes).
  final StripeStyle stripe;

  /// Icon shape channel (distinct glyph per level).
  final IconData icon;

  /// A localization KEY (the library never hardcodes user-facing strings).
  final String labelKey;
}

extension UrgencyX on Urgency {
  /// Ordered severity (0..4).
  int get severity => index;

  /// The aggregate halo NEVER exceeds saffron (u2) — the capped-aggregate
  /// guardrail, regardless of how many u3/u4 cards exist.
  Urgency get haloClamped => index > Urgency.soon.index ? Urgency.soon : this;

  /// The redundant stripe shape for this level.
  StripeStyle get stripe => index <= Urgency.scheduled.index
      ? const StripeStyle.solid()
      : StripeStyle.dashed(
          dash: const [8.0, 5.0, 3.0][index - 2],
          gap: const [6.0, 4.0, 5.0][index - 2],
        );

  /// The distinct icon (greyscale-legible shape) for this level.
  IconData get icon => const [
        Icons.check_circle_outline, // u0 calm
        Icons.event_available_outlined, // u1 scheduled
        Icons.schedule, // u2 soon
        Icons.warning_amber_rounded, // u3 pressing
        Icons.priority_high, // u4 overdue
      ][index];

  /// The l10n key for this level's label.
  String get labelKey => const [
        'urgency.calm',
        'urgency.scheduled',
        'urgency.soon',
        'urgency.pressing',
        'urgency.overdue',
      ][index];
}

/// Resolve the full encoding bundle for [urgency] in a theme [brightness].
/// The temperature ramp is shared across themes (hues hold on paper and ink);
/// [brightness] is accepted so night-tuned variants can be added without an API
/// change.
UrgencyStyle resolveUrgency(Urgency urgency, Brightness brightness) =>
    UrgencyStyle(
      urgency: urgency,
      color: PulseTokens.temp[urgency.index],
      stripe: urgency.stripe,
      icon: urgency.icon,
      labelKey: urgency.labelKey,
    );

/// The clamped aggregate halo colour for a set of open urgencies — never hotter
/// than saffron (u2). Feeds the always-on ambient halo.
Urgency aggregateHalo(Iterable<Urgency> open) {
  var worst = Urgency.calm;
  for (final u in open) {
    if (u.index > worst.index) worst = u;
  }
  return worst.haloClamped;
}
