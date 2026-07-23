import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:car_and_pain/src/shell/shell_state.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

/// M1-T10: the shell's durable UI state (active vehicle, scope, last Room) is
/// written through the settings repository at the canonical boundary and rides
/// the single-file backup (whole DB) + JSON export/import (CanonicalCodec covers
/// the SETTING table with schema versioning). This proves persist → reload →
/// restore for each field.
void main() {
  test(
      'shell UI state persists, reloads, and survives an export/import restore',
      () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final settings = SettingsRepository(db);
    final shell = ShellStateController(settings);

    // Persist — each write returns a sealed Result (never throws across it).
    expect((await shell.setActiveVehicle('veh-1')).isOk, isTrue);
    expect((await shell.setScope(VehicleScope.fleet)).isOk, isTrue);
    expect((await shell.setLastRoom('garage')).isOk, isTrue);

    // Reload — read straight back from the repository.
    expect(await settings.get(SettingsKeys.defaultVehicleId), 'veh-1');
    expect(await settings.get(SettingsKeys.scope), 'fleet');
    expect(await settings.get(SettingsKeys.lastRoom), 'garage');

    // Restore — export the DB and replace-restore into a fresh one.
    final doc = await CanonicalCodec(db).export();
    expect(doc['schemaVersion'], isNotNull); // versioned document

    final db2 = AppDatabase.memory();
    addTearDown(db2.close);
    expect((await CanonicalCodec(db2).import(doc)).isOk, isTrue);

    final restored = SettingsRepository(db2);
    expect(await restored.get(SettingsKeys.defaultVehicleId), 'veh-1');
    expect(await restored.get(SettingsKeys.scope), 'fleet');
    expect(await restored.get(SettingsKeys.lastRoom), 'garage');
  });

  test(
      'a restore whose active vehicle is gone falls back, never a broken shell',
      () async {
    // The pinned vehicle no longer exists in the active set → resolve to the
    // first active vehicle (or empty), never a dangling selection.
    final active = [
      const Vehicle(id: 'a', nickname: 'Golf'),
      const Vehicle(id: 'b', nickname: 'Civic'),
    ];
    expect(resolveActiveVehicleId(active, 'ghost'), 'a');
    expect(resolveActiveVehicleId(const [], 'ghost'), isNull);
  });
}
