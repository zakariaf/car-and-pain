import '../scheduling/schedule_rule.dart';
import '../time/temporal.dart';

/// A reminder paired with its evaluated [DueResult], fed to the Home readiness
/// aggregation (M1-T5). The caller runs `NextDueEngine` upstream (it needs the
/// ledger) and passes the results here; this layer is pure timing arithmetic.
class ReminderDue {
  const ReminderDue({
    required this.reminderId,
    required this.title,
    required this.due,
  });

  final String reminderId;
  final String title;
  final DueResult due;
}

/// The single "needs you now" acute-ache card — the worst open reminder. It may
/// carry urgency up to 4 (ember/pomegranate) even though the ambient halo is
/// capped at 2.
class AcuteAche {
  const AcuteAche({
    required this.reminderId,
    required this.title,
    required this.urgency,
    required this.dueAt,
  });

  final String reminderId;
  final String title;
  final int urgency;
  final Instant dueAt;

  @override
  bool operator ==(Object other) =>
      other is AcuteAche &&
      other.reminderId == reminderId &&
      other.title == title &&
      other.urgency == urgency &&
      other.dueAt == dueAt;

  @override
  int get hashCode => Object.hash(reminderId, title, urgency, dueAt);
}

/// The one readiness vital the Cockpit "Now" renders (M1-T4/T5).
class ReadinessSummary {
  const ReadinessSummary({
    required this.score,
    required this.urgency,
    required this.haloUrgency,
    this.ache,
  });

  /// A calm, ready-to-drive summary — a brand-new car with no history reads
  /// this, never a fabricated ache.
  static const ReadinessSummary calm =
      ReadinessSummary(score: 100, urgency: 0, haloUrgency: 0);

  /// 0..100 readiness (higher = more ready); animates as a count-up.
  final int score;

  /// 0..4 aggregate urgency of the worst open reminder (drives the StatusBadge).
  final int urgency;

  /// 0..2 halo urgency — the aggregate `clamp(worst, 0, 2)`, so the day-halo
  /// never warms past saffron regardless of how many pressing/overdue cards.
  final int haloUrgency;

  /// The single worst open reminder, or null when everything is calm.
  final AcuteAche? ache;

  bool get isCalm => urgency == 0;

  @override
  bool operator ==(Object other) =>
      other is ReadinessSummary &&
      other.score == score &&
      other.urgency == urgency &&
      other.haloUrgency == haloUrgency &&
      other.ache == ache;

  @override
  int get hashCode => Object.hash(score, urgency, haloUrgency, ache);
}

/// Map one [DueResult] to an urgency 0..4 given [now]. Derived from TIMING (not
/// the notification channel): overdue once past `dueAt`, "soon" once inside the
/// lead window (past `fireAt`), scheduled further out. `NoDue`/`InsufficientData`
/// contribute nothing (0) — an estimate-pending rule never fabricates an ache.
int urgencyForDue(DueResult due, Instant now) => switch (due) {
      Due(:final next) => now.epochMillis >= next.dueAt.epochMillis
          ? 4 // overdue
          : now.epochMillis >= next.fireAt.epochMillis
              ? 2 // soon — the lead/"due soon" window is open
              : 1, // scheduled — further out
      InsufficientData() => 0,
      NoDue() => 0,
    };

// Per-reminder readiness cost by urgency 0..4.
const List<int> _penalty = [0, 5, 15, 30, 40];

/// Aggregate a scope's already-evaluated [reminders] into the single readiness
/// vital (M1-T5). Pure + deterministic — all time flows through [now]. Empty or
/// insufficient history reads calm (urgency 0, score 100). The acute-ache is the
/// highest-urgency open reminder, ties broken by the earliest `dueAt`.
ReadinessSummary aggregateReadiness({
  required Instant now,
  required List<ReminderDue> reminders,
}) {
  var worst = 0;
  var penalty = 0;
  ReminderDue? worstReminder;
  Instant? worstDueAt;

  for (final r in reminders) {
    final u = urgencyForDue(r.due, now);
    penalty += _penalty[u];
    if (u == 0 || r.due is! Due) continue;
    final dueAt = (r.due as Due).next.dueAt;
    final better = u > worst ||
        (u == worst &&
            (worstDueAt == null || dueAt.epochMillis < worstDueAt.epochMillis));
    if (better) {
      worst = u;
      worstReminder = r;
      worstDueAt = dueAt;
    }
  }

  return ReadinessSummary(
    score: (100 - penalty).clamp(0, 100),
    urgency: worst,
    haloUrgency: worst > 2 ? 2 : worst,
    ache: worst == 0 || worstReminder == null
        ? null
        : AcuteAche(
            reminderId: worstReminder.reminderId,
            title: worstReminder.title,
            urgency: worst,
            dueAt: worstDueAt!,
          ),
  );
}
