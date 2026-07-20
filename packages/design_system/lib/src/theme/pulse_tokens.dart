import 'package:flutter/material.dart';

/// Immutable, theme-agnostic raw PULSE values. UI reads THESE, never hex
/// literals. See docs/design/pulse/01-tokens.md — this is the single source of
/// truth for colour/space/radius/motion.
abstract final class PulseTokens {
  // ── Emotional-temperature ramp (urgency 0..4), shared across themes ──────
  static const List<Color> temp = [
    Color(0xFF2FB8A8), // u0 firouzeh — calm/healthy
    Color(0xFF7FBF6A), // u1 pistachio — watch
    Color(0xFFE9A43B), // u2 saffron   — due soon  (HALO CAP)
    Color(0xFFE8703A), // u3 ember     — due/overdue
    Color(0xFFD64533), // u4 pomegranate — aching (card only)
  ];

  /// The aggregate ambient halo may never exceed u2 (saffron).
  static const int haloMaxUrgency = 2;

  /// Halo colour for an aggregate urgency, clamped to the cap.
  static Color halo(int aggregateUrgency) =>
      temp[aggregateUrgency.clamp(0, haloMaxUrgency)];

  /// Card wash colour for a single item's urgency (up to u4).
  static Color card(int urgency) => temp[urgency.clamp(0, 4)];

  // ── Vehicle accent palette (identity only, NEVER status) ────────────────
  static const List<Color> vehicleAccents = [
    Color(0xFF2FB8A8),
    Color(0xFF3E6BE8),
    Color(0xFFE9A43B),
    Color(0xFFB65CC4),
    Color(0xFF7FBF6A),
  ];

  // ── Radii ───────────────────────────────────────────────────────────────
  static const double rCard = 20;
  static const double rSheet = 26;
  static const double rPill = 999;
  static const double rIconTile = 12;
  static const double rSmall = 16;

  // ── Spacing (8px grid; 4 = half step) ───────────────────────────────────
  static const double s0 = 0;
  static const double sHalf = 4;
  static const double s1 = 8;
  static const double s2 = 16;
  static const double s3 = 24;
  static const double s4 = 32;
  static const double s5 = 40;
  static const double s6 = 56;

  // ── Tap targets (accessibility floor) ───────────────────────────────────
  static const double tapMin = 44;
  static const double quickAdd = 56;
  static const double roomNav = 48;

  // ── Motion ──────────────────────────────────────────────────────────────
  static const Duration breath = Duration(milliseconds: 4000);
  static const Duration exhale = Duration(milliseconds: 800);
  static const Duration count = Duration(milliseconds: 600);
  static const Duration sheet = Duration(milliseconds: 380);
  static const Duration fast = Duration(milliseconds: 200);
  static const Cubic easeExhale = Cubic(0.2, 0.7, 0.2, 1);
  static const Cubic easeStd = Cubic(0.2, 0, 0.2, 1);

  // ── Grain opacity (kills OLED banding on ambient tints) ─────────────────
  static const double grainDay = .05;
  static const double grainNight = .06;
}

/// Per-theme neutrals + AA-safe semantic text tones, resolved by brightness.
/// These extended neutrals can't all live on a [ColorScheme], so they ride the
/// widget tree via [PulseColorsExt].
// ignore: use_enums — a 12-field colour container, not enum-appropriate.
class PulseColors {
  const PulseColors._({
    required this.base,
    required this.surface,
    required this.surface2,
    required this.hairline,
    required this.hairlineStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accentInk,
    required this.okText,
    required this.warnText,
    required this.critText,
  });

  final Color base;
  final Color surface;
  final Color surface2;
  final Color hairline;
  final Color hairlineStrong;
  final Color text;
  final Color text2;
  final Color text3;

  /// Ink-safe accent for strokes/labels.
  final Color accentInk;

  /// AA-safe semantic text tones (foreground on surface/surface-2).
  final Color okText;
  final Color warnText;
  final Color critText;

  /// DAY — warm paper.
  static const PulseColors light = PulseColors._(
    base: Color(0xFFF4EFE7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFBF8F2),
    hairline: Color(0xFFE4DCD0),
    hairlineStrong: Color(0xFFD6CBBB),
    text: Color(0xFF1B242E),
    text2: Color(0xFF5E6B74),
    text3: Color(0xFF8A949B),
    accentInk: Color(0xFF1F8F82),
    okText: Color(0xFF1F8F82),
    warnText: Color(0xFF9A6B12),
    critText: Color(0xFFA5352A),
  );

  /// NIGHT — ink (hand-tuned on the ink surface, never auto-flipped).
  static const PulseColors dark = PulseColors._(
    base: Color(0xFF0E1317),
    surface: Color(0xFF141A20),
    surface2: Color(0xFF182027),
    hairline: Color(0xFF222A32),
    hairlineStrong: Color(0xFF2E3841),
    text: Color(0xFFECF1F3),
    text2: Color(0xFF98A4AD),
    text3: Color(0xFF6E7A83),
    accentInk: Color(0xFF3ED6C4),
    okText: Color(0xFF3ED6C4),
    warnText: Color(0xFFF0BD6A),
    critText: Color(0xFFF08A7C),
  );
}

/// Exposes the extended neutrals to the widget tree:
/// `Theme.of(context).extension<PulseColorsExt>()!.c`.
@immutable
class PulseColorsExt extends ThemeExtension<PulseColorsExt> {
  const PulseColorsExt(this.c);

  final PulseColors c;

  @override
  PulseColorsExt copyWith({PulseColors? c}) => PulseColorsExt(c ?? this.c);

  // Snap on theme switch (no cross-fade of neutrals).
  @override
  PulseColorsExt lerp(ThemeExtension<PulseColorsExt>? other, double t) => this;
}
