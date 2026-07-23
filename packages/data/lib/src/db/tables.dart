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
  TextColumn get trim => text().nullable()();
  IntColumn get modelYear => integer().nullable()();
  TextColumn get vehicleType => text().withDefault(const Constant('car'))();
  IntColumn get wheelCount => integer().nullable()();
  TextColumn get axleConfig => text().nullable()();

  // ── Identity ────────────────────────────────────────────────────────────
  TextColumn get licensePlate => text().nullable()();
  TextColumn get plateCountry => text().nullable()();
  TextColumn get vin => text().nullable()();
  BoolColumn get vinScanned => boolean().withDefault(const Constant(false))();
  BoolColumn get vinChecksumValid => boolean().nullable()();
  // Decoded WMI summary ("manufacturer · region · year") for quick reference.
  TextColumn get wmiDecoded => text().nullable()();
  TextColumn get paintColor => text().nullable()();
  TextColumn get paintCode => text().nullable()();

  // ── Powertrain (adaptive; see core PowertrainProfile) ─────────────────────
  TextColumn get energyType => text().nullable()();
  TextColumn get secondaryEnergyType => text().nullable()();
  IntColumn get tankCapacityMl => integer().nullable()();
  IntColumn get secondaryTankMl => integer().nullable()();
  TextColumn get fuelGrade => text().nullable()();
  IntColumn get batteryCapacityJoules => integer().nullable()();
  IntColumn get usableCapacityJoules => integer().nullable()();
  // Charge connectors as a comma-joined code list (small fixed enum, not a log).
  TextColumn get connectorTypes => text().nullable()();
  BoolColumn get distanceTrackingEnabled =>
      boolean().withDefault(const Constant(true))();

  // ── Odometer / engine-hour ledger cache ───────────────────────────────────
  IntColumn get currentOdometerMetres => integer().nullable()();
  IntColumn get currentOdometerAt => integer().nullable()();
  IntColumn get clusterOffsetMetres =>
      integer().withDefault(const Constant(0))();

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  TextColumn get status => text().withDefault(const Constant('active'))();
  IntColumn get statusChangedAt => integer().nullable()();
  IntColumn get soldDate => integer().nullable()();
  IntColumn get soldPriceMinor => integer().nullable()();
  IntColumn get finalOdometerMetres => integer().nullable()();

  // ── Ownership / valuation ─────────────────────────────────────────────────
  IntColumn get purchaseDate => integer().nullable()();
  IntColumn get purchasePriceMinor => integer().nullable()();
  TextColumn get purchaseCurrency => text().nullable()();
  IntColumn get currentValueMinor => integer().nullable()();

  // ── Grouping / organization ───────────────────────────────────────────────
  TextColumn get groupId => text().nullable()();
  // Free custom tags as a comma-joined list.
  TextColumn get tags => text().nullable()();
  IntColumn get sortOrder => integer().nullable()();
  TextColumn get coverPhotoRef => text().nullable()();

  // ── Reference ─────────────────────────────────────────────────────────────
  // factory_reference_specs as a JSON object (a bag of OEM specs, not a log).
  TextColumn get factorySpecs => text().nullable()();

  // ── Per-vehicle display overrides (null → fall back to the global default) ─
  TextColumn get distanceUnit => text().nullable()();
  TextColumn get volumeUnit => text().nullable()();
  TextColumn get consumptionUnit => text().nullable()();
  TextColumn get currencyCode => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

/// Prior-plate history — a normalized child table (never a JSON blob) so it
/// exports as a linked child CSV keyed by `vehicle_id` (M2-T1).
@DataClassName('PlateHistoryRow')
class PlateHistory extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  TextColumn get plate => text()();
  TextColumn get country => text().nullable()();
  IntColumn get fromDate => integer().nullable()();
  IntColumn get toDate => integer().nullable()();
}

/// Dated valuations for equity / depreciation — a normalized child table.
@DataClassName('ValuationRow')
class ValuationHistory extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  IntColumn get valuedAt => integer()();
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text()();
  TextColumn get source => text().nullable()();
}

