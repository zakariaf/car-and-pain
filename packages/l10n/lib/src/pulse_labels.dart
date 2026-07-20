import 'generated/app_localizations.dart';

/// Resolve a PULSE library label **key** (emitted by `design_system`, e.g.
/// `urgency.overdue`, `room.cockpit`) to a localized string.
///
/// The design system stays l10n-free (it emits keys/enums, never strings); this
/// bridges keys → ARB so no library string is ever hardcoded (F3-T10). Unknown
/// keys degrade to the key itself rather than crashing.
String pulseLabel(AppLocalizations l10n, String key) => switch (key) {
      'urgency.calm' => l10n.urgencyCalm,
      'urgency.scheduled' => l10n.urgencyScheduled,
      'urgency.soon' => l10n.urgencySoon,
      'urgency.pressing' => l10n.urgencyPressing,
      'urgency.overdue' => l10n.urgencyOverdue,
      'room.cockpit' => l10n.roomCockpit,
      'room.garage' => l10n.roomGarage,
      'room.pitlane' => l10n.roomPitlane,
      _ => key,
    };
