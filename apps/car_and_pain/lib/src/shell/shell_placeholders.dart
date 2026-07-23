import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../routing/app_locations.dart';
import '../settings/locale_controller.dart';
import 'shell_state.dart';

/// The minimal first-run onboarding (M1-T7 target; M10 replaces it): create the
/// first vehicle, mark onboarding complete, and land in the Cockpit. Rendered as
/// a full-screen flow above the shell.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    final created =
        await ref.read(vehiclesRepositoryProvider).add(nickname: name);
    final id = created.valueOrNull?.id;
    final settings = ref.read(settingsRepositoryProvider);
    await settings.set(SettingsKeys.onboardingComplete, 'true');
    if (id != null) {
      await ref.read(shellStateControllerProvider).setActiveVehicle(id);
    }
    if (mounted) context.go(AppLocations.cockpit);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PulseScaffold(
      title: l10n.onboardingTitle,
      body: Padding(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        child: Column(
          children: [
            Text(l10n.homeEmptyTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: PulseTokens.s3),
            TextField(controller: _controller, autofocus: true),
            const SizedBox(height: PulseTokens.s3),
            PulseButton(
              label: l10n.homeEmptyCta,
              icon: Icons.add,
              onPressed: _busy ? null : _create,
            ),
          ],
        ),
      ),
    );
  }
}
