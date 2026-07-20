import 'package:drift/drift.dart';

/// Forward-only, **append-only** migration steps. Never edit a shipped step; add
/// a new one and bump `schemaVersion` (F2-T5).
///
/// Empty at schemaVersion 1 (a fresh DB is built by `onCreate`). Each future
/// version appends its `from == N` block here.
Future<void> runForwardMigrations(
  Migrator m, {
  required int from,
  required int to,
}) async {
  for (var v = from; v < to; v++) {
    switch (v) {
      // case 1: // 1 → 2
      //   await m.addColumn(...);
      default:
        break;
    }
  }
}
