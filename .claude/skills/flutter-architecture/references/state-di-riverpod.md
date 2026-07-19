# State + DI with Riverpod — the load-bearing context-free wiring

Grounds `docs/flutter/02-state-management.md` and `docs/flutter/04-dependency-injection.md`.
**Decision locked:** Riverpod 3.x with codegen (`@riverpod` + `riverpod_generator`), enforced by
`riverpod_lint`/`custom_lint`, paired with Freezed. It is the single mechanism for **both** DI and
state (ADR-1: `Superseded → Riverpod 3.x adopted`). No `get_it`, `injectable`, or `package:provider`
app-wide — one DI system only.

## Why context-free DI is load-bearing

Car and Pain does substantial work **outside the widget tree**: the notification reschedule worker,
the odometer/engine-hour projection worker, the TCO engine, and backup/import all run where there is
no `BuildContext`. Riverpod resolves dependencies without `BuildContext`, so the *same* repositories
and engines are reachable from a screen, a notification callback, and a background isolate — **one
wiring, three call sites**. This is the single reason `package:provider` (BuildContext-bound) is
disqualifying here.

## The layered provider graph (a DAG)

```text
infra (placeholder → overridden)   appDatabaseProvider, secureKeyStoreProvider,
        │                          appDirsProvider, timezoneProvider
        ▼
repositories (per module)          fuelRepositoryProvider, ledgerRepositoryProvider …
        │                          (return ABSTRACT interfaces)
        ▼
domain/application engines         tcoEngineProvider, usageProjectorProvider,
        │                          reminderSchedulerProvider … (Clock-injected, Flutter-free)
        ▼
presentation controllers           @riverpod class VehicleDashboardController …
                                   (autoDispose AsyncNotifier)
```

## keepAlive vs autoDispose

| Provider kind | Lifetime | Example |
| --- | --- | --- |
| Encrypted DB, secure key store, repositories, engines, scheduler, cross-cutting settings notifiers (locale/calendar/numeral/units/currency/theme) | **`keepAlive`** — built once, disposed on app exit | `appDatabaseProvider`, `fuelRepositoryProvider`, `tcoEngineProvider`, `LocaleController` |
| Cheap derived providers | **`autoDispose`** (default) | a scoped list filter |
| Expensive derived providers (TCO, charts) | `autoDispose` **plus** `ref.keepAlive()` so navigating away doesn't force a recompute; key recompute off the DB revision counter, not wall-clock | `tcoProvider(vehicleId)` |
| Per-screen form/controller | **`autoDispose`** | `fuelEntryNotifier` |

Never make an expensive singleton (DB, scheduler) `autoDispose` — it can be torn down mid-operation.

## 1. Placeholder root providers, overridden at startup

The canonical pattern for injecting async-constructed infra, doubling as the test seam.

```dart
// packages/data/lib/src/providers.dart
final appDatabaseProvider   = Provider<AppDatabase>((ref)   => throw UnimplementedError('override in bootstrap()'));
final secureKeyStoreProvider = Provider<SecureKeyStore>((ref) => throw UnimplementedError('override in bootstrap()'));
final appDirsProvider       = Provider<AppDirs>((ref)       => throw UnimplementedError('override in bootstrap()'));
```

`bootstrap.dart` constructs the real instances (key unwrapped on the main isolate) and
`overrideWithValue`s them in the root `ProviderScope`. Opening the DB before the key is unwrapped
fails — gate `appDatabaseProvider` on the key and splash via `AsyncValue` until resolved.

## 2. Repositories return abstract interfaces

```dart
@riverpod
FuelRepository fuelRepository(Ref ref) => DriftFuelRepository(ref.watch(appDatabaseProvider));

@riverpod
Stream<List<FuelEntry>> fuelEntries(Ref ref, String vehicleId) =>
    ref.watch(fuelRepositoryProvider).watchFuelEntries(vehicleId); // scoped .watch()
```

`FuelRepository` is an `abstract interface class` in `core`/`domain`; `DriftFuelRepository` is the
`data` implementation. Cross-module code depends only on the interface. **Notifiers and widgets
never touch Drift directly — always through a repository provider.** Scope streams by vehicle + time
window so one fuel entry never re-emits app-wide (reads the rollup tables).

## 3. Derived analytics/TCO — memoized, isolate-offloaded

```dart
@riverpod
Future<TcoBreakdown> tco(Ref ref, String vehicleId) async {
  final fuel = await ref.watch(fuelEntriesProvider(vehicleId).future);
  final svc  = await ref.watch(serviceRecordsProvider(vehicleId).future);
  final link = ref.keepAlive();               // expensive → survive navigation
  ref.onDispose(link.close);
  return Isolate.run(() => TcoCalculator.compute(TcoInput(fuel, svc))); // never compute in build()
}
```

Keep the math **pure** in `core`. Cross-module aggregation (TCO = fuel + service + depreciation +
projection) is just provider composition — no manual stream combining.

## 4. Durability side-effects — stable AsyncNotifier, not Mutations

```dart
@riverpod
class BackupController extends _$BackupController {
  @override
  FutureOr<void> build() {}
  Future<void> exportTo(String path) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(backupRepositoryProvider).exportTo(path));
  }
}
```

Backup/import/restore drive a **stable `AsyncNotifier`** with `AsyncValue` progress. Riverpod 3's
experimental **Mutation API is optional sugar only** — never the backbone of the flagship durability
surface. Use `ref.listen` (not `ref.watch`) in the UI for one-shot SnackBar/navigation reactions.

