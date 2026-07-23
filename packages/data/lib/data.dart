/// Car and Pain — `data`.
///
/// The single public entry point for the data layer: the encrypted Drift/
/// SQLCipher database, the isolate-safe open factory, the secure key store, the
/// repositories (emitting domain models with scoped `.watch()` streams), the
/// shared odometer ledger + rollups, soft-delete/trash, the custom taxonomy, and
/// the data-integrity validators. Zero network dependencies by construction.
library;

export 'src/attachments/attachment_bundle.dart'
    show AttachmentBundle, AttachmentBundler, AttachmentManifestEntry;
export 'src/attachments/attachment_gc.dart' show AttachmentGc, GcReport;
export 'src/attachments/blob_store.dart'
    show
        AttachmentBlobStore,
        DirectoryAttachmentBlobStore,
        InMemoryAttachmentBlobStore,
        blobRelativePath,
        contentSha256;
export 'src/backup/archive_cipher.dart' show ArchiveCipher;
export 'src/backup/backup_engine.dart' show BackupContents, BackupEngine;
export 'src/backup/backup_format.dart'
    show
        ArchiveHeader,
        ArchiveKdf,
        ArchiveSummary,
        archiveSha256,
        assembleArchive,
        parseArchive;
export 'src/backup/competitor_presets.dart'
    show
        CompetitorPreset,
        CsvFieldMap,
        aCarServicePreset,
        competitorPresets,
        dollarsToMinorUnits,
        drivvoServicePreset,
        fuelioServicePreset,
        fuellyFuelPreset,
        gallonsToMillilitres,
        isoDateToEpochMillis,
        kmToMetres,
        milesToMetres;
export 'src/backup/csv_export.dart'
    show csvField, exportEntitiesToCsv, rowsToCsv;
export 'src/backup/csv_import.dart' show parseCsv, parseCsvToMaps;
export 'src/db/app_database.dart' show AppDatabase;
export 'src/db/database_factory.dart' show openAppDatabase;
export 'src/db/migrations/snapshot_guard.dart' show SnapshotGuard;
export 'src/db/open_connection.dart'
    show ensureSqlCipherLoaded, openEncryptedExecutor;
export 'src/db/rekey.dart' show rekeyDatabaseFile;
export 'src/diagnostics/diagnostics_repository.dart'
    show AppDiagnosticsRepository, DiagnosticsRepository;
export 'src/domain/attachment.dart'
    show Attachment, AttachmentKind, AttachmentOwner;
export 'src/domain/fuel_entry.dart' show FuelEntry;
export 'src/domain/service_appointment.dart'
    show ServiceAppointment, WarrantyExpiry;
export 'src/domain/service_visit.dart'
    show
        FluidDraft,
        FluidUsed,
        PartDraft,
        PartUsed,
        ProcedureStep,
        ProcedureStepDraft,
        ServiceLineItem,
        ServiceLineItemDraft,
        ServiceVisit;
export 'src/domain/vehicle.dart' show Vehicle;
export 'src/infra/app_dirs.dart' show AppDirs;
export 'src/infra/app_time_zone.dart' show AppTimeZone;
export 'src/infra/secure_key_store.dart'
    show FakeSecureKeyStore, FlutterSecureKeyStore, SecureKeyStore;
export 'src/ledger/ledger_repository.dart' show LedgerRepository;
export 'src/merge/lww_merge_engine.dart'
    show
        EntityMergeResult,
        EntityStat,
        LwwMergeEngine,
        MergeConflict,
        MergeReport;
export 'src/notifications/notification_schedule_repository.dart'
    show NotificationScheduleRepository;
export 'src/providers.dart'
    show
        appDatabaseProvider,
        appDirsProvider,
        appTimeZoneProvider,
        attachmentsRepositoryProvider,
        diagnosticsRepositoryProvider,
        fuelRepositoryProvider,
        ledgerRepositoryProvider,
        notificationScheduleRepositoryProvider,
        secureKeyStoreProvider,
        serviceRepositoryProvider,
        settingsRepositoryProvider,
        stationsRepositoryProvider,
        taxonomyRepositoryProvider,
        trashRepositoryProvider,
        vehiclesRepositoryProvider;
export 'src/repositories/attachments_repository.dart'
    show AttachmentsRepository;
export 'src/repositories/base_repository.dart' show BaseRepository, newId;
export 'src/repositories/fuel_repository.dart' show FuelRepository;
export 'src/repositories/rollup_service.dart'
    show RollupService, monthPeriodKey;
export 'src/repositories/service_repository.dart' show ServiceRepository;
export 'src/repositories/stations_repository.dart' show StationsRepository;
export 'src/repositories/vehicles_repository.dart'
    show VehicleEdit, VehiclesRepository;
export 'src/serialization/canonical_codec.dart' show CanonicalCodec;
export 'src/service/schedule_template_library.dart'
    show ScheduleTemplateLibrary;
export 'src/settings/settings_repository.dart' show SettingsRepository;
export 'src/taxonomy/taxonomy.dart' show Category, TaxonomyRepository;
export 'src/trash/trash_repository.dart' show TrashItem, TrashRepository;
export 'src/validation/validators.dart' show IntegrityValidators;
