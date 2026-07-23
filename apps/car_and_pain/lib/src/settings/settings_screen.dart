import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import 'locale_controller.dart';

/// The PULSE language / calendar / numeral settings surface (F4-T9). Every
/// choice applies **live** (F4-T2), mirrors under RTL via Directional geometry,
/// and encodes selection **redundantly** — a check-vs-outline icon *shape* plus
/// the label, never colour alone. Endonyms are shown in each language's own
/// script; a live preview renders today's date + a sample number in the chosen
/// combination.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // Language endonyms — proper names in their own script, deliberately NOT
  // localized (they read the same in any UI language).
  static const List<(Locale?, String)> _languages = [
    (Locale('en'), 'English'),
    (Locale('de'), 'Deutsch'),
    (Locale('fr'), 'Français'),
    (Locale('fa'), 'فارسی'),
    (Locale('ar'), 'العربية'),
    (Locale('ckb'), 'کوردی'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(localizationPrefsProvider);
    final fmt = ref.watch(activeNumeralFormatProvider);
    final controller = ref.read(localizationControllerProvider);

    return PulseScaffold(
      title: l10n.settingsTitle,
      body: ListView(
        children: [
          _SectionLabel(l10n.settingsPresetSection),
          for (final p in RegionalPreset.values)
            _OptionRow(
              label: _presetName(l10n, p),
              onTap: () async {
                await controller.applyRegionalPreset(p);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.settingsPresetApplied)),
                  );
                }
              },
            ),
          _SectionLabel(l10n.settingsLanguage),
          _OptionRow(
            label: l10n.languageSystemDefault,
            selected: prefs.locale == null,
            onTap: () => controller.setLocale(null),
          ),
          for (final (loc, endonym) in _languages)
            _OptionRow(
              label: endonym,
              selected: prefs.locale == loc,
              onTap: () => controller.setLocale(loc),
            ),
          _SectionLabel(l10n.settingsCalendar),
          for (final c in CalendarSystem.values)
            _OptionRow(
              label: _calendarName(l10n, c),
              selected: prefs.calendar == c,
              onTap: () => controller.setCalendar(c),
            ),
          _SectionLabel(l10n.settingsNumerals),
          for (final n in NumeralSystem.values)
            _OptionRow(
              label: _numeralName(l10n, n),
              trailing: n.shape('0123456789'),
              selected: prefs.numeralSystem == n,
              onTap: () => controller.setNumeralSystem(n),
            ),
          _SectionLabel(l10n.settingsSecurity),
          Semantics(
            button: true,
            label: l10n.settingsSecurity,
            child: InkWell(
              onTap: () => context.push('/settings/security'),
              borderRadius: BorderRadius.circular(PulseTokens.rCard),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: PulseTokens.s2,
                  vertical: PulseTokens.s2,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 22),
                    const SizedBox(width: PulseTokens.s2),
                    Expanded(
                      child: Text(
                        l10n.securityAppLockDesc,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Icon(Icons.adaptive.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ),
          _SectionLabel(l10n.settingsBackup),
          Semantics(
            button: true,
            label: l10n.settingsBackup,
            child: InkWell(
              onTap: () => context.push('/settings/backup'),
              borderRadius: BorderRadius.circular(PulseTokens.rCard),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: PulseTokens.s2,
                  vertical: PulseTokens.s2,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.backup_outlined, size: 22),
                    const SizedBox(width: PulseTokens.s2),
                    Expanded(
                      child: Text(
                        l10n.backupTitle,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Icon(Icons.adaptive.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ),
          _SectionLabel(l10n.settingsStorage),
          Semantics(
            button: true,
            label: l10n.settingsStorage,
            child: InkWell(
              onTap: () => context.push('/settings/storage'),
              borderRadius: BorderRadius.circular(PulseTokens.rCard),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: PulseTokens.s2,
                  vertical: PulseTokens.s2,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 22),
                    const SizedBox(width: PulseTokens.s2),
                    Expanded(
                      child: Text(
                        l10n.storageTitle,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Icon(Icons.adaptive.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ),
          _SectionLabel(l10n.settingsPrivacySection),
          Padding(
            padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
            child: PulseCard(
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined),
                  const SizedBox(width: PulseTokens.s3),
                  Expanded(child: Text(l10n.settingsPrivacyBody)),
                ],
              ),
            ),
          ),
          _SectionLabel(l10n.settingsPreview),
          _Preview(prefs: prefs, fmt: fmt),
        ],
      ),
    );
  }

  static String _presetName(AppLocalizations l, RegionalPreset p) =>
      switch (p) {
        RegionalPreset.iran => l.presetIran,
        RegionalPreset.germany => l.presetGermany,
        RegionalPreset.france => l.presetFrance,
        RegionalPreset.unitedStates => l.presetUnitedStates,
        RegionalPreset.saudiArabia => l.presetSaudiArabia,
        RegionalPreset.kurdistan => l.presetKurdistan,
        RegionalPreset.turkey => l.presetTurkey,
        RegionalPreset.india => l.presetIndia,
        RegionalPreset.israel => l.presetIsrael,
        RegionalPreset.spain => l.presetSpain,
        RegionalPreset.brazil => l.presetBrazil,
      };

  static String _calendarName(AppLocalizations l, CalendarSystem c) =>
      switch (c) {
        CalendarSystem.gregorian => l.calendarGregorian,
        CalendarSystem.jalali => l.calendarJalali,
        CalendarSystem.hijri => l.calendarHijri,
        CalendarSystem.hebrew => l.calendarHebrew,
      };

  static String _numeralName(AppLocalizations l, NumeralSystem n) =>
      switch (n) {
        NumeralSystem.western => l.numeralWestern,
        NumeralSystem.easternArabic => l.numeralEasternArabic,
        NumeralSystem.persian => l.numeralPersian,
      };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final pc = Theme.of(context).extension<PulseColorsExt>()!.c;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: PulseTokens.s3,
        bottom: PulseTokens.s1,
        start: PulseTokens.s1,
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: pc.text3, letterSpacing: 1.2),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PulseTokens.rCard),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: PulseTokens.s2,
            vertical: PulseTokens.s2,
          ),
          child: Row(
            children: [
              // Redundant, non-colour cue: a filled check vs. an empty ring.
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
                color: selected ? theme.colorScheme.primary : pc.text3,
              ),
              const SizedBox(width: PulseTokens.s2),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              if (trailing != null)
                Text(
                  trailing!,
                  style: theme.textTheme.labelLarge?.copyWith(color: pc.text2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.prefs, required this.fmt});

  final LocalizationPrefs prefs;
  final NumeralFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = CalendarDate.fromInstant(
      Instant.fromDateTime(now),
      prefs.calendar,
      utcOffsetMinutes: now.timeZoneOffset.inMinutes,
    );
    final month =
        monthName(prefs.calendar, today.year, today.month, native: prefs.isRtl);
    final dateLine =
        '${fmt.formatInt(today.day)} $month ${fmt.formatInt(today.year)}';
    final numberLine = fmt.formatScaled(123456789, 2);

    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLine, style: theme.textTheme.titleLarge),
          const SizedBox(height: PulseTokens.s1),
          Text(numberLine, style: theme.textTheme.displayMedium),
        ],
      ),
    );
  }
}
