import 'package:flutter/material.dart';

import '../theme/pulse_tokens.dart';
import '../theme/urgency.dart';

/// A compact, redundant status token: **always icon + text**, never a bare
/// colour dot. The icon shape differs per urgency, so the pill is fully legible
/// in greyscale. The tint is decoration behind an AA-safe foreground.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.urgency, required this.label, super.key});

  final Urgency urgency;

  /// Localized by the caller (from `urgency.labelKey`) — never hardcoded here.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    final style = resolveUrgency(urgency, theme.brightness);
    final fg = switch (urgency) {
      Urgency.calm || Urgency.scheduled => pc.okText,
      Urgency.soon => pc.warnText,
      Urgency.pressing || Urgency.overdue => pc.critText,
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
            color: style.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(PulseTokens.rPill),
            border: Border.all(color: fg.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: 14, color: fg),
              const SizedBox(width: PulseTokens.sHalf),
              Text(
                label,
                style: TextStyle(
                  color: fg,
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
