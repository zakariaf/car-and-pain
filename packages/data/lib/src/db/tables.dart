import 'package:drift/drift.dart';

/// Universal audit columns on **every** table (F2-T1):
/// - `id` — UUIDv7 text PK (time-ordered, collision-free, stable across export).
/// - `created_at` / `updated_at` — UTC epoch millis; `updated_at` is the
///   last-write-wins merge tiebreaker, bumped on every write.
/// - `row_revision` — incremented on every write (soft-delete/Undo/P2P merge).
/// - `is_deleted` / `deleted_at` / `trash_expires_at` — soft-delete tombstones.
///
/// Shaped so household P2P sync (UUID + tombstone + `updated_at`) is possible
/// later without a migration.
mixin AuditColumns on Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get rowRevision => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get trashExpiresAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The hub. Every operational record references a vehicle. Rich powertrain
/// fields are added by M2; F2 defines the backbone + per-vehicle unit/currency
/// overrides (canonical storage is unaffected by these display preferences).
@DataClassName('VehicleRow')
class Vehicles extends Table with AuditColumns {
  TextColumn get nickname => text()();
  TextColumn get make => text().nullable()();
  TextColumn get model => text().nullable()();
  IntColumn get modelYear => integer().nullable()();
  TextColumn get vehicleType => text().withDefault(const Constant('car'))();
  TextColumn get energyType => text().nullable()();
  IntColumn get tankCapacityMl => integer().nullable()();
  IntColumn get batteryCapacityJoules => integer().nullable()();
  IntColumn get currentOdometerMetres => integer().nullable()();
  IntColumn get currentOdometerAt => integer().nullable()();
  IntColumn get clusterOffsetMetres =>
      integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  // Per-vehicle display overrides (null → fall back to the global default).
  TextColumn get distanceUnit => text().nullable()();
  TextColumn get volumeUnit => text().nullable()();
  TextColumn get currencyCode => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

/// The single shared per-vehicle odometer / engine-hour ledger — the app's spine.
/// Written by fuel/service/expense/trip/tire/manual/import; read by reminders,
/// stats, tires, warranties, financing. `value` is canonical (metres or minutes).
class OdometerReadings extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  IntColumn get value => integer()();
  IntColumn get takenAt => integer()();
  // fuel | service | expense | trip | tire | manual | import (LedgerSource).
  TextColumn get source => text()();
  TextColumn get sourceRecordId => text().nullable()();
  IntColumn get cumulativeOffset => integer().withDefault(const Constant(0))();
  BoolColumn get isRegressionOverride =>
      boolean().withDefault(const Constant(false))();
}

/// A unified energy record (liquid/gas fill or EV/PHEV charge). M3 adds the full
/// economy state machine; F2 keeps the canonical backbone.
class FuelEntries extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  IntColumn get filledAt => integer()();
  IntColumn get odometerMetres => integer()();
  IntColumn get volumeMl => integer()();
  IntColumn get energyJoules => integer().nullable()();
  IntColumn get totalCostMinor => integer()();
  TextColumn get currencyCode => text()();
  BoolColumn get isFullTank => boolean().withDefault(const Constant(true))();
  BoolColumn get isPartial => boolean().withDefault(const Constant(false))();
  BoolColumn get isMissedPrevious =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get excludeFromEconomy =>
      boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

/// A service visit mapped to one receipt. M4 adds line items/parts/warranties.
class ServiceEntries extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  IntColumn get servicedAt => integer()();
  IntColumn get odometerMetres => integer().nullable()();
  IntColumn get totalCostMinor => integer()();
  TextColumn get currencyCode => text()();
  BoolColumn get isDiy => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

/// Any car cost. M6 adds recurring/amortization/loan/lease/TCO.
class Expenses extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  IntColumn get spentAt => integer()();
  // Signed so refunds net as negatives.
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text()();
  IntColumn get odometerMetres => integer().nullable()();
  TextColumn get notes => text().nullable()();
}

/// A trip logbook entry. M7 adds tax classification + rate engines.
class Trips extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  IntColumn get tripAt => integer()();
  IntColumn get startOdometerMetres => integer().nullable()();
  IntColumn get endOdometerMetres => integer().nullable()();
  IntColumn get distanceMetres => integer()();
  TextColumn get purpose => text().nullable()();
  BoolColumn get isBusiness => boolean().withDefault(const Constant(false))();
}

