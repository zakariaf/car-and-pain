# 🧪 Testing Strategy

> How Car and Pain proves its compute engines are correct, its data is never lost, and its RTL/multi-calendar UI never regresses — deterministically, offline, and without telemetry.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · See also **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)**, **[Local Notifications & Background Reliability](./07-notifications.md)**, and **[Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)**.

## Decision

We adopt a logic-heavy **"diamond-topped pyramid."** Almost all correctness (TCO, fuel/energy economy, odometer & engine-hour projection, next-due, calendars, numerals/separators, currency exponents, and the notification scheduler) lives in pure, Flutter-free Dart injected with a `Clock`, and is covered by fast table-driven unit tests at **100%**. Above that sit data-layer tests on a **real in-memory Drift engine**, a small dedicated **keyed-encryption / migration / backup** suite, a **trimmed Alchemist golden matrix** for RTL/i18n, headless `ProviderContainer` Notifier tests, and a handful of `integration_test` + **Patrol** native flows. The pinned toolset is **`mocktail`** (no codegen), **`alchemist`** (golden), **`package:clock` + `fake_async` + `package:timezone`** (determinism), **`patrol`** (native surfaces), and **Very Good Coverage** for the 100% gate on logic packages. Reboot/Doze/OEM-battery-killer survival is an explicitly documented **manual real-device matrix** — never a fabricated automated pass.

## Why

The value of Car and Pain is in its compute engines and its data custody, not in novel UI. Two facts drive the whole strategy:

- **There is no server and no telemetry.** We never find out in the field that a projection was off by a day or that a backup was silently unrestorable. Correctness must be proven at build time. Pure-Dart engines injected with a `Clock` are the single highest-leverage testability decision — they are trivially deterministic and cheaply 100%-covered.
- **The user's history exists nowhere else.** A raw-file backup passes a naive round-trip test and corrupts in production; that is why the flagship blocking test is `export → wipe → import → deep-equal` with **WAL active**.

Alternatives considered and rejected:

- **Golden framework:** `golden_toolkit` is in wind-down and has no CI-vs-platform font split (flaky on exactly the RTL text we care about) — we borrow only its `loadAppFonts` pattern. Raw `matchesGoldenFile` alone gives no font loading and no scenario tables. **Alchemist wins** for its two lanes (deterministic Ahem CI mode + real-font platform mode) and `GoldenTestGroup` locale × direction tables.
- **Mocking:** `mockito` needs `@GenerateMocks` + `build_runner` churn across many immutable value types (`Vehicle`, `FuelEntry`, `Reminder`). **`mocktail` wins** — null-safe, closure-based, no codegen.
- **DB double:** a mocked DAO says nothing about whether the SQL, constraints, indexes, or migrations are correct — false confidence. **A real in-memory Drift engine wins** for all data-layer tests; mocked repositories are used only *above* the data layer.
- **Coverage:** global 100% incentivizes trivial UI tests written only to hit a number and produces exclusion churn. **Tiered wins** — 100% enforced on curated logic packages, ratcheting floor elsewhere.
- **Integration:** Maestro/Appium add a toolchain outside Dart with no advantage. **`integration_test` + Patrol wins.**

## How we do it

### Test folder layout (mirror `lib/`, package-per-concern)

```text
packages/
  core/
    lib/…                      # pure engines + value objects (zero Flutter/IO)
    test/
      tco/tco_calculator_test.dart
      economy/economy_test.dart          # partial / full / missed / first fill
      projection/usage_projector_test.dart
      calendars/…                         # Gregorian ↔ Jalali ↔ Hijri anchors
      money/currency_exponent_test.dart   # IRR=0, USD=2, KWD=3, Rial↔Toman
  data/
    test/
      dao/…                               # NativeDatabase.memory()
      encryption/db_header_test.dart      # NOT 'SQLite format 3'
      migration/migration_test.dart       # large seeded DB + forced mid-fail
      backup/roundtrip_test.dart          # WAL-active export→wipe→import
      attachments/gc_test.dart            # orphan blob + shared-blob refcount
  notifications/
    test/
      scheduler/reminder_scheduler_test.dart  # DST, 64-cap, clock-tamper
  l10n/
    test/…                                # numeral/separator round-trips, bidi
  design_system/
    test/
      goldens/ci/…                        # Ahem, byte-stable cross-OS
      goldens/<platform>/…                # real-font (Vazirmatn/Noto)
    flutter_test_config.dart              # loadAppFonts + AlchemistConfig
  app_test_utils/                         # builders, fakes, pump helpers (shared)
apps/car_and_pain/
  integration_test/…                      # smoke flows + Patrol native
```