/// Dated EV battery State-of-Health entries — a normalized child table. `soh`
/// is stored in per-mille (0–1000) so 87.5 % round-trips losslessly.
@DataClassName('StateOfHealthRow')
class StateOfHealthLog extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  IntColumn get recordedAt => integer()();
  IntColumn get sohPermille => integer()();
  TextColumn get note => text().nullable()();
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
@DataClassName('FuelEntryRow')
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

  // ── M3 liquid/gas fields ──────────────────────────────────────────────────
  // gasoline | diesel | lpg | cng | ethanol | hydrogen | electric.
  TextColumn get fuelType => text().nullable()();
  TextColumn get octaneGrade => text().nullable()();
  TextColumn get secondaryFuelType => text().nullable()();
  // Entered display unit (L | usGal | ukGal | kg | m3); volume stays canonical.
  TextColumn get volumeUnit => text().nullable()();
  // Unit price in thousandths of a major currency unit (3-decimal precision).
  IntColumn get pricePerUnitThousandths => integer().nullable()();
  BoolColumn get isFree => boolean().withDefault(const Constant(false))();

  // ── M3 EV / PHEV charge fields ────────────────────────────────────────────
  TextColumn get chargerType => text().nullable()(); // acL1/acL2/dcFast
  TextColumn get connectorType => text().nullable()();
  IntColumn get startSocPct => integer().nullable()();
  IntColumn get endSocPct => integer().nullable()();
  BoolColumn get isHomeCharge => boolean().withDefault(const Constant(false))();
  IntColumn get energyFromWallJoules => integer().nullable()();
  TextColumn get network => text().nullable()();

  // ── Shared ────────────────────────────────────────────────────────────────
  TextColumn get stationId => text().nullable()();
  TextColumn get stationName => text().nullable()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get tripId => text().nullable()();
  TextColumn get tags => text().nullable()();
  TextColumn get receiptAttachmentId => text().nullable()();
}

/// A multi-line-item service visit mapped to one receipt (M4-T1). The header
/// carries the visit-level cost breakdown; the jobs live in [ServiceLineItems].
/// `totalCostMinor` is the cached authoritative visit total
/// (Σ line items + tax − discount + fees), computed by the pure cost engine.
class ServiceEntries extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  IntColumn get servicedAt => integer()();
  IntColumn get odometerMetres => integer().nullable()();
  IntColumn get totalCostMinor => integer()();
  TextColumn get currencyCode => text()();
  BoolColumn get isDiy => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  // ── M4-T1: header cost breakdown, provider, tags, source ──────────────────
  // Workshop from the offline directory (nullable, non-cascading).
  TextColumn get providerId =>
      text().nullable().references(ServiceProviders, #id)();
  IntColumn get taxMinor => integer().withDefault(const Constant(0))();
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();
  IntColumn get feesMinor => integer().withDefault(const Constant(0))();
  // Visit-level labour: canonical whole minutes + per-hour rate (minor units).
  IntColumn get labourMinutes => integer().nullable()();
  IntColumn get labourRateMinor => integer().nullable()();
  // JSON array of user tags (comma-safe, unlike a delimited string).
  TextColumn get tags => text().nullable()();
  // manual | import | template.
  TextColumn get source => text().withDefault(const Constant('manual'))();
  // generic | severe | custom — the schedule profile applied (M4-T3).
  TextColumn get scheduleProfile => text().nullable()();
}

/// The offline workshop / mechanic directory (M4-T4). Global, not vehicle-scoped:
/// one shop is referenced by many visits across vehicles. Phone numbers are
/// stored raw and rendered LTR-isolated (bidi) at the edge, never reordered.
@DataClassName('ServiceProviderRow')
class ServiceProviders extends Table with AuditColumns {
  TextColumn get name => text()();
  // shop | mechanic | dealer | diy | other.
  TextColumn get kind => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get notes => text().nullable()();
}

