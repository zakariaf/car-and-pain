import 'package:core/core.dart';

import '../db/app_database.dart';
import '../repositories/base_repository.dart';

/// The app-global key/value settings store (F4-T2). Deliberately generic — the
/// app owns the key namespace (locale, calendar, numeral, …). Reads never throw
/// across the boundary; writes return a typed [Result]. Backed by a reactive
/// Drift `.watch()` so a preference change re-renders the app with no restart.
class SettingsRepository extends BaseRepository {
  SettingsRepository(super.db);

  /// Every setting as a `{key: value}` map, re-emitting on any change.
  Stream<Map<String, String>> watchAll() =>
      db.select(db.settings).watch().map(_toMap);

  /// One-shot snapshot of all settings.
  Future<Map<String, String>> readAll() async =>
      _toMap(await db.select(db.settings).get());

  /// Read a single setting, or `null` if unset.
  Future<String?> get(String key) async {
    final row = await (db.select(db.settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Upsert [key]. Passing a `null` [value] removes it (reverting to default).
  Future<Result<void, DbFailure>> set(String key, String? value) async {
    try {
      if (value == null) {
        await (db.delete(db.settings)..where((t) => t.key.equals(key))).go();
      } else {
        await db.into(db.settings).insertOnConflictUpdate(
              SettingsCompanion.insert(key: key, value: value),
            );
      }
      return const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'settings'));
    }
  }

  Map<String, String> _toMap(List<SettingRow> rows) => {
        for (final r in rows) r.key: r.value,
      };
}
