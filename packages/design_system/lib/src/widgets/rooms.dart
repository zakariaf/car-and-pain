import 'package:flutter/material.dart';

import '../theme/pulse_tokens.dart';

/// The three emotional Rooms — not a generic tab bar. Order is **logical** (a
/// `Row` under `Directionality` mirrors automatically in RTL); labels are l10n
/// keys. The room shells own chrome only; navigation state lives in the app's
/// `StatefulShellRoute` (M1).
enum Room { cockpit, garage, pitlane }

extension RoomX on Room {
  IconData get icon => const [
        Icons.show_chart,
        Icons.home_outlined,
        Icons.timer_outlined,
      ][index];

  IconData get selectedIcon =>
      const [Icons.show_chart, Icons.home, Icons.timer][index];

  String get labelKey =>
      const ['room.cockpit', 'room.garage', 'room.pitlane'][index];

  String get subKey => const [
        'room.cockpit_sub',
        'room.garage_sub',
        'room.pitlane_sub',
      ][index];
}

/// A start-aligned section header. Drops letter-spacing on Arabic scripts (never
/// letter-space Arabic) and marks itself a semantics header.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.eyebrow, super.key});

  final String title;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    final lang = Localizations.maybeLocaleOf(context)?.languageCode;
    final rtlScript = const {'ar', 'fa', 'ckb'}.contains(lang);
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null && eyebrow!.isNotEmpty)
            Text(
              rtlScript ? eyebrow! : eyebrow!.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: rtlScript ? 0 : 1.6,
                color: pc.text3,
              ),
            ),
          Text(title, style: theme.textTheme.displayMedium),
        ],
      ),
    );
  }
}

/// The base Room chrome: PULSE background, an optional start-aligned header, and
/// a safe-area body. Consistent across Cockpit / Garage / Pit-lane.
class PulseScaffold extends StatelessWidget {
  const PulseScaffold({
    required this.body,
    this.title,
    this.eyebrow,
    this.actions,
    super.key,
  });

  final Widget body;
  final String? title;
  final String? eyebrow;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final pc = Theme.of(context).extension<PulseColorsExt>()!.c;
    return Scaffold(
      backgroundColor: pc.base,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: SectionHeader(title: title!, eyebrow: eyebrow),
                    ),
                    ...?actions,
                  ],
                ),
                const SizedBox(height: PulseTokens.s3),
              ],
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
