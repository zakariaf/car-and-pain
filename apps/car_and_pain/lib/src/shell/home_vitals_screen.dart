import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../routing/app_locations.dart';
import '../settings/locale_controller.dart';
import 'home_vitals.dart';
import 'shell_state.dart';

/// The Cockpit "Now" Home (PULSE screen A2, M1-T4): ONE breathing vital, no
/// visible list. The full-bleed pulse-line hero, a count-up readiness numeral,
/// the redundantly-encoded aggregate StatusBadge, and the capped ambient halo —
/// all reading live from streams (instant paint, no skeleton). With no vehicle
/// it shows the calm empty first-run state (M1-T7).
class HomeVitalsScreen extends ConsumerWidget {
  const HomeVitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(activeVehiclesProvider);
    if (vehicles.isEmpty) return const _EmptyHome();

    final l10n = AppLocalizations.of(context);
    // Instant paint: fall back to calm while the async recompute settles — the
    // Home never shows a skeleton loader.
    final summary =
        ref.watch(homeReadinessProvider).asData?.value ?? ReadinessSummary.calm;
    final urgency = Urgency.values[summary.urgency.clamp(0, 4)];
    final status = _statusFor(summary.urgency);

    return AmbientHalo(
      open: [urgency],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                VitalHero(
                  semanticsLabel:
                      '${l10n.readinessLabel}: ${_statusLabel(l10n, summary.urgency)}',
                  aggregate: urgency,
                ),
                const SizedBox(height: PulseTokens.s3),
                _ReadinessNumeral(score: summary.score),
                Text(l10n.readinessLabel,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: PulseTokens.s2),
                StatusBadge(
                    status: status, label: _statusLabel(l10n, summary.urgency)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PulseStatus _statusFor(int urgency) => switch (urgency) {
        0 => PulseStatus.healthy,
        1 || 2 => PulseStatus.dueSoon,
        _ => PulseStatus.overdue,
      };

  String _statusLabel(AppLocalizations l10n, int urgency) => switch (urgency) {
        0 => l10n.statusHealthy,
        1 || 2 => l10n.statusDue,
        _ => l10n.statusOverdue,
      };
}

/// The count-up readiness numeral — animates ONLY on a real readiness change
/// (TweenAnimationBuilder settles from the last value), instant under reduced
/// motion. Rendered in the user's numeral system.
class _ReadinessNumeral extends ConsumerWidget {
  const _ReadinessNumeral({required this.score});
  final int score;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(activeNumeralFormatProvider);
    final theme = Theme.of(context);
    final duration = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 900);

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: score, end: score),
      duration: duration,
      builder: (context, value, _) => Semantics(
        label: fmt.formatInt(value),
        child: ExcludeSemantics(
          child: Text(
            fmt.formatInt(value),
            style: theme.textTheme.displayLarge
                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ),
    );
  }
}

/// The empty first-run Home (PULSE Empty pattern B6, M1-T7): calm (urgency 0),
/// one authored sentence, one CTA into onboarding. Never warm, never a skeleton.
class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(PulseTokens.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The illustration does not mirror in RTL.
                Icon(Icons.directions_car_outlined, size: 64, color: pc.text3),
                const SizedBox(height: PulseTokens.s3),
                Text(
                  l10n.homeEmptyTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: PulseTokens.s3),
                PulseButton(
                  label: l10n.homeEmptyCta,
                  icon: Icons.add,
                  onPressed: () => context.push(AppLocations.onboarding),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
