import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

/// The F1 placeholder home. Proves the whole stack is wired: DI (reads the
/// diagnostics repository, which consumes the injected database), i18n (every
/// string localized), and PULSE (theme + redundant-encoding status badges).
/// The real breathing-vitals Home + Rooms shell arrive in M1.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final infraLabel = ref.watch(diagnosticsRepositoryProvider).databaseLabel();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.homeTitle, style: theme.textTheme.displayMedium),
              const SizedBox(height: PulseTokens.s2),
              Text(l10n.homeBody, style: theme.textTheme.bodyLarge),
              const SizedBox(height: PulseTokens.s4),
              Wrap(
                spacing: PulseTokens.s2,
                runSpacing: PulseTokens.s2,
                children: [
                  StatusBadge(
                    status: PulseStatus.healthy,
                    label: l10n.statusHealthy,
                  ),
                  StatusBadge(
                    status: PulseStatus.dueSoon,
                    label: l10n.statusDue,
                  ),
                  StatusBadge(
                    status: PulseStatus.overdue,
                    label: l10n.statusOverdue,
                  ),
                ],
              ),
              const SizedBox(height: PulseTokens.s4),
              OutlinedButton.icon(
                onPressed: () => context.push('/trash'),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.trashTitle),
              ),
              const SizedBox(height: PulseTokens.s4),
              Text(
                l10n.homeInfraLabel(infraLabel),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
