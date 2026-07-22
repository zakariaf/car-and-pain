import 'package:car_and_pain/src/security/app_lock_screen.dart';
import 'package:car_and_pain/src/shell/shell_placeholders.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security/security.dart';

import 'support/harness.dart';

/// The app-lock gate is now a router redirect to `/lock` (M1-T1): a configured
/// lock covers the whole app until the correct PIN clears it, after which the
/// redirect falls through the remaining gates (here: onboarding, since the test
/// DB is empty). A wrong PIN keeps `/lock` mounted.
void main() {
  Future<void> pumpLocked(
      WidgetTester tester, InMemorySecureStore store) async {
    final vault = SecureVault(store);
    await vault.savePin('1234');
    await vault.saveLockPrefs(const LockPrefs(enabled: true));

    await tester.pumpWidget(
      testApp(FakeStartupInitializer(Ok(fakeInfra())), secureStore: store),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a configured lock hides the app behind the unlock screen',
      (tester) async {
    await pumpLocked(tester, InMemorySecureStore());

    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('the correct PIN reveals the app', (tester) async {
    await pumpLocked(tester, InMemorySecureStore());
    expect(find.byType(OnboardingScreen), findsNothing);

    // Tap the four digits on the pad (en → western glyphs).
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(AppLockScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('a wrong PIN keeps the app locked', (tester) async {
    await pumpLocked(tester, InMemorySecureStore());

    for (final d in ['0', '0', '0', '0']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(AppLockScreen), findsOneWidget);
  });
}
