import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:l10n/l10n.dart';

/// A recoverable startup-failure screen. Localizes the message from the
/// [failure]'s stable code and offers a retry — never a raw crash or hang.
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({
    required this.failure,
    required this.onRetry,
    super.key,
  });

  final Failure failure;
  final VoidCallback onRetry;

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
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: PulseTokens.s2),
              Text(
                l10n.startupErrorTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PulseTokens.s1),
              Text(
                _message(l10n, failure),
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PulseTokens.s4),
              FilledButton(
                onPressed: onRetry,
                child: Text(l10n.startupErrorRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Localize from the code. Exhaustive over [StartupFailure] (a new subtype is
  /// a compile error) with an explicit fallback for any non-startup failure.
  String _message(AppLocalizations l10n, Failure failure) {
    if (failure is StartupFailure) {
      return switch (failure) {
        DatabaseOpenFailed() => l10n.startupFailureDatabaseOpenFailed,
        KeyStoreUnavailable() => l10n.startupFailureKeyStoreUnavailable,
        TimezoneInitFailed() => l10n.startupFailureTimezoneInitFailed,
        AppDirsUnavailable() => l10n.startupFailureAppDirsUnavailable,
      };
    }
    return l10n.startupFailureUnknown;
  }
}
