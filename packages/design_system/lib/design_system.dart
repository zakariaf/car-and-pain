/// Car and Pain — `design_system` (PULSE).
///
/// The single public entry point for the PULSE design system: warm-paper/ink
/// dual-theme tokens, the temperature ramp, and RTL-aware, redundant-encoding
/// widgets. Later: Rooms scaffolding, the breathing vitals hero, and
/// Semantics-annotated CustomPainter charts.
library;

export 'src/theme/pulse_theme.dart'
    show
        buildPulseTextTheme,
        pulseDarkScheme,
        pulseDarkTheme,
        pulseLightScheme,
        pulseLightTheme,
        pulseTheme;
export 'src/theme/pulse_tokens.dart'
    show PulseColors, PulseColorsExt, PulseTokens;
export 'src/widgets/status_badge.dart' show PulseStatus, StatusBadge;
