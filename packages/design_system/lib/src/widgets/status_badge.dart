import 'package:flutter/material.dart';

import '../theme/pulse_tokens.dart';

/// The health states surfaced by [StatusBadge]. Kept minimal for F1; the full
/// urgency ramp (u0..u4) and the aching-card stripe arrive in F3.
enum PulseStatus { healthy, dueSoon, overdue }

/// A status chip that encodes state **redundantly** — never colour alone.
///
/// Per the PULSE non-negotiable (docs/design/pulse/01-tokens.md §1.4), every
/// status carries at least two of {icon, text label, shape/position}. Here the
/// distinct **icon** (check / triangle-alert / bell) and the **text [label]**
/// carry the meaning; the temperature tint is decoration behind an AA-safe
/// foreground. The app remains fully operable in greyscale.
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, required this.label, super.key});

  final PulseStatus status;

  /// The localized status text (resolved upstream in `l10n` — never hardcoded).
  final String label;

  @override
  Widget build(BuildContext context) {
    final pc = Theme.of(context).extension<PulseColorsExt>()!.c;
    final (IconData icon, Color foreground, Color tint) = switch (status) {
      PulseStatus.healthy => (
          Icons.check_circle_outline,
          pc.okText,
          PulseTokens.temp[0],
        ),
      PulseStatus.dueSoon => (
          Icons.warning_amber_rounded,
          pc.warnText,
          PulseTokens.temp[2],
        ),
      PulseStatus.overdue => (
          Icons.notifications_active_outlined,
          pc.critText,
          PulseTokens.temp[4],
        ),
    };

    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: PulseTokens.s2,
            vertical: PulseTokens.sHalf,
          ),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(PulseTokens.rPill),
            border: Border.all(color: foreground.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: PulseTokens.sHalf),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
