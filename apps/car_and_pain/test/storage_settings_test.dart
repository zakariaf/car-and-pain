import 'package:car_and_pain/src/attachments/attachment_providers.dart';
import 'package:car_and_pain/src/attachments/storage_settings_screen.dart';
import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

Future<void> _seed(
  AttachmentsRepository repo, {
  required String type,
  required String id,
  required String sha,
  required int size,
}) async {
  await repo.add(
    linkedEntityType: type,
    linkedEntityId: id,
    sha256: sha,
    relativePath: 'p$sha',
    mimeType: 'application/pdf',
    sizeBytes: size,
  );
}

void main() {
  testWidgets('storage surface shows the roll-up total + per-type breakdown',
      (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final repo = AttachmentsRepository(db);
    await _seed(repo,
        type: AttachmentOwner.vehicle, id: 'v1', sha: 'a', size: 2000);
    await _seed(repo,
        type: AttachmentOwner.fuelEntry, id: 'f1', sha: 'b', size: 1000);
    final gc = AttachmentGc(db: db, store: InMemoryAttachmentBlobStore());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsMapProvider
              .overrideWith((ref) => Stream.value(const <String, String>{})),
          attachmentGcProvider.overrideWithValue(gc),
        ],
        child: MaterialApp(
          localizationsDelegates: carAndPainLocalizationsDelegates,
          supportedLocales: carAndPainSupportedLocales,
          theme: pulseTheme(Brightness.light),
          home: const StorageSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Vehicles'), findsOneWidget); // owner-type label
    expect(find.text('Fuel'), findsOneWidget);
    expect(find.text('2.9 KB'), findsOneWidget); // 3000 bytes total
    expect(find.text('Encrypt attachments'), findsOneWidget);
    expect(find.text('Reclaim space'), findsOneWidget);
  });
}
