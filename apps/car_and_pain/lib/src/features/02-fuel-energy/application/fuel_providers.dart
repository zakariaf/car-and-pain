import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A vehicle's fuel/charge history, newest first (live).
final fuelHistoryProvider = StreamProvider.family<List<FuelEntry>, String>(
  (ref, id) => ref.watch(fuelRepositoryProvider).watchByVehicle(id),
);

/// The liquid economy report for a vehicle, recomputed whenever its fills
/// change. EV charges are excluded (a separate series).
final fuelEconomyProvider = FutureProvider.family<EconomyReport, String>(
  (ref, id) {
    // Depend on the history so the report recomputes reactively.
    ref.watch(fuelHistoryProvider(id));
    return ref.watch(fuelRepositoryProvider).economyReport(id);
  },
);
