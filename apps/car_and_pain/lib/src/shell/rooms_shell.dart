import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../routing/app_locations.dart';
import 'shell_state.dart';

/// The Rooms shell (M1-T2): the three-Room `indexedStack` body with the bottom
/// Rooms nav and a thumb-reachable quick-add. `indexedStack` keeps each Room's
/// stack + scroll alive across switches; re-tapping the active Room pops it to
/// root. The nav order + focus mirror automatically under RTL (the Row reads
/// `Directionality`); branch indices stay logical.
class RoomsShell extends ConsumerWidget {
  const RoomsShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: RoomsNav(
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) {
          ref
              .read(shellStateControllerProvider)
              .setLastRoom(Room.values[index].name);
          navigationShell.goBranch(
            index,
            // Re-tap the active Room → pop it to its root.
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
      floatingActionButton: QuickAddPill(
        // Room-aware quick-add lands on the feature flows (M2+); the shell just
        // owns the persistent, thumb-reachable entry point.
        onTap: () => context.push(AppLocations.garage),
      ),
    );
  }
}

/// The three-Room bottom nav — icon + label + plain-language sublabel per Room.
/// The active Room is encoded redundantly (filled icon + bold label + a shape
/// indicator), never colour alone; the indicator animation is gated by reduced
/// motion. Custom (not Material `NavigationBar`) so it carries the sublabel and
/// honours the reduced-motion contract.
class RoomsNav extends ConsumerWidget {
  const RoomsNav({
    required this.currentIndex,
    required this.onSelect,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pc = Theme.of(context).extension<PulseColorsExt>()!.c;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: pc.surface,
        border: Border(top: BorderSide(color: pc.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: PulseTokens.roomNav + 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final room in Room.values)
                _RoomTab(
                  room: room,
                  selected: room.index == currentIndex,
                  label: pulseLabel(l10n, room.labelKey),
                  sublabel: pulseLabel(l10n, room.subKey),
                  onTap: () => onSelect(room.index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomTab extends StatelessWidget {
  const _RoomTab({
    required this.room,
    required this.selected,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  final Room room;
  final bool selected;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    final tint = selected ? theme.colorScheme.primary : pc.text2;
    final animate = !reduceMotion(context);

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $sublabel',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: PulseTokens.tapMin,
              minHeight: PulseTokens.roomNav,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shape indicator (position channel): a top bar on the active
                // Room — instant under reduced motion.
                AnimatedContainer(
                  duration: animate ? PulseMotion.room : Duration.zero,
                  curve: PulseMotion.roomEase,
                  height: 3,
                  width: selected ? 24 : 0,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(PulseTokens.rPill),
                  ),
                ),
                const SizedBox(height: PulseTokens.s1),
                Icon(selected ? room.selectedIcon : room.icon, color: tint),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tint,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                Text(
                  sublabel,
                  style: theme.textTheme.labelSmall?.copyWith(color: pc.text3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The persistent quick-add entry point (M1-T2) — thumb-reachable in every Room.
class QuickAddPill extends StatelessWidget {
  const QuickAddPill({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.quickAdd,
      child: FloatingActionButton(
        onPressed: onTap,
        child: const Icon(Icons.add),
      ),
    );
  }
}
