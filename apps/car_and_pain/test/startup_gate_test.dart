import 'package:car_and_pain/src/shell/home_screen.dart';
import 'package:car_and_pain/src/startup/splash_screen.dart';
import 'package:car_and_pain/src/startup/startup_error_screen.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  testWidgets('splash → ready shows the home shell', (tester) async {
    await tester.pumpWidget(testApp(FakeStartupInitializer(Ok(fakeInfra()))));

    // First frame: init still running → splash.
    expect(find.byType(SplashScreen), findsOneWidget);

    // Resolve the startup future.
    await tester.pump();
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('splash → error shows a retry-capable failure screen',
      (tester) async {
    await tester.pumpWidget(
      testApp(FakeStartupInitializer(const Err(DatabaseOpenFailed()))),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(StartupErrorScreen), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget); // en retry label
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('retry re-runs initialization and recovers', (tester) async {
    final init = FakeStartupInitializer(const Err(DatabaseOpenFailed()));
    await tester.pumpWidget(testApp(init));
    await tester.pump();
    await tester.pump();
    expect(find.byType(StartupErrorScreen), findsOneWidget);

    // Flip to success, then tap retry. Settle covers startup resolving AND the
    // app-lock gate resolving its (unlocked) state on the frame after mount.
    init.result = Ok(fakeInfra());
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(init.calls, greaterThanOrEqualTo(2));
  });
}
