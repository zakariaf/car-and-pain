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
      // Future versions append their `case N` block here.
    }
  }
}
