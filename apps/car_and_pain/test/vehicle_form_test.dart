import 'package:car_and_pain/src/features/01-vehicles-garage/presentation/vehicle_form_screen.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

/// M2-T2/T9: the powertrain-adaptive form shows exactly the relevant field set,
/// recomputes it reactively on an energy change, preserves hidden-field values
/// on toggle, and decodes the VIN live.
void main() {
  // Stop the text-cursor blink so pumpAndSettle doesn't chase its periodic
  // repaint forever while a field is focused.
  setUpAll(() => EditableText.debugDeterministicCursor = true);
  tearDownAll(() => EditableText.debugDeterministicCursor = false);

  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<void> pumpForm(WidgetTester tester) async {
    // A tall viewport so the whole (lazily-built) form is laid out at once.
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: pulseTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: carAndPainLocalizationsDelegates,
          supportedLocales: carAndPainSupportedLocales,
          home: const VehicleFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectEnergy(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('energyField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('field visibility adapts to the chosen energy', (tester) async {
    await pumpForm(tester);

    // No energy yet → neither tank nor battery.
    expect(find.text('Tank capacity'), findsNothing);
    expect(find.text('Battery capacity'), findsNothing);

    // Electric → battery fields, no tank.
    await selectEnergy(tester, 'Electric');
    expect(find.text('Battery capacity'), findsOneWidget);
    expect(find.text('Usable capacity'), findsOneWidget);
    expect(find.text('Tank capacity'), findsNothing);

    // Switch to Gasoline → tank, no battery.
    await selectEnergy(tester, 'Gasoline');
    expect(find.text('Tank capacity'), findsOneWidget);
    expect(find.text('Battery capacity'), findsNothing);
  });

  testWidgets('hidden-field values are preserved across an energy toggle',
      (tester) async {
    await pumpForm(tester);

    await selectEnergy(tester, 'Gasoline');
    await tester.enterText(
        find.widgetWithText(TextField, 'Tank capacity'), '55');
    await tester.pumpAndSettle();

    // Switch away (Electric hides the tank) then back (Gasoline).
    await selectEnergy(tester, 'Electric');
    expect(find.text('Tank capacity'), findsNothing);
    await selectEnergy(tester, 'Gasoline');

    // The previously-typed tank value survived the toggle.
    expect(find.widgetWithText(TextField, '55'), findsOneWidget);
  });

  testWidgets('VIN decodes live: valid checksum + manufacturer',
      (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'VIN'),
      '1HGCM82633A004352', // Honda, valid checksum
    );
    await tester.pumpAndSettle();

    expect(find.text('Checksum valid'), findsOneWidget);
    expect(find.textContaining('Honda'), findsOneWidget); // decoded WMI
  });
}
