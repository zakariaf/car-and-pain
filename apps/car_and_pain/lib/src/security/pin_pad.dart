import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import '../settings/locale_controller.dart';

/// The number of PIN digits the app uses. Fixed-length so entry auto-submits.
const int kPinLength = 4;

/// A reusable numeric keypad (F7-T4). Digits render in the user's numeral
/// system (Western / Eastern-Arabic / Persian) while the value stays ASCII.
/// Layout is Directional so it mirrors correctly under RTL; the backspace uses
/// `Icons.adaptive` and carries a semantic label (never glyph-only).
class PinPad extends ConsumerWidget {
  const PinPad({
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// When non-null, the bottom-start key becomes a biometric shortcut.
  final VoidCallback? onBiometric;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numerals = ref.watch(localizationPrefsProvider).numeralSystem;
    final l10n = AppLocalizations.of(context);

    Widget digit(int n) => _PadKey(
          label: numerals.shape('$n'),
          onTap: enabled ? () => onDigit('$n') : null,
          semanticLabel: numerals.shape('$n'),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final n in row) digit(n)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Bottom-start: biometric shortcut, or an empty spacer.
            if (onBiometric != null)
              _PadKey(
                icon: Icons.fingerprint,
                onTap: enabled ? onBiometric : null,
                semanticLabel: l10n.appLockUseBiometric,
              )
            else
              const _PadKey(),
            digit(0),
            _PadKey(
              icon: Icons.backspace_outlined,
              onTap: enabled ? onBackspace : null,
              semanticLabel:
                  MaterialLocalizations.of(context).keyboardKeyBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({
    this.label,
    this.icon,
    this.onTap,
    this.semanticLabel,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    final empty = label == null && icon == null;

    return Padding(
      padding: const EdgeInsets.all(PulseTokens.s1),
      child: Semantics(
        button: !empty,
        label: semanticLabel,
        excludeSemantics: true,
        child: SizedBox(
          width: 72,
          height: 64,
          child: empty
              ? const SizedBox.shrink()
              : Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PulseTokens.rCard),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Center(
                      child: icon != null
                          ? Icon(icon, size: 26, color: pc.text2)
                          : Text(
                              label!,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(color: pc.text),
                            ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The row of filled/empty dots showing how many PIN digits have been entered.
/// The count is also exposed to screen readers (never dots-only).
class PinDots extends StatelessWidget {
  const PinDots({required this.filled, this.length = kPinLength, super.key});

  final int filled;
  final int length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    return Semantics(
      label: '$filled / $length',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < length; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: PulseTokens.s1),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    i < filled ? theme.colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: i < filled ? theme.colorScheme.primary : pc.text3,
                  width: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
