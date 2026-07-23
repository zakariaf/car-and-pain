import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:notifications/notifications.dart';

/// The localized copy for a budget alert (M6-T3), resolved at the edge so this
/// service stays l10n-free.
typedef BudgetAlertCopy = ({String title, String body}) Function(
  Budget budget,
  int threshold,
  BudgetStatus status,
);

/// Fires a real F5 notification when a budget crosses an alert threshold (M6-T3),
/// once per crossing per period (deduped via [BudgetsRepository.recordAlert] state
/// that survives reboot). Delivery flows through the F5 [NotificationGateway] —
/// no parallel scheduler. Pure evaluation over the [BudgetEngine].
class BudgetAlertService {
  BudgetAlertService({
    required this.budgets,
    required this.expenses,
    required this.gateway,
    required this.copyFor,
    this.engine = const BudgetEngine(),
    Clock clock = const SystemClock(),
    this.thresholds = const [80, 100],
  }) : _clock = clock;

  final BudgetsRepository budgets;
  final ExpensesRepository expenses;
  final NotificationGateway gateway;
  final BudgetAlertCopy copyFor;
  final BudgetEngine engine;
  final List<int> thresholds;
  final Clock _clock;

  /// Evaluate every budget covering [vehicleId] and fire a notification for each
  /// NEW highest threshold crossing this period. Returns the number fired.
  Future<int> evaluate(String vehicleId) async {
    final now = _clock.nowUtc();
    final list = await budgets.watchForVehicle(vehicleId).first;
    var fired = 0;
    for (final b in list) {
      final (start, end, key, periodDays) = _period(b.period, now);
      final spent = await _spentInPeriod(
        vehicleId,
        categoryId: b.categoryId,
        start: start,
        end: end,
      );
      final status = engine.evaluate(
        targetMinor: b.targetMinor,
        spentToDateMinor: spent,
        elapsedDays: now.difference(start).inDays + 1,
        periodDays: periodDays,
      );
      final crossed = engine.crossedThresholds(status, thresholds);
      if (crossed.isEmpty) continue;
      final highest = crossed.first;
      // Dedup: only the same period's prior alert suppresses; a new period resets.
      final alreadyFired =
          b.lastAlertPeriod == key ? (b.lastAlertThreshold ?? 0) : 0;
      if (highest <= alreadyFired) continue;

      final copy = copyFor(b, highest, status);
      final ok = await gateway.schedule(ScheduledNotification(
        id: stableNotificationId('budget#${b.id}#$key#$highest'),
        when: Instant.fromEpochMillis(now.millisecondsSinceEpoch),
        title: copy.title,
        body: copy.body,
        channelId: highest >= 100 ? 'overdue' : 'dueSoon',
      ));
      if (ok.isOk) {
        await budgets.recordAlert(b.id, threshold: highest, periodKey: key);
        fired++;
      }
    }
    return fired;
  }

  Future<int> _spentInPeriod(
    String vehicleId, {
    required DateTime start,
    required DateTime end,
    String? categoryId,
  }) async {
    final rows = await expenses.inRange(
      vehicleId,
      sinceMillis: start.millisecondsSinceEpoch,
      untilMillis: end.millisecondsSinceEpoch,
    );
    return rows
        .where((e) => categoryId == null || e.categoryId == categoryId)
        // A projected cross-module row was counted by its own module; a budget
        // measures the canonical spend, so include only manual rows here.
        .where((e) => !e.isProjected)
        .fold<int>(0, (sum, e) => sum + e.baseAmountOrSelf);
  }

  /// The current period's [start, end), its dedup key, and its length in days.
  (DateTime, DateTime, String, int) _period(String period, DateTime now) {
    switch (period) {
      case 'annual':
        final start = DateTime.utc(now.year);
        final end = DateTime.utc(now.year + 1);
        return (start, end, '${now.year}', end.difference(start).inDays);
      case 'quarterly':
        final q = (now.month - 1) ~/ 3;
        final start = DateTime.utc(now.year, q * 3 + 1);
        final end = DateTime.utc(now.year, q * 3 + 4);
        return (
          start,
          end,
          '${now.year}-Q${q + 1}',
          end.difference(start).inDays
        );
      default: // monthly
        final start = DateTime.utc(now.year, now.month);
        final end = DateTime.utc(now.year, now.month + 1);
        final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        return (start, end, key, end.difference(start).inDays);
    }
  }
}
