import 'package:car_and_pain/src/features/01-vehicles-garage/application/vehicle_profile_providers.dart';
import 'package:car_and_pain/src/features/02-fuel-energy/presentation/fuel_entry_form_screen.dart';
import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

/// M3-T4: the energy-adaptive fuel form — enter-any-two live math, liquid vs
/// charge field switching, flags, and a save that writes to the ledger.
void main() {
  setUpAll(() => EditableText.debugDeterministicCursor = true);
  tearDownAll(() => EditableText.debugDeterministicCursor = false);

  late AppDatabase db;
  late String vehicleId;

  setUp(() async {
    db = AppDatabase.memory();
    vehicleId =
        (await VehiclesRepository(db).add(nickname: 'Rig')).valueOrNull!.id;
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vehicle =
        (await VehiclesRepository(db).getById(vehicleId)).valueOrNull;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, __) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/fuel'),
                child: const Text('home'), // i18n-ignore (test scaffold)
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/fuel',
          builder: (_, __) => FuelEntryFormScreen(vehicleId: vehicleId),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsMapProvider
              .overrideWith((ref) => Stream.value(const <String, String>{})),
          vehicleProvider.overrideWith((ref, id) => Stream.value(vehicle)),
        ],
        child: MaterialApp.router(
          theme: pulseTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: carAndPainLocalizationsDelegates,
          supportedLocales: carAndPainSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  testWidgets('enter-any-two computes the total from volume × price',
      (tester) async {
    await pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Volume (L)'), '40');
    await tester.enterText(
        find.widgetWithText(TextField, 'Price / L'), '1.759');
    await tester.pumpAndSettle();
    // 40 L × €1.759 = €70.36.
    expect(find.widgetWithText(TextField, '70.36'), findsOneWidget);
  });

  testWidgets('toggling charge swaps liquid fields for charge fields',
      (tester) async {
    await pump(tester);
    expect(find.text('Volume (L)'), findsOneWidget);
    expect(find.text('Energy (kWh)'), findsNothing);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Charge'));
    await tester.pumpAndSettle();
    expect(find.text('Energy (kWh)'), findsOneWidget);
    expect(find.text('Volume (L)'), findsNothing);
  });

  testWidgets('save writes a fuel entry + ledger row', (tester) async {
    await pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Odometer'), '12000');
    await tester.enterText(find.widgetWithText(TextField, 'Volume (L)'), '40');
    await tester.enterText(find.widgetWithText(TextField, 'Total'), '70.36');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    final entries = await db.select(db.fuelEntries).get();
    expect(entries, hasLength(1));
    expect(entries.single.volumeMl, 40000); // 40 L → 40000 mL
    expect(entries.single.odometerMetres, 12000000); // 12000 km → metres
    final ledger = await db.select(db.odometerReadings).get();
    expect(ledger, hasLength(1));
    expect(find.text('home'), findsOneWidget); // popped back
  });
}
