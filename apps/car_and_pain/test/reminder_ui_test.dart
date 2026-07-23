import 'package:car_and_pain/src/features/04-reminders-notifications/application/reminder_providers.dart';
import 'package:car_and_pain/src/features/04-reminders-notifications/presentation/reminder_form_screen.dart';
import 'package:car_and_pain/src/features/04-reminders-notifications/presentation/reminders_screen.dart';
import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

/// M5-T3/T8: the reminder surfaces. The Drift `.watch()`-backed live-state
/// provider is stubbed with a fixed stream so no pending timer survives teardown.
void main() {
  setUpAll(() => EditableText.debugDeterministicCursor = true);
  tearDownAll(() => EditableText.debugDeterministicCursor = false);

  late AppDatabase db;

  ReminderWithState item(String title, ReminderLiveState state) =>
      ReminderWithState(
        reminder: Reminder(
          id: title,
          vehicleId: 'v',
          title: title,
          triggerType: 'date',
          dueDate: const Instant.fromEpochMillis(1000),
        ),
        state: state,
        due: const Due(
          NextDue(
            fireAt: Instant.fromEpochMillis(1000),
            dueAt: Instant.fromEpochMillis(1000),
            confidence: DueConfidence.exact,
          ),
        ),
        next: const NextDue(
          fireAt: Instant.fromEpochMillis(1000),
          dueAt: Instant.fromEpochMillis(1000),
          confidence: DueConfidence.exact,
        ),
      );

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Widget wrap(Widget child,
      {List<ReminderWithState> items = const [],
      Locale locale = const Locale('en')}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, __) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/x'),
                child: const Text('home'), // i18n-ignore (test scaffold)
              ),
            ),
          ),
        ),
        GoRoute(path: '/x', builder: (_, __) => child),
      ],
    );
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsMapProvider
            .overrideWith((ref) => Stream.value(const <String, String>{})),
        reminderLiveStatesProvider
            .overrideWith((ref, id) => Stream.value(items)),
      ],
      child: MaterialApp.router(
        theme: pulseTheme(Brightness.light),
        locale: locale,
        localizationsDelegates: carAndPainLocalizationsDelegates,
        supportedLocales: carAndPainSupportedLocales,
        routerConfig: router,
      ),
    );
  }

  Future<void> open(WidgetTester t, Widget child,
      {List<ReminderWithState> items = const [],
      Locale locale = const Locale('en')}) async {
    t.view.physicalSize = const Size(1200, 3600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(wrap(child, items: items, locale: locale));
    await t.pumpAndSettle();
    await t.tap(find.text('home'));
    await t.pumpAndSettle();
  }

  testWidgets('the list renders an item with a redundant status badge',
      (t) async {
    await open(t, const RemindersScreen(vehicleId: 'v'),
        items: [item('Inspection', ReminderLiveState.overdue)]);
    expect(find.text('Inspection'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('Overdue'), findsWidgets); // status label (redundant)
    expect(find.text('Complete'), findsOneWidget);
  });

  testWidgets('the list shows the empty state with no reminders', (t) async {
    await open(t, const RemindersScreen(vehicleId: 'v'));
    expect(find.text('No reminders yet'), findsOneWidget);
  });

  testWidgets('the form renders the rule-kind selector and inputs', (t) async {
    await open(t, const ReminderFormScreen(vehicleId: 'v'));
    expect(find.text('Title'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<TriggerKind>), findsOneWidget);
    expect(find.text('Due date'), findsOneWidget); // date kind default
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('the reminder surface mirrors correctly in RTL (fa)', (t) async {
    await open(t, const RemindersScreen(vehicleId: 'v'),
        items: [item('روغن', ReminderLiveState.dueSoon)],
        locale: const Locale('fa'));
    expect(Directionality.of(t.element(find.text('روغن'))), TextDirection.rtl);
  });

  testWidgets('the form prefills its fields when editing (M5-T3)', (t) async {
    final v = (await VehiclesRepository(db).add(nickname: 'Golf')).valueOrNull!;
    final id = (await RemindersRepository(db).add(
      vehicleId: v.id,
      title: 'Old title',
      kind: TriggerKind.date,
      dueDate: const Instant.fromEpochMillis(1000),
    ))
        .valueOrNull!;

    await open(t, ReminderFormScreen(vehicleId: v.id, reminderId: id));
    // The edit title, and the stored title prefilled into the field.
    expect(find.text('Edit reminder'), findsOneWidget);
    expect(find.text('Old title'), findsOneWidget);
  });
}
