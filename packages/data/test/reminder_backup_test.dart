import 'dart:convert';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

/// M5-T6 — reminders (incl. the M5 notes + snooze state) round-trip losslessly
/// through the canonical backup, and their due dates export to a read-only .ics.
void main() {
  test('a reminder with notes + snooze round-trips through canonical JSON',
      () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final v = (await VehiclesRepository(db).add(nickname: 'Golf')).valueOrNull!;
    final repo = RemindersRepository(db);
    final id = (await repo.add(
      vehicleId: v.id,
      title: 'Inspection',
      kind: TriggerKind.date,
      dueDate: const Instant.fromEpochMillis(2000000),
      notes: 'TÜV + emissions',
      severity: 'documents',
    ))
        .valueOrNull!;
    await repo.snooze(id, const Instant.fromEpochMillis(1500000));

    final doc = await CanonicalCodec(db).export();
    final db2 = AppDatabase.memory();
    addTearDown(db2.close);
    expect((await CanonicalCodec(db2).import(doc)).isOk, isTrue);

    // Deep-equal the reminders entity, then re-read the live state.
    final doc2 = await CanonicalCodec(db2).export();
    expect(
      jsonEncode((doc2['entities'] as Map)['reminders']),
      jsonEncode((doc['entities'] as Map)['reminders']),
    );
    final restored = await RemindersRepository(db2).byId(id);
    expect(restored, isNotNull);
    expect(restored!.notes, 'TÜV + emissions');
    expect(restored.snoozeUntil, const Instant.fromEpochMillis(1500000));
  });

  test('due dates export to a read-only .ics without mutating state', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final v = (await VehiclesRepository(db).add(nickname: 'Golf')).valueOrNull!;
    final repo = RemindersRepository(db);
    await repo.add(
      vehicleId: v.id,
      title: 'Inspection',
      kind: TriggerKind.date,
      dueDate: Instant.fromDateTime(DateTime.utc(2026, 12)),
    );

    final ics = await repo.dueDatesIcs(
      v.id,
      summary: (r) => r.title,
      dtstamp: Instant.fromDateTime(DateTime.utc(2026, 7)),
    );
    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, contains('DTSTART;VALUE=DATE:20261201'));
    expect(ics, contains('SUMMARY:Inspection'));

    // The projection table is untouched (a read-only convenience).
    final projection =
        await NotificationScheduleRepository(db).loadProjection();
    expect(projection, isEmpty);
  });
}
