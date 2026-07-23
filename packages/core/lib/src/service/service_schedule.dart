/// M4-T9 · the pure interval / next-due projection engine for Service &
/// Maintenance. Resolves the last-done anchor from a service type's history,
/// computes the absolute next-due thresholds, projects the distance dimension
/// onto the calendar, and grades OK / due-soon / overdue — all Clock-injected,
/// I/O-free, and exhaustively table-testable.
library;

import '../ledger/ledger.dart';
import '../scheduling/schedule_rule.dart';
import '../time/clock.dart';
import '../time/temporal.dart';

/// How a service type's interval governs: purely by distance, purely by time, or
/// whichever threshold arrives first (the shape most real schedules are written
/// in). Stored as the taxonomy default; overridable per vehicle.
enum ServiceIntervalLogic { distance, time, whicheverFirst }

/// OK / due-soon / overdue — plus [unknown] when there is no anchor or not enough
/// data to project. Downstream this is encoded **redundantly** (icon + label +
/// shape/position), never by colour alone (PULSE invariant).
enum ServiceDueLevel { ok, dueSoon, overdue, unknown }

/// One completed service event for a single service type — the raw input the
/// schedule engine anchors from. [doneAt] is the **true event date** (a back-
/// dated historical service carries its real date here, never the entry-creation
/// date). [odometerMetres] is null when the reading at that visit is unknown,
/// which forces a time-only fallback. [resetsInterval] false marks a top-up that
/// must NOT restart a full-change clock.
final class ServiceEvent {
  const ServiceEvent({
    required this.doneAt,
    this.odometerMetres,
    this.resetsInterval = true,
  });

  final Instant doneAt;
  final int? odometerMetres;
  final bool resetsInterval;
}

/// A service type's recurrence definition. Distance is canonical metres; time is
/// a calendar-correct [Recurrence] (months/years advance with end-of-month
/// clamping). Either dimension may be null so a type can be purely one kind;
/// [logic] resolves the governing dimension when both are present.
final class ServiceInterval {
  const ServiceInterval({
    required this.logic,
    this.distanceMetres,
    this.time,
  }) : assert(
          distanceMetres == null || distanceMetres > 0,
          'interval distance must be positive',
        );

  final ServiceIntervalLogic logic;
  final int? distanceMetres;
  final Recurrence? time;

  /// Whether this interval carries a usable distance dimension.
  bool get hasDistance => distanceMetres != null;

  /// Whether this interval carries a usable time dimension.
  bool get hasTime => time != null;
}

/// The computed last-done / next-due status for one service type on one vehicle —
/// the model behind a status card. Absolute thresholds are canonical (metres /
/// UTC instant); display conversion happens only at the edge.
final class ServiceDueStatus {
  const ServiceDueStatus({
    required this.level,
    required this.governing,
    required this.confidence,
    this.anchor,
    this.nextDueOdometerMetres,
    this.nextDueDate,
    this.remainingMetres,
    this.remainingTime,
    this.projectedDueDate,
  });

  /// No resetting service has been logged yet — nothing to project from.
  const ServiceDueStatus.noHistory()
      : level = ServiceDueLevel.unknown,
        governing = null,
        confidence = DueConfidence.exact,
        anchor = null,
        nextDueOdometerMetres = null,
        nextDueDate = null,
        remainingMetres = null,
        remainingTime = null,
        projectedDueDate = null;

  final ServiceDueLevel level;

  /// The dimension that actually governs the due state — the clock that reaches
  /// its threshold first. Null when unknown.
  final ServiceIntervalLogic? governing;
  final DueConfidence confidence;

  /// The resetting visit the projection is anchored to.
  final ServiceEvent? anchor;

  /// `anchor.odometer + interval.distance`. Null for a time-only rule or when the
  /// anchor's odometer is unknown.
  final int? nextDueOdometerMetres;

  /// `anchor.date + interval.time`. Null for a distance-only rule.
  final Instant? nextDueDate;

  /// `nextDueOdometer − currentOdometer` (negative when overdue). Null when there
  /// is no distance threshold or the current odometer is unknown.
  final int? remainingMetres;

  /// `nextDueDate − now` (negative when overdue). Null for distance-only.
  final Duration? remainingTime;

  /// The distance threshold projected onto the calendar from average daily
  /// distance — so a "due in 1,000 km" rule surfaces an estimated date. Null when
  /// there is no distance threshold or not enough ledger data.
  final Instant? projectedDueDate;

  bool get isOverdue => level == ServiceDueLevel.overdue;
}

/// The pure-Dart heart of service scheduling (M4-T9): isolated from persistence
/// and notifications so it is exhaustively unit-testable. It resolves the
/// last-done anchor from a service type's history (honouring reset flags and
/// back-dated true dates), computes the absolute next-due thresholds, resolves
/// the whichever-first governing dimension via average daily distance, and grades
/// the status. Deleting an anchor is modelled by simply passing a history without
/// it — the engine re-anchors to the previous valid resetting event.
///
/// It reuses [LedgerEngine.avgDailyValue] / [LedgerEngine.estimatedValueNow] —
/// the same projection primitive the F5 `NextDueEngine` uses — so the notify
/// side (M4-T5) and the card side stay consistent. Use [toScheduleRule] to hand
/// a resolved rule to `NextDueEngine` for OS firing (no parallel firing engine).
final class ServiceScheduleEngine {
  const ServiceScheduleEngine({
    Clock clock = const SystemClock(),
    LedgerEngine ledger = const LedgerEngine(),
  })  : _clock = clock,
        _ledger = ledger;

