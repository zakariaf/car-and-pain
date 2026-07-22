import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../features/01-vehicles-garage/presentation/vehicle_profile_screen.dart';
import '../routing/app_locations.dart';
import 'shell_state.dart';

/// The Garage Room root (M2-T5): the whole garage — active and non-active alike
/// — with script-normalized/digit-folded search, a per-row redundantly-encoded
/// lifecycle status, a single pinned default, and per-vehicle actions. Tapping a
/// vehicle makes it the active one (cross-module scope) and opens its profile.
class GarageScreen extends ConsumerStatefulWidget {
  const GarageScreen({super.key});

  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Vehicle v) {
    if (_query.isEmpty) return true;
    final needle = normalizeForSearch(_query);
    final hay = normalizeForSearch('${v.nickname} ${v.displayModel}');
    return hay.contains(needle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehicles = ref.watch(garageVehiclesProvider);
    final activeId = ref.watch(activeVehicleIdProvider);
    final filtered = vehicles.where(_matches).toList();

    return PulseScaffold(
      title: pulseLabel(l10n, 'room.garage'),
      body: vehicles.isEmpty
          ? Center(child: Text(l10n.garageEmpty))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.all(PulseTokens.s2),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: l10n.garageSearch,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final v in filtered)
                        _VehicleRow(vehicle: v, active: v.id == activeId),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _VehicleRow extends ConsumerWidget {
  const _VehicleRow({required this.vehicle, required this.active});
  final Vehicle vehicle;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isActiveStatus = vehicle.status == 'active';
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: PulseTokens.s2,
        vertical: PulseTokens.sHalf,
      ),
      child: PulseCard(
        // A transparent Material so the ListTile's ink paints on its own layer,
        // not the card's DecoratedBox.
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            leading: Icon(
              active
                  ? Icons.check_circle
                  : (isActiveStatus
                      ? Icons.directions_car_outlined
                      : Icons.inventory_2_outlined),
            ),
            title: Row(
              children: [
                Flexible(child: Text(vehicle.nickname)),
                if (vehicle.isDefault) ...[
                  const SizedBox(width: PulseTokens.s1),
                  StatusBadge(
                      status: PulseStatus.healthy,
                      label: l10n.garageDefaultBadge),
                ],
              ],
            ),
            // Redundant status: non-active vehicles carry the lifecycle word
            // here; an active vehicle shows its make/model, or nothing if unset.
            subtitle: isActiveStatus
                ? (vehicle.displayModel.isEmpty
                    ? null
                    : Text(vehicle.displayModel))
                : Text(vehicleStatusLabel(l10n, vehicle.status)),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => _onAction(context, ref, action),
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: 'default', child: Text(l10n.garageSetDefault)),
                PopupMenuItem(value: 'edit', child: Text(l10n.vehicleEdit)),
                PopupMenuItem(value: 'delete', child: Text(l10n.vehicleDelete)),
              ],
            ),
            onTap: () {
              ref
                  .read(shellStateControllerProvider)
                  .setActiveVehicle(vehicle.id);
              context.go(AppLocations.garageVehicle(vehicle.id));
            },
          ),
        ),
      ),
    );
  }

  void _onAction(BuildContext context, WidgetRef ref, String action) {
    final repo = ref.read(vehiclesRepositoryProvider);
    switch (action) {
      case 'default':
        repo.setDefault(vehicle.id);
      case 'edit':
        context.push(AppLocations.editVehicle(vehicle.id));
      case 'delete':
        repo.softDelete(vehicle.id);
    }
  }
}
