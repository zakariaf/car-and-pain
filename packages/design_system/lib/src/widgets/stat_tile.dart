import 'package:flutter/material.dart';

import '../theme/pulse_tokens.dart';

/// A secondary vital: a tabular value over a caption. Numerals use tabular
/// figures so columns align; the whole tile reads as one semantic unit.
class StatTile extends StatelessWidget {
  const StatTile({required this.value, required this.label, super.key});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: pc.text2),
            ),
          ],
        ),
      ),
    );
  }
}
