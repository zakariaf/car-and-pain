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
      case 4: // 4 → 5: full M2 vehicle profile + plate/valuation/SoH child tables.
        final v = db.vehicles;
        for (final col in [
          v.trim,
          v.wheelCount,
          v.axleConfig,
          v.licensePlate,
          v.plateCountry,
          v.vin,
          v.vinScanned,
          v.vinChecksumValid,
          v.wmiDecoded,
          v.paintColor,
          v.paintCode,
          v.secondaryEnergyType,
          v.secondaryTankMl,
          v.fuelGrade,
          v.usableCapacityJoules,
          v.connectorTypes,
          v.distanceTrackingEnabled,
          v.statusChangedAt,
          v.soldDate,
          v.soldPriceMinor,
          v.finalOdometerMetres,
          v.purchaseDate,
          v.purchasePriceMinor,
          v.purchaseCurrency,
          v.currentValueMinor,
          v.groupId,
          v.tags,
          v.sortOrder,
          v.coverPhotoRef,
          v.factorySpecs,
          v.consumptionUnit,
        ]) {
          await m.addColumn(v, col);
        }
        await m.createTable(db.plateHistory);
        await m.createTable(db.valuationHistory);
        await m.createTable(db.stateOfHealthLog);
      case 5: // 5 → 6: M3 unified fuel/charge fields on fuel_entries.
        final fe = db.fuelEntries;
        for (final col in [
          fe.fuelType,
          fe.octaneGrade,
          fe.secondaryFuelType,
          fe.volumeUnit,
          fe.pricePerUnitThousandths,
          fe.isFree,
          fe.chargerType,
          fe.connectorType,
          fe.startSocPct,
          fe.endSocPct,
          fe.isHomeCharge,
          fe.energyFromWallJoules,
          fe.network,
          fe.stationId,
          fe.stationName,
          fe.paymentMethod,
          fe.tripId,
          fe.tags,
          fe.receiptAttachmentId,
        ]) {
          await m.addColumn(fe, col);
        }
      case 6: // 6 → 7: M3-T9 saved-stations library.
        await m.createTable(db.savedStations);
      // Future versions append their `case N` block here.
    }
  }
}
