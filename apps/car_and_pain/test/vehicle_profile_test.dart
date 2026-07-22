import 'package:car_and_pain/src/features/01-vehicles-garage/presentation/vehicle_profile_screen.dart';
import 'package:car_and_pain/src/routing/app_locations.dart';
import 'package:car_and_pain/src/shell/rooms_shell.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/harness.dart';

/// M2-T6/T9: the A4 vehicle-profile screen renders identity + specs with the
/// lifecycle status redundantly encoded, keeps VIN/plate LTR, and mirrors under
/// RTL.
void main() {
  const v = Vehicle(
    id: 'v1',
    nickname: 'Rocinante',
    make: 'Toyota',
    model: 'Corolla',
    energyType: 'electric',
    vin: '1HGCM82633A004352',
    licensePlate: 'ABC-123',
  );

  Future<void> openProfile(WidgetTester tester,
      {Map<String, String> settings = const {}}) async {
    await tester.pumpWidget(
      testApp(
        FakeStartupInitializer(Ok(fakeInfra())),
        vehicles: const [v],
        settings: settings,
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(RoomsNav)))
        .go(AppLocations.garageVehicle('v1'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders identity, specs, and a redundantly-encoded status (en)',
      (tester) async {
    await openProfile(tester);
    expect(find.byType(VehicleProfileScreen), findsOneWidget);
    // Identity + specs.
    expect(find.text('Toyota Corolla'), findsOneWidget);
    expect(find.text('1HGCM82633A004352'), findsOneWidget); // VIN
    expect(find.text('Electric'), findsOneWidget); // energy spec
    // Lifecycle status carries the WORD (redundant encoding), not colour alone.
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('VIN renders left-to-right even under an RTL (fa) layout',
      (tester) async {
    await openProfile(tester, settings: const {'locale': 'fa'});
    // The screen mirrors...
    final dir =
        Directionality.of(tester.element(find.byType(VehicleProfileScreen)));
    expect(dir, TextDirection.rtl);
    // ...but the VIN is bidi-isolated LTR (LtrText forces a local Directionality).
    expect(
      Directionality.of(tester.element(find.text('1HGCM82633A004352'))),
      TextDirection.ltr,
    );
  });
}