## 5. Background isolates get NO ProviderScope (the load-bearing exception)

A `ProviderContainer` cannot cross isolates. Infra construction lives in **plain top-level factory
functions** that both the app and a fresh in-isolate container call.

```dart
// packages/data — plain top-level factory, no Riverpod, no Flutter widgets
Future<AppDatabase> openAppDatabase(Uint8List key, String dbPath) async {
  final db = AppDatabase(NativeDatabase(File(dbPath), setup: (raw) {
    raw.execute("PRAGMA key = \"x'${hex.encode(key)}'\";"); // first statement; header check is a CI test
  }));
  return db;
}

// packages/notifications — @pragma('vm:entry-point') background reschedule worker
@pragma('vm:entry-point')
Future<void> rescheduleWorker(Uint8List dbKey) async {
  final db = await openAppDatabase(dbKey, await resolveDbPath());
  final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
  try {
    await container.read(reminderSchedulerProvider).reconcileFromDb();
  } finally {
    container.dispose();
    await db.close();
  }
}
```

The DB key is **read on the main isolate** (secure storage / boot receiver after first unlock,
`AfterFirstUnlock` key class) and **passed in** — the isolate never opens secure-storage plumbing.
The encrypted DB is the true source of truth; the isolate rebuilds everything from it. Scheduling is
a **framework-agnostic service**, not a Notifier — recurring schedules resolve to `TZDateTime` in the
pure scheduler.

## 6. Cross-cutting settings notifiers

Locale, calendar system, numeral system, units, currency, and theme are small app-level `keepAlive`
`Notifier`s persisted to the encrypted DB (so they travel inside the single-file backup) and watched
app-wide. `MaterialApp.locale` watches `LocaleController` so an RTL↔LTR switch rebuilds cleanly.
**Never** read locale/calendar/numeral/units from ad-hoc singletons.

```dart
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  Locale build() => ref.watch(settingsRepositoryProvider).readLocale();
  Future<void> set(Locale l) async {
    await ref.read(settingsRepositoryProvider).writeLocale(l);
    state = l;
  }
}
```

## Rules

**Do**
- `ref.watch` in `build`/derivations; `ref.read` only in callbacks; `ref.listen` for side-effects.
- Read the DB only through repository providers; wrap Drift `.watch()` in stream providers.
- Use `ref.watch(p.select((s) => s.field))` and small `ConsumerWidget`s to avoid rebuild storms.
- Offload heavy analytics/TCO/import parsing to `Isolate.run`/`compute` — never sync in `build`.
- Keep engines (`TcoEngine`, `UsageProjector`, `ReminderScheduler`) framework-free, `Clock`-injected;
  providers do only wiring.
- Add `addTearDown(container.dispose)` — or use `ProviderContainer.test()` — in every provider test.

**Don't**
- Touch Drift, `flutter_secure_storage`, or platform channels from a widget or feature Notifier.
- Build backup/import/restore on the experimental Mutation API.
- Reference providers/`ProviderScope` from a background isolate entrypoint, or share a container across isolates.
- Put reboot/Doze-surviving scheduling inside a Notifier — it lives in a framework-agnostic service.
- Introduce a second DI container (`get_it`/`injectable`/`MultiProvider`) or a god `AppState`/`injection.dart`.
- Make the DB/scheduler `autoDispose`; treat provider memory as durable state.

## Testing with ProviderContainer overrides

```dart
test('tco recomputes when fuel stream emits', () async {
  final container = ProviderContainer(overrides: [
    fuelRepositoryProvider.overrideWithValue(FakeFuelRepo(controller.stream)),
  ]);
  addTearDown(container.dispose);
  final sub = container.listen(tcoProvider('v1'), (_, __) {});
  controller.add([sampleFill]);
  await container.pump();
  expect(sub.read(), isA<AsyncData<TcoBreakdown>>());
});
```

- **Pure engines with no Riverpod** — construct `TcoEngine`/`UsageProjector` directly with fake
  repositories via their constructors and an injected `Clock` (`package:clock` + `fake_async`).
- **In-memory DB seam** — override `appDatabaseProvider` with `NativeDatabase.memory()`; the *same*
  override seam serves production startup and tests, so no SQLCipher key is needed in unit tests.
- **Override style** — `overrideWith((ref) => fake)` for behavior fakes, `overrideWithValue(x)` for
  pre-built instances; both give per-test isolation with **no global mutation** (the win over
  `get_it reset()`).
- **Background reschedule path** — invoke the isolate entrypoint's composition function directly with
  an in-memory DB and assert the `FakeNotificationGateway` received the expected pending set.
- **Widget/golden** — wrap in `ProviderScope(overrides: […])` and override the locale provider to lock
  RTL (fa/ar/ckb) vs LTR, Jalali/Hijri, Eastern-Arabic/Persian numerals, `textScaler` 1.5–2×.
- Use `mocktail` (no codegen); prefer fakes over mocks. 100% coverage enforced on logic packages only.

## Package list

```yaml
dependencies:
  flutter_riverpod: ^3.0.0        # DI + state core (pin verified stable at kickoff)
  riverpod_annotation: ^3.0.0
  freezed_annotation: ^2.0.0
dev_dependencies:
  riverpod_generator: ^3.0.0
  riverpod_lint: ^3.0.0
  custom_lint: ^0.7.0
  build_runner: ^2.0.0
  freezed: ^2.0.0
  mocktail: ^1.0.0
  # NOT used, on purpose: get_it, injectable, package:provider, riverpod_sqflite.
```
