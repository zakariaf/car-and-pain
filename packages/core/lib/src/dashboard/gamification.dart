/// M8-T7 · lightweight streaks & badges (pure Dart).
///
/// Rewards consistent logging from the user's OWN aggregates — no network, no
/// telemetry, no leaderboard. Streaks count consecutive logged periods;
/// milestone badges measure against the user's own history. The presentation
/// layer fires the PULSE exhale when a new badge is earned; this engine only
/// computes state, deterministically.
library;

/// A streak of consecutive logged periods.
final class Streak {
  const Streak({required this.current, required this.longest});

  final int current;
  final int longest;

  bool get isActive => current > 0;
}

/// Milestone badges, measured against the user's own baseline/history.
enum Badge {
  firstLog,
  distance1000km,
  distance10000km,
  distance100000km,
  economyImproved,
  tidyLogbook,
}

/// The gamification engine.
final class GamificationEngine {
  const GamificationEngine();

  /// Compute the streak from period indices (e.g. months since epoch) that have
  /// at least one logged entry. Consecutive integers extend the streak; a gap
  /// breaks it. [currentPeriod] anchors the *current* streak: it only counts if
  /// the most recent logged period is the current one or the one just before
  /// (so a lapsed streak reads as 0 current, preserving the longest).
  Streak streak(List<int> loggedPeriods, {required int currentPeriod}) {
    if (loggedPeriods.isEmpty) return const Streak(current: 0, longest: 0);
    final sorted = loggedPeriods.toSet().toList()..sort();
    var longest = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] == sorted[i - 1] + 1) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }
    // The current streak is the trailing run, but only if it reaches up to
    // (or one short of) the current period — otherwise it has lapsed.
    final last = sorted.last;
    var current = 0;
    if (last >= currentPeriod - 1) {
      current = 1;
      for (var i = sorted.length - 1; i > 0; i--) {
        if (sorted[i] == sorted[i - 1] + 1) {
          current++;
        } else {
          break;
        }
      }
    }
    return Streak(current: current, longest: longest);
  }

  /// The set of badges earned given the user's own milestones. [economyImproved]
  /// is true when the recent economy beats the earlier baseline; [tidyLogbook]
  /// when there are no outstanding unclassified/anomalous entries.
  Set<Badge> badges({
    required int totalDistanceMetres,
    required int loggedEntries,
    bool economyImproved = false,
    bool tidyLogbook = false,
  }) {
    final earned = <Badge>{};
    if (loggedEntries > 0) earned.add(Badge.firstLog);
    if (totalDistanceMetres >= 1000000) earned.add(Badge.distance1000km);
    if (totalDistanceMetres >= 10000000) earned.add(Badge.distance10000km);
    if (totalDistanceMetres >= 100000000) earned.add(Badge.distance100000km);
    if (economyImproved) earned.add(Badge.economyImproved);
    if (tidyLogbook) earned.add(Badge.tidyLogbook);
    return earned;
  }

  /// Badges newly earned this evaluation (in [now] but not [previous]) — the set
  /// that should trigger the exhale.
  Set<Badge> newlyEarned(Set<Badge> previous, Set<Badge> now) =>
      now.difference(previous);
}
