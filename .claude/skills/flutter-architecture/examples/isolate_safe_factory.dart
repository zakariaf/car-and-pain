// Illustrative: the isolate-safe factory pattern that makes infra reachable from
// a background reschedule worker WITHOUT a BuildContext or a shared ProviderScope.
//
// The SAME openAppDatabase() factory is called by bootstrap.dart (main isolate) and
// by rescheduleWorker (background isolate). That symmetry is what lets a reminder
// re-arm after reboot/Doze rebuild entirely from the encrypted DB.
//
// See references/state-di-riverpod.md §5 and SKILL.md "The canonical composition root".

import 'dart:io';
import 'dart:typed_data';

// --- packages/data: plain top-level factory, no Riverpod, no Flutter widgets ---
Future<AppDatabase> openAppDatabase(Uint8List key, String dbPath) async {
  final db = AppDatabase(
    NativeDatabase(
      File(dbPath),
      setup: (raw) {
        // First statement on the connection; hex-encoded raw key PRAGMA (SQLCipher).
        raw.execute("PRAGMA key = \"x'${hexEncode(key)}'\";");
        // Cipher/KDF asserted here; the not-plaintext header check runs as a CI test.
      },
    ),
  );
  return db;
}

// --- packages/notifications: background reschedule worker ---------------------
@pragma('vm:entry-point')
Future<void> rescheduleWorker(Uint8List dbKey) async {
  // The DB key was read on the MAIN isolate (secure storage / boot receiver after
  // first unlock) and passed in — this isolate never opens secure-storage plumbing.
  final db = await openAppDatabase(dbKey, await resolveDbPath());

  // A throwaway container; NEVER the UI container, NEVER shared across isolates.
  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
  );
  try {
    await container.read(reminderSchedulerProvider).reconcileFromDb();
  } finally {
    container.dispose();
    await db.close();
  }
}

// --- symbols elided for illustration -----------------------------------------
class AppDatabase {
  AppDatabase(Object connection);
  Future<void> close() async {}
}

class NativeDatabase {
  NativeDatabase(File file, {required void Function(Object raw) setup});
}

class ProviderContainer {
  ProviderContainer({required List<Object> overrides});
  T read<T>(Object provider) => throw UnimplementedError();
  void dispose() {}
}

Object get appDatabaseProvider => throw UnimplementedError();
Object get reminderSchedulerProvider => throw UnimplementedError();
extension _Ovr on Object {
  Object overrideWithValue(Object value) => this;
}

String hexEncode(Uint8List b) => throw UnimplementedError();
Future<String> resolveDbPath() async => throw UnimplementedError();
