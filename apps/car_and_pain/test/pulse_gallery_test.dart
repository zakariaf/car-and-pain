import 'package:car_and_pain/src/gallery/pulse_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

void main() {
  testWidgets('gallery renders components and toggles theme/direction/motion',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: carAndPainLocalizationsDelegates,
        supportedLocales: carAndPainSupportedLocales,
        home: const PulseGallery(),
      ),
    );
    await tester.pump();

    // Localized urgency labels + a chart's Semantics summary render (the bar
    // chart is below the fold — its semantics is covered in design_system).
    expect(find.text('Overdue'), findsWidgets); // pill + card title (en)
    expect(find.bySemanticsLabel('Economy trending down'), findsOneWidget);

    // Live toggles do not crash (no pumpAndSettle — the vital breathes forever).
    await tester.tap(find.byTooltip('Theme'));
    await tester.pump();
    await tester.tap(find.byTooltip('Direction'));
    await tester.pump();
    await tester.tap(find.byTooltip('Reduce motion'));
    await tester.pump();

    expect(find.byType(PulseGallery), findsOneWidget);
  });
}
