import 'package:flutter/material.dart';

import 'pulse_tokens.dart';

/// PULSE light `ColorScheme` (warm paper). Extended neutrals live in
/// [PulseColorsExt]; this holds the Material-required roles only.
const ColorScheme pulseLightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF1F8F82), // accent-ink (AA on paper)
  onPrimary: Color(0xFF04241F),
  secondary: Color(0xFFE9A43B), // saffron
  onSecondary: Color(0xFF2A1C00),
  error: Color(0xFFA5352A), // crit text-safe
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF1B242E),
);

/// PULSE dark `ColorScheme` (ink).
const ColorScheme pulseDarkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF3ED6C4),
  onPrimary: Color(0xFF04241F),
  secondary: Color(0xFFE9A43B),
  onSecondary: Color(0xFF2A1C00),
  error: Color(0xFFF08A7C),
  onError: Color(0xFF2A0B07),
  surface: Color(0xFF141A20),
  onSurface: Color(0xFFECF1F3),
);

/// Builds the PULSE type scale. `tabular` figures are on for numeric styles so
/// digits never jitter on count-up and stay column-aligned.
/// TODO(F4): set fontFamily (Hanken Grotesk / Vazirmatn) once fonts are bundled
/// and add the fa/ar/ckb +2 line-height + numeral overrides.
TextTheme buildPulseTextTheme(Color onSurface, Color onSurface2) {
  const tab = [FontFeature.tabularFigures()];
  return TextTheme(
    // hero-numeral 84/88
    displayLarge: TextStyle(
      fontSize: 84,
      height: 88 / 84,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.04 * 84,
      fontFeatures: tab,
      color: onSurface,
    ),
    // display 30/38
    displayMedium: TextStyle(
      fontSize: 30,
      height: 38 / 30,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.02 * 30,
      color: onSurface,
    ),
    // title 20/28
    titleLarge: TextStyle(
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.01 * 20,
      color: onSurface,
    ),
    // body 16/26
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 26 / 16,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    // label 13/20
    labelLarge: TextStyle(
      fontSize: 13,
      height: 20 / 13,
      fontWeight: FontWeight.w600,
      color: onSurface2,
    ),
    // caption 12/18
    bodySmall: TextStyle(
      fontSize: 12,
      height: 18 / 12,
      fontWeight: FontWeight.w500,
      color: onSurface2,
    ),
  );
}

/// Assemble the full PULSE [ThemeData] for a [brightness].
ThemeData pulseTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final cs = isDark ? pulseDarkScheme : pulseLightScheme;
  final pc = isDark ? PulseColors.dark : PulseColors.light;
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: pc.base,
    textTheme: buildPulseTextTheme(pc.text, pc.text2),
    extensions: [PulseColorsExt(pc)],
    // Calm: the exhale is our feedback, not ripples.
    splashFactory: NoSplash.splashFactory,
    // TODO(F3): add the PULSE page-transition builders + motion tokens.
  );
}

/// The light PULSE theme.
ThemeData get pulseLightTheme => pulseTheme(Brightness.light);

/// The dark PULSE theme.
ThemeData get pulseDarkTheme => pulseTheme(Brightness.dark);
