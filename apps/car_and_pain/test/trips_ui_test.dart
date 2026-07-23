import 'package:car_and_pain/src/features/01-vehicles-garage/application/vehicle_profile_providers.dart';
import 'package:car_and_pain/src/features/06-trips-mileage/application/trip_providers.dart';
import 'package:car_and_pain/src/features/06-trips-mileage/presentation/trips_logbook_screen.dart';
import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

/// M7-T5/T6: the trip logbook surface. Drift `.watch()`-backed providers are
/// stubbed with fixed streams so no pending timer survives teardown; the pure
/// TripRollup runs for real so the summary is engine-shaped.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  // ignore: always_declare_return_types  (Override is not a public type name)
  base() => [
        appDatabaseProvider.overrideWithValue(db),
        settingsMapProvider
            .overrideWith((ref) => Stream.value(const <String, String>{})),
        vehicleProvider.overrideWith((ref, id) => Stream<Vehicle?>.value(null)),
      ];

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

  const trip = Trip(
    id: 't1',
    vehicleId: 'v',
    tripAt: Instant.fromEpochMillis(1000),
    distanceMetres: 50000, // 50.0 km
    classification: TripClassification.business,
    isDeductible: true,
    isContemporaneous: true,
    autoDetected: false,
    vehicleClass: 'car',
    passengerCount: 0,
    billable: false,
  );

  testWidgets('the logbook shows its empty state', (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          tripHistoryProvider
              .overrideWith((ref, id) => Stream.value(const <Trip>[])),
        ],
        child: scaffold(const TripsLogbookScreen(vehicleId: 'v')),
      ),
    );
    expect(find.text('No trips logged yet.'), findsOneWidget);
  });

  testWidgets('the logbook lists a trip with a redundant classification badge',
      (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          tripHistoryProvider
              .overrideWith((ref, id) => Stream.value(const <Trip>[trip])),
        ],
        child: scaffold(const TripsLogbookScreen(vehicleId: 'v')),
      ),
    );
    expect(find.text('Trips'), findsOneWidget);
    // Summary strip labels are present.
    expect(find.text('Business use'), findsOneWidget);
    // The classification is knowable by text label (not colour): "Business"
    // appears in the row badge and the classify menu.
    expect(find.text('Business'), findsWidgets);
    // The distance renders in the default unit (km).
    expect(find.textContaining('50'), findsWidgets);
  });

  testWidgets('the logbook mirrors correctly in RTL (fa)', (t) async {
    await open(
      t,
      ProviderScope(
        overrides: [
          ...base(),
          tripHistoryProvider
              .overrideWith((ref, id) => Stream.value(const <Trip>[])),
        ],
        child: scaffold(
          const TripsLogbookScreen(vehicleId: 'v'),
          locale: const Locale('fa'),
        ),
      ),
    );
    expect(
      Directionality.of(t.element(find.byType(TripsLogbookScreen))),
      TextDirection.rtl,
    );
  });
}