`flutter_test_config.dart` at each golden test root loads app fonts and wraps the suite in the Alchemist config so golden text renders real glyphs instead of tofu boxes.

### Pure engines: table-driven + injected `Clock`

```dart
// packages/core/test/economy/economy_test.dart
final cases = <EconomyCase>[
  EconomyCase('full fill, km', input: /* … */, expected: /* … */),
  EconomyCase('partial fill accumulates until next full', /* … */),
  EconomyCase('missed fill → flagged, excluded from ratio', /* … */),
  EconomyCase('first fill → no prior distance, returns Insufficient', /* … */),
];

void main() {
  for (final c in cases) {
    test(c.name, () => expect(computeEconomy(c.input), c.expected));
  }
}
```

Never call `DateTime.now()` in production logic. Read `clock.now()` and pin it in tests:

```dart
withClock(Clock.fixed(DateTime.utc(2026, 3, 21)), () {
  expect(nextDue(reminder), TZDateTime.from(/* … */, tehran));
});
```

### Notification scheduler: pure planner + thin gateway

The scheduler is pure and clock-injected; the plugin is mocked behind the `NotificationGateway` port (see **[Local Notifications & Background Reliability](./07-notifications.md)**).

```dart
// Pure: exhaustively unit-tested, no device, no plugin.
final plan = ReminderScheduler(clock: fixed, tz: tehran)
    .plan(reminders, projectedOdometer, projectedEngineHours);

expect(plan.length, lessThanOrEqualTo(50));   // headroom under iOS 64 cap
expect(plan.first.due, isNearestDue);          // eviction keeps nearest

// Thin gateway: mock the plugin, verify the call.
registerFallbackValue(tzFallback);             // TZDateTime for any()/captureAny()
verify(() => gateway.zonedSchedule(any(), any(), captureAny(), any())).called(plan.length);
```

Drive timer/reconcile code with `fake_async` and pin timezone with fixtures:

```dart
tz.initializeTimeZones();
tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
fakeAsync((async) {
  scheduler.armAll();
  async.elapse(const Duration(days: 1));       // cross a DST boundary explicitly
  expect(fakeGateway.pending, /* wall-clock preserved, not shifted */);
});
```

### Data layer: real in-memory Drift

```dart
late AppDatabase db;
setUp(() => db = AppDatabase(NativeDatabase.memory()));
addTearDown(() => db.close());                 // avoid "Timer still pending"

test('scoped watch re-emits only on changed window', () async {
  final stream = db.fuelDao.watchEconomy(vehicleId, window);
  await expectLater(stream, emitsInOrder([/* … */]));
});
```

Use `closeStreamsSynchronously: true` and close the DB in teardown so reactive Drift streams don't leak timers.

### Golden matrix: locale × direction, trimmed

Golden the **i18n primitives** (numerals, calendars, bidi, mirroring) and a **few representative screens** exhaustively; sample the rest. `large-text-scale` (`textScaler` 1.5–2×) and `RTL overflow` are explicit dimensions.

```dart
GoldenTestGroup(
  children: [
    for (final locale in const [Locale('en'), Locale('de'), Locale('fr'),
                                Locale('fa'), Locale('ar'), Locale('ckb')])
      GoldenTestScenario(
        name: '$locale',
        child: pumpLocalized(const ServiceDueCard(), locale: locale,
            textScaler: const TextScaler.linear(1.5)),
      ),
  ],
);
```

Two golden lanes: an **Ahem CI lane** (byte-stable across OSes, catches geometry/mirroring) and a **narrow real-font lane** on one pinned OS with bundled Vazirmatn/Noto (catches Persian/Arabic shaping + Eastern-Arabic/Persian numerals). Assert `Semantics` on `fl_chart` wrappers.

### Headless Notifier tests

```dart
final container = ProviderContainer(overrides: [
  appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
]);
addTearDown(container.dispose);
final notifier = container.read(backupNotifierProvider.notifier);
await notifier.runBackup();
expect(container.read(backupNotifierProvider), isA<AsyncData<BackupResult>>());
```

### CI lanes (GitHub Actions, Flutter pinned via FVM)

```yaml
jobs:
  static:      # dart format --set-exit-if-changed + flutter analyze
  unit_widget: # flutter test --coverage --exclude-tags golden → Very Good Coverage
  goldens_ci:  # flutter test --tags golden (Alchemist Ahem, one pinned Linux box)
  goldens_font:# same tests, real-font mode, bundled fonts (PR or nightly)
  integration: # integration_test + Patrol (label-triggered / nightly)
```

Use `@Tags(['golden'])` to keep golden and unit lanes separate. Block accidental `--update-goldens` in the pipeline.

