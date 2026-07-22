import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import '../security/security_providers.dart';

/// Redeem a one-time recovery code to regain access (F6-T7). Gated by the same
/// un-skippable data-loss warning as code generation. Redemption is single-use:
/// the service consumes the code on success. Wrong/used codes fail closed with
/// a typed failure — no key material leaks.
class RecoveryRedeemScreen extends ConsumerStatefulWidget {
  const RecoveryRedeemScreen({super.key});

  @override
  ConsumerState<RecoveryRedeemScreen> createState() =>
      _RecoveryRedeemScreenState();
}

class _RecoveryRedeemScreenState extends ConsumerState<RecoveryRedeemScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _ok = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final result = await ref
        .read(masterKeyServiceProvider)
        .redeemRecovery(_controller.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = result.isOk;
      _message =
          result.isOk ? l10n.recoveryRedeemDone : l10n.recoveryRedeemInvalid;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;

    return PulseScaffold(
      title: l10n.recoveryRedeem,
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          Text(l10n.recoveryRedeemDesc, style: theme.textTheme.bodyLarge),
          const SizedBox(height: PulseTokens.s2),
          // The same loss warning as generation — redundantly encoded.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: theme.colorScheme.error, size: 22),
              const SizedBox(width: PulseTokens.s2),
              Expanded(
                child: Text(l10n.securityRecoveryWarning,
                    style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: PulseTokens.s3),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: l10n.securityRecovery),
          ),
          const SizedBox(height: PulseTokens.s2),
          if (_message != null)
            Row(
              children: [
                Icon(
                  _ok ? Icons.check_circle_outline : Icons.error_outline,
                  size: 20,
                  color: _ok ? pc.okText : theme.colorScheme.error,
                ),
                const SizedBox(width: PulseTokens.s1),
                Text(_message!, style: theme.textTheme.bodyMedium),
              ],
            ),
          const SizedBox(height: PulseTokens.s3),
          PulseButton(
            label: l10n.recoveryRedeem,
            onPressed: _busy ? null : _redeem,
          ),
        ],
      ),
    );
  }
}
