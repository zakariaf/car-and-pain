import 'package:car_and_pain/src/attachments/attachment_gallery.dart';
import 'package:car_and_pain/src/attachments/attachment_providers.dart';
import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

Attachment _att(String id, AttachmentKind kind) => Attachment(
      id: id,
      linkedEntityType: AttachmentOwner.vehicle,
      linkedEntityId: 'v1',
      sha256: 'sha$id',
      relativePath: 'p$id',
      mimeType: switch (kind) {
        AttachmentKind.pdf => 'application/pdf',
        AttachmentKind.video => 'video/mp4',
        AttachmentKind.image => 'image/jpeg',
        AttachmentKind.other => 'application/octet-stream',
      },
      size: const ByteSize(1000),
      refCount: 1,
      isEncrypted: false,
      createdAt: 0,
    );

Widget _host(
  Widget child, {
  required List<Attachment> items,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      settingsMapProvider
          .overrideWith((ref) => Stream.value(const <String, String>{})),
      attachmentsForOwnerProvider((type: AttachmentOwner.vehicle, id: 'v1'))
          .overrideWith((ref) => Stream.value(items)),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: carAndPainLocalizationsDelegates,
      supportedLocales: carAndPainSupportedLocales,
      theme: pulseTheme(Brightness.light),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  const gallery = AttachmentGallery(
    ownerType: AttachmentOwner.vehicle,
    ownerId: 'v1',
  );

  testWidgets('empty state invites adding', (tester) async {
    await tester.pumpWidget(_host(
      AttachmentGallery(
        ownerType: AttachmentOwner.vehicle,
        ownerId: 'v1',
        onAdd: () {},
      ),
      items: const [],
    ));
    await tester.pump();
    expect(find.text('No attachments yet'), findsOneWidget);
    expect(find.text('Add'), findsWidgets);
  });

  testWidgets('renders a tile per attachment with a redundant kind label',
      (tester) async {
    await tester.pumpWidget(_host(
      gallery,
      items: [_att('1', AttachmentKind.pdf), _att('2', AttachmentKind.video)],
    ));
    await tester.pump();
    // Non-colour type cue: the kind label appears on each tile.
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
  });

  testWidgets('mirrors under an RTL locale without overflow', (tester) async {
    await tester.pumpWidget(_host(
      gallery,
      items: [_att('1', AttachmentKind.pdf)],
      locale: const Locale('ar'),
    ));
    await tester.pump();
    expect(Directionality.of(tester.element(find.byType(AttachmentGallery))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });
}
