import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import 'trash_notifier.dart';

/// The Trash room (F2-T13): lists trashed items across entities with restore,
/// empty-trash, and a retention countdown. Status is encoded **redundantly**
/// (entity icon + type label + countdown text), never colour alone. RTL-aware
/// via Directional-only geometry.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  static IconData iconFor(String entityType) => switch (entityType) {
        'vehicles' => Icons.directions_car_outlined,
        'fuel_entries' => Icons.local_gas_station_outlined,
        'service_entries' => Icons.build_outlined,
        'expenses' => Icons.receipt_long_outlined,
        'trips' => Icons.route_outlined,
        'reminders' => Icons.notifications_outlined,
        _ => Icons.inventory_2_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final itemsAsync = ref.watch(trashItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trashTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: l10n.trashEmptyAll,
            onPressed: () =>
                ref.read(trashControllerProvider.notifier).emptyTrash(),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _empty(context, l10n),
        data: (items) => items.isEmpty
            ? _empty(context, l10n)
            : ListView.separated(
                padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: PulseTokens.s1),
                itemBuilder: (context, i) => _TrashTile(item: items[i]),
              ),
      ),
    );
  }

  Widget _empty(BuildContext context, AppLocalizations l10n) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: PulseTokens.s2),
            Text(l10n.trashEmpty, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
}

class _TrashTile extends ConsumerWidget {
  const _TrashTile({required this.item});

  final TrashItem item;

  int _daysLeft() {
    final expires = item.trashExpiresAt;
    if (expires == null) return 0;
    final ms = expires - DateTime.now().millisecondsSinceEpoch;
    final days = (ms / Duration.millisecondsPerDay).ceil();
    return days < 0 ? 0 : days;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    final type = item.entityType;

    return Container(
      decoration: BoxDecoration(
        color: pc.surface,
        borderRadius: BorderRadius.circular(PulseTokens.rCard),
        border: Border.all(color: pc.hairline),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: PulseTokens.s2,
        vertical: PulseTokens.s1,
      ),
      child: Row(
        children: [
          Icon(TrashScreen.iconFor(type), color: pc.text2),
          const SizedBox(width: PulseTokens.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.trashEntityName(type),
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  l10n.trashExpiresIn(_daysLeft()),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => ref
                .read(trashControllerProvider.notifier)
                .restore(type, item.id),
            child: Text(l10n.trashRestore),
          ),
        ],
      ),
    );
  }
}