### Package list

`flutter_test`, `integration_test`, `mocktail`, `alchemist`, `clock`, `fake_async`, `timezone`, `drift` + `sqlite3` (`NativeDatabase.memory`), `sqlcipher_flutter_libs` (keyed suite), `patrol`, `coverage`/`lcov`, Very Good Coverage (Action), `very_good_analysis`.

## Rules

- **Do** put every business rule in a Flutter-/plugin-/IO-free package and inject a `Clock`. **Don't** call `DateTime.now()` or read the local timezone in production logic.
- **Do** test the data layer against a real in-memory Drift engine. **Don't** mock the DAO/SQL layer as a substitute — that gives false confidence.
- **Do** `registerFallbackValue` for every custom type passed to `any()`/`captureAny()` (`TZDateTime`, domain entities) in `setUpAll`. **Don't** rely on mocktail catching type mismatches at compile time — they surface at runtime.
- **Do** override widget-test defaults explicitly (locale, `TextDirection`, `textScaler`). **Don't** trust the 800×600 / `1.0` / `en_US` / LTR defaults — RTL and dynamic-type bugs hide there.
- **Do** run the WAL-active `export → wipe → import → deep-equal` round-trip as a **blocking** CI check. **Don't** ever test a backup produced by a raw live-file copy.
- **Do** run a real-font golden lane in addition to the Ahem CI lane. **Don't** trust Ahem squares to validate Arabic/Persian glyph joining or numeral glyphs.
- **Do** freeze clock, locale, and numeral system when snapshotting exported CSV/JSON fixtures. **Don't** commit fixtures with live timestamps — they flake.
- **Do** prefer timed `pump(Duration)` + `fakeAsync` over `pumpAndSettle()` on any screen with a shimmer/splash/spinner. **Don't** call `pumpAndSettle()` on infinite animations — it hangs forever.
- **Do** enforce 100% coverage on logic packages via Very Good Coverage (excluding `.g.dart`/`.freezed.dart`). **Don't** chase global 100% with trivial UI tests.
- **Do** pin the Flutter version and generate/commit goldens in that one environment. **Don't** regenerate goldens on a dev Mac while CI runs Linux.
- **Do** document reboot/Doze/OEM survival as manual QA. **Don't** fabricate an automated green check for behavior emulators cannot reproduce.

## For Car and Pain specifically

- **Offline / no-telemetry:** because there is no backend, there are no network mocks and there is a **negative test**: a CI lockfile scan fails the build if any analytics/crash SDK appears, and an integration assertion proves the app makes **zero outbound connections**. The offline flavor omits `INTERNET`, so the OS enforces the claim the test verifies.
- **Canonical storage:** invariance tests assert that switching unit/currency/calendar/numeral leaves rows **byte-identical**, and that true instants (UTC epoch millis) are stored distinctly from wall-clock recurring schedules. Currency-exponent tests cover IRR=0, USD=2, KWD=3 and the Rial↔Toman display convention — never a hardcoded two decimals.
- **Notifications:** the projection model is unit-tested under a fake clock across its whole surface — rolling usage-rate estimation, the **min-samples guard**, zero-usage handling, and the explicit *"insufficient data / projection beyond the pending window → fall back to time-only or don't schedule"* branch. Wall-clock recurrence resolved to `TZDateTime` is tested **across a DST boundary**, plus the iOS-64-cap budgeting and a monotonic-clock **clock-tamper** guard for overdue detection.
- **RTL/i18n:** goldens are the RTL safety net — mirroring, bidi isolation (assert FSI/PDI marks around VIN/plate/phone), Gregorian/Jalali/Hijri projection, and Eastern-Arabic/Persian numeral + decimal (٫)/grouping (٬) separator format/parse round-trips, exhaustively across the six locales.
- **Data custody:** the flagship WAL-active backup round-trip (VACUUM-INTO source, attachment SHA-256, preserved full/partial/missed fill flags), competitor-import goldens, a CSV formula-injection + Persian-digit/separator round-trip, a **key-recovery** test (Keystore/Keychain key destroyed → passphrase/recovery-code restores access), and attachment orphan/refcount GC tests.

## Testing

