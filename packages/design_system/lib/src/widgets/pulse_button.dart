import 'package:flutter/material.dart';

/// The two PULSE button registers: a primary CTA and a ghost (outline).
enum PulseButtonVariant { primary, ghost }

/// A token-driven button. Material's `FilledButton`/`OutlinedButton` already
/// give correct button semantics and ≥48dp targets; this wraps them with the
/// PULSE variant + optional leading icon (which follows reading direction).
class PulseButton extends StatelessWidget {
  const PulseButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PulseButtonVariant.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PulseButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final text = Text(label);
    return switch (variant) {
      PulseButtonVariant.primary => icon == null
          ? FilledButton(onPressed: onPressed, child: text)
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: text,
            ),
      PulseButtonVariant.ghost => icon == null
          ? OutlinedButton(onPressed: onPressed, child: text)
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: text,
            ),
    };
  }
}
