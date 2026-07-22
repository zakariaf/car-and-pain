import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import 'backup_controller.dart';

/// The PULSE Backup & Recovery surface (F6-T10): back-up-now with a redundantly
/// encoded status (icon + label, never colour alone), the last-successful-backup
/// honesty line, a restore/import entry, and recovery-code redemption. Every
/// string is localized; layout is Directional (RTL-mirrored).
class BackupRecoveryScreen extends ConsumerWidget {
  const BackupRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(backupControllerProvider);

    return PulseScaffold(
      title: l10n.backupTitle,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.backupFailed)),
        data: (s) => _Body(state: s),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});
  final BackupState state;

  BackupController _ctrl(WidgetRef ref) =>
      ref.read(backupControllerProvider.notifier);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      children: [
        _StatusCard(state: state),
        _PlainRow(
          icon: Icons.backup_outlined,
          label: l10n.backupNow,
          subtitle: l10n.backupNowDesc,
          enabled: state.phase != BackupPhase.running,
          onTap: () => _backupNow(context, ref),
        ),
        const Divider(height: 1),
        _PlainRow(
          icon: Icons.restore_outlined,
          label: l10n.backupRestore,
          subtitle: l10n.backupRestoreDesc,
          onTap: () => _restore(context, ref),
        ),
        _PlainRow(
          icon: Icons.vpn_key_outlined,
          label: l10n.recoveryRedeem,
          subtitle: l10n.recoveryRedeemDesc,
          onTap: () => context.push('/settings/recovery'),
        ),
      ],
    );
  }

  Future<void> _backupNow(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final passphrase =
        await _askPassphrase(context, l10n.backupEnterPassphrase);
    if (passphrase == null || passphrase.isEmpty) return;
    await _ctrl(ref).backupNow(passphrase);
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final bytes = picked?.files.singleOrNull?.bytes;
    if (bytes == null || !context.mounted) return;

    final passphrase =
        await _askPassphrase(context, l10n.backupUnlockPassphrase);
    if (passphrase == null || !context.mounted) return;

    final confirmed = await _confirm(context, l10n.backupRestoreConfirm);
    if (confirmed != true || !context.mounted) return;

    final result = await _ctrl(ref)
        .restoreFromBytes(Uint8List.fromList(bytes), passphrase);
    if (!context.mounted) return;
    final message = switch (result) {
      Ok() => l10n.backupRestoreDone,
      Err(:final failure) => _restoreError(l10n, failure),
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _restoreError(AppLocalizations l10n, Failure f) => switch (f) {
        WrongBackupPassphrase() => l10n.backupWrongPassphrase,
        SchemaVersionMismatch() => l10n.backupNewerVersion,
        _ => l10n.backupDamaged,
      };

  Future<String?> _askPassphrase(BuildContext context, String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
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

  Future<bool?> _confirm(BuildContext context, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(ctx).backupRestore),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});
  final BackupState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;

    // Redundant encoding: icon + label carry the state, never colour alone.
    final (icon, label) = switch (state.phase) {
      BackupPhase.running => (Icons.hourglass_top, l10n.backupInProgress),
      BackupPhase.success => (Icons.check_circle_outline, l10n.backupSuccess),
      BackupPhase.failure => (Icons.error_outline, l10n.backupFailed),
      BackupPhase.idle => state.hasBackedUp
          ? (Icons.cloud_done_outlined, l10n.backupSuccess)
          : (Icons.cloud_off_outlined, l10n.backupNever),
    };

    return PulseCard(
      child: Padding(
        padding: const EdgeInsets.all(PulseTokens.s2),
        child: Row(
          children: [
            Icon(icon, color: pc.text2, size: 28),
            const SizedBox(width: PulseTokens.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  if (state.hasBackedUp)
                    Text(
                      l10n.backupLastSuccess(
                        _formatWhen(context, state.lastBackupAtMillis!),
                      ),
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: pc.text2),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatWhen(BuildContext context, int millis) {
    // A simple ISO date — canonical + unambiguous for the log line.
    final d = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: PulseTokens.s2,
              vertical: PulseTokens.s2,
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: pc.text2),
                const SizedBox(width: PulseTokens.s2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.bodyLarge),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: pc.text2)),
                    ],
                  ),
                ),
                Icon(Icons.adaptive.arrow_forward, size: 18, color: pc.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
