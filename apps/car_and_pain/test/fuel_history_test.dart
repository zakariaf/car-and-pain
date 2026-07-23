import 'package:car_and_pain/src/features/02-fuel-energy/presentation/economy_chart.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// M3-T5: the built-in-first economy chart renders, exposes a readable
/// accessibility summary, and mirrors under RTL. (The economy figures the chart
/// plots are computed + tested by the pure EconomyEngine and the fuel repo.)
void main() {
  const points = [
    EconomyPoint(value: 8, label: '8.0 L/100km'),
    EconomyPoint(value: 7.2, label: '7.2 L/100km'),
    EconomyPoint(value: 9.1, label: '9.1 L/100km'),
  ];

  Widget wrap({TextDirection dir = TextDirection.ltr}) => MaterialApp(
        theme: pulseTheme(Brightness.light),
        home: Directionality(
          textDirection: dir,
          child: const Scaffold(
            body: EconomyChart(
              points: points,
              semanticsSummary: 'Economy: 8.0, 7.2, 9.1 L/100km',
            ),
          ),
        ),
      );

  testWidgets('renders with a CustomPaint and an accessible summary',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(EconomyChart), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets); // painter present
    expect(find.bySemanticsLabel(RegExp('Economy: 8.0')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('paints under both text directions without error',
      (tester) async {
    await tester.pumpWidget(wrap(dir: TextDirection.rtl));
    await tester.pump();
    expect(find.byType(EconomyChart), findsOneWidget);
    expect(tester.takeException(), isNull); // RTL mirror paints cleanly
  });
}
