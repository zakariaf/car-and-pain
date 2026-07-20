import 'package:car_and_pain/src/features/18-data-offline-backup/presentation/trash_notifier.dart';
import 'package:car_and_pain/src/features/18-data-offline-backup/presentation/trash_screen.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

// Override the trash data directly so the widget test never touches the DB
// (drift's real async doesn't advance under testWidgets' FakeAsync).
Widget _app(List<TrashItem> items) => ProviderScope(
      overrides: [trashItemsProvider.overrideWith((ref) => items)],
      child: MaterialApp(
        theme: pulseLightTheme,
        localizationsDelegates: carAndPainLocalizationsDelegates,
        supportedLocales: carAndPainSupportedLocales,
        home: const TrashScreen(),
      ),
    );

void main() {
  testWidgets('renders a trashed item with redundant encoding + i18n',
      (tester) async {
    final expiry =
        DateTime.now().add(const Duration(days: 20)).millisecondsSinceEpoch;
    await tester.pumpWidget(
      _app([
        TrashItem(entityType: 'vehicles', id: 'v1', trashExpiresAt: expiry),
      ]),
    );
    await tester.pump(); // resolve the override future

    // Redundant encoding: a distinct icon + the localized type label + action.
    expect(find.text('Vehicle'), findsOneWidget); // en type label
    expect(find.text('Restore'), findsOneWidget);
    expect(find.byIcon(Icons.directions_car_outlined), findsOneWidget);
    // Retention countdown is shown (not colour alone).
    expect(find.textContaining('day'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing is trashed', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pump();
    expect(find.text('Trash is empty'), findsOneWidget);
  });
}