  final Clock _clock;
  final LedgerEngine _ledger;

  /// The most recent **resetting** event by true date — the anchor a top-up never
  /// becomes. Returns null when no resetting service exists.
  ServiceEvent? anchorOf(List<ServiceEvent> history) {
    ServiceEvent? anchor;
    for (final e in history) {
      // Top-ups never anchor a full-change clock.
      if (!e.resetsInterval) continue;
      if (anchor == null || e.doneAt.epochMillis > anchor.doneAt.epochMillis) {
        anchor = e;
      }
    }
    return anchor;
  }

  /// Grade one service type's [interval] against its [history] and the vehicle's
  /// current state. [odometerHistory] feeds the distance→date projection (may be
  /// empty). [dueSoonWindow] / [dueSoonMetres] set the early-warning bands.
  ServiceDueStatus status(
    ServiceInterval interval,
    List<ServiceEvent> history, {
    int? currentOdometerMetres,
    List<LedgerReading> odometerHistory = const [],
    Duration dueSoonWindow = const Duration(days: 14),
    int dueSoonMetres = 500000, // 500 km
  }) {
    final anchor = anchorOf(history);
    if (anchor == null) return const ServiceDueStatus.noHistory();

    final nowMs = _clock.nowUtc().millisecondsSinceEpoch;

    // ── Distance dimension (only when the anchor has a known reading) ─────────
    final hasDistance = interval.hasDistance && anchor.odometerMetres != null;
    int? nextDueOdo;
    int? remainingMetres;
    Instant? projectedDueDate;
    if (hasDistance) {
      nextDueOdo = anchor.odometerMetres! + interval.distanceMetres!;
      if (currentOdometerMetres != null) {
        remainingMetres = nextDueOdo - currentOdometerMetres;
      }
      projectedDueDate =
          _projectOdometerDate(nextDueOdo, odometerHistory, nowMs);
    }

    // ── Time dimension ───────────────────────────────────────────────────────
    Instant? nextDueDate;
    Duration? remainingTime;
    if (interval.hasTime) {
      nextDueDate = interval.time!.nextAfter(anchor.doneAt);
      remainingTime = Duration(milliseconds: nextDueDate.epochMillis - nowMs);
    }

    // Nothing usable to project from (e.g. distance-only rule with an unknown
    // historical odometer, and no time dimension) → unknown rather than a guess.
    if (nextDueOdo == null && nextDueDate == null) {
      return ServiceDueStatus(
        level: ServiceDueLevel.unknown,
        governing: null,
        confidence: DueConfidence.exact,
        anchor: anchor,
      );
    }

    // Grade each present dimension independently.
    final distanceLevel = nextDueOdo == null
        ? ServiceDueLevel.unknown
        : _gradeDistance(remainingMetres, dueSoonMetres);
    final timeLevel = nextDueDate == null
        ? ServiceDueLevel.unknown
        : _gradeTime(remainingTime, dueSoonWindow);

    // Whichever-first is the worst (soonest) of the two; a single-dim rule is its
    // own dimension. `whicheverFirst` with only one usable dimension degrades to
    // that dimension.
    final bothPresent = nextDueOdo != null && nextDueDate != null;
    final ServiceDueLevel level;
    final ServiceIntervalLogic governing;
    if (interval.logic == ServiceIntervalLogic.whicheverFirst && bothPresent) {
      level = _worst(distanceLevel, timeLevel);
      governing = _earliestClock(
        distanceDueDate: _distanceComparisonDate(
          remainingMetres: remainingMetres,
          projectedDueDate: projectedDueDate,
          nowMs: nowMs,
        ),
        timeDueDate: nextDueDate,
        distanceLevel: distanceLevel,
      );
    } else if (nextDueOdo != null && nextDueDate == null) {
      level = distanceLevel;
      governing = ServiceIntervalLogic.distance;
    } else if (nextDueDate != null && nextDueOdo == null) {
      level = timeLevel;
      governing = ServiceIntervalLogic.time;
    } else {
      // Both present but logic is distance-only or time-only: honour the logic.
      if (interval.logic == ServiceIntervalLogic.distance) {
        level = distanceLevel;
        governing = ServiceIntervalLogic.distance;
      } else {
        level = timeLevel;
        governing = ServiceIntervalLogic.time;
      }
    }

    // Confidence reflects how we know the governing due date: a calendar date is
    // exact; a distance date is projected, or uncertain when we cannot project.
    final confidence = governing == ServiceIntervalLogic.time
        ? DueConfidence.exact
        : projectedDueDate != null
            ? DueConfidence.projected
            : DueConfidence.uncertain;

    return ServiceDueStatus(
      level: level,
      governing: governing,
      confidence: confidence,
      anchor: anchor,
      nextDueOdometerMetres: nextDueOdo,
      nextDueDate: nextDueDate,
      remainingMetres: remainingMetres,
      remainingTime: remainingTime,
      projectedDueDate: projectedDueDate,
    );
  }

