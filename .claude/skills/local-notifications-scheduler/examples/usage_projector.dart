// PURE, clock-injected projector: collapses DISTANCE and ENGINE-HOUR targets into
// a single TIME instant so ReminderScheduler handles one homogeneous list.
// No plugin, no IO, no DateTime.now() — inject a Clock (package:clock).
//
// Readings are canonical: odometer in whole metres, engine time in whole minutes.

import 'package:clock/clock.dart';

/// A single odometer or engine-hour reading (canonical units).
class Reading {
  final DateTime at;
  final num value; // metres, or minutes
  const Reading(this.at, this.value);
}

sealed class Projection {}

class ProjectedAt extends Projection {
  final DateTime when;
  ProjectedAt(this.when);
}

/// < minSamples, or a non-positive rate (dormant vehicle, typo, decreasing reading).
class InsufficientData extends Projection {}

/// Lands past the pending horizon — re-project on a later foreground.
class BeyondWindow extends Projection {}

class UsageProjector {
  final Clock clock;
  final int minSamples;
  const UsageProjector(this.clock, {this.minSamples = 3});

  Projection project({
    required List<Reading> history,
    required num target,
    required Duration horizon,
    Duration leadTime = Duration.zero,
  }) {
    if (history.length < minSamples) return InsufficientData();

    final rate = _rollingRatePerDay(history); // metres/day or minutes/day
    if (rate <= 0) return InsufficientData();  // dormant / typo / decreasing

    final latest = history.last;
    if (latest.value >= target) {
      return ProjectedAt(clock.now()); // already overdue -> fire now
    }

    final daysToTarget = (target - latest.value) / rate;
    final when = latest.at
        .add(Duration(
          milliseconds: (daysToTarget * Duration.millisecondsPerDay).round(),
        ))
        .subtract(leadTime); // a distance-lead is converted to days by the caller

    if (when.difference(clock.now()) > horizon) return BeyondWindow();
    return ProjectedAt(when);
  }

  num _rollingRatePerDay(List<Reading> h) {
    // Simple rolling average over the recent window; swap for EWMA if variance is
    // high. Widen the window and lower confidence on missed entries rather than
    // emitting wild figures. Apply any documented rollback offset before this.
    final first = h.first, last = h.last;
    final days = last.at.difference(first.at).inMilliseconds /
        Duration.millisecondsPerDay;
    if (days <= 0) return 0;
    return (last.value - first.value) / days;
  }
}
