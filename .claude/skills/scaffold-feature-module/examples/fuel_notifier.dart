// Illustrative — a real filled-in feature Notifier for features/02-fuel-energy/.
// Shows the finished shape the template becomes: a scoped stream provider, a command
// Notifier, and a derived analytics provider composed from other providers.
//
// This is a reference sample, not wired into a build.

import 'package:core/core.dart'; // Result, Ok, Err, Failure, Distance, Volume, Money, FuelEconomy
import 'package:data/data.dart'; // fuelRepositoryProvider, serviceRepositoryProvider (packages/data)
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/fuel_entry.dart';

part 'fuel_notifier.g.dart';

/// Reactive backbone — scoped by vehicle so a fill for car A never re-emits for car B.
/// The repository returns FuelEntry domain models (Volume/Money value objects), never Drift rows.
@riverpod
Stream<List<FuelEntry>> fuelEntries(Ref ref, String vehicleId) =>
    ref.watch(fuelRepositoryProvider).watchFuelEntries(vehicleId);

/// Derived analytics: memoized, recomputed only when the underlying stream changes.
/// Expensive compute is offloaded off the UI thread and kept alive across navigation.
@riverpod
Future<FuelEconomy> fuelEconomy(Ref ref, String vehicleId) async {
  final entries = await ref.watch(fuelEntriesProvider(vehicleId).future);
  final link = ref.keepAlive(); // survive navigate-away; recompute is DB-revision driven
  ref.onDispose(link.close);
  // Pure math lives in `core`; we only wire it here. Heavy sets -> Isolate.run.
  return Isolate.run(() => FuelEconomy.fromEntries(entries));
}

/// The ViewModel for the quick-log sheet (A3). autoDispose — one per open sheet.
@riverpod
class FuelLogController extends _$FuelLogController {
  @override
  FutureOr<void> build() {}

  /// "Enter any two of {litres, price/L, total}" — the app derives the third in `core`,
  /// not in the widget. Money is integer minor units; Volume is canonical SI litres.
  Future<void> logFill({
    required String vehicleId,
    required Volume litres,
    required Money total,
    required Distance odometer,
  }) async {
    state = const AsyncLoading();
    final draft = FuelEntry.draft(
      vehicleId: vehicleId,
      litres: litres,
      total: total,
      odometer: odometer,
    );
    final Result<void, Failure> result =
        await ref.read(fuelRepositoryProvider).addFuelEntry(draft);
    state = switch (result) {
      Ok() => const AsyncData(null), // View fires the "exhale" (cool + haptic) on success
      Err(:final failure) => AsyncError(failure, StackTrace.current),
    };
  }
}
