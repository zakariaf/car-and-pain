import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

/// The Pit-lane Room root — "what's due". M5 fills it with the prioritised
/// reminder list; for M1 it is the shell placeholder.
class PitlaneScreen extends ConsumerWidget {
  const PitlaneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PulseScaffold(
      title: pulseLabel(l10n, 'room.pitlane'),
      body: Center(child: Text(l10n.statusHealthy)),
    );
  }
}