/// A reminder record. F5/M5 add the projection + scheduling state.
class Reminders extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  // date | distance | hours | whicheverFirst.
  TextColumn get triggerType => text()();
  IntColumn get dueDate => integer().nullable()();
  IntColumn get dueOdometerMetres => integer().nullable()();
  // F5-T2: engine-hour threshold (whole minutes) + completion anchor.
  IntColumn get dueEngineMinutes => integer().nullable()();
  IntColumn get completedAt => integer().nullable()();
  // Recurrence: `every` + unit (days|weeks|months|years); null = one-off.
  IntColumn get recurrenceEvery => integer().nullable()();
  TextColumn get recurrenceUnit => text().nullable()();
  // Lead-times (fire early): whole minutes + distance-expressed metres.
  IntColumn get leadMinutes => integer().withDefault(const Constant(0))();
  IntColumn get leadDistanceMetres => integer().nullable()();
  // Severity → channel: overdue | dueSoon | documents | info.
  TextColumn get severity => text().withDefault(const Constant('info'))();
  // Quiet-hours (local minutes from midnight) + preferred delivery minute.
  IntColumn get quietStartMinute => integer().nullable()();
  IntColumn get quietEndMinute => integer().nullable()();
  IntColumn get quietDeliverMinute => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
}

/// The derived OS-notification projection (F5-T2): one row per concrete pending
/// entry with its deterministic id, computed fire instant, the already-localized
/// copy that was armed, the severity channel, and a digest group key.
/// Rebuildable from [Reminders] + the ledger; a pure projection, so it carries
/// no audit/tombstone columns.
@DataClassName('ScheduledNotificationRow')
class ScheduledNotifications extends Table {
  IntColumn get notifId => integer()();
  // Nullable, no FK: a digest entry spans several reminders, and the whole
  // projection is wiped + rebuilt on every reconcile, so referential cleanup
  // isn't needed.
  TextColumn get reminderId => text().nullable()();
  IntColumn get fireAt => integer()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get channel => text().withDefault(const Constant('info'))();
  TextColumn get groupKey => text().nullable()();

  @override
  Set<Column> get primaryKey => {notifId};
}

/// The shared custom taxonomy: service types, expense categories, trip
/// categories, tags, and cost-centres — one table with a `kind` discriminator.
/// Custom user rows map to a fixed `analyticBucket` so reports stay stable.
@DataClassName('CategoryRow')
class Categories extends Table with AuditColumns {
  // service | expense | trip | tag | costCentre.
  TextColumn get kind => text()();
  // A localization key OR a user-entered literal (see `isCustom`).
  TextColumn get label => text()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get iconKey => text().withDefault(const Constant('tag'))();
  // Colour is paired with icon+label (never colour alone) per PULSE.
  TextColumn get colorToken => text().nullable()();
  IntColumn get defaultIntervalMetres => integer().nullable()();
  // Fixed analytic bucket so custom naming never destabilizes reports.
  TextColumn get analyticBucket => text()();
}

/// Pre-aggregated per-vehicle / per-period summaries feeding dashboards. Keyed
/// by (vehicle, period, metric); revision-stamped; rebuildable from source.
class Rollups extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  // e.g. '2026-07' (month) — the aggregation bucket.
  TextColumn get periodKey => text()();
  // distanceMetres | costMinor | fuelMl | energyJoules.
  TextColumn get metric => text()();
  IntColumn get value => integer().withDefault(const Constant(0))();
  IntColumn get revision => integer().withDefault(const Constant(0))();
}

/// Polymorphic attachment metadata (F8-T1). Bytes never live in SQLite — the
/// file is content-addressed by PLAINTEXT sha256 and stored (optionally sealed)
/// on disk; refcounted for shared-blob GC. `sizeBytes`/`thumbnailRelativePath`/
/// `isEncrypted` were added at schema v4 for size accounting, gallery rendering,
/// and per-blob at-rest sealing (F8-T3/T4/T5).
@DataClassName('AttachmentRow')
class Attachments extends Table with AuditColumns {
  TextColumn get sha256 => text()();
  TextColumn get relativePath => text()();
  TextColumn get mimeType => text()();
  TextColumn get originalFilename => text().nullable()();
  TextColumn get linkedEntityType => text()();
  TextColumn get linkedEntityId => text()();
  IntColumn get refCount => integer().withDefault(const Constant(1))();

  /// Canonical byte size of the stored (plaintext) content — for size accounting.
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();

  /// App-private path to the derived thumbnail, if one was generated.
  TextColumn get thumbnailRelativePath => text().nullable()();

  /// Whether the on-disk blob (+ thumbnail) is AES-GCM sealed with the master key.
  BoolColumn get isEncrypted => boolean().withDefault(const Constant(false))();
}

/// App-global key/value settings (F4-T2): the app-controlled locale, calendar
/// system, numeral system, and future display preferences. Not per-vehicle and
/// never trashed, so it carries no [AuditColumns] — just a typed key and its
/// string value. Added at schema v2 (see `migrations/steps.dart`).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