  /// Resolve the [interval] + [history] into the canonical [ScheduleRule] the F5
  /// `NextDueEngine` fires from — absolute thresholds anchored to the last
  /// resetting service. Returns null when there is no anchor to project from.
  ScheduleRule? toScheduleRule(
    ServiceInterval interval,
    List<ServiceEvent> history, {
    Duration leadTime = Duration.zero,
    int? leadDistanceMetres,
  }) {
    final anchor = anchorOf(history);
    if (anchor == null) return null;

    final hasDistance = interval.hasDistance && anchor.odometerMetres != null;
    final nextDueOdo =
        hasDistance ? anchor.odometerMetres! + interval.distanceMetres! : null;
    final nextDueDate =
        interval.hasTime ? interval.time!.nextAfter(anchor.doneAt) : null;

    final kind = switch (interval.logic) {
      ServiceIntervalLogic.time => TriggerKind.date,
      ServiceIntervalLogic.distance =>
        hasDistance ? TriggerKind.distance : TriggerKind.date,
      ServiceIntervalLogic.whicheverFirst =>
        (nextDueOdo != null && nextDueDate != null)
            ? TriggerKind.whicheverFirst
            : (nextDueOdo != null ? TriggerKind.distance : TriggerKind.date),
    };

    return ScheduleRule(
      kind: kind,
      dueDate: nextDueDate,
      dueOdometerMetres: nextDueOdo,
      leadTime: leadTime,
      leadDistanceMetres: leadDistanceMetres,
    );
  }

  // ── internals ──────────────────────────────────────────────────────────────

  /// Project the calendar date at which [threshold] metres is reached from the
  /// average daily distance. Null on insufficient data (< 2 readings, flat/zero
  /// rate) — the caller then treats distance as an uncertain estimate.
  Instant? _projectOdometerDate(
    int threshold,
    List<LedgerReading> odometerHistory,
    int nowMs,
  ) {
    final rate = _ledger.avgDailyValue(odometerHistory); // metres/day
    final estNow = _ledger.estimatedValueNow(odometerHistory);
    if (rate == null || estNow == null || rate <= 0) return null;
    if (estNow >= threshold) return Instant.fromEpochMillis(nowMs);
    final days = (threshold - estNow) / rate;
    return Instant.fromEpochMillis(
      nowMs + (days * Duration.millisecondsPerDay).round(),
    );
  }

  /// The date used to rank the distance clock against the time clock: `now` when
  /// already overdue by metres, the projected date otherwise (null if unknown).
  Instant? _distanceComparisonDate({
    required int? remainingMetres,
    required Instant? projectedDueDate,
    required int nowMs,
  }) {
    if (remainingMetres != null && remainingMetres <= 0) {
      return Instant.fromEpochMillis(nowMs);
    }
    return projectedDueDate;
  }

  ServiceIntervalLogic _earliestClock({
    required Instant? distanceDueDate,
    required Instant? timeDueDate,
    required ServiceDueLevel distanceLevel,
  }) {
    if (distanceDueDate == null && timeDueDate == null) {
      return distanceLevel != ServiceDueLevel.unknown
          ? ServiceIntervalLogic.distance
          : ServiceIntervalLogic.time;
    }
    if (distanceDueDate == null) return ServiceIntervalLogic.time;
    if (timeDueDate == null) return ServiceIntervalLogic.distance;
    return distanceDueDate.epochMillis <= timeDueDate.epochMillis
        ? ServiceIntervalLogic.distance
        : ServiceIntervalLogic.time;
  }

  ServiceDueLevel _worst(ServiceDueLevel a, ServiceDueLevel b) {
    int rank(ServiceDueLevel l) => switch (l) {
          ServiceDueLevel.overdue => 3,
          ServiceDueLevel.dueSoon => 2,
          ServiceDueLevel.ok => 1,
          ServiceDueLevel.unknown => 0,
        };
    return rank(a) >= rank(b) ? a : b;
  }

  ServiceDueLevel _gradeDistance(int? remainingMetres, int dueSoonMetres) {
    if (remainingMetres == null) return ServiceDueLevel.unknown;
    if (remainingMetres <= 0) return ServiceDueLevel.overdue;
    if (remainingMetres <= dueSoonMetres) return ServiceDueLevel.dueSoon;
    return ServiceDueLevel.ok;
  }

  ServiceDueLevel _gradeTime(Duration? remainingTime, Duration dueSoonWindow) {
    if (remainingTime == null) return ServiceDueLevel.unknown;
    if (remainingTime.inMilliseconds <= 0) return ServiceDueLevel.overdue;
    if (remainingTime <= dueSoonWindow) return ServiceDueLevel.dueSoon;
    return ServiceDueLevel.ok;
  }
}
