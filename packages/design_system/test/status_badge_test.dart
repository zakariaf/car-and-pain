import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: pulseTheme(brightness),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('StatusBadge renders the label + a distinct icon (redundant)',
      (tester) async {
    await tester.pumpWidget(
      wrap(const StatusBadge(status: PulseStatus.overdue, label: 'Overdue')),
    );

    // Text label present (non-colour channel #1).
    expect(find.text('Overdue'), findsOneWidget);
    // A distinct icon present (non-colour channel #2).
    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
  });

  testWidgets('each status uses a distinct icon', (tester) async {
    for (final (status, icon) in <(PulseStatus, IconData)>[
      (PulseStatus.healthy, Icons.check_circle_outline),
      (PulseStatus.dueSoon, Icons.warning_amber_rounded),
      (PulseStatus.overdue, Icons.notifications_active_outlined),
    ]) {
      await tester.pumpWidget(
        wrap(StatusBadge(status: status, label: 'x')),
      );
      expect(find.byIcon(icon), findsOneWidget);
    }
  });

  testWidgets('the badge exposes its label to the semantics tree',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(const StatusBadge(status: PulseStatus.dueSoon, label: 'Due soon')),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Due soon')),
      isNotNull,
    );
    handle.dispose();
  });

  testWidgets('theme provides PULSE extended neutrals in both brightnesses',
      (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(
        wrap(
          const StatusBadge(status: PulseStatus.healthy, label: 'ok'),
          brightness: b,
        ),
      );
      final context = tester.element(find.byType(StatusBadge));
      expect(Theme.of(context).extension<PulseColorsExt>(), isNotNull);
    }
  });
}
