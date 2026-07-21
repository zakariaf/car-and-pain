import 'package:flutter/material.dart';

import 'pulse_tokens.dart';

/// Bundled OFL font families (F4-T6), referenced by their package-qualified
/// names. Latin runs render in Hanken Grotesk; Arabic-script codepoints
/// (fa/ar/ckb) that Hanken lacks fall back per-glyph to Vazirmatn, which also
/// carries Persian/Sorani letterforms and Eastern-Arabic/Persian digits.
const pulseLatinFont = 'packages/design_system/HankenGrotesk';
const pulseArabicFont = 'packages/design_system/Vazirmatn';

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
/// digits never jitter on count-up and stay column-aligned. The font family is
/// applied by [pulseTheme]; F4-T2 layers the fa/ar/ckb +2 line-height override
/// on top when the active locale is an Arabic-script one.
TextTheme buildPulseTextTheme(
  Color onSurface,
  Color onSurface2, {
  double heightScale = 1.0,
}) {
  const tab = [FontFeature.tabularFigures()];
  return TextTheme(
    // hero-numeral 84/88
    displayLarge: TextStyle(
      fontSize: 84,
      height: 88 / 84 * heightScale,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.04 * 84,
      fontFeatures: tab,
      color: onSurface,
    ),
    // display 30/38
    displayMedium: TextStyle(
      fontSize: 30,
      height: 38 / 30 * heightScale,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.02 * 30,
      color: onSurface,
    ),
    // title 20/28
    titleLarge: TextStyle(
      fontSize: 20,
      height: 28 / 20 * heightScale,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.01 * 20,
      color: onSurface,
    ),
    // body 16/26
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 26 / 16 * heightScale,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    // label 13/20
    labelLarge: TextStyle(
      fontSize: 13,
      height: 20 / 13 * heightScale,
      fontWeight: FontWeight.w600,
      color: onSurface2,
    ),
    // caption 12/18
    bodySmall: TextStyle(
      fontSize: 12,
      height: 18 / 12 * heightScale,
      fontWeight: FontWeight.w500,
      color: onSurface2,
    ),
  );
}

/// Assemble the full PULSE [ThemeData] for a [brightness]. Pass
/// [arabicScript] = true under an fa/ar/ckb locale (F4-T2): Vazirmatn becomes
/// the primary face for consistent RTL metrics (Hanken Grotesk falls back for
/// embedded LTR tokens), and the type scale gains a little line-height for the
/// script's ascenders/descenders.
ThemeData pulseTheme(Brightness brightness, {bool arabicScript = false}) {
  final isDark = brightness == Brightness.dark;
  final cs = isDark ? pulseDarkScheme : pulseLightScheme;
  final pc = isDark ? PulseColors.dark : PulseColors.light;
  final primary = arabicScript ? pulseArabicFont : pulseLatinFont;
  final fallback =
      arabicScript ? const [pulseLatinFont] : const [pulseArabicFont];
  final textTheme = buildPulseTextTheme(
    pc.text,
    pc.text2,
    heightScale: arabicScript ? 1.12 : 1.0,
  ).apply(fontFamily: primary, fontFamilyFallback: fallback);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: pc.base,
    fontFamily: primary,
    fontFamilyFallback: fallback,
    textTheme: textTheme,
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
