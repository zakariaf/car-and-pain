import 'package:drift/drift.dart';

import '../app_database.dart';

/// Forward-only, **append-only** migration steps. Never edit a shipped step; add
/// a new one and bump `schemaVersion` (F2-T5).
///
/// Each `case N` migrates `N → N+1`. A fresh install is built entirely by
/// `onCreate`; these steps only bring an *existing* DB forward, guarded by the
/// pre-migration snapshot in [AppDatabase.migration].
Future<void> runForwardMigrations(
  Migrator m,
  AppDatabase db, {
  required int from,
  required int to,
}) async {
  for (var v = from; v < to; v++) {
    switch (v) {
      case 1: // 1 → 2: the app-global key/value settings store (F4-T2).
        await m.createTable(db.settings);
      case 2: // 2 → 3: notification-engine schedule fields + projection (F5-T2).
        final r = db.reminders;
        await m.addColumn(r, r.dueEngineMinutes);
        await m.addColumn(r, r.completedAt);
        await m.addColumn(r, r.recurrenceEvery);
        await m.addColumn(r, r.recurrenceUnit);
        await m.addColumn(r, r.leadMinutes);
        await m.addColumn(r, r.leadDistanceMetres);
        await m.addColumn(r, r.severity);
        await m.addColumn(r, r.quietStartMinute);
        await m.addColumn(r, r.quietEndMinute);
        await m.addColumn(r, r.quietDeliverMinute);
        await m.createTable(db.scheduledNotifications);
      case 3: // 3 → 4: attachment size accounting, thumbnail + at-rest seal (F8).
        final a = db.attachments;
        await m.addColumn(a, a.sizeBytes);
        await m.addColumn(a, a.thumbnailRelativePath);
        await m.addColumn(a, a.isEncrypted);
      // Future versions append their `case N` block here.
    }
  }
}
