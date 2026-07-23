import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

/// A vehicle's expense history, newest first (live).
final expenseHistoryProvider = StreamProvider.family<List<Expense>, String>(
  (ref, id) => ref.watch(expensesRepositoryProvider).watchByVehicle(id),
);

/// The editable expense-category taxonomy (built-in + custom) as a live list.
final expenseCategoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(taxonomyRepositoryProvider).watchByKind('expense'),
);

/// A vehicle's loan/lease financing as a live list.
final financingListProvider = StreamProvider.family<List<Financing>, String>(
  (ref, id) => ref.watch(financingRepositoryProvider).watchByVehicle(id),
);

/// A budget paired with its evaluated status (M6-T3/T6).
class BudgetMeter {
  const BudgetMeter({required this.budget, required this.status});
  final Budget budget;
  final BudgetStatus status;
}

/// The on-device TCO report for a vehicle (M6-T5/T6): sums the (non-projected)
/// expense ledger bucketed by analytic category + financing interest-to-date,
/// over the ledger's distance/day span, with the engine's insufficient-data
/// fallback. Recomputes when the expenses change.
final tcoReportProvider = FutureProvider.family<TcoReport, String>(
  (ref, vehicleId) async {
    ref.watch(expenseHistoryProvider(vehicleId)); // stay reactive
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final expenses = await ref
        .watch(expensesRepositoryProvider)
        .inRange(vehicleId, sinceMillis: 0, untilMillis: now);
    final categories =
        ref.watch(expenseCategoriesProvider).asData?.value ?? const [];
    final bucketOf = {for (final c in categories) c.id: c.analyticBucket};

    final costs = <TcoCostItem>[
      for (final e in expenses)
        if (!e.isProjected) // a projected row is already counted by its module
          TcoCostItem(
            bucket: e.categoryId == null
                ? 'other'
                : (bucketOf[e.categoryId] ?? 'other'),
            amountMinor: e.baseAmountOrSelf,
          ),
    ];

    // Financing interest paid to date across active loans/leases.
    final financings = await ref
        .watch(financingRepositoryProvider)
        .watchByVehicle(vehicleId)
        .first;
    var financingInterest = 0;
    for (final f in financings) {
      if (f.isClosed) continue;
      final schedule = const AmortizationEngine().schedule(f.toLoanTerms());
      final months = _elapsedMonths(f.startDate.epochMillis, now)
          .clamp(0, schedule.rows.length);
      financingInterest +=
          schedule.rows.take(months).fold(0, (sum, r) => sum + r.interestMinor);
    }

    // Distance + day denominators from the shared ledger.
    final ledger = await ref
        .watch(ledgerRepositoryProvider)
        .watchByVehicle(vehicleId)
        .first;
    var distance = 0;
    var spanDays = 0;
    if (ledger.length >= 2) {
      final first = ledger.first;
      final last = ledger.last;
      distance = last.lifetimeValue - first.lifetimeValue;
      spanDays =
          ((last.takenAt.epochMillis - first.takenAt.epochMillis) / 86400000)
              .round();
    }

    return const TcoEngine().compute(
      costs: costs,
      distanceMetres: distance < 0 ? 0 : distance,
      spanDays: spanDays,
      financingInterestMinor: financingInterest,
    );
  },
);

/// Per-budget meters for a vehicle (M6-T3/T6): each budget evaluated against
/// spend-to-date over its period, with a run-rate + upcoming projection.
final budgetMetersProvider =
    FutureProvider.family<List<BudgetMeter>, String>((ref, vehicleId) async {
  ref.watch(expenseHistoryProvider(vehicleId));
  final budgets = await ref
      .watch(budgetsRepositoryProvider)
      .watchForVehicle(vehicleId)
      .first;
  if (budgets.isEmpty) return const [];

  final repo = ref.watch(expensesRepositoryProvider);
  const engine = BudgetEngine();
  final nowUtc = DateTime.now().toUtc();

  final meters = <BudgetMeter>[];
  for (final b in budgets) {
    final (start, periodDays) = _periodWindow(b.budgetPeriod, nowUtc);
    final elapsedDays = nowUtc.difference(start).inDays.clamp(1, periodDays);
    final expenses = await repo.inRange(
      vehicleId,
      sinceMillis: start.millisecondsSinceEpoch,
      untilMillis: nowUtc.millisecondsSinceEpoch,
    );
    var spent = 0;
    for (final e in expenses) {
      if (e.isProjected) continue;
      if (b.categoryId != null && e.categoryId != b.categoryId) continue;
      spent += e.baseAmountOrSelf;
    }
    meters.add(BudgetMeter(
      budget: b,
      status: engine.evaluate(
        targetMinor: b.targetMinor,
        spentToDateMinor: spent,
        elapsedDays: elapsedDays,
        periodDays: periodDays,
      ),
    ));
  }
  return meters;
});

int _elapsedMonths(int startMillis, int nowMillis) {
  if (nowMillis <= startMillis) return 0;
  return ((nowMillis - startMillis) / (30.44 * 86400000)).floor();
}

(DateTime start, int days) _periodWindow(BudgetPeriod period, DateTime now) {
  return switch (period) {
    BudgetPeriod.monthly => (DateTime.utc(now.year, now.month), 30),
    BudgetPeriod.quarterly => (
        DateTime.utc(now.year, ((now.month - 1) ~/ 3) * 3 + 1),
        91,
      ),
    BudgetPeriod.annual => (DateTime.utc(now.year), 365),
  };
}

/// A localized amount with its currency code, formatted to the currency's real
/// exponent (0/2/3) with active numerals — never a hardcoded two decimals.
String formatMoney(NumeralFormat fmt, int minorUnits, String currencyCode) {
  final exp = Currency.tryParse(currencyCode)?.exponent ?? 2;
  return '${fmt.formatScaled(minorUnits, exp)} $currencyCode';
}

/// A localized calendar date for an expense [when] (active calendar + numerals).
String formatExpenseDate(CalendarSystem cal, NumeralFormat fmt, Instant when) {
  final d = CalendarDate.fromInstant(when, cal);
  return '${fmt.formatUngrouped(d.year)}/${fmt.formatUngrouped(d.month)}'
      '/${fmt.formatUngrouped(d.day)}';
}

/// The localized display name for an expense category. Custom categories are user
/// literals; seeded types resolve their dotted taxonomy key to an ARB string.
String expenseCategoryName(AppLocalizations l10n, Category type) {
  if (type.isCustom) return type.label;
  return switch (type.label) {
    'taxonomy.fuel' => l10n.expenseCategoryFuel,
    'taxonomy.insurance' => l10n.expenseCategoryInsurance,
    'taxonomy.tax' => l10n.expenseCategoryTax,
    'taxonomy.parking' => l10n.expenseCategoryParking,
    _ => type.label.replaceFirst('taxonomy.', ''), // i18n-ignore (custom key)
  };
}

/// The localized display name for an analytic bucket (TCO breakdown).
String bucketName(AppLocalizations l10n, String bucket) => switch (bucket) {
      'fuel' => l10n.expenseCategoryFuel,
      'insurance' => l10n.expenseCategoryInsurance,
      'tax' => l10n.expenseCategoryTax,
      'parking' => l10n.expenseCategoryParking,
      'service' => l10n.tcoBucketService,
      'financing' => l10n.tcoBucketFinancing,
      'depreciation' => l10n.tcoBucketDepreciation,
      _ => l10n.tcoBucketOther,
    };
