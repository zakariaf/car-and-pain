import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single vehicle's live profile stream (null once trashed/removed).
final vehicleProvider = StreamProvider.family<Vehicle?, String>(
  (ref, id) => ref.watch(vehiclesRepositoryProvider).watchVehicle(id),
);

/// A vehicle's odometer/engine-hour ledger, newest-first for the timeline.
final vehicleLedgerProvider =
    StreamProvider.family<List<LedgerReading>, String>(
  (ref, id) => ref.watch(ledgerRepositoryProvider).watchByVehicle(id),
);
