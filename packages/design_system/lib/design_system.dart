/// Car and Pain — `design_system` (PULSE).
///
/// The single public entry point for the PULSE design system: warm-paper/ink
/// dual-theme tokens, the urgency temperature scale (redundantly encoded), the
/// breathing vital + capped halo, the exhale, the Rooms scaffold, CustomPainter
/// charts, and the RTL/reduced-motion contract.
library;

// ── Theme / tokens / motion / urgency ──────────────────────────────────────
export 'src/theme/font_licenses.dart' show registerFontLicenses;
export 'src/theme/pulse_motion.dart' show PulseMotion;
export 'src/theme/pulse_theme.dart'
    show
        buildPulseTextTheme,
        pulseArabicFont,
        pulseDarkScheme,
        pulseDarkTheme,
        pulseLatinFont,
        pulseLightScheme,
        pulseLightTheme,
        pulseTheme;
export 'src/theme/pulse_tokens.dart'
    show PulseColors, PulseColorsExt, PulseTokens;
export 'src/theme/urgency.dart'
    show
        StripeStyle,
        Urgency,
        UrgencyStyle,
        UrgencyX,
        aggregateHalo,
        resolveUrgency;

// ── Utilities (reduced-motion, symmetric glyphs) ───────────────────────────
export 'src/util/reduced_motion.dart'
    show ReducedMotionScope, reduceMotion, resolveReducedMotion;
export 'src/util/symmetric_glyph.dart' show nonMirrored;

// ── Widgets ────────────────────────────────────────────────────────────────
export 'src/widgets/charts.dart'
    show
        BarChartPainter,
        LineChartPainter,
        PulseBarChart,
        PulseLineChart,
        pulseChartRamp;
export 'src/widgets/exhale.dart' show Exhale, ExhaleSettle, coolOneNotch;
export 'src/widgets/pulse_button.dart' show PulseButton, PulseButtonVariant;
export 'src/widgets/pulse_card.dart' show PulseCard, UStripePainter;
export 'src/widgets/pulse_line.dart'
    show AmbientHalo, PulseLinePainter, VitalHero;
export 'src/widgets/rooms.dart' show PulseScaffold, Room, RoomX, SectionHeader;
export 'src/widgets/stat_tile.dart' show StatTile;
export 'src/widgets/status_badge.dart' show PulseStatus, StatusBadge;
export 'src/widgets/status_pill.dart' show StatusPill;
