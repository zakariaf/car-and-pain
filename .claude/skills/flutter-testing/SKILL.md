---
name: flutter-testing
description: >-
  Governs how Car and Pain tests its logic engines, Drift data layer, Riverpod
  Notifiers, notification scheduler, backup round-trip, and RTL/i18n goldens via
  a diamond-topped pyramid: 100 percent Very Good Coverage on Flutter-free logic
  packages with clock-injected table-driven tests and round-trip/rounding
  properties; real in-memory Drift (NativeDatabase.memory), never a mocked SQL
  layer; off-device scheduler tests for the iOS 64-cap, DST, and reconcile diff
  via fake_async plus timezone; headless ProviderContainer Notifier tests with
  overrideWithValue; a sampled Alchemist golden and RTL matrix with loadAppFonts
  across the six locales; the flagship WAL-active export-wipe-import deep-equal
  test; and mocktail with registerFallbackValue for custom types. Use when
  writing tests under test/, integration_test/, or flutter_test_config.dart;
  testing a calculator, DAO, scheduler, Notifier, or golden; picking mocktail,
  alchemist, patrol, clock, fake_async, or timezone; or chasing a leaking-timer
  or coverage-gate failure.
metadata:
  project: car-and-pain
  area: testing-qa
---

# Flutter Testing

Ground rules for testing Car and Pain: a logic-heavy **diamond-topped pyramid**.
Almost all correctness lives in pure, Flutter-free Dart injected with a `Clock`
and is covered at **100 percent**. Above it sit real-Drift data tests, a small
keyed encryption/migration/backup suite, headless Notifier tests, a trimmed
Alchemist golden matrix, and a few Patrol native flows.

Assume general Flutter/Dart/Drift/Riverpod/mocktail/RTL knowledge. What follows
is only the project-specific, non-negotiable decisions. There is **no server and
no telemetry** — correctness is proven at build time or never.

## Non-negotiable rules

- **Put every business rule in a Flutter-/plugin-/IO-free package and inject a
  `Clock`.** TCO, fuel/energy economy, odometer and engine-hour projection,
  next-due, calendars, numerals/separators, currency exponents, and the
  notification planner live in `packages/core` (or `l10n`/`notifications`
  planner) with zero Flutter imports. NEVER call `DateTime.now()` or read the
  local timezone in production logic — read `clock.now()` and pin it in tests
  with `withClock(Clock.fixed(...), ...)`.
- **Enforce 100 percent coverage on the logic packages via Very Good Coverage**,
  excluding `*.g.dart`/`*.freezed.dart`/`*.drift.dart`. Do NOT chase a global
  100 percent with trivial UI tests — that rewards vanity tests and exclusion
  churn. Elsewhere a ratcheting floor applies. Logic tests are **table-driven**:
  one `test()` per named case in a `cases` list.
- **Assert conversion properties, not just examples.** Every unit/display
  conversion (SI to imperial, UTC to wall-clock, minor-units to display) has a
  **round-trip** test (`decode(encode(x)) == x`) and **rounding goldens** at the
  half-way and exponent boundaries. Money is integer minor units keyed to the
  **ISO-4217 exponent** — cover IRR exponent 0, USD exponent 2, KWD exponent 3,
  and the Rial/Toman display convention; never hardcode two decimals.
- **Test the data layer against a real in-memory Drift engine**
  (`AppDatabase(NativeDatabase.memory())`). NEVER mock the DAO/SQL layer as a
  substitute — a mocked DAO proves nothing about the SQL, constraints, indexes,
  or migrations. Mock repositories only *above* the data layer. Set
  `closeStreamsSynchronously: true` and `addTearDown(db.close)` so reactive
  `.watch()` streams do not leak "Timer still pending".
- **Keep SQLCipher out of the in-memory path.** `NativeDatabase.memory` cannot
  open a keyed DB without the cipher libs linked. Test business logic on a plain
  in-memory DB; keep encryption, keying, key-recovery, and the raw-header assert
  (first bytes are NOT `SQLite format 3`) to the separate keyed-**file** suite
  under `data/test/encryption/`.
- **Test the scheduler off-device as a pure planner.** `ReminderScheduler` is
  clock- and timezone-injected and returns a plan; the plugin sits behind the
  `NotificationGateway` port and is mocked. Assert the plan stays **under the
  iOS 64-cap** (schedule with headroom, e.g. `lessThanOrEqualTo(50)`), nearest-
  due eviction wins, wall-clock recurrence resolves to `TZDateTime` **across a
  DST boundary**, and the reconcile **diff** cancels/reschedules only what
  changed. Drive timers with `fakeAsync` + `async.elapse`; pin the zone with
  `tz.setLocalLocation(tz.getLocation('Asia/Tehran'))`.
- **Test Notifiers headlessly with `ProviderContainer`**, overriding
  `appDatabaseProvider` (and repository ports) via `overrideWithValue`; never
  pump a widget to test state. `addTearDown(container.dispose)`. Assert on the
  `AsyncValue` (`isA<AsyncData<...>>()`), read `.notifier` to drive actions.
