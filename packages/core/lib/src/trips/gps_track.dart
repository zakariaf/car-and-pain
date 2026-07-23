/// M7-T2 · pure on-device distance from a GPS track — no network, ever.
///
/// Distance is derived purely from local track points via the haversine great-
/// circle formula. There is **no online routing and no reverse geocoding**: this
/// works identically in airplane mode. The live sensor capture, the permission
/// rationale flow, and the always-visible active indicator are the app/device
/// lane; this is the math they lean on, kept pure so it is exhaustively testable.
///
/// Drift, tunnels, and signal loss are handled here as *filters*: a jump faster
/// than [GpsTrackReducer.maxSpeedMetresPerSecond] between two fixes is treated as
/// noise and dropped, and fixes closer than [GpsTrackReducer.minStepMetres] are
/// coalesced so a stationary phone does not accrue phantom metres. A track that
/// the OS killed mid-trip arrives as fragments; [GpsTrackReducer.mergeFragments]
/// stitches ordered pieces into one distance without double-counting the seam.
library;

import 'dart:math' as math;

/// One on-device position fix. [epochMillis] is a true UTC instant; lat/lon are
/// decimal degrees. No address, no place name — coordinates only.
final class GpsFix {
  const GpsFix({
    required this.epochMillis,
    required this.latitude,
    required this.longitude,
  });

  final int epochMillis;
  final double latitude;
  final double longitude;
}

/// Reduces raw fixes to a trustworthy distance.
final class GpsTrackReducer {
  const GpsTrackReducer({
    this.minStepMetres = 5,
    this.maxSpeedMetresPerSecond = 75, // ~270 km/h: above this is a GPS jump
  })  : assert(minStepMetres >= 0, 'step floor must be >= 0'),
        assert(maxSpeedMetresPerSecond > 0, 'max speed must be > 0');

  /// Steps shorter than this are noise (a parked phone jittering); coalesced.
  final double minStepMetres;

  /// A leg implying a speed above this is a GPS glitch (tunnel re-acquire, urban
  /// canyon bounce) and is dropped from the distance.
  final double maxSpeedMetresPerSecond;

  static const double _earthRadiusMetres = 6371000;

  /// Great-circle distance between two fixes (metres), haversine.
  static double haversineMetres(GpsFix a, GpsFix b) {
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLon = _toRadians(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return _earthRadiusMetres * c;
  }

  /// Total distance (whole metres, canonical) over an ordered track, dropping
  /// implausible jumps and coalescing sub-[minStepMetres] jitter. Fewer than two
  /// fixes → 0.
  int distanceMetres(List<GpsFix> orderedTrack) {
    if (orderedTrack.length < 2) return 0;
    var total = 0.0;
    var anchor = orderedTrack.first;
    for (var i = 1; i < orderedTrack.length; i++) {
      final fix = orderedTrack[i];
      final step = haversineMetres(anchor, fix);
      final dtSeconds = (fix.epochMillis - anchor.epochMillis) / 1000.0;
      // Drop a physically-impossible jump (keep the anchor; wait for a sane fix).
      if (dtSeconds > 0 && step / dtSeconds > maxSpeedMetresPerSecond) {
        continue;
      }
      // Coalesce jitter below the step floor (advance only when we truly moved).
      if (step < minStepMetres) continue;
      total += step;
      anchor = fix;
    }
    return total.round();
  }

  /// Stitch ordered fragments of an OS-interrupted track into one distance. The
  /// seam between fragments is bridged (the gap where the tracker was dead is
  /// counted once as a single straight leg, not dropped and not doubled).
  int mergeFragments(List<List<GpsFix>> orderedFragments) {
    final flat = <GpsFix>[
      for (final fragment in orderedFragments) ...fragment,
    ];
    return distanceMetres(flat);
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
}
