/// Personal fuel-price memory (M3-T9) — the fully offline substitute for a live
/// price feed. Built purely from the user's OWN recorded fills; it is never
/// presented as live market pricing. Prices are thousandths of a major currency
/// unit per unit volume (3-decimal precision).
library;

import '../time/temporal.dart';

/// One observed price from history.
class PriceObservation {
  const PriceObservation({
    required this.at,
    required this.priceThousandths,
    this.station,
  });

  final Instant at;
  final int priceThousandths;
  final String? station;
}

/// Pure queries over a vehicle's price history. Newest observation wins.
class PriceMemory {
  const PriceMemory(this._observations);

  final List<PriceObservation> _observations;

  /// The most recent price recorded at each named station (unnamed fills are
  /// ignored here — see [latestOverall]).
  Map<String, int> latestByStation() {
    final byStation = <String, int>{};
    final newest = <String, int>{}; // station → its newest timestamp
    for (final o in _observations) {
      final s = o.station;
      if (s == null || s.isEmpty) continue;
      final ms = o.at.epochMillis;
      if (!newest.containsKey(s) || ms >= newest[s]!) {
        newest[s] = ms;
        byStation[s] = o.priceThousandths;
      }
    }
    return byStation;
  }

  /// The single most recent price across all stations — the default quick-add
  /// pre-fill. Null when there is no history.
  int? latestOverall() {
    PriceObservation? newest;
    for (final o in _observations) {
      if (newest == null || o.at.epochMillis >= newest.at.epochMillis) {
        newest = o;
      }
    }
    return newest?.priceThousandths;
  }

  /// The most recent price for [station], falling back to [latestOverall].
  int? latestFor(String? station) {
    if (station != null && station.isNotEmpty) {
      final byStation = latestByStation();
      if (byStation.containsKey(station)) return byStation[station];
    }
    return latestOverall();
  }
}
