import 'package:car_and_pain/src/shell/shell_placeholders.dart';
import 'package:car_and_pain/src/startup/splash_screen.dart';
import 'package:car_and_pain/src/startup/startup_error_screen.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// The startup gate now lives in the router redirect (M1-T1): splash while init
/// runs, a retry-capable error screen on failure, and — on success with a fresh
/// (empty) install — the onboarding flow (no vehicle yet). These drive the whole
/// stack end-to-end through the real `CarAndPainApp` + GoRouter.
void main() {
  testWidgets('splash → ready clears the gates into the app', (tester) async {
    await tester.pumpWidget(testApp(FakeStartupInitializer(Ok(fakeInfra()))));

    // First frame: init still running → splash.
    expect(find.byType(SplashScreen), findsOneWidget);

    // Resolve the startup future and let the redirect settle.
    await tester.pumpAndSettle();

    // Fresh install (no vehicle, no PIN) lands on onboarding, past splash/error.
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(StartupErrorScreen), findsNothing);
  });

  testWidgets('splash → error shows a retry-capable failure screen',
      (tester) async {
    await tester.pumpWidget(
      testApp(FakeStartupInitializer(const Err(DatabaseOpenFailed()))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StartupErrorScreen), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget); // en retry label
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('retry re-runs initialization and recovers', (tester) async {
    final init = FakeStartupInitializer(const Err(DatabaseOpenFailed()));
    await tester.pumpWidget(testApp(init));
    await tester.pumpAndSettle();
    expect(find.byType(StartupErrorScreen), findsOneWidget);

    // Flip to success, then tap retry. Settle covers startup resolving AND the
    // redirect re-running through the (unlocked) gates to the app.
    init.result = Ok(fakeInfra());
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(init.calls, greaterThanOrEqualTo(2));
  });
}
