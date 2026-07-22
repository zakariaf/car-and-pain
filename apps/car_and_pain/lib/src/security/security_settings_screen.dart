import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import 'pin_setup_screen.dart';
import 'recovery_code_screen.dart';
import 'security_settings_controller.dart';

/// The PULSE security & app-lock surface (F7-T7): the app-lock toggle + PIN,
/// biometric unlock, auto-lock timeout, and the recoverable-by-default recovery
/// code. Every control applies live; selection is encoded redundantly (switch
/// state + label, radio shape + label), never by colour alone.
class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(securitySettingsControllerProvider);

    return PulseScaffold(
      title: l10n.securityTitle,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (s) => _Body(snapshot: s),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.snapshot});

  final SecuritySettingsSnapshot snapshot;

  SecuritySettingsController _ctrl(WidgetRef ref) =>
      ref.read(securitySettingsControllerProvider.notifier);

  Future<void> _toggleLock(BuildContext context, WidgetRef ref, bool on) async {
    if (!on) {
      await _ctrl(ref).disableLock();
      return;
    }
    // A PIN already exists → just re-enable. Otherwise set one first.
    if (snapshot.hasPin) {
      await _ctrl(ref).enableLock();
      return;
    }
    final pin = await _pushPinSetup(context);
    if (pin != null) await _ctrl(ref).setPin(pin);
  }

  Future<String?> _pushPinSetup(BuildContext context) => Navigator.of(context)
      .push<String>(MaterialPageRoute(builder: (_) => const PinSetupScreen()));

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final pin = await _pushPinSetup(context);
    if (pin != null) await _ctrl(ref).setPin(pin);
  }

  Future<void> _setupRecovery(BuildContext context, WidgetRef ref) async {
    final passphrase = await _askPassphrase(context);
    if (passphrase == null || passphrase.isEmpty) return;
    final code = await _ctrl(ref).setupRecovery(passphrase);
    if (code == null || !context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => RecoveryCodeScreen(code: code)),
    );
  }

  Future<String?> _askPassphrase(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.securityRecovery),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.securityRecoveryDesc),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = snapshot;
    final lockOn = s.prefs.enabled && s.hasPin;

    return ListView(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: PulseTokens.s2,
        vertical: PulseTokens.s2,
      ),
      children: [
        _Section(l10n.securityAppLock),
        _ToggleRow(
          label: l10n.securityAppLock,
          subtitle: l10n.securityAppLockDesc,
          value: lockOn,
          onChanged: (on) => _toggleLock(context, ref, on),
        ),
        if (lockOn) ...[
          if (s.biometricAvailable)
            _ToggleRow(
              label: l10n.securityBiometric,
              value: s.prefs.biometricEnabled,
              onChanged: (on) => _ctrl(ref).setBiometricEnabled(enabled: on),
            ),
          _PlainRow(
            label: l10n.securityChangePin,
            icon: Icons.password,
            onTap: () => _changePin(context, ref),
          ),
          _Section(l10n.securityAutoLock),
          for (final (minutes, label) in [
            (0, l10n.securityAutoLockImmediate),
            (1, l10n.securityAutoLock1Min),
            (5, l10n.securityAutoLock5Min),
          ])
            _RadioRow(
              label: label,
              selected: s.prefs.timeoutMinutes == minutes,
              onTap: () => _ctrl(ref).setTimeoutMinutes(minutes),
            ),
        ],
        _Section(l10n.securityRecovery),
        _PlainRow(
          label: s.recoveryConfigured
              ? l10n.securityRecovery
              : l10n.securityRecoveryDesc,
          icon: s.recoveryConfigured ? Icons.verified_user : Icons.key,
          onTap: () => _setupRecovery(context, ref),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final pc = Theme.of(context).extension<PulseColorsExt>()!.c;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: PulseTokens.s3,
        bottom: PulseTokens.s1,
        start: PulseTokens.s1,
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: pc.text3, letterSpacing: 1.2),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: PulseTokens.s2,
      ),
      title: Text(label, style: theme.textTheme.bodyLarge),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: pc.text2)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PulseTokens.rCard),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: PulseTokens.s2,
            vertical: PulseTokens.s2,
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
                color: selected ? theme.colorScheme.primary : pc.text3,
              ),
              const SizedBox(width: PulseTokens.s2),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PulseTokens.rCard),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: PulseTokens.s2,
          vertical: PulseTokens.s2,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: pc.text2),
            const SizedBox(width: PulseTokens.s2),
            Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
            Icon(Icons.adaptive.arrow_forward, size: 18, color: pc.text3),
          ],
        ),
      ),
    );
  }
}
