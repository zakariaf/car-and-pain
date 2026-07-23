import 'package:car_and_pain/src/features/17-dashboard-statistics-reports/application/dashboard_providers.dart';
import 'package:car_and_pain/src/features/17-dashboard-statistics-reports/presentation/dashboard_screen.dart';
import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:car_and_pain/src/shell/shell_state.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

/// M8-T5/T9/T10: the analytics dashboard. Every rollup-backed provider is
/// stubbed with a fixed value so the pure engines (KPIs, forecast, insights)
/// run for real over engine-shaped data — no pending timer at teardown.
void main() {
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

  const vehicle = Vehicle(id: 'v', nickname: 'Golf');
  final kpis = DashboardKpis.of(const [
    KpiContribution(
        currencyCode: 'EUR',
        spendMinor: 10000,
        distanceMetres: 200000,
        fuelMl: 70000,
        fillCount: 2),
  ]);

  // ignore: always_declare_return_types  (Override is not a public type name)
  base() => [
        settingsMapProvider
            .overrideWith((ref) => Stream.value(const <String, String>{})),
        activeVehicleProvider.overrideWithValue(vehicle),
        scopeProvider.overrideWithValue(VehicleScope.perVehicle),
        dashboardKpisProvider.overrideWith((ref) => Stream.value(kpis)),
      ];

  testWidgets('renders KPIs, chart, forecast and quick-add', (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          // A rising 3-month spend series → forecastable AND a spend spike.
          spendSeriesProvider
              .overrideWith((ref) => Stream.value(const [50000, 60000, 90000])),
        ],
        child: scaffold(const DashboardScreen()),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Golf'), findsOneWidget);
    // KPI tiles.
    expect(find.text('Spend'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('CO₂ (kg)'), findsOneWidget);
    expect(find.textContaining('EUR'), findsWidgets); // formatted money
    // The built-in CustomPainter chart (no chart library).
    expect(find.byType(CustomPaint), findsWidgets);
    // The forecast projected (3 months ≥ threshold).
    expect(find.textContaining('Projected 30-day spend'), findsOneWidget);
    // The insight fired (90000 >> avg(50000,60000)).
    expect(
        find.text('Spend is higher than usual this period.'), findsOneWidget);
    // Quick-add deep links.
    expect(find.text('Fuel'), findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);
  });

  testWidgets('a thin history shows the honest insufficient-forecast state',
      (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          // One month → below the min-samples threshold.
          spendSeriesProvider
              .overrideWith((ref) => Stream.value(const [50000])),
        ],
        child: scaffold(const DashboardScreen()),
      ),
    );
    expect(find.text('Not enough history to forecast yet.'), findsOneWidget);
    // No spurious insight on a thin history.
    expect(find.text('Nothing unusual — all healthy.'), findsOneWidget);
  });

  testWidgets('mirrors correctly in RTL (fa)', (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          spendSeriesProvider
              .overrideWith((ref) => Stream.value(const <int>[])),
        ],
        child: scaffold(const DashboardScreen(), locale: const Locale('fa')),
      ),
    );
    expect(
      Directionality.of(t.element(find.byType(DashboardScreen))),
      TextDirection.rtl,
    );
  });
}
