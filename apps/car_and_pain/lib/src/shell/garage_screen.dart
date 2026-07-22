import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../routing/app_locations.dart';
import 'shell_state.dart';

/// The Garage Room root — the cars and their care. A live list of active
/// vehicles; a vehicle detail route (`/garage/:vehicleId`) lands on M2's screen.
class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vehicles = ref.watch(activeVehiclesProvider);
    final activeId = ref.watch(activeVehicleIdProvider);

    return PulseScaffold(
      title: pulseLabel(l10n, 'room.garage'),
      body: vehicles.isEmpty
          ? Center(child: Text(l10n.attachmentsEmpty))
          : ListView(
              children: [
                for (final v in vehicles)
                  ListTile(
                    leading: Icon(
                      v.id == activeId
                          ? Icons.check_circle
                          : Icons.directions_car_outlined,
                    ),
                    title: Text(v.nickname),
                    subtitle: v.make == null
                        ? null
                        // User data (make + model), not localizable UI copy.
                        : Text(
                            '${v.make} ${v.model ?? ''}'.trim()), // i18n-ignore
                    onTap: () {
                      // Opening a vehicle makes it the active one (cross-module
                      // scope) and navigates to its profile (M2-T6).
                      ref
                          .read(shellStateControllerProvider)
                          .setActiveVehicle(v.id);
                      context.go(AppLocations.garageVehicle(v.id));
                    },
                  ),
              ],
            ),
    );
  }
}
