import 'package:car_and_pain/src/backup/backup_providers.dart';
import 'package:car_and_pain/src/backup/backup_recovery_screen.dart';
import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

void main() {
  group('backupsToPrune (retention)', () {
    test('keeps the newest N; never prunes when at or below N', () {
      final files = [
        'backup-100.capb',
        'backup-300.capb',
        'backup-200.capb',
        'backup-400.capb',
      ];
      // Keep 2 newest (400, 300) → prune (200, 100).
      expect(backupsToPrune(files, 2)..sort(),
          ['backup-100.capb', 'backup-200.capb']);
      expect(backupsToPrune(files, 4), isEmpty);
      expect(backupsToPrune(files, 10), isEmpty);
    });

    test('never deletes the most recent, even with keepLast 0', () {
      final r = backupsToPrune(['backup-1.capb', 'backup-2.capb'], 0);
      expect(r, ['backup-1.capb']); // only the older one
    });

    test('a single backup is never pruned', () {
      expect(backupsToPrune(['backup-1.capb'], 0), isEmpty);
    });
  });

  testWidgets('the surface shows the entries + "no backups yet" state',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(AppDatabase.memory()),
          settingsMapProvider
              .overrideWith((ref) => Stream.value(const <String, String>{})),
        ],
        child: MaterialApp(
          localizationsDelegates: carAndPainLocalizationsDelegates,
          supportedLocales: carAndPainSupportedLocales,
          theme: pulseTheme(Brightness.light),
          home: const BackupRecoveryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Back up now'), findsOneWidget);
    expect(find.text('Restore or import'), findsOneWidget);
    expect(find.text('Use a recovery code'), findsOneWidget);
    expect(find.text('No backups yet'), findsOneWidget); // honesty state
  });
}