*(How each layer is exercised — this doc's subject is testing, so the practical detail lives in [How we do it](#how-we-do-it) above.)*

- **Unit (100%, pure Dart):** table-driven, injected `Clock` + `fake_async` + timezone fixtures + `FakeNotificationGateway`. TCO, economy, projection+fallback, next-due, calendars, numerals/separators, currency exponents, scheduler.
- **Data layer:** real in-memory Drift with an index/query-plan check and a scoped-`.watch()`/rollup recompute test.
- **Encryption / migration / backup (small keyed suite):** raw file header is **NOT** `SQLite format 3`; migrations on a realistically large seeded DB including a **forced mid-migration failure** that must restore the pre-migration snapshot; the WAL-active round-trip.
- **Golden:** trimmed Alchemist matrix (primitives + representative screens) across locale × direction × calendar × numeral, with large-text-scale and RTL-overflow dimensions and chart `Semantics`.
- **Headless state:** `ProviderContainer` with DB/repository overrides for the `AsyncNotifier`-driven backup/import/restore flows.
- **Integration/native:** a few `integration_test` smoke flows (add vehicle → log fuel → see TCO; create reminder → notification scheduled) + **Patrol** for the notification-permission and fired-notification surfaces.
- **Typed failures:** exhaustive branch tests plus a `Failure` × 6-locale exhaustiveness test.
- **Manual only:** reboot/Doze/OEM-battery-killer survival + week-one Impeller-on-low-end validation.

## Pitfalls

- **Ahem CI goldens render text as squares** — they validate geometry and mirroring but **not** glyph shaping. Broken Persian/Arabic joining or wrong Eastern-Arabic/Persian numerals slip through unless you also run the real-font platform lane.
- **Forgetting `loadAppFonts`** makes golden text render as tofu/fallback boxes or differ per machine.
- **Leaking `DateTime.now()`/local timezone** into logic makes notification and calendar tests non-deterministic and causes Jalali/Hijri off-by-one at DST and midnight boundaries.
- **Mocked SQL/DAO layers** never run the actual queries, constraints, or migrations — false confidence at the data layer.
- **SQLCipher DBs can't be opened by plain `NativeDatabase.memory`** without the cipher libs linked — test business logic on a plain in-memory DB and keep encryption/keying to the separate keyed-file suite.
- **`pumpAndSettle()` hangs forever** on infinite animations (splash, shimmer, spinners) — use timed pump / `fakeAsync`.
- **Reboot/Doze/OEM survival cannot be verified by `integration_test` or emulators** — manual device matrix (Xiaomi/MIUI, Samsung/OneUI, Huawei/EMUI, Oppo/ColorOS) plus a `BOOT_COMPLETED` reschedule check; never fabricate a pass.
- **Goldens are Flutter-version and OS sensitive** — pin the version, generate in one environment, and guard against accidental `--update-goldens`.
- **Missing `registerFallbackValue`** for a custom type used with `any()`/`captureAny()` throws at runtime in mocktail.
- **Widget-test defaults (800×600, `1.0`, `en_US`, LTR)** hide RTL, dynamic-type, and locale bugs unless overridden per test.
- **Reactive Drift streams leak timers** after a test unless you set `closeStreamsSynchronously: true` and close the DB in teardown — otherwise "Timer still pending".
- **Snapshotting CSV/JSON without normalizing timestamps/locale/numerals** makes fixtures flaky — freeze the clock, locale, and numeral system when generating them.
- **Global-100% vanity** rewards trivial UI tests and exclusion churn — gate 100% where correctness lives.

## Decisions to confirm

- **State management (Riverpod vs Bloc):** the golden `blocTest` vs headless `ProviderContainer` test shape differs. Confirm the solo dev's existing muscle memory before locking Riverpod at kickoff — a Cubit-heavy Bloc choice reshapes the presentation-test patterns across all 25 modules.
- **Household P2P sync in MVP?** If in-scope, the test suite must add merge/tombstone/conflict tests (UUIDv7 + `updated_at` + `row_revision`), and the backup round-trip and notification-reconcile tests must account for merged state. Confirm it is OUT of MVP before finalizing the data-layer test plan.
- **Encryption spike outcome:** the keyed-suite host libs (`sqlcipher_flutter_libs` default vs `drift`'s `sqlite3mc` build-hook path) must be pinned once the week-one spike records its decision; the header-assert test is the same either way.
- **Argon2id params:** the key-recovery test's timing expectations depend on the device-calibrated memory/iteration params (with low-end fallback) chosen against the slowest target device.

## Related

- **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)** — the in-memory Drift engine, migration harness, and snapshot-restore this doc tests against.
- **[Local Notifications & Background Reliability](./07-notifications.md)** — the pure `ReminderScheduler` + `NotificationGateway` port the scheduler tests exercise.
- **[Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)** — the flagship WAL-active round-trip and CSV-injection assertions.
- **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)** — what the golden matrix and numeral/separator round-trips protect.
- **[Build, Tooling, Release & CI/CD](./12-build-ci-release.md)** — the pinned Flutter version, coverage gate, and CI lanes that run these tests.
- **[Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md)** — the product promise the backup round-trip defends.
