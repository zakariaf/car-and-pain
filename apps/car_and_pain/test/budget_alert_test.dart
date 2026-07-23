import 'package:car_and_pain/src/notifications/budget_alert_service.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';

/// M6-T3 — the budget-alert service fires a real F5 notification on a threshold
/// crossing, once per crossing per period (deduped), escalating and resetting.
void main() {
  test('crossing fires once, escalates to 100%, dedups, resets next period',
      () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final v = (await VehiclesRepository(db).add(nickname: 'Golf')).valueOrNull!;
    final budgets = BudgetsRepository(db);
    final expenses = ExpensesRepository(db);
    final gateway = FakeNotificationGateway();

    final budgetId = (await budgets.add(
      period: 'monthly',
      targetMinor: 10000,
      currencyCode: 'EUR',
      vehicleId: v.id,
    ))
        .valueOrNull!;

    BudgetAlertService serviceAt(DateTime now) => BudgetAlertService(
          budgets: budgets,
          expenses: expenses,
          gateway: gateway,
          clock: FixedClock(now),
          copyFor: (b, threshold, status) =>
              (title: 'Budget $threshold%', body: 'over'),
        );

    Future<void> spend(int amount, DateTime at) => expenses.add(
          vehicleId: v.id,
          spentAt: Instant.fromDateTime(at),
          amountMinor: amount,
          currencyCode: 'EUR',
        );

    // 85% of a 10_000 monthly budget in July → crosses 80% → one alert.
    await spend(8500, DateTime.utc(2026, 7, 10));
    expect(await serviceAt(DateTime.utc(2026, 7, 15)).evaluate(v.id), 1);
    expect(gateway.scheduled, hasLength(1));

    // Re-evaluating the same period fires nothing more (dedup).
    expect(await serviceAt(DateTime.utc(2026, 7, 16)).evaluate(v.id), 0);
    expect(gateway.scheduled, hasLength(1));

    // Push over 100% → escalates → a second alert.
    await spend(2000, DateTime.utc(2026, 7, 17));
    expect(await serviceAt(DateTime.utc(2026, 7, 18)).evaluate(v.id), 1);
    expect(gateway.scheduled, hasLength(2));
    expect((await budgets.byId(budgetId))!.lastAlertThreshold, 100);

    // A new month resets the dedup: the same (still-over) spend re-alerts once.
    await spend(9000, DateTime.utc(2026, 8, 5));
    expect(await serviceAt(DateTime.utc(2026, 8, 10)).evaluate(v.id), 1);
    expect(gateway.scheduled, hasLength(3));
  });
}
