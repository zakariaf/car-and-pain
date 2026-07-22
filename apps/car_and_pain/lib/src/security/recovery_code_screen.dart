import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:l10n/l10n.dart';

/// Shows the one-time recovery code with the un-skippable data-loss warning
/// (F7-T7). The code is the offline fallback if the PIN/passphrase is forgotten;
/// there is no server backup, so the warning is prominent and acknowledgement is
/// explicit. The code is rendered LTR + selectable regardless of UI direction.
class RecoveryCodeScreen extends StatelessWidget {
  const RecoveryCodeScreen({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;

    // Un-skippable (F6-T7): the system back gesture can't dismiss the one-time
    // code — the owner must acknowledge via "I've saved it".
    return PopScope(
      canPop: false,
      child: PulseScaffold(
        title: l10n.securityRecovery,
        body: ListView(
          padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
          children: [
            PulseCard(
              child: Padding(
                padding: const EdgeInsets.all(PulseTokens.s2),
                child: Center(
                  // Force LTR so the code never reorders on an RTL screen; keep it
                  // selectable so the owner can copy it. Tabular figures align it.
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      code,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 2,
                        color: pc.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: PulseTokens.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: theme.colorScheme.error, size: 22),
                const SizedBox(width: PulseTokens.s2),
                Expanded(
                  child: Text(
                    l10n.securityRecoveryWarning,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: PulseTokens.s4),
            PulseButton(
              label: l10n.securityRecoverySaved,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