- **`registerFallbackValue` for EVERY custom type** passed to `any()`/
  `captureAny()` — `TZDateTime`, `Vehicle`, `FuelEntry`, `Reminder`, `Failure` —
  in `setUpAll`. mocktail does NOT catch the mismatch at compile time; it throws
  at runtime. Use mocktail only (closure-based, null-safe, no codegen) — never
  `mockito`/`@GenerateMocks`.
- **Run the WAL-active `export → wipe → import → deep-equal` round-trip as a
  BLOCKING check.** Export from a `VACUUM INTO` source with WAL active, wipe,
  import, and assert the DB is deep-equal to the original — attachment SHA-256
  and full/partial/missed fill flags preserved. NEVER test a backup produced by
  a raw live-file copy; it passes naive round-trips and corrupts in the field.
- **Override widget-test defaults explicitly** — `locale`, `TextDirection`,
  `textScaler`. The 800x600 / `1.0` / `en_US` / LTR defaults hide RTL and
  dynamic-type bugs. Route ALL asserted strings through gen-l10n; never assert a
  hardcoded English literal.
- **Two golden lanes, both with `loadAppFonts`.** An **Ahem CI lane**
  (byte-stable cross-OS, validates geometry/mirroring) tagged `@Tags(['golden'])`
  and a **narrow real-font lane** on one pinned OS with bundled Vazirmatn/Noto
  (validates Persian/Arabic joining + Eastern-Arabic/Persian numerals). Ahem
  squares do NOT prove glyph shaping. Golden the i18n primitives exhaustively
  across the six locales; **sample** representative screens. Assert `Semantics`
  on `CustomPainter` chart wrappers. Pin the Flutter version, generate goldens in
  that one environment, and block accidental `--update-goldens` in CI.
- **Never `pumpAndSettle()` on an infinite animation** (splash, shimmer,
  spinner) — it hangs forever. Use timed `pump(Duration)` + `fakeAsync`.
- **Freeze clock, locale, and numeral system when snapshotting** CSV/JSON
  fixtures. Never commit fixtures with live timestamps — they flake.
- **Pin the toolset** in dev_dependencies: `flutter_test`, `integration_test`,
  `mocktail`, `alchemist`, `clock`, `fake_async`, `timezone`, `drift` +
  `sqlite3` (`NativeDatabase.memory`), `sqlcipher_flutter_libs` (keyed suite),
  `patrol`, `coverage`/`lcov`, `very_good_analysis`, Very Good Coverage (Action).
  Built-in-first — do not add a redundant mocking or golden package.
- **Reboot/Doze/OEM-battery-killer survival is a MANUAL real-device matrix** —
  never fabricate an automated green check. `integration_test` and emulators
  cannot reproduce it.

## Canonical snippet

The mock-plus-fallback plus clock-and-timezone shape used by every scheduler and
gateway test. Note `registerFallbackValue` in `setUpAll`, the fixed `Clock`, the
pinned zone, and the 64-cap headroom assertion.

```dart
// packages/notifications/test/scheduler/reminder_scheduler_test.dart
class MockNotificationGateway extends Mock implements NotificationGateway {}

void main() {
  late tz.Location tehran;

  setUpAll(() {
    tz.initializeTimeZones();
    tehran = tz.getLocation('Asia/Tehran');
    tz.setLocalLocation(tehran);
    // Custom types crossing any()/captureAny() MUST be registered or mocktail
    // throws at runtime, not compile time.
    registerFallbackValue(tz.TZDateTime.now(tehran));
    registerFallbackValue(const Reminder.fallback());
  });

  test('plan stays under the iOS 64-cap and evicts by nearest-due', () {
    final fixed = Clock.fixed(DateTime.utc(2026, 3, 21)); // near a DST boundary
    final gateway = MockNotificationGateway();
    when(() => gateway.zonedSchedule(any(), any(), captureAny(), any()))
        .thenAnswer((_) async {});

    final plan = ReminderScheduler(clock: fixed, tz: tehran)
        .plan(reminders, projectedOdometer, projectedEngineHours);

    expect(plan.length, lessThanOrEqualTo(50)); // headroom under the 64 cap
    expect(plan.first.due, isNearestDue);        // eviction keeps the nearest
  });
}
```

## References

- `references/test-patterns-by-layer.md` — per-layer harness, imports, teardown,
  and edge-case tables: pure engines, in-memory Drift, keyed encryption/
  migration/backup, scheduler, headless Notifiers, integration/Patrol.
- `references/golden-rtl-matrix.md` — the locale x direction x calendar x numeral
  sampling matrix, the two golden lanes, `flutter_test_config.dart` setup, and
  which screens are exhaustive versus sampled.

## Scripts

- `scripts/run_tests.sh` — mirror the CI lanes locally: analyze, regenerate
  codegen, run the unit/widget lane with coverage, run the Ahem golden lane, and
  grep-scan for the common violations (leaked `DateTime.now()` in logic, a
  `pumpAndSettle()` on a known infinite-animation screen, a mocked DAO, a missing
  `registerFallbackValue`, `mockito` creeping in). Prints findings to stdout.
