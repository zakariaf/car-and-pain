// PULSE token bridge — the single source of truth for colour/type/space/radius/
// motion. UI reads THESE, never hex/dp/ms literals. Lives in
// packages/design_system/lib/src/. Illustrative — trim imports to your package.
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

/// Immutable, theme-agnostic raw values.
abstract final class PulseTokens {
  // ---- Temperature ramp (urgency 0..4), shared across themes ----
  static const List<Color> temp = [
    Color(0xFF2FB8A8), // u0 firouzeh    — calm/healthy
    Color(0xFF7FBF6A), // u1 pistachio   — watch/scheduled
    Color(0xFFE9A43B), // u2 saffron     — due soon (HALO CAP)
    Color(0xFFE8703A), // u3 ember       — pressing (card only)
    Color(0xFFD64533), // u4 pomegranate — aching (the ONE card only)
  ];

  /// The aggregate halo may NEVER exceed u2. Cards do not clamp.
  static const int haloMaxUrgency = 2;
  static Color halo(int aggregateUrgency) =>
      temp[aggregateUrgency.clamp(0, haloMaxUrgency)];
  static Color card(int urgency) => temp[urgency.clamp(0, 4)];

  // ---- Vehicle accent palette (IDENTITY only, never status) ----
  static const List<Color> vehicleAccents = [
    Color(0xFF2FB8A8), Color(0xFF3E6BE8), Color(0xFFE9A43B),
    Color(0xFFB65CC4), Color(0xFF7FBF6A),
  ];

  // ---- Radii / spacing (8px grid, 4 = half) / tap targets ----
  static const double rCard = 20, rSheet = 26, rPill = 999, rIconTile = 12, rSmall = 16;
  static const double s0 = 0, sHalf = 4, s1 = 8, s2 = 16, s3 = 24, s4 = 32, s5 = 40, s6 = 56;
  static const double tapMin = 44, quickAdd = 56, roomNav = 48;

  // ---- Motion (durations + house curves) ----
  static const Duration breathe = Duration(milliseconds: 4000);
  static const Duration exhaleSettle = Duration(milliseconds: 420);
  static const Duration cool = Duration(milliseconds: 520);
  static const Duration countUp = Duration(milliseconds: 600);
  static const Duration room = Duration(milliseconds: 320);
  static const Duration halo_ = Duration(milliseconds: 600);
  static const Duration sheet = Duration(milliseconds: 380);
  static const Duration fast = Duration(milliseconds: 200);
  static const Cubic breatheEase = Cubic(0.37, 0.0, 0.63, 1.0);
  static const Cubic exhaleEase = Cubic(0.2, 0.7, 0.2, 1.0);
  static const Cubic coolEase = Cubic(0.4, 0.0, 0.2, 1.0);
  static const Cubic countUpEase = Cubic(0.0, 0.0, 0.2, 1.0);
  static const Cubic roomEase = Cubic(0.2, 0.0, 0.0, 1.0);

  static const double grainDay = .05, grainNight = .06;

  /// Read per-theme neutrals + semantic text tones from the widget tree.
  static PulseColors of(BuildContext c) =>
      Theme.of(c).extension<PulseColorsExt>()!.c;
}

/// Per-theme neutrals + AA-safe semantic TEXT tones. Night is hand-tuned on ink.
class PulseColors {
  final Color base, surface, surface2, hairline, hairlineStrong, text, text2, text3;
  final Color accentInk;                    // ink-safe accent for strokes/labels
  final Color okText, warnText, critText;   // AA-safe when a hue carries TEXT
  const PulseColors._({
    required this.base, required this.surface, required this.surface2,
    required this.hairline, required this.hairlineStrong,
    required this.text, required this.text2, required this.text3,
    required this.accentInk,
    required this.okText, required this.warnText, required this.critText,
  });

  List<Color> get temperature => PulseTokens.temp;

