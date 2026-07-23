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
      case 7: // 7 → 8: M4-T1 service line items, provider directory, taxonomy
        // interval defaults, and the visit header cost breakdown.
        await m.createTable(db.serviceProviders);
        await m.createTable(db.serviceLineItems);
        final c = db.categories;
        await m.addColumn(c, c.defaultIntervalMonths);
        await m.addColumn(c, c.defaultIntervalLogic);
        final s = db.serviceEntries;
        for (final col in [
          s.providerId,
          s.taxMinor,
          s.discountMinor,
          s.feesMinor,
          s.labourMinutes,
          s.labourRateMinor,
          s.tags,
          s.source,
          s.scheduleProfile,
        ]) {
          await m.addColumn(s, col);
        }
      case 8: // 8 → 9: M4-T2 parts/fluids/procedure logs + workmanship warranty.
        final li = db.serviceLineItems;
        // `createTable(serviceLineItems)` in case 7 uses the *live* (v9) schema,
        // which already carries these columns — so a v7→v9 run creates them
        // there and must NOT re-add them here. A genuine v8 install created the
        // table without them and DOES need the add. Guard on the live column set.
        if (!await _hasColumn(
            db, 'service_line_items', 'warranty_until_date')) {
          await m.addColumn(li, li.warrantyUntilDate);
        }
        if (!await _hasColumn(
            db, 'service_line_items', 'warranty_until_mileage_metres')) {
          await m.addColumn(li, li.warrantyUntilMileageMetres);
        }
        await m.createTable(db.partsUsed);
        await m.createTable(db.fluidsUsed);
        await m.createTable(db.serviceProcedureSteps);
      case 9: // 9 → 10: M4-T5 service appointments (separate from reminders).
        await m.createTable(db.serviceAppointments);
      case 10: // 10 → 11: M5-T1 reminder notes + snooze state.
        final rem = db.reminders;
        await m.addColumn(rem, rem.notes);
        await m.addColumn(rem, rem.snoozeUntil);
      // Future versions append their `case N` block here.
    }
  }
}

/// Whether [table] currently has [column] — used to make an `addColumn` step
/// idempotent when the same table may have been created fresh (with the live
/// schema, which already includes the column) earlier in the same upgrade run.
Future<bool> _hasColumn(AppDatabase db, String table, String column) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.any((r) => r.read<String>('name') == column);
}
