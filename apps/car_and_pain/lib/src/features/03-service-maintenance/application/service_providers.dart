import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

/// A vehicle's service-visit history, newest first (live).
final serviceHistoryProvider =
    StreamProvider.family<List<ServiceVisit>, String>(
  (ref, id) => ref.watch(serviceRepositoryProvider).watchByVehicle(id),
);

/// The editable service-type taxonomy (built-in + custom) as a live list.
final serviceTypesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(taxonomyRepositoryProvider).watchByKind('service'),
);

/// A per-service-type last-done / next-due status card model (M4-T4).
class ServiceStatusCard {
  const ServiceStatusCard({
    required this.type,
    this.status,
    this.lastDoneAt,
    this.lastDoneOdometerMetres,
  });

  final Category type;

  /// The graded next-due status — null when the type has no interval default
  /// (last-done is still shown).
  final ServiceDueStatus? status;
  final Instant? lastDoneAt;
  final int? lastDoneOdometerMetres;
}

/// Per-service-type status for a vehicle, recomputed whenever its history
/// changes. Only types with a logged resetting service surface a card. Distance
/// projection uses the shared ledger; the pure [ServiceScheduleEngine] grades it.
final serviceStatusProvider =
    FutureProvider.family<List<ServiceStatusCard>, String>(
        (ref, vehicleId) async {
  ref.watch(serviceHistoryProvider(vehicleId)); // stay reactive on new visits
  final types = ref.watch(serviceTypesProvider).asData?.value ?? const [];
  final repo = ref.watch(serviceRepositoryProvider);
  final events = await repo.serviceEventsByType(vehicleId);
  final ledger =
      await ref.watch(ledgerRepositoryProvider).watchByVehicle(vehicleId).first;

  int? currentOdo;
  var newest = -1;
  for (final r in ledger) {
    if (r.takenAt.epochMillis > newest) {
      newest = r.takenAt.epochMillis;
      currentOdo = r.value;
    }
  }

  const engine = ServiceScheduleEngine();
  final cards = <ServiceStatusCard>[];
  for (final type in types) {
    final evs = events[type.id];
    if (evs == null || evs.isEmpty) continue;
    final anchor = engine.anchorOf(evs);
    if (anchor == null) continue;
    final interval = _intervalFor(type);
    final status = interval == null
        ? null
        : engine.status(
            interval,
            evs,
            currentOdometerMetres: currentOdo,
            odometerHistory: ledger,
          );
    cards.add(
      ServiceStatusCard(
        type: type,
        status: status,
        lastDoneAt: anchor.doneAt,
        lastDoneOdometerMetres: anchor.odometerMetres,
      ),
    );
  }
  return cards;
});

/// Build a [ServiceInterval] from a service type's taxonomy defaults, or null
/// when it carries no interval (a card then shows last-done only).
ServiceInterval? _intervalFor(Category t) {
  final hasDist = t.defaultIntervalMetres != null;
  final hasTime = t.defaultIntervalMonths != null;
  if (!hasDist && !hasTime) return null;
  final logic = switch (t.defaultIntervalLogic) {
    'distance' => ServiceIntervalLogic.distance,
    'time' => ServiceIntervalLogic.time,
    'whicheverFirst' => ServiceIntervalLogic.whicheverFirst,
    _ => hasDist && hasTime
        ? ServiceIntervalLogic.whicheverFirst
        : (hasDist ? ServiceIntervalLogic.distance : ServiceIntervalLogic.time),
  };
  return ServiceInterval(
    logic: logic,
    distanceMetres: t.defaultIntervalMetres,
    time: t.defaultIntervalMonths == null
        ? null
        : Recurrence(t.defaultIntervalMonths!, RecurrenceUnit.months),
  );
}

/// A localized calendar date for a service [when] — projected into the active
/// [cal] system with numerals shaped by [fmt] (YYYY/MM/DD, canonical stored UTC
/// converted only for display).
String formatServiceDate(CalendarSystem cal, NumeralFormat fmt, Instant when) {
  final d = CalendarDate.fromInstant(when, cal);
  return '${fmt.formatUngrouped(d.year)}/${fmt.formatUngrouped(d.month)}'
      '/${fmt.formatUngrouped(d.day)}';
}

/// The localized display name for a service type (M4-T4/T6). Custom types are
/// user literals (shown as-is); seeded types resolve their dotted taxonomy key
/// to an ARB string, falling back to the de-prefixed key for an unknown key.
String serviceTypeName(AppLocalizations l10n, Category type) {
  if (type.isCustom) return type.label;
  return switch (type.label) {
    'taxonomy.oil_change' => l10n.serviceTypeOilChange,
    'taxonomy.brakes' => l10n.serviceTypeBrakes,
    _ => type.label.replaceFirst('taxonomy.', ''), // i18n-ignore (custom key)
  };
}
