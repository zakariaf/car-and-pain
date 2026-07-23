import 'package:core/core.dart';
import 'package:data/data.dart';
// Hide the SQL helpers so the matchers (not drift) win in expectations.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

/// M7-T1 · the trip logbook boundary: odometer/direct/location entry, shared
/// ledger writes, gap reconciliation, classification, and the rate-scheme
/// round-trip through the engine.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Instant at(int day) => Instant.fromEpochMillis(
      1000000000000 + day * Duration.millisecondsPerDay);

  Future<String> seedVehicle() async =>
      (await VehiclesRepository(db).add(nickname: 'Trip Car')).valueOrNull!.id;

  Future<int> ledgerCount(String vehicleId) async {
    final rows = await (db.select(db.odometerReadings)
          ..where((t) =>
              t.vehicleId.equals(vehicleId) &
              t.source.equals(LedgerSource.trip.name)))
        .get();
    return rows.length;
  }

  group('TripsRepository.add', () {
    test('by odometer: distance = end − start, both readings hit the ledger',
        () async {
      final v = await seedVehicle();
      final repo = TripsRepository(db);
      final r = await repo.add(
        vehicleId: v,
        tripAt: at(0),
        startOdometerMetres: 10000000,
        endOdometerMetres: 10050000,
      );
      expect(r.isOk, isTrue);
      final trip = (await repo.byId(r.valueOrNull!))!;
      expect(trip.distanceMetres, 50000);
      // Two ledger readings (start + end), source-tagged trip.
      expect(await ledgerCount(v), 2);
      // Vehicle odometer advanced to the end reading.
      final veh = await (db.select(db.vehicles)..where((t) => t.id.equals(v)))
          .getSingle();
      expect(veh.currentOdometerMetres, 10050000);
    });

    test('by direct distance: stored as-is, no odometer readings', () async {
      final v = await seedVehicle();
      final repo = TripsRepository(db);
      final r = await repo.add(
          vehicleId: v, tripAt: at(0), directDistanceMetres: 8000);
      expect(r.isOk, isTrue);
      expect((await repo.byId(r.valueOrNull!))!.distanceMetres, 8000);
      expect(await ledgerCount(v), 0);
    });

    test('zero / negative / missing distance → typed ValidationFailure',
        () async {
      final v = await seedVehicle();
      final repo = TripsRepository(db);
      // end == start → zero distance.
      final zero = await repo.add(
          vehicleId: v,
          tripAt: at(0),
          startOdometerMetres: 100,
          endOdometerMetres: 100);
      expect(zero.isErr, isTrue);
      expect(zero.failureOrNull, isA<ValidationFailure>());
      expect((zero.failureOrNull! as ValidationFailure).fieldErrors.single.code,
          'non_positive');
      // Neither odometer pair nor direct distance → required.
      final missing = await repo.add(vehicleId: v, tripAt: at(0));
      expect(
          (missing.failureOrNull! as ValidationFailure).fieldErrors.single.code,
          'required');
    });

    test('gap reconciliation stores the gap before the next trip', () async {
      final v = await seedVehicle();
      final repo = TripsRepository(db);
      await repo.add(
          vehicleId: v,
          tripAt: at(0),
          startOdometerMetres: 10000000,
          endOdometerMetres: 10050000);
      // Next trip starts 20 km later than the previous end → a 20_000 m gap.
      final second = await repo.add(
          vehicleId: v,
          tripAt: at(1),
          startOdometerMetres: 10070000,
          endOdometerMetres: 10090000);
      final trip = (await repo.byId(second.valueOrNull!))!;
      expect(trip.gapMetres, 20000);
      expect(trip.hasGapWarning, isTrue);
    });
  });

  group('TripsRepository.classify / softDelete / watch', () {
    test('classify sets tag + default deductibility', () async {
      final v = await seedVehicle();
      final repo = TripsRepository(db);
      final id = (await repo.add(
              vehicleId: v, tripAt: at(0), directDistanceMetres: 5000))
          .valueOrNull!;
      expect((await repo.byId(id))!.classification,
          TripClassification.unclassified);
      expect(
          (await repo.classify(id, TripClassification.business)).isOk, isTrue);
      final trip = (await repo.byId(id))!;
      expect(trip.classification, TripClassification.business);
      expect(trip.isDeductible, isTrue); // business default
    });

    test('updateDetails edits non-ledger fields, leaves distance intact',
        () async {
      final v = await seedVehicle();
      final repo = TripsRepository(db);
      final id = (await repo.add(
              vehicleId: v,
              tripAt: at(0),
              startOdometerMetres: 10000000,
              endOdometerMetres: 10050000))
          .valueOrNull!;
      final r = await repo.updateDetails(
        id,
        classification: TripClassification.commute,
        passengerCount: 3,
        notes: 'school run',
      );
      expect(r.isOk, isTrue);
      final trip = (await repo.byId(id))!;
      expect(trip.classification, TripClassification.commute);
      expect(trip.isDeductible, isFalse); // commute default
      expect(trip.passengerCount, 3);
      expect(trip.notes, 'school run');
      expect(trip.distanceMetres, 50000); // untouched
    });

    test('softDelete tombstones and excludes from watch', () async {
      final v = await seedVehicle();
      final repo = TripsRepository(db);
      final id = (await repo.add(
              vehicleId: v, tripAt: at(0), directDistanceMetres: 5000))
          .valueOrNull!;
      expect(await repo.watchByVehicle(v).first, hasLength(1));
      expect((await repo.softDelete(id)).isOk, isTrue);
      expect(await repo.watchByVehicle(v).first, isEmpty);
      expect(await repo.byId(id), isNull);
    });

    test('watch filters by classification', () async {
      final v = await seedVehicle();
      final repo = TripsRepository(db);
      final biz = (await repo.add(
              vehicleId: v,
              tripAt: at(0),
              directDistanceMetres: 5000,
              classification: TripClassification.business))
          .valueOrNull!;
      await repo.add(
          vehicleId: v,
          tripAt: at(1),
          directDistanceMetres: 3000,
          classification: TripClassification.personal);
      final business = await repo
          .watchByVehicle(v, classification: TripClassification.business)
          .first;
      expect(business.map((t) => t.id), [biz]);
    });
  });

  group('RateSchemesRepository round-trip', () {
    test('encode → store → rehydrate engine → price matches', () async {
      final repo = RateSchemesRepository(db);
      final id = (await repo.add(
        name: 'HMRC',
        kind: 'hmrc',
        currencyCode: 'GBP',
        unit: 'mile',
        taxYearStartMonth: 4,
        taxYearStartDay: 6,
        revisions: [
          RateRevision(
            effectiveFrom: DateTime.utc(2011, 4, 6),
            tiersByClass: {
              MileageVehicleClass.car: [
                const RateTier(
                    rateThousandthsPerUnit: 45000, upToMetres: 16093440),
                const RateTier(rateThousandthsPerUnit: 25000),
              ],
            },
          ),
        ],
      ))
          .valueOrNull!;
      final engine = await repo.engineFor(id);
      expect(engine, isNotNull);
      // 1000 mi under the threshold → £450.00 at 45p.
      final priced =
          engine!.price(date: DateTime.utc(2024, 6), distanceMetres: 1609344);
      expect(priced.deductionMinor, 45000);
      expect(engine.taxYearLabel(DateTime.utc(2024, 6)), '2024-25');
    });
  });

  group('SavedLocations & Roadtrips CRUD', () {
    test('saved location add / watch / soft-delete', () async {
      final repo = SavedLocationsRepository(db);
      final id = (await repo.add(name: 'Home', kind: 'home')).valueOrNull!;
      expect(await repo.watchAll().first, hasLength(1));
      expect((await repo.byId(id))!.isHome, isTrue);
      expect((await repo.softDelete(id)).isOk, isTrue);
      expect(await repo.watchAll().first, isEmpty);
    });

    test('roadtrip container add / watch by vehicle', () async {
      final v = await seedVehicle();
      final repo = RoadtripsRepository(db);
      final id = (await repo.add(
        vehicleId: v,
        title: 'Alps 2026',
        startAt: at(0),
        currencyCode: 'EUR',
        companionCount: 3,
      ))
          .valueOrNull!;
      final list = await repo.watchByVehicle(v).first;
      expect(list.single.id, id);
      expect(list.single.companionCount, 3);
    });
  });
}
