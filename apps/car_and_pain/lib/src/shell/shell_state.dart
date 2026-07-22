import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/locale_controller.dart';

/// The scope every downstream dashboard/list/stat reads (M1-T3).
enum VehicleScope { perVehicle, allVehicles, fleet }

/// Vehicle lifecycle statuses that are NOT part of the active scope — sold,
/// archived, etc. are excluded (never silently mixed into "what's due now").
const Set<String> _inactiveStatuses = {
  'sold',
  'archived',
  'scrapped',
  'stolen',
  'written_off',
};

/// Whether a vehicle participates in the active scope.
bool isActiveVehicle(Vehicle v) => !_inactiveStatuses.contains(v.status);

/// Resolve the active vehicle id (M1-T3): the persisted default if it is still
/// an active vehicle, else the first active vehicle (graceful fallback when the
/// pinned vehicle was deleted/sold), else null. Pure + table-tested.
String? resolveActiveVehicleId(List<Vehicle> activeVehicles, String? pinned) {
  if (pinned != null && activeVehicles.any((v) => v.id == pinned)) {
    return pinned;
  }
  return activeVehicles.isEmpty ? null : activeVehicles.first.id;
}

/// The vehicle ids the current scope covers. Pure.
List<String> scopedVehicleIds(
  VehicleScope scope,
  List<Vehicle> activeVehicles,
  String? activeVehicleId,
) =>
    switch (scope) {
      VehicleScope.perVehicle => [
          if (activeVehicleId != null) activeVehicleId,
        ],
      VehicleScope.allVehicles ||
      VehicleScope.fleet =>
        activeVehicles.map((v) => v.id).toList(),
    };

// ── Providers ───────────────────────────────────────────────────────────────

/// All vehicles as a live stream.
final vehiclesStreamProvider = StreamProvider<List<Vehicle>>(
  (ref) => ref.watch(vehiclesRepositoryProvider).watchAll(),
);

/// The whole garage — every non-trashed vehicle (active AND non-active), for
/// the Garage Room's management surface (M2-T5). Active-scope filtering for
/// dashboards/stats uses [activeVehiclesProvider] instead.
final garageVehiclesProvider = Provider<List<Vehicle>>(
  (ref) => ref.watch(vehiclesStreamProvider).asData?.value ?? const [],
);

/// The active (non-sold/archived) vehicles the scope operates over.
final activeVehiclesProvider = Provider<List<Vehicle>>((ref) {
  final all = ref.watch(vehiclesStreamProvider).asData?.value ?? const [];
  return all.where(isActiveVehicle).toList();
});

/// The active vehicle id (persisted default, else first active, else null).
final activeVehicleIdProvider = Provider<String?>((ref) {
  final settings = ref.watch(settingsMapProvider).asData?.value ?? const {};
  final pinned = settings[SettingsKeys.defaultVehicleId];
  return resolveActiveVehicleId(ref.watch(activeVehiclesProvider), pinned);
});

/// The active vehicle, or null when there are none.
final activeVehicleProvider = Provider<Vehicle?>((ref) {
  final id = ref.watch(activeVehicleIdProvider);
  if (id == null) return null;
  for (final v in ref.watch(activeVehiclesProvider)) {
    if (v.id == id) return v;
  }
  return null;
});

/// The current scope (persisted; defaults to per-vehicle).
final scopeProvider = Provider<VehicleScope>((ref) {
  final raw = ref.watch(settingsMapProvider).asData?.value[SettingsKeys.scope];
  return VehicleScope.values.asNameMap()[raw] ?? VehicleScope.perVehicle;
});

/// The vehicle ids in the current scope (reactive over scope + active vehicle).
final scopedVehicleIdsProvider = Provider<List<String>>(
  (ref) => scopedVehicleIds(
    ref.watch(scopeProvider),
    ref.watch(activeVehiclesProvider),
    ref.watch(activeVehicleIdProvider),
  ),
);

/// Persists shell UI state (active vehicle, scope, last Room) through the
/// settings repository (M1-T3/T10) — one canonical boundary, not ad-hoc keys.
final shellStateControllerProvider = Provider<ShellStateController>(
  (ref) => ShellStateController(ref.read(settingsRepositoryProvider)),
);

class ShellStateController {
  const ShellStateController(this._settings);
  final SettingsRepository _settings;

  Future<Result<void, DbFailure>> setActiveVehicle(String id) =>
      _settings.set(SettingsKeys.defaultVehicleId, id);

  Future<Result<void, DbFailure>> setScope(VehicleScope scope) =>
      _settings.set(SettingsKeys.scope, scope.name);

  Future<Result<void, DbFailure>> setLastRoom(String roomName) =>
      _settings.set(SettingsKeys.lastRoom, roomName);
}
