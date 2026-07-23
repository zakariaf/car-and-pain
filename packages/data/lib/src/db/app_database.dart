import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'migrations/snapshot_guard.dart';
import 'migrations/steps.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The one shared encrypted Drift database. Opened via `openEncryptedExecutor`
/// (PRAGMA key first, cipher asserted); tests use [AppDatabase.memory].
@DriftDatabase(
  tables: [
    Vehicles,
    PlateHistory,
    ValuationHistory,
    StateOfHealthLog,
    OdometerReadings,
    FuelEntries,
    ServiceEntries,
    ServiceProviders,
    ServiceLineItems,
    PartsUsed,
    FluidsUsed,
    ServiceProcedureSteps,
    ServiceAppointments,
    Expenses,
    Trips,
    Reminders,
    Categories,
    Rollups,
    Attachments,
    Settings,
    ScheduledNotifications,
    SavedStations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// An in-memory (plaintext) database for host tests — no cipher needed.
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  /// Optional snapshot guard; when set, forward migrations take a pre-migration
  /// file-copy snapshot and restore it on failure. Null in memory/tests.
  SnapshotGuard? snapshotGuard;

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (m, from, to) async {
          // Forward-only + snapshot-guarded (F2-T5). Restore the snapshot on any
          // failure — SQLite has no true down-migration.
          final snapshot = await snapshotGuard?.take();
          try {
            await runForwardMigrations(m, this, from: from, to: to);
          } catch (_) {
            if (snapshot != null) await snapshotGuard?.restore(snapshot);
            rethrow;
          }
        },
        beforeOpen: (details) async {
          // Refuse to open a DB newer than this binary understands (forward-only;
          // never silently downgrade). Surfaces as a typed startup failure.
          final before = details.versionBefore;
          if (before != null && before > schemaVersion) {
            throw StateError(
              'DB schema v$before is newer than supported v$schemaVersion',
            );
          }
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  Future<void> _createIndexes() async {
    // Index for the real access patterns: "this vehicle, ordered by time".
    const statements = <String>[
      'CREATE INDEX IF NOT EXISTS idx_odo_vehicle_time ON odometer_readings (vehicle_id, taken_at);',
      'CREATE INDEX IF NOT EXISTS idx_fuel_vehicle_time ON fuel_entries (vehicle_id, filled_at);',
      'CREATE INDEX IF NOT EXISTS idx_service_vehicle_time ON service_entries (vehicle_id, serviced_at);',
      'CREATE INDEX IF NOT EXISTS idx_service_line_item_visit ON service_line_items (visit_id, sort_order);',
      'CREATE INDEX IF NOT EXISTS idx_part_line_item ON parts_used (line_item_id);',
      'CREATE INDEX IF NOT EXISTS idx_fluid_line_item ON fluids_used (line_item_id);',
      'CREATE INDEX IF NOT EXISTS idx_procedure_line_item ON service_procedure_steps (line_item_id, step_order);',
      'CREATE INDEX IF NOT EXISTS idx_appointment_vehicle_time ON service_appointments (vehicle_id, scheduled_at);',
      'CREATE INDEX IF NOT EXISTS idx_expense_vehicle_time ON expenses (vehicle_id, spent_at);',
      'CREATE INDEX IF NOT EXISTS idx_trip_vehicle_time ON trips (vehicle_id, trip_at);',
      // UNIQUE: exactly one rollup per (vehicle, period, metric). Enforces the
      // documented invariant at the DB level so RollupService.getSingleOrNull()
      // can never trip a StateError on a duplicate and crash dashboard reads.
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_rollup_key ON rollups (vehicle_id, period_key, metric);',
      'CREATE INDEX IF NOT EXISTS idx_attach_sha ON attachments (sha256);',
      'CREATE INDEX IF NOT EXISTS idx_attach_owner ON attachments (linked_entity_type, linked_entity_id);',
    ];
    for (final s in statements) {
      await customStatement(s);
    }
  }
}
