import 'package:car_and_pain/src/features/01-vehicles-garage/application/vehicle_profile_providers.dart';
import 'package:car_and_pain/src/features/05-expenses-cost-ownership/application/expense_providers.dart';
import 'package:car_and_pain/src/features/05-expenses-cost-ownership/presentation/budget_meters_screen.dart';
import 'package:car_and_pain/src/features/05-expenses-cost-ownership/presentation/expense_quick_add_screen.dart';
import 'package:car_and_pain/src/features/05-expenses-cost-ownership/presentation/expenses_screen.dart';
import 'package:car_and_pain/src/features/05-expenses-cost-ownership/presentation/financing_detail_screen.dart';
import 'package:car_and_pain/src/features/05-expenses-cost-ownership/presentation/tco_screen.dart';
import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

/// M6-T6/T7: the expense & cost-of-ownership surfaces. The Drift `.watch()`-backed
/// providers are stubbed with fixed streams/futures so no pending timer survives
/// teardown; the pure engines (TCO/budget/amortization) are exercised for real so
/// the screens render engine-shaped data, not hand-faked numbers.
void main() {
  setUpAll(() => EditableText.debugDeterministicCursor = true);
  tearDownAll(() => EditableText.debugDeterministicCursor = false);

  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  // The three overrides every screen needs: the in-memory DB, a synchronous
  // (empty) settings stream driving locale/numerals/calendar to their defaults,
  // and a null vehicle (currency falls back to EUR). No return annotation, so the
  // inferred element type stays the (non-exported) Override — spread cleanly into
  // a ProviderScope's `overrides:` below without ever naming it.
  // ignore: always_declare_return_types  (Override is not a public type name)
  base() => [
        appDatabaseProvider.overrideWithValue(db),
        settingsMapProvider
            .overrideWith((ref) => Stream.value(const <String, String>{})),
        vehicleProvider.overrideWith((ref, id) => Stream<Vehicle?>.value(null)),
      ];

  // The host route + localized MaterialApp.router. A '/' button pushes the screen
  // under test onto '/x' so `context.push`/`context.pop` behave as in the app.
  Widget scaffold(Widget child, {Locale locale = const Locale('en')}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, __) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/x'),
                child: const Text('home'), // i18n-ignore (test scaffold)
              ),
            ),
          ),
        ),
        GoRoute(path: '/x', builder: (_, __) => child),
      ],
    );
    return MaterialApp.router(
      theme: pulseTheme(Brightness.light),
      locale: locale,
      localizationsDelegates: carAndPainLocalizationsDelegates,
      supportedLocales: carAndPainSupportedLocales,
      routerConfig: router,
    );
  }

  Future<void> open(WidgetTester t, Widget app) async {
    t.view.physicalSize = const Size(1400, 3600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(app);
    await t.pumpAndSettle();
    await t.tap(find.text('home'));
    await t.pumpAndSettle();
  }

  // --- Fixtures ------------------------------------------------------------
  const fuelCat = Category(
    id: 'c-fuel',
    kind: 'expense',
    label: 'taxonomy.fuel',
    analyticBucket: 'fuel',
  );
  const expense = Expense(
    id: 'e1',
    vehicleId: 'v',
    spentAt: Instant.fromEpochMillis(1000),
    amountMinor: 2550,
    currencyCode: 'EUR',
    categoryId: 'c-fuel',
  );
  const budget = Budget(
    id: 'b1',
    period: 'monthly',
    targetMinor: 10000,
    currencyCode: 'EUR',
    vehicleId: 'v',
  );
  // Spent > target → a genuinely over-budget evaluated status.
  final overMeter = BudgetMeter(
    budget: budget,
    status: const BudgetEngine().evaluate(
      targetMinor: 10000,
      spentToDateMinor: 15000,
      elapsedDays: 15,
      periodDays: 30,
    ),
  );
  // Distance + span both below the engine's floors → insufficient-data fallback.
  final thinReport = const TcoEngine().compute(
    costs: const [TcoCostItem(bucket: 'fuel', amountMinor: 5000)],
    distanceMetres: 5000,
    spanDays: 3,
  );
  const financing = Financing(
    id: 'f1',
    vehicleId: 'v',
    kind: 'loan',
    principalMinor: 2000000,
    currencyCode: 'EUR',
    aprBps: 500,
    termMonths: 24,
    startDate: Instant.fromEpochMillis(1000),
  );

  testWidgets('quick-add renders its fields and saves an expense', (t) async {
    // A real vehicle row so the expense FK resolves (the canonical ledger write).
    final vehicle =
        (await VehiclesRepository(db).add(nickname: 'Golf')).valueOrNull!;
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          expenseCategoriesProvider
              .overrideWith((ref) => Stream.value(const <Category>[fuelCat])),
        ],
        child: scaffold(ExpenseQuickAddScreen(vehicleId: vehicle.id)),
      ),
    );

    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await t.enterText(find.byType(TextField).first, '25.50');
    await t.tap(find.text('Save'));
    await t.pump(); // kick off _save (the add transaction)

    // The canonical expense row was written to the ledger. Drift I/O runs on the
    // real event loop, so read it via runAsync (a bare await would stall the
    // widget-test fake clock).
    final rows = await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return ExpensesRepository(db).watchByVehicle(vehicle.id).first;
    });
    expect(rows, hasLength(1));
    expect(rows!.single.amountMinor, 2550);
  });

  testWidgets('the expense timeline lists an entry with category + currency',
      (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          expenseHistoryProvider.overrideWith(
              (ref, id) => Stream.value(const <Expense>[expense])),
          expenseCategoriesProvider
              .overrideWith((ref) => Stream.value(const <Category>[fuelCat])),
        ],
        child: scaffold(const ExpensesScreen(vehicleId: 'v')),
      ),
    );

    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Fuel'), findsOneWidget); // resolved taxonomy label
    expect(find.textContaining('EUR'), findsOneWidget); // formatted money
  });

  testWidgets('the expense timeline shows the empty state', (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          expenseHistoryProvider
              .overrideWith((ref, id) => Stream.value(const <Expense>[])),
          expenseCategoriesProvider
              .overrideWith((ref) => Stream.value(const <Category>[])),
        ],
        child: scaffold(const ExpensesScreen(vehicleId: 'v')),
      ),
    );
    expect(find.text('No expenses yet'), findsOneWidget);
  });

  testWidgets('the TCO surface renders totals and the insufficient-data state',
      (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          tcoReportProvider.overrideWith((ref, id) => thinReport),
        ],
        child: scaffold(const TcoScreen(vehicleId: 'v')),
      ),
    );

    expect(find.text('Total cost'), findsOneWidget);
    // Per-km AND per-day both fall back to the honest "not enough data".
    expect(find.text('Not enough data'), findsNWidgets(2));
    // The built-in-first bucket chart painted (no chart library).
    expect(find.text('Fuel'), findsOneWidget); // bucket label
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('the budget meter encodes over-budget redundantly', (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          budgetMetersProvider
              .overrideWith((ref, id) => <BudgetMeter>[overMeter]),
        ],
        child: scaffold(const BudgetMetersScreen(vehicleId: 'v')),
      ),
    );

    // Over-budget is knowable without colour: an icon+shape badge AND a label.
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('Over budget'), findsWidgets);
    // The three vitals are all present and labelled.
    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('Limit'), findsOneWidget);
    expect(find.text('Projected'), findsOneWidget);
  });

  testWidgets('the financing detail renders the schedule and equity position',
      (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          financingListProvider.overrideWith(
              (ref, id) => Stream.value(const <Financing>[financing])),
        ],
        child: scaffold(
          const FinancingDetailScreen(vehicleId: 'v', financingId: 'f1'),
        ),
      ),
    );

    expect(find.text('Monthly payment'), findsOneWidget);
    expect(find.text('Total interest'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    // The equity position is surfaced with a label (icon+label, never colour).
    final equity = find.text('Equity').evaluate().isNotEmpty ||
        find.text('Negative equity').evaluate().isNotEmpty;
    expect(equity, isTrue);
  });

  testWidgets('the financing detail shows a not-found state for an unknown id',
      (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          financingListProvider.overrideWith(
              (ref, id) => Stream.value(const <Financing>[financing])),
        ],
        child: scaffold(
          const FinancingDetailScreen(vehicleId: 'v', financingId: 'missing'),
        ),
      ),
    );
    expect(find.text("This financing isn't available"), findsOneWidget);
  });

  testWidgets('the expense surface mirrors correctly in RTL (fa)', (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          expenseHistoryProvider
              .overrideWith((ref, id) => Stream.value(const <Expense>[])),
          expenseCategoriesProvider
              .overrideWith((ref) => Stream.value(const <Category>[])),
        ],
        child: scaffold(
          const ExpensesScreen(vehicleId: 'v'),
          locale: const Locale('fa'),
        ),
      ),
    );
    expect(
      Directionality.of(t.element(find.byType(ExpensesScreen))),
      TextDirection.rtl,
    );
  });
}
