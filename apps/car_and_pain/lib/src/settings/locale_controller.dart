import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

/// Persisted localization setting keys (F4-T2). Stored in the encrypted DB.
abstract final class SettingsKeys {
  static const locale = 'locale';
  static const calendar = 'calendar';
  static const numeral = 'numeral';

  // ── Shell UI state (M1-T3/T10): persisted through the settings table, so it
  // round-trips through the single-file backup / JSON export like any setting.
  static const defaultVehicleId = 'default_vehicle_id';
  static const scope = 'scope';
  static const lastRoom = 'last_room';
  static const onboardingComplete = 'onboarding_complete';
}

/// Reactive snapshot of the encrypted settings table — the single source that
/// drives live, restart-free localization switching.
final settingsMapProvider = StreamProvider<Map<String, String>>(
  (ref) => ref.watch(settingsRepositoryProvider).watchAll(),
);

/// Resolved localization preferences.
class LocalizationPrefs {
  const LocalizationPrefs({
    required this.locale,
    required this.languageCode,
    required this.calendar,
    required this.numeralSystem,
  });

  /// The explicit app locale, or `null` to follow the device.
  final Locale? locale;

  /// The language actually in effect (chosen, else resolved device locale).
  final String languageCode;
  final CalendarSystem calendar;
  final NumeralSystem numeralSystem;

  bool get isRtl =>
      languageCode == 'fa' || languageCode == 'ar' || languageCode == 'ckb';
}

Locale _parseLocale(String tag) {
  final parts = tag.split(RegExp('[-_]'));
  return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts.first);
}

String _tag(Locale l) => l.countryCode == null
    ? l.languageCode
    : '${l.languageCode}-${l.countryCode}';

T? _enumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// Pure resolution of preferences from the stored settings [map] plus the
/// device's [deviceLocales] preference order. Extracted from the provider so it
/// is deterministic and testable without any async, binding, or StreamProvider.
/// The effective language is the chosen locale, else the device locale resolved
/// against the supported set (mirroring what MaterialApp displays).
LocalizationPrefs resolveLocalizationPrefs(
  Map<String, String> map,
  List<Locale> deviceLocales,
) {
  final localeTag = map[SettingsKeys.locale];
  final locale =
      (localeTag == null || localeTag.isEmpty) ? null : _parseLocale(localeTag);
  final lang = locale != null
      ? locale.languageCode
      : basicLocaleListResolution(deviceLocales, carAndPainSupportedLocales)
          .languageCode;
  return LocalizationPrefs(
    locale: locale,
    languageCode: lang,
    calendar: _enumByName(CalendarSystem.values, map[SettingsKeys.calendar]) ??
        defaultCalendarFor(lang),
    numeralSystem:
        _enumByName(NumeralSystem.values, map[SettingsKeys.numeral]) ??
            defaultNumeralSystemFor(lang),
  );
}

/// The resolved preferences, recomputed whenever the settings table changes.
final localizationPrefsProvider = Provider<LocalizationPrefs>((ref) {
  final map = ref.watch(settingsMapProvider).asData?.value ?? const {};
  return resolveLocalizationPrefs(
    map,
    WidgetsBinding.instance.platformDispatcher.locales,
  );
});

/// Drives `MaterialApp.locale` (null → follow the device).
final localeProvider =
    Provider<Locale?>((ref) => ref.watch(localizationPrefsProvider).locale);

/// The active display calendar and numeral system, for formatters and UI.
final activeCalendarProvider = Provider<CalendarSystem>(
  (ref) => ref.watch(localizationPrefsProvider).calendar,
);
final activeNumeralSystemProvider = Provider<NumeralSystem>(
  (ref) => ref.watch(localizationPrefsProvider).numeralSystem,
);

/// A ready-to-use numeral formatter for the effective locale + numeral system.
final activeNumeralFormatProvider = Provider<NumeralFormat>((ref) {
  final prefs = ref.watch(localizationPrefsProvider);
  return resolveNumeralFormat(prefs.languageCode, system: prefs.numeralSystem);
});

/// Writes localization preferences to the encrypted DB; the reactive
/// [settingsMapProvider] applies them live, with no restart.
class LocalizationController {
  const LocalizationController(this._settings);
  final SettingsRepository _settings;

  Future<Result<void, DbFailure>> setLocale(Locale? locale) =>
      _settings.set(SettingsKeys.locale, locale == null ? null : _tag(locale));

  Future<Result<void, DbFailure>> setCalendar(CalendarSystem c) =>
      _settings.set(SettingsKeys.calendar, c.name);

  Future<Result<void, DbFailure>> setNumeralSystem(NumeralSystem n) =>
      _settings.set(SettingsKeys.numeral, n.name);
}

final localizationControllerProvider = Provider<LocalizationController>(
  (ref) => LocalizationController(ref.watch(settingsRepositoryProvider)),
);
