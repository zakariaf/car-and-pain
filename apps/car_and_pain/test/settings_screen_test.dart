import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:car_and_pain/src/settings/settings_screen.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

Widget _host(
  AppDatabase db,
  Map<String, String> stored, {
  Locale? locale,
}) =>
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        // Fixed stream: exercise rendering + persistence without opening a
        // live Drift .watch() (which would leave a pending timer at teardown).
        settingsMapProvider.overrideWith((ref) => Stream.value(stored)),
      ],
      child: MaterialApp(
        locale: locale,
        theme: pulseTheme(Brightness.light, arabicScript: locale != null),
        localizationsDelegates: carAndPainLocalizationsDelegates,
        supportedLocales: carAndPainSupportedLocales,
        home: const SettingsScreen(),
      ),
    );

/// A tall surface so the whole settings list is laid out (the ListView is lazy;
/// off-screen rows aren't built in the default 600px test window).
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renders localized pickers, endonyms, samples and preview (en)',
      (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    _tall(tester);
    await tester.pumpWidget(_host(db, const {}));
    await tester.pumpAndSettle();

    // Section headers (localized).
    for (final t in ['Language', 'Calendar', 'Numerals', 'Preview']) {
      expect(find.text(t), findsOneWidget);
    }
    // Language options: the localized "system default" + each endonym.
    expect(find.text('System default'), findsOneWidget);
    for (final endonym in [
      'English',
      'Deutsch',
      'Français',
      'فارسی',
      'العربية',
      'کوردی'
    ]) {
      expect(find.text(endonym), findsOneWidget);
    }
    // Calendar names + a Persian-digit sample in the numeral picker.
    expect(find.text('Gregorian'), findsOneWidget);
    expect(find.text('Solar Hijri'), findsOneWidget);
    expect(find.text('۰۱۲۳۴۵۶۷۸۹'), findsOneWidget);
  });

  testWidgets('selecting a calendar persists it to the encrypted store',
      (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    _tall(tester);
    await tester.pumpWidget(_host(db, const {}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Solar Hijri'));
    await tester.pumpAndSettle();

    expect(await SettingsRepository(db).get('calendar'), 'jalali');
  });

  testWidgets('selection is encoded redundantly (check-circle, not colour)',
      (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    _tall(tester);
    await tester.pumpWidget(_host(db, const {'calendar': 'hijri'}));
    await tester.pumpAndSettle();

    // Both shapes are present: selected rows use a filled check, unselected an
    // empty ring — selection is legible by shape, never colour alone.
    expect(find.byIcon(Icons.check_circle), findsWidgets);
    expect(find.byIcon(Icons.radio_button_unchecked), findsWidgets);

    // The stored Hijri calendar row is the selected one (filled check).
    final hijriRow =
        find.ancestor(of: find.text('Hijri'), matching: find.byType(Row)).first;
    expect(
      find.descendant(of: hijriRow, matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
  });

  testWidgets('mirrors under an RTL locale (fa)', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    _tall(tester);
    await tester.pumpWidget(_host(db, const {}, locale: const Locale('fa')));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(SettingsScreen))),
      TextDirection.rtl,
    );
  });
}
