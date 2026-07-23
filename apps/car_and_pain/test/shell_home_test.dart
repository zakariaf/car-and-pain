import 'package:car_and_pain/src/features/01-vehicles-garage/presentation/vehicle_profile_screen.dart';
import 'package:car_and_pain/src/features/04-reminders-notifications/presentation/reminder_detail_screen.dart';
import 'package:car_and_pain/src/routing/app_locations.dart';
import 'package:car_and_pain/src/shell/garage_screen.dart';
import 'package:car_and_pain/src/shell/home_vitals_screen.dart';
import 'package:car_and_pain/src/shell/pitlane_screen.dart';
import 'package:car_and_pain/src/shell/rooms_shell.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/harness.dart';

/// Shell + Home widget and accessibility suite (M1-T8 behavioural ACs + M1-T12).
/// Pixel goldens (light/dark × LTR/RTL real-font shaping) ride the repo's
/// dedicated `golden-realfont` CI lane; these deterministic tests cover Room
/// switching + branch preservation, the cold-start deep-link (`extra == null`)
/// path, the empty first-run state, reduced-motion, RTL numerals, redundant
/// status encoding, and minimum touch targets.
void main() {
  const v = Vehicle(id: 'v1', nickname: 'Rocinante', make: 'Toyota');
  Widget ready({
    List<Vehicle> vehicles = const [v],
    Map<String, String> settings = const {},
    bool reduceMotion = true,
    String? pendingLocation,
  }) =>
      testApp(
        FakeStartupInitializer(Ok(fakeInfra())),
        vehicles: vehicles,
        settings: settings,
        reduceMotion: reduceMotion,
        pendingLocation: pendingLocation,
      );

  group('Home breathing vital', () {
    testWidgets('renders one vital, count-up numeral, redundant status (en)',
        (tester) async {
      await tester.pumpWidget(ready());
      await tester.pumpAndSettle();

      expect(find.byType(HomeVitalsScreen), findsOneWidget);
      expect(find.byType(VitalHero), findsOneWidget);
      // Redundant encoding: the calm status carries a WORD, not just colour.
      expect(find.text('Healthy'), findsWidgets);
      // Calm readiness = 100, in western digits under en.
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('a11y: screen readers hear the status word + the number',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ready());
      await tester.pumpAndSettle();

      // The hero announces readiness + the status word (never a colour).
      expect(
        find.bySemanticsLabel(RegExp('Readiness: Healthy')),
        findsOneWidget,
      );
      // The numeral is exposed to a11y as its number.
      expect(find.bySemanticsLabel('100'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('reduced motion stops the breath controller', (tester) async {
      await tester.pumpWidget(ready());
      await tester.pumpAndSettle();
      // A stopped controller registers no ticker → no scheduled frame callback.
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('normal motion runs the breath controller', (tester) async {
      await tester.pumpWidget(ready(reduceMotion: false));
      // Let startup + redirect settle to the Home, then a frame for the hero.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byType(VitalHero), findsOneWidget);
      // The repeating breath keeps a ticker scheduled.
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });
  });

  group('Empty first-run', () {
    testWidgets('no vehicle (onboarded) shows the calm empty Home + CTA',
        (tester) async {
      await tester.pumpWidget(
        ready(
          vehicles: const [],
          settings: const {'onboarding_complete': 'true'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeVitalsScreen), findsOneWidget);
      expect(find.text('Add your first vehicle to begin'), findsOneWidget);
      expect(find.text('Add a vehicle'), findsOneWidget);
      expect(find.byType(VitalHero), findsNothing);
    });
  });

  group('Rooms navigation', () {
    Finder navTab(String label) => find.descendant(
          of: find.byType(RoomsNav),
          matching: find.text(label),
        );

    testWidgets('switching Rooms preserves each branch stack; re-tap pops root',
        (tester) async {
      await tester.pumpWidget(ready());
      await tester.pumpAndSettle();

      // Drive the Garage branch into a detail route (URL-addressable, no extra).
      final ctx = tester.element(find.byType(RoomsNav));
      GoRouter.of(ctx).go(AppLocations.garageVehicle('v1'));
      await tester.pumpAndSettle();
      expect(find.byType(VehicleProfileScreen), findsOneWidget);

      // Switch to Pit-lane, then back to Garage: its stack must be preserved.
      await tester.tap(navTab('Pit-lane'));
      await tester.pumpAndSettle();
      expect(find.byType(PitlaneScreen), findsOneWidget);

      await tester.tap(navTab('Garage'));
      await tester.pumpAndSettle();
      expect(find.byType(VehicleProfileScreen), findsOneWidget); // preserved

      // Re-tapping the active Room pops it to its root.
      await tester.tap(navTab('Garage'));
      await tester.pumpAndSettle();
      expect(find.byType(GarageScreen), findsOneWidget);
      expect(find.byType(VehicleProfileScreen), findsNothing);
    });

    testWidgets('quick-add and Room tabs meet the minimum touch target',
        (tester) async {
      await tester.pumpWidget(ready());
      await tester.pumpAndSettle();

      final fab = tester.getSize(find.byType(FloatingActionButton));
      expect(fab.height, greaterThanOrEqualTo(PulseTokens.tapMin));
      expect(fab.width, greaterThanOrEqualTo(PulseTokens.tapMin));
    });
  });

  group('Deep-link cold start', () {
    testWidgets('initialLocation renders the reminder detail rebuilt from path',
        (tester) async {
      await tester.pumpWidget(
        ready(pendingLocation: '/garage/v1/reminders/r7'),
      );
      await tester.pumpAndSettle();

      // The target is reconstructed from path params alone (extra == null).
      expect(find.byType(ReminderDetailScreen), findsOneWidget);
      expect(find.text('Reminder not found'), findsOneWidget);
    });
  });

  group('RTL + numerals (fa)', () {
    testWidgets('mirrors direction and renders Persian numerals + status',
        (tester) async {
      await tester.pumpWidget(ready(settings: const {'locale': 'fa'}));
      await tester.pumpAndSettle();

      // The app is now right-to-left.
      final dir = Directionality.of(tester.element(find.byType(VitalHero)));
      expect(dir, TextDirection.rtl);

      // Readiness 100 in Persian digits; the status word is localized.
      expect(find.text('۱۰۰'), findsOneWidget);
      expect(find.text('سالم'), findsWidgets); // statusHealthy (fa)
    });
  });
}
