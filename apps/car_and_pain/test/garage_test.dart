import 'package:car_and_pain/src/shell/garage_screen.dart';
import 'package:car_and_pain/src/shell/rooms_shell.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// M2-T5/T9: the Garage lists the whole garage (active + non-active), encodes a
/// non-active lifecycle status redundantly (word, not colour), and filters by a
/// script-normalized/digit-folded search.
void main() {
  const active = Vehicle(id: 'v1', nickname: 'Rocinante', make: 'Toyota');
  const sold = Vehicle(id: 'v2', nickname: 'Tachi', status: 'sold');

  Future<void> openGarage(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        FakeStartupInitializer(Ok(fakeInfra())),
        vehicles: const [active, sold],
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(RoomsNav),
      matching: find.text('Garage'),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('lists active + non-active with the sold status word shown',
      (tester) async {
    await openGarage(tester);
    expect(find.byType(GarageScreen), findsOneWidget);
    expect(find.text('Rocinante'), findsOneWidget);
    expect(find.text('Tachi'), findsOneWidget);
    // The sold vehicle carries its lifecycle word (redundant encoding).
    expect(find.text('Sold'), findsOneWidget);
  });

  testWidgets('search filters by a digit-folded, script-normalized nickname',
      (tester) async {
    await openGarage(tester);
    await tester.enterText(find.byType(TextField), 'roc');
    await tester.pumpAndSettle();
    expect(find.text('Rocinante'), findsOneWidget);
    expect(find.text('Tachi'), findsNothing);
  });
}
