import 'package:car_and_pain/src/features/01-vehicles-garage/application/vehicle_profile_providers.dart';
import 'package:car_and_pain/src/features/03-service-maintenance/application/service_providers.dart';
import 'package:car_and_pain/src/features/03-service-maintenance/presentation/service_entry_form_screen.dart';
import 'package:car_and_pain/src/features/03-service-maintenance/presentation/service_history_screen.dart';
import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

/// M4-T4: the multi-line service visit editor + history/status cards. Drift
/// `.watch()`-backed providers are stubbed with Stream/Future values so no
/// pending timer survives teardown.
void main() {
  setUpAll(() => EditableText.debugDeterministicCursor = true);
  tearDownAll(() => EditableText.debugDeterministicCursor = false);

  late AppDatabase db;
  late String vehicleId;

  const oilType = Category(
    id: 'oil',
    kind: 'service',
    label: 'taxonomy.oil_change',
    analyticBucket: 'service',
    iconKey: 'oil',
  );

  setUp(() async {
    db = AppDatabase.memory();
    vehicleId =
        (await VehiclesRepository(db).add(nickname: 'Rig')).valueOrNull!.id;
  });
  tearDown(() => db.close());

  Widget wrap(Widget child) {
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
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsMapProvider
            .overrideWith((ref) => Stream.value(const <String, String>{})),
        vehicleProvider.overrideWith(
          (ref, id) => Stream.value(const Vehicle(id: 'v', nickname: 'Rig')),
        ),
        serviceTypesProvider.overrideWith((ref) => Stream.value([oilType])),
        // History + status providers stubbed so no Drift .watch() opens (the
        // form ignores them; the history screen reads them).
        serviceHistoryProvider.overrideWith(
          (ref, id) => Stream.value(const <ServiceVisit>[]),
        ),
        serviceStatusProvider.overrideWith(
          (ref, id) => Future.value(const <ServiceStatusCard>[]),
        ),
      ],
      child: MaterialApp.router(
        theme: pulseTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: carAndPainLocalizationsDelegates,
        supportedLocales: carAndPainSupportedLocales,
        routerConfig: router,
      ),
    );
  }

  Future<void> open(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(child));
    await tester.pumpAndSettle();
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  testWidgets('the form renders the visit header and a line item', (t) async {
    await open(t, ServiceEntryFormScreen(vehicleId: vehicleId));
    expect(find.text('Service date'), findsOneWidget);
    expect(find.text('Odometer'), findsOneWidget);
    expect(find.text('Did it myself (DIY)'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
    expect(find.text('Add job'), findsOneWidget);
  });

  testWidgets('adding a job appends a line-item row', (t) async {
    await open(t, ServiceEntryFormScreen(vehicleId: vehicleId));
    expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
    await tapText(t, 'Add job');
    expect(find.byType(DropdownButtonFormField<String?>), findsNWidgets(2));
  });

  testWidgets('save writes a visit + odometer ledger row and pops', (t) async {
    await open(t, ServiceEntryFormScreen(vehicleId: vehicleId));
    await t.enterText(find.widgetWithText(TextField, 'Odometer'), '120000');
    await t.pumpAndSettle();
    await tapText(t, 'Save');
    await t.pumpAndSettle();

    final visits = await db.select(db.serviceEntries).get();
    expect(visits, hasLength(1));
    expect(visits.single.odometerMetres, 120000000); // 120000 km → metres
    final ledger = await db.select(db.odometerReadings).get();
    expect(ledger, hasLength(1));
    expect(find.text('home'), findsOneWidget); // popped back
  });

  testWidgets('history shows the empty state with no visits', (t) async {
    await open(t, ServiceHistoryScreen(vehicleId: vehicleId));
    expect(find.text('No service records yet'), findsOneWidget);
  });
}

/// Tap a widget by its visible text (works for TextButton/PulseButton labels).
Future<void> tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text));
  await t.pumpAndSettle();
}
