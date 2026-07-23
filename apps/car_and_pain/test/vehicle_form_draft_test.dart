import 'package:car_and_pain/src/features/01-vehicles-garage/presentation/vehicle_form_screen.dart';
import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

/// M2-T2: in-progress add-vehicle input autosaves to a draft (the encrypted
/// settings store) and is restored when the form is reopened — surviving process
/// death. A completed save clears the draft.
void main() {
  setUpAll(() => EditableText.debugDeterministicCursor = true);
  tearDownAll(() => EditableText.debugDeterministicCursor = false);

  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  GoRouter router() => GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, __) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push('/form'),
                  child: const Text('home'), // i18n-ignore (test scaffold)
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/form',
            builder: (_, __) => const VehicleFormScreen(),
          ),
        ],
      );

  /// Pump the app at home, then push the form (so a save can pop back home).
  Future<void> pumpForm(WidgetTester tester, GoRouter r) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          // Stub the localization stream so reading the numeral parser doesn't
          // open a Drift .watch() on the settings table (which re-emits on every
          // settings write and would keep pumpAndSettle from settling). The
          // draft itself round-trips through the real DB via the settings repo.
          settingsMapProvider
              .overrideWith((ref) => Stream.value(const <String, String>{})),
        ],
        child: MaterialApp.router(
          theme: pulseTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: carAndPainLocalizationsDelegates,
          supportedLocales: carAndPainSupportedLocales,
          routerConfig: r,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  testWidgets('a draft is autosaved and restored on reopen (process death)',
      (tester) async {
    await pumpForm(tester, router());
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Draft Rig');
    await tester.pumpAndSettle();

    expect(await SettingsRepository(db).get('draft:vehicle:new'), isNotNull);

    // Simulate process death: tear the whole tree down and rebuild a NEW form
    // (fresh router) over the SAME database.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await pumpForm(tester, router());

    expect(find.widgetWithText(TextField, 'Draft Rig'), findsOneWidget);
  });

  testWidgets('saving the vehicle clears the draft', (tester) async {
    await pumpForm(tester, router());
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Keeper');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    // A real vehicle exists (one-shot read — no lingering watch stream), the
    // draft is gone, and the form popped home.
    expect(await db.select(db.vehicles).get(), hasLength(1));
    expect(await SettingsRepository(db).get('draft:vehicle:new'), isNull);
    expect(find.text('home'), findsOneWidget);
  });
}
