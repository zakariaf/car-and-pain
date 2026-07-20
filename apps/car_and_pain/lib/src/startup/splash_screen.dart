import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:l10n/l10n.dart';

/// Shown while async startup runs. Localized, RTL-aware, calm.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(PulseTokens.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appTitle,
                style: theme.textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PulseTokens.s1),
              Text(
                l10n.appTagline,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PulseTokens.s5),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(height: PulseTokens.s3),
              Text(
                l10n.splashPreparing,
                style: theme.textTheme.labelLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
