import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import 'pin_pad.dart';

/// Choose-then-confirm PIN entry (F7-T4/T7). Returns the chosen PIN via
/// `Navigator.pop`, or null if cancelled. A mismatch resets to the first step
/// with a redundant (icon + text) error — the PIN is never revealed.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String? _first;
  String _entered = '';
  bool _mismatch = false;

  bool get _confirming => _first != null;

  void _onDigit(String d) {
    if (_entered.length >= kPinLength) return;
    setState(() {
      _entered += d;
      _mismatch = false;
    });
    if (_entered.length == kPinLength) _advance();
  }

  void _advance() {
    if (!_confirming) {
      setState(() {
        _first = _entered;
        _entered = '';
      });
      return;
    }
    if (_entered == _first) {
      Navigator.of(context).pop(_entered);
    } else {
      setState(() {
        _first = null;
        _entered = '';
        _mismatch = true;
      });
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PulseScaffold(
      title: _confirming ? l10n.securityConfirmPin : l10n.securityChoosePin,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PinDots(filled: _entered.length),
            const SizedBox(height: PulseTokens.s2),
            SizedBox(
              height: 24,
              child: _mismatch
                  ? Text(
                      l10n.securityPinMismatch,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error),
                    )
                  : null,
            ),
            const SizedBox(height: PulseTokens.s2),
            PinPad(onDigit: _onDigit, onBackspace: _onBackspace),
          ],
        ),
      ),
    );
  }
}
