import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import '../settings/locale_controller.dart';
import 'attachment_format.dart';
import 'storage_controller.dart';

/// The PULSE Storage surface (F8-T8): the attachment size roll-up (total +
/// per-owner-type), the at-rest encryption toggle, and a reclaim-space action
/// that dry-runs then sweeps. Sizes render with the user's numerals; every
/// control is labelled and RTL-mirrored.
class StorageSettingsScreen extends ConsumerWidget {
  const StorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(storageControllerProvider);

    return PulseScaffold(
      title: l10n.storageTitle,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.attachmentLoadError)),
        data: (s) => _Body(snapshot: s),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.snapshot});
  final StorageSnapshot snapshot;

  StorageController _ctrl(WidgetRef ref) =>
      ref.read(storageControllerProvider.notifier);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(activeNumeralFormatProvider);
    final s = snapshot;

    return ListView(
      children: [
        _Section(l10n.storageUsage),
        PulseCard(
          child: Padding(
            padding: const EdgeInsets.all(PulseTokens.s2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UsageRow(
                  label: l10n.storageTotal,
                  value: formatByteSize(l10n, fmt, s.total),
                  emphasize: true,
                ),
                for (final e in s.byType)
                  _UsageRow(
                    label: l10n.attachmentOwnerLabel(e.key),
                    value: formatByteSize(l10n, fmt, e.value),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: PulseTokens.s2),
        SwitchListTile.adaptive(
          contentPadding:
              const EdgeInsetsDirectional.symmetric(horizontal: PulseTokens.s2),
          title: Text(l10n.storageEncryption,
              style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text(l10n.storageEncryptionDesc),
          value: s.encrypt,
          onChanged: (v) => _ctrl(ref).setEncrypt(value: v),
        ),
        _PlainRow(
          icon: Icons.auto_delete_outlined,
          label: l10n.storageReclaim,
          subtitle: l10n.storageReclaimDesc,
          onTap: () => _reclaim(context, ref),
        ),
      ],
    );
  }

  Future<void> _reclaim(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.read(activeNumeralFormatProvider);
    final preview = await _ctrl(ref).previewReclaim();
    if (!context.mounted) return;

    if (preview.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.storageNothingToReclaim)),
      );
      return;
    }

    final size = formatByteSize(l10n, fmt, ByteSize(preview.reclaimedBytes));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.storageReclaimConfirm(size)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.storageReclaim),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final report = await _ctrl(ref).reclaim();
    if (!context.mounted) return;
    final freed = formatByteSize(l10n, fmt, ByteSize(report.reclaimedBytes));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.storageReclaimed(freed))),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        emphasize ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge;
    return Padding(
      padding:
          const EdgeInsetsDirectional.symmetric(vertical: PulseTokens.sHalf),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
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

class _PlainRow extends StatelessWidget {
  const _PlainRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    return InkWell(
      onTap: onTap,
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
    );
  }
}
