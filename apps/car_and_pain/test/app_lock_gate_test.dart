import 'package:car_and_pain/src/security/app_lock_screen.dart';
import 'package:car_and_pain/src/shell/home_screen.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security/security.dart';

import 'support/harness.dart';

void main() {
  testWidgets('a configured lock hides the shell behind the unlock screen',
      (tester) async {
    final store = InMemorySecureStore();
    final vault = SecureVault(store);
    await vault.savePin('1234');
    await vault.saveLockPrefs(const LockPrefs(enabled: true));

    await tester.pumpWidget(
      testApp(FakeStartupInitializer(Ok(fakeInfra())), secureStore: store),
    );
    await tester.pumpAndSettle();

    // The shell is not mounted; the unlock screen covers it.
    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('the correct PIN reveals the shell', (tester) async {
    final store = InMemorySecureStore();
    final vault = SecureVault(store);
    await vault.savePin('1234');
    await vault.saveLockPrefs(const LockPrefs(enabled: true));

    await tester.pumpWidget(
      testApp(FakeStartupInitializer(Ok(fakeInfra())), secureStore: store),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);

    // Tap the four digits on the pad (en → western glyphs).
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(AppLockScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a wrong PIN keeps the shell locked', (tester) async {
    final store = InMemorySecureStore();
    final vault = SecureVault(store);
    await vault.savePin('1234');
    await vault.saveLockPrefs(const LockPrefs(enabled: true));

    await tester.pumpWidget(
      testApp(FakeStartupInitializer(Ok(fakeInfra())), secureStore: store),
    );
    await tester.pumpAndSettle();

    for (final d in ['0', '0', '0', '0']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(AppLockScreen), findsOneWidget);
  });
}
