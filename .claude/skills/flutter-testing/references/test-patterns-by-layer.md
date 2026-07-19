# Test patterns by layer

Concrete harness, imports, teardown, and edge-case tables for each layer of the
Car and Pain diamond-topped pyramid. Mirror `lib/` package-per-concern; tests
live in the sibling `test/` of the package that owns the code.

## Layer map

| Package | What it holds | Test style | Coverage gate |
| --- | --- | --- | --- |
| `core` | TCO, economy, projection, next-due, calendars, money, numerals | Table-driven pure Dart + `Clock` | 100% (VGC) |
| `l10n` | numeral/separator format+parse, bidi isolation | Round-trip tables + bidi asserts | 100% (VGC) |
| `notifications` | pure `ReminderScheduler` planner + `NotificationGateway` port | `fake_async` + `timezone` + mocktail gateway | 100% (VGC) |
| `data` | Drift DAOs, migrations, backup, attachments GC | Real in-memory Drift; keyed-**file** suite for cipher | Ratcheting floor |
| `design_system` | widgets, `CustomPainter` charts | Alchemist golden matrix | Sampled, not %-gated |
| `app_test_utils` | builders, fakes, pump helpers | (shared library, exercised by consumers) | n/a |
| `apps/car_and_pain` | smoke flows + Patrol native surfaces | `integration_test` + Patrol | Label/nightly |

## 1. Pure engines (`core`, `l10n`, `notifications` planner)

Rules: zero Flutter/IO imports; read `clock.now()`; one `test()` per named case.
Every conversion carries a round-trip property plus rounding goldens at the
boundary.

```dart
final cases = <EconomyCase>[
  EconomyCase('full fill, km', input: /* … */, expected: /* … */),
  EconomyCase('partial fill accumulates until next full', /* … */),
  EconomyCase('missed fill → flagged, excluded from ratio', /* … */),
  EconomyCase('first fill → no prior distance → Insufficient', /* … */),
];

void main() {
  for (final c in cases) {
    test(c.name, () => expect(computeEconomy(c.input), c.expected));
  }

  test('SI↔imperial round-trips', () {
    for (final km in sampleDistances) {
      expect(fromMiles(toMiles(km)), closeTo(km, 1e-9));
    }
  });

  test('clock-pinned next-due resolves to Tehran wall clock', () {
    withClock(Clock.fixed(DateTime.utc(2026, 3, 21)), () {
      expect(nextDue(reminder), TZDateTime.from(/* … */, tehran));
    });
  });
}
```

Edge cases that MUST have a named row:

| Domain | Required cases |
| --- | --- |
| Economy | full / partial-accumulate / missed-flagged-excluded / first-fill-Insufficient |
| Money | IRR exp 0, USD exp 2, KWD exp 3, Rial↔Toman display, half-up rounding at boundary |
| Projection | rolling rate, min-samples guard, zero-usage, projection-beyond-window fallback (time-only or don't schedule) |
| Calendars | Gregorian↔Jalali↔Hijri anchors, DST boundary, midnight boundary off-by-one |
| Numerals | Latin↔Eastern-Arabic↔Persian digits, decimal `٫`, grouping `٬` — format+parse round-trip |

## 2. Data layer — real in-memory Drift

```dart
late AppDatabase db;
setUp(() => db = AppDatabase(NativeDatabase.memory()));
addTearDown(() => db.close()); // avoid "Timer still pending"

test('scoped watch re-emits only on changed window', () async {
  final stream = db.fuelDao.watchEconomy(vehicleId, window);
  await expectLater(stream, emitsInOrder([/* … */]));
});
```

- Construct `AppDatabase` with `closeStreamsSynchronously: true` so reactive
  streams shut down synchronously in teardown.
- Include an **index / query-plan** assertion (`EXPLAIN QUERY PLAN` uses the
  intended index) and a scoped-`.watch()` rollup-recompute test.
- Mock repositories only *above* this layer; never mock the DAO here.

## 3. Keyed encryption / migration / backup (separate FILE suite)

Plain `NativeDatabase.memory` cannot open a SQLCipher DB — this suite uses a
real keyed file with the cipher libs linked.

| Test | Assertion |
| --- | --- |
| `encryption/db_header_test.dart` | First bytes of the raw file are NOT `SQLite format 3` |
| `migration/migration_test.dart` | Migrate a realistically large **seeded** DB; a **forced mid-migration failure** restores the pre-migration snapshot |
| `backup/roundtrip_test.dart` | WAL-active `export → wipe → import → deep-equal`; `VACUUM INTO` source; attachment SHA-256 and full/partial/missed flags preserved |
| key-recovery | Keystore/Keychain key destroyed → passphrase/recovery-code restores access |
| `attachments/gc_test.dart` | Orphan blob collected; shared blob survives via refcount |
| CSV export | Formula-injection neutralized; Persian-digit/separator round-trip |

The backup round-trip is a **blocking** CI gate. Never back up a raw live-file
copy.

## 4. Scheduler — pure planner + thin gateway

See the canonical snippet in `SKILL.md`. Additional required scenarios:

```dart
tz.initializeTimeZones();
tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
fakeAsync((async) {
  scheduler.armAll();
  async.elapse(const Duration(days: 1)); // cross a DST boundary explicitly
  expect(fakeGateway.pending, /* wall-clock preserved, not shifted */);
});

// Verify the gateway call count equals the plan length.
verify(() => gateway.zonedSchedule(any(), any(), captureAny(), any()))
    .called(plan.length);
```

| Scenario | Assertion |
| --- | --- |
| iOS 64-cap | `plan.length` within headroom; nearest-due eviction |
| DST boundary | wall-clock recurrence → `TZDateTime` not shifted |
| Reconcile diff | only changed reminders cancelled/rescheduled |
| Clock-tamper | monotonic-clock guard flags overdue on backwards jump |
| Insufficient data | falls back to time-only or does not schedule |

## 5. Headless Notifier tests (Riverpod)

```dart
final container = ProviderContainer(overrides: [
  appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
  // repository ports overridden with mocktail fakes as needed
]);
addTearDown(container.dispose);

final notifier = container.read(backupNotifierProvider.notifier);
await notifier.runBackup();
expect(container.read(backupNotifierProvider), isA<AsyncData<BackupResult>>());
```

Drive `AsyncNotifier`-based backup/import/restore this way — never pump a widget
to exercise state. Read `.notifier` to act; assert on the `AsyncValue`.

## 6. Integration + Patrol

A few `integration_test` smoke flows (add vehicle → log fuel → see TCO; create
reminder → notification scheduled) plus Patrol for notification-permission and
fired-notification native surfaces. A negative test asserts **zero outbound
connections** (the offline flavor omits `INTERNET`). Label-triggered or nightly.

## Typed failures

Exhaustive branch tests over the `Failure` union, plus a `Failure` x 6-locale
exhaustiveness test proving every failure has a localized message in en, de, fr,
fa, ar, ckb.
