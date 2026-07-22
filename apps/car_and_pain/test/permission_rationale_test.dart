import 'package:car_and_pain/src/notifications/permission_flow.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

Widget _host(Widget child, {Locale? locale}) => MaterialApp(
      locale: locale,
      theme: pulseTheme(Brightness.light, arabicScript: locale != null),
      localizationsDelegates: carAndPainLocalizationsDelegates,
      supportedLocales: carAndPainSupportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('rationale sheet shows the copy + a single action',
      (tester) async {
    await tester.pumpWidget(_host(const NotificationRationaleSheet(
      title: 'Never miss a due date',
      body: 'Allow notifications to get reminders.',
      actionLabel: 'Allow',
    )));

    expect(find.text('Never miss a due date'), findsOneWidget);
    expect(find.text('Allow notifications to get reminders.'), findsOneWidget);
    expect(find.widgetWithText(PulseButton, 'Allow'), findsOneWidget);
  });

  testWidgets('rationale sheet mirrors under an RTL locale', (tester) async {
    await tester.pumpWidget(_host(
      const NotificationRationaleSheet(
          title: 'ت', body: 'ب', actionLabel: 'اجازه'),
      locale: const Locale('fa'),
    ));
    expect(
      Directionality.of(
          tester.element(find.byType(NotificationRationaleSheet))),
      TextDirection.rtl,
    );
  });
}