/// One job within a visit — several map to a single receipt (M4-T1). The service
/// type resolves through the shared taxonomy ([Categories], built-in-editable +
/// custom), never an enum. Interval columns override the taxonomy default per
/// vehicle; null = inherit. Cost is the labour-vs-parts split in integer minor
/// units (no float anywhere in the money path).
@DataClassName('ServiceLineItemRow')
class ServiceLineItems extends Table with AuditColumns {
  TextColumn get visitId =>
      text().references(ServiceEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get serviceTypeId =>
      text().nullable().references(Categories, #id)();
  IntColumn get labourMinor => integer().withDefault(const Constant(0))();
  IntColumn get partsMinor => integer().withDefault(const Constant(0))();
  // A full change resets the interval clock; a top-up must NOT (leaves it).
  BoolColumn get resetsInterval =>
      boolean().withDefault(const Constant(true))();
  // Per-item DIY override; null = inherit the visit-level flag.
  BoolColumn get isDiy => boolean().nullable()();
  // Interval override (null = inherit the service type's taxonomy default).
  IntColumn get intervalDistanceMetres => integer().nullable()();
  IntColumn get intervalMonths => integer().nullable()();
  // distance | time | whicheverFirst.
  TextColumn get intervalLogic => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  // ── M4-T2: workmanship warranty (both date and mileage) ───────────────────
  IntColumn get warrantyUntilDate => integer().nullable()();
  IntColumn get warrantyUntilMileageMetres => integer().nullable()();
}

/// A part fitted during a line item (M4-T2). Part numbers are stored raw and
/// rendered LTR-isolated (bidi) at the edge so they are never reordered in RTL or
/// export. Cost is `unitCostMinor × quantity` in integer minor units. Parts carry
/// their own warranty (date + mileage), feeding the warranty-compliance surface.
@DataClassName('PartUsedRow')
class PartsUsed extends Table with AuditColumns {
  TextColumn get lineItemId =>
      text().references(ServiceLineItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get oemNumber => text().nullable()();
  TextColumn get aftermarketNumber => text().nullable()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get unitCostMinor => integer().withDefault(const Constant(0))();
  TextColumn get supplier => text().nullable()();
  IntColumn get warrantyUntilDate => integer().nullable()();
  IntColumn get warrantyUntilMileageMetres => integer().nullable()();
}

/// A fluid/consumable used during a line item (M4-T2), e.g. 5W-30, DOT4, G12.
/// Quantity is canonical millilitres; display converts (L/qt) at the edge.
@DataClassName('FluidUsedRow')
class FluidsUsed extends Table with AuditColumns {
  TextColumn get lineItemId =>
      text().references(ServiceLineItems, #id, onDelete: KeyAction.cascade)();
  // engineOil | coolant | brakeFluid | transmission | … (free text, localized).
  TextColumn get fluidType => text()();
  TextColumn get spec => text().nullable()();
  IntColumn get quantityMl => integer().nullable()();
}

/// One ordered step of a DIY procedure log (M4-T2): the instruction plus optional
/// torque spec and notes. Reorderable via [stepOrder].
@DataClassName('ProcedureStepRow')
class ServiceProcedureSteps extends Table with AuditColumns {
  TextColumn get lineItemId =>
      text().references(ServiceLineItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get stepOrder => integer().withDefault(const Constant(0))();
  TextColumn get instruction => text()();
  TextColumn get torqueSpec => text().nullable()();
  TextColumn get notes => text().nullable()();
}

/// A booked service appointment (M4-T5) — a specific date+time with a shop.
/// Deliberately a SEPARATE class from interval reminders: cancelling an
/// appointment never clears an interval reminder and vice-versa. Generates a
/// local timed `.ics` for the device calendar (no server). `scheduledAt` is a
/// true instant (UTC epoch millis); the calendar renders it in the user's locale.
@DataClassName('AppointmentRow')
class ServiceAppointments extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  TextColumn get providerId =>
      text().nullable().references(ServiceProviders, #id)();
  IntColumn get scheduledAt => integer()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(60))();
  // scheduled | completed | cancelled | noShow.
  TextColumn get status => text().withDefault(const Constant('scheduled'))();
  TextColumn get title => text().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Any car cost — the canonical ledger every cost writes into (M6-T1). Money is
/// integer minor units keyed to the currency's real exponent; a dated-FX triple
/// converts the entry to the base currency at the rate that applied on its date.
/// A polymorphic source link lets fuel/service/tire rows project here without
/// being double-counted.
@DataClassName('ExpenseRow')
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
  // ── M6-T1 ─────────────────────────────────────────────────────────────────
  // Optional driver scoping (household P&L, later modules).
  TextColumn get driverId => text().nullable()();
  // Dated FX: rate (thousandths of base per unit) applied on [fxAsOf], and the
  // resulting base-currency amount — so a historical entry never re-converts at
  // today's rate.
  IntColumn get fxRateThousandths => integer().nullable()();
  IntColumn get fxAsOf => integer().nullable()();
  IntColumn get baseAmountMinor => integer().nullable()();
  // Polymorphic source link (fuel | service | tire | …) so a module row projects
  // into the ledger without duplication.
  TextColumn get sourceEntityType => text().nullable()();
  TextColumn get sourceEntityId => text().nullable()();
  TextColumn get receiptAttachmentId => text().nullable()();
  // JSON array of user tags (comma-safe).
  TextColumn get tags => text().nullable()();
  // The calendar the entry was made in (for calendar-aware display).
  TextColumn get entryCalendar => text().nullable()();
}

/// A loan or lease against a vehicle (M6-T4). The amortization schedule is
/// recomputed by the pure engine from these terms — never stored as a lossy
/// duplicate. `refinancedFromId` links a successor to the schedule it replaced;
/// `closedAt` marks a paid-off/refinanced loan.
@DataClassName('FinancingRow')
class Financings extends Table with AuditColumns {
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  // loan | lease.
  TextColumn get kind => text()();
  IntColumn get principalMinor => integer()();
  TextColumn get currencyCode => text()();
  IntColumn get aprBps => integer()();
  IntColumn get termMonths => integer()();
  IntColumn get startDate => integer()();
  IntColumn get residualMinor => integer().withDefault(const Constant(0))();
  TextColumn get refinancedFromId => text().nullable()();
  IntColumn get closedAt => integer().nullable()();
  TextColumn get notes => text().nullable()();
}

/// A spending budget (M6-T3): per category (null = overall), per vehicle (null =
/// all-vehicles), a calendar-aware period, and a minor-unit target in the base
/// currency. Alert de-dup state fires each threshold once per period.
@DataClassName('BudgetRow')
class Budgets extends Table with AuditColumns {
  TextColumn get vehicleId => text()
      .nullable()
      .references(Vehicles, #id, onDelete: KeyAction.cascade)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  // monthly | quarterly | annual.
  TextColumn get period => text()();
  IntColumn get targetMinor => integer()();
  TextColumn get currencyCode => text()();
  // cash | amortized.
  TextColumn get basis => text().withDefault(const Constant('cash'))();
  // The highest alert threshold already fired + the period key it fired for.
  IntColumn get lastAlertThreshold => integer().nullable()();
  TextColumn get lastAlertPeriod => text().nullable()();
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

/// A reminder record. F5 owns the scheduling primitives; M5 adds the user-facing
/// layer (notes, snooze state) + the CRUD repository and live-state stream.
@DataClassName('ReminderRow')
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
  // ── M5-T1: user-facing layer ──────────────────────────────────────────────
  TextColumn get notes => text().nullable()();
  // Snoozed until this instant (UTC epoch millis); null = not snoozed.
  IntColumn get snoozeUntil => integer().nullable()();
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
  // M4: time + logic interval defaults for service types (the distance default
  // is `defaultIntervalMetres`). logic: distance | time | whicheverFirst.
  IntColumn get defaultIntervalMonths => integer().nullable()();
  TextColumn get defaultIntervalLogic => text().nullable()();
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

/// A user-saved fuel/charge station (M3-T9): the fully-offline substitute for a
/// live station directory. Name + optional brand and raw GPS (micro-degrees,
/// lat/lng × 1e6) pinned on the bundled offline map — no online geocoding. Rides
/// backup/export like every other entity.
@DataClassName('SavedStationRow')
class SavedStations extends Table with AuditColumns {
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  IntColumn get latMicro => integer().nullable()();
  IntColumn get lngMicro => integer().nullable()();
}