  static const day = PulseColors._(
    base: Color(0xFFF4EFE7), surface: Color(0xFFFFFFFF), surface2: Color(0xFFFBF8F2),
    hairline: Color(0xFFE4DCD0), hairlineStrong: Color(0xFFD6CBBB),
    text: Color(0xFF1B242E), text2: Color(0xFF5E6B74), text3: Color(0xFF8A949B),
    accentInk: Color(0xFF1F8F82),
    okText: Color(0xFF1F8F82), warnText: Color(0xFF9A6B12), critText: Color(0xFFA5352A),
  );
  static const night = PulseColors._(
    base: Color(0xFF0E1317), surface: Color(0xFF141A20), surface2: Color(0xFF182027),
    hairline: Color(0xFF222A32), hairlineStrong: Color(0xFF2E3841),
    text: Color(0xFFECF1F3), text2: Color(0xFF98A4AD), text3: Color(0xFF6E7A83),
    accentInk: Color(0xFF3ED6C4),
    okText: Color(0xFF3ED6C4), warnText: Color(0xFFF0BD6A), critText: Color(0xFFF08A7C),
  );
}

/// ColorScheme cannot hold all neutrals → expose them via a ThemeExtension.
@immutable
class PulseColorsExt extends ThemeExtension<PulseColorsExt> {
  final PulseColors c;
  const PulseColorsExt(this.c);
  @override
  PulseColorsExt copyWith({PulseColors? c}) => PulseColorsExt(c ?? this.c);
  @override
  PulseColorsExt lerp(ThemeExtension<PulseColorsExt>? o, double t) => this; // snap
}

// ---- Hand-built ColorSchemes (night NOT auto-flipped) ----
const ColorScheme pulseLightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF1F8F82), onPrimary: Color(0xFF04241F),
  secondary: Color(0xFFE9A43B), onSecondary: Color(0xFF2A1C00),
  error: Color(0xFFA5352A), onError: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF), onSurface: Color(0xFF1B242E),
);
const ColorScheme pulseDarkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF3ED6C4), onPrimary: Color(0xFF04241F),
  secondary: Color(0xFFE9A43B), onSecondary: Color(0xFF2A1C00),
  error: Color(0xFFF08A7C), onError: Color(0xFF2A0B07),
  surface: Color(0xFF141A20), onSurface: Color(0xFFECF1F3),
);

// ---- TextTheme: every numeral is tabular; height = lineHeightPx / sizePx ----
const _latin = 'HankenGrotesk';
TextTheme buildPulseTextTheme(Color onSurface, Color onSurface2) {
  const tab = [FontFeature.tabularFigures()];
  return TextTheme(
    displayLarge: TextStyle(fontFamily: _latin, fontSize: 84, height: 88 / 84,
        fontWeight: FontWeight.w600, letterSpacing: -0.04 * 84, fontFeatures: tab,
        color: onSurface), // hero — reflows to 60/64 in the hero widget
    displayMedium: TextStyle(fontFamily: _latin, fontSize: 30, height: 38 / 30,
        fontWeight: FontWeight.w600, letterSpacing: -0.02 * 30, color: onSurface),
    titleLarge: TextStyle(fontFamily: _latin, fontSize: 20, height: 28 / 20,
        fontWeight: FontWeight.w600, letterSpacing: -0.01 * 20, color: onSurface),
    bodyLarge: TextStyle(fontFamily: _latin, fontSize: 16, height: 26 / 16,
        fontWeight: FontWeight.w400, color: onSurface), // fa/ar/ckb → +2 lh override
    labelLarge: TextStyle(fontFamily: _latin, fontSize: 13, height: 20 / 13,
        fontWeight: FontWeight.w600, color: onSurface2),
    bodySmall: TextStyle(fontFamily: _latin, fontSize: 12, height: 18 / 12,
        fontWeight: FontWeight.w500, color: onSurface2),
  );
}

/// Assemble ThemeData. Theme switching via a Riverpod ThemeMode provider.
ThemeData pulseTheme(Brightness b) {
  final cs = b == Brightness.dark ? pulseDarkScheme : pulseLightScheme;
  final pc = b == Brightness.dark ? PulseColors.night : PulseColors.day;
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: pc.base,
    textTheme: buildPulseTextTheme(pc.text, pc.text2),
    extensions: [PulseColorsExt(pc)],
    splashFactory: NoSplash.splashFactory, // the exhale is the feedback, not ripples
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    }),
  );
}
