# 🧩 Dependency Injection & Composition Root

> How Car and Pain wires its object graph — repositories, services, and pure engines — so the same infrastructure is reachable from the widget tree **and** from background isolates, with zero `BuildContext` and zero global mutable state.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · See also **[State Management with Riverpod](./02-state-management.md)** · **[Architecture & Module Structure](./01-architecture-and-structure.md)** · **[Local Notifications & Background Reliability](./07-notifications.md)**

## Decision

**Riverpod 3.x with code generation (`@riverpod` + `riverpod_generator`, plus `riverpod_lint`/`custom_lint`) is the single, unified mechanism for BOTH dependency injection and state management.** There is no second DI container. Repositories, services, and framework-free engines are exposed as providers; async-initialized infrastructure (the opened + key-unwrapped encrypted DB, the secure key store, app directories, the timezone database) is injected via **placeholder root providers** that `throw UnimplementedError()` and are **overridden with real instances in a `ProviderScope` at `main()`/`bootstrap.dart`**. The one deliberate exception: **background isolates get no `ProviderScope`** — they build infrastructure through **plain top-level factory functions** into their own throwaway `ProviderContainer`, with the DB key read on the main isolate and passed in. `get_it`/`injectable` and `package:provider` are explicitly rejected as app-wide containers.

## Why

Car and Pain does substantial work **outside the widget tree**: the notification reschedule worker, the odometer/engine-hour projection worker, the TCO engine, and the backup/import pipeline all run where there is no `BuildContext`. Riverpod resolves dependencies **without `BuildContext`**, so the *same* repositories and engines are reachable from a notification callback, a background isolate, and a screen — one wiring, three call sites. Reactivity is free and load-bearing: `ref.watch` makes charts, analytics, and TCO recompute automatically when the underlying fuel/odometer/maintenance rows change, mapping 1:1 onto Drift's `.watch()` streams (see **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)**). And `ProviderContainer(overrides: […])` gives per-test, fully-isolated dependency graphs — swap the encrypted DB for `NativeDatabase.memory()` with **zero global mutation**.

Alternatives considered and rejected:

- **`get_it` + `injectable`** — works without `BuildContext` and in isolates, but it is a **global mutable singleton**: a forgotten registration crashes at *runtime*, not compile time; it has **no reactivity** (you would hand-wire every chart/TCO recompute); and test isolation via `reset()`/`allowReassignment` is more error-prone than scoped, throwaway overrides. Redundant once Riverpod already gives context-free DI. **Never run it alongside Riverpod** — two DI systems is needless surface.
- **`package:provider`** (the official Flutter-guide default) — its `BuildContext` dependency is **disqualifying** for an app that does heavy work in background isolates and notification handlers; `MultiProvider` at the root becomes a central god-object; no compile-safe test overrides. We adopt its **layering discipline** (View → ViewModel → Repository → Service) but not the package.
- **Hand-wired composition root (no framework)** — its principles (constructor injection into plain classes, a single composition root) are **kept inside Riverpod** — engines stay framework-free classes — but manual wiring across ~25 feature modules is brittle and reactivity-free.

## How we do it

### Layered provider graph

Dependencies flow in one direction and the graph is a **DAG**:

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

### 1. Placeholder root providers, overridden at startup

The canonical Riverpod pattern for injecting things that need **async construction** — and it doubles as the test seam.

```dart
// packages/data/lib/src/providers.dart
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('override in bootstrap()'),
);
final secureKeyStoreProvider = Provider<SecureKeyStore>(
  (ref) => throw UnimplementedError('override in bootstrap()'),
);
final appDirsProvider = Provider<AppDirs>(
  (ref) => throw UnimplementedError('override in bootstrap()'),
);
```

```dart
// apps/car_and_pain/lib/src/bootstrap.dart — the composition root
Future<void> bootstrap({required Flavor flavor}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeTimeZones();              // timezone db
  tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));

  final dirs = await resolveAppDirs();
  final keyStore = await SecureKeyStore.open();
  final dbKey = await keyStore.readAndUnwrapDbKey();   // recoverable key, main isolate only
  final db = await openAppDatabase(dbKey, dirs.dbPath); // asserts cipher + header

  runApp(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      secureKeyStoreProvider.overrideWithValue(keyStore),
      appDirsProvider.overrideWithValue(dirs),
    ],
    child: const CarAndPainApp(),
  ));
}
```

`main_dev.dart` / `main_prod.dart` are thin — each calls `bootstrap(flavor: …)`.

### 2. Repository providers depend on abstract interfaces

```dart
// packages/data — feature repos wired to infra
@riverpod
FuelRepository fuelRepository(Ref ref) =>
    DriftFuelRepository(ref.watch(appDatabaseProvider));

@riverpod
Stream<List<FuelEntry>> vehicleFuelHistory(Ref ref, VehicleId id) =>
    ref.watch(fuelRepositoryProvider).watchByVehicle(id); // scoped .watch()
```

`FuelRepository` is an **interface** (`abstract interface class`) declared in `core`/`domain`; `DriftFuelRepository` is the implementation in `data`. Cross-module code depends only on the interface.

### 3. Engines compose repositories and stay framework-free

```dart
@Riverpod(keepAlive: true)
TcoEngine tcoEngine(Ref ref) => TcoEngine(
      fuel: ref.watch(fuelRepositoryProvider),
      maintenance: ref.watch(maintenanceRepositoryProvider),
      depreciation: ref.watch(depreciationRepositoryProvider),
      clock: ref.watch(clockProvider), // package:clock — deterministic in tests
    );
```

`TcoEngine`, `UsageProjector`, and `ReminderScheduler` are **plain Dart classes** with zero Flutter/plugin/IO imports (they live in `core`/`notifications`). Providers do only the wiring — the highest-leverage testability decision in the app.

### 4. Controllers as autoDispose AsyncNotifiers

```dart
@riverpod
class VehicleDashboardController extends _$VehicleDashboardController {
  @override
  Future<Dashboard> build() {
    final vehicleId = ref.watch(currentVehicleIdProvider);
    return ref.watch(tcoEngineProvider).computeFor(vehicleId); // recomputes on data change
  }
}
```

### 5. Isolate-safe factory functions (the load-bearing exception)

A `ProviderContainer` **cannot cross isolates**. Infra construction lives in **top-level factory functions** that both the app and a fresh in-isolate container call.

```dart
// packages/data — plain top-level factory, no Riverpod, no Flutter widgets
Future<AppDatabase> openAppDatabase(Uint8List key, String dbPath) async {
  final db = AppDatabase(NativeDatabase(File(dbPath), setup: (raw) {
    raw.execute("PRAGMA key = \"x'${hex.encode(key)}'\";"); // first statement
    // assert cipher/KDF explicitly; header check runs in a CI test
  }));
  return db;
}
```

```dart
// packages/notifications — @pragma('vm:entry-point') background reschedule worker
@pragma('vm:entry-point')
Future<void> rescheduleWorker(Uint8List dbKey) async {
  final db = await openAppDatabase(dbKey, await resolveDbPath());
  final container = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
  ]);
  try {
    await container.read(reminderSchedulerProvider).reconcileFromDb();
  } finally {
    container.dispose();
    await db.close();
  }
}
```

The key is **read on the main isolate** (secure storage / boot receiver after first unlock) and **passed in** — the isolate never opens secure storage plumbing itself. The encrypted DB is the true source of truth; the isolate rebuilds everything from it.

### Package list

```yaml
dependencies:
  flutter_riverpod: ^3.0.0        # DI + state core (pin verified stable at kickoff)
  riverpod_annotation: ^3.0.0     # @riverpod annotations
dev_dependencies:
  riverpod_generator: ^3.0.0      # generates type-safe providers
  build_runner: ^2.4.0            # runs codegen (also Drift/Freezed/gen-l10n)
  custom_lint: ^0.7.0
  riverpod_lint: ^3.0.0           # static checks for provider misuse / missing deps
  # melos — monorepo script/CI orchestration (see Build & CI doc)
# NOT used, on purpose: get_it / injectable, package:provider.
```

## Rules

**Do**

- Expose every repository across a module boundary as an **abstract interface**; return the interface from its provider, never the concrete class.
- Mark infra and engine providers **`keepAlive`** (or plain `Provider`); keep per-screen controllers **autoDispose**.
- Use **`ref.watch`** in `build`/derivations (so charts/TCO recompute) and **`ref.read`** only in event callbacks.
- Put **all** infra construction (DB open, scheduler build) in **top-level factory functions** the isolate can call. Read the DB key on the main isolate and pass it in.
- Keep engines (`TcoEngine`, `UsageProjector`, `ReminderScheduler`) as **framework-free classes** injected with a `Clock`; let providers do only wiring.
- Enable **`riverpod_lint` + `custom_lint`** and run them in CI to recover compile-time safety.
- Write per-test `ProviderContainer(overrides: […])` with `addTearDown(container.dispose)` (or `ProviderContainer.test()`).

**Don't**

- ❌ Share a `ProviderContainer` across isolates, or read the UI container from a background worker.
- ❌ Introduce a second DI container (`get_it`, `injectable`, `MultiProvider`) — one DI system only.
- ❌ Build a single god `AppState`/ViewModel or a central `injection.dart` registration file — keep providers decentralized, one per concern.
- ❌ Create providers for trivial constants — reserve them for things with lifecycle, dependencies, or a test-override need.
- ❌ Let a feature folder import another feature folder; share via `core`/`data` or navigate by ID. Keep the graph a DAG (circular provider deps throw at runtime).
- ❌ Make an expensive singleton (DB, scheduler) `autoDispose` — it can be torn down mid-operation.
- ❌ Treat provider memory as durable state — everything must rebuild from the encrypted DB after process death, Doze, or an isolate cold-start.

## For Car and Pain specifically

- **Offline / account-free** — the DI graph bottoms out at the **encrypted Drift/SQLCipher DB, the local-notification scheduler, and file/backup services**. There are **zero network providers**. Nothing here pulls in an analytics or crash SDK; Riverpod is pure Dart, so the **no-telemetry** posture is preserved (a CI lockfile scan still enforces it — see **[Store Compliance, Privacy Declarations & Licensing](./17-store-compliance-licensing.md)**).
- **Notifications (the hardest DI constraint)** — the reschedule worker runs in a **background isolate** with no UI container. Because infra is reachable through factory functions and the DB is the source of truth, a tap-after-reboot, a `BOOT_COMPLETED` re-arm (Android, post-unlock, `AfterFirstUnlock` key class), or a foreground reconcile all rebuild the pending set from the DB alone. Baked in from day one, not retrofitted. See **[Local Notifications & Background Reliability](./07-notifications.md)**.
- **Canonical storage** — repositories are the enforcement boundary for SI units, currency-exponent minor units, and instants-vs-wall-clock. Feature widgets receive value objects from engines; conversion/formatting lives only in `core` and `l10n`.
- **RTL / i18n / calendars / numerals** — modeled as small formatter **services in `l10n`**, injected as `keepAlive` providers and **overridable in golden tests** to force a locale × direction × calendar × numeral combination. See **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)**.
- **Reactivity for analytics/TCO** — `ref.watch` on the fuel/maintenance/odometer repositories means adding a fill-up recomputes TCO and refreshes charts with no manual invalidation, feeding off the pre-aggregated rollup tables.

## Testing

- **Pure engines with no Riverpod** — construct `TcoEngine`/`UsageProjector` directly with **fake repositories via their constructors** and an injected `Clock` (`package:clock` + `fake_async`). This is *why* engines stay framework-free.
- **Wiring / controllers** — `final container = ProviderContainer(overrides: [fuelRepositoryProvider.overrideWith((ref) => FakeFuelRepository()), appDatabaseProvider.overrideWithValue(inMemoryDb)]); addTearDown(container.dispose);`. Riverpod 3's `ProviderContainer.test()` handles disposal automatically.
- **In-memory DB seam** — override `appDatabaseProvider` with `NativeDatabase.memory()`; the *same* override seam serves production startup and tests, so no SQLCipher key is needed in unit tests.
- **Reading results** — `await container.read(someControllerProvider.future)`; observe rebuilds with `container.listen(provider, (prev, next) {…}, fireImmediately: true)`.
- **Override style** — `overrideWith((ref) => fake)` for behavior fakes, `overrideWithValue(x)` for pre-built instances; both give per-test isolation with **no global mutation** — the concrete win over `get_it reset()`.
- **Background reschedule path** — invoke the isolate entrypoint's composition function directly with an in-memory DB and assert the `FakeNotificationGateway` received the expected pending set (respecting the iOS 64-cap budgeting).
- **Widget/golden tests** — wrap the tree in `ProviderScope(overrides: […])` with a locale/`textDirection` override provider to verify RTL mirroring and Eastern-Arabic/Persian numerals in both directions. See **[Testing Strategy](./11-testing.md)**.

## Pitfalls

- **Sharing a `ProviderContainer` across isolates** — impossible; the worker has separate memory. Rebuild infra via factory functions and treat the encrypted DB as the source of truth, not in-memory provider state.
- **God ViewModel / central registration module** — the trap `get_it`'s `injection.dart` and `provider`'s `MultiProvider` root fall into. Keep one Notifier per concern.
- **`ref.watch` vs `ref.read` mix-ups** — watching in a callback or reading in `build` causes stale UI or missed TCO recomputes.
- **Circular provider dependencies** — throw at runtime. Structure inter-module deps as a DAG; extract shared contracts into `core`.
- **`autoDispose` on expensive singletons** — a DB/scheduler provider torn down mid-operation. Mark infra `keepAlive`.
- **Over-providering trivial constants** — noise with no benefit; reserve providers for lifecycle/dependency/override needs.
- **Two DI systems** — running `get_it` alongside Riverpod doubles the surface for zero gain.

## Decisions to confirm

- **State-management/DI foundation** — Riverpod is recommended, but if the solo developer has deep `flutter_bloc` muscle memory, Cubit-heavy Bloc is a defensible second choice that reshapes all 25 modules. Confirm existing expertise before locking this in at kickoff, since the DI mechanism and the state layer are the same tool here.
- **Household P2P sync (post-MVP)** — confirmed **out** of MVP scope? If it is in-scope, the composition root gains a sync-transport service and the isolate/merge story changes; the current DI graph assumes single-device.
- **Pin verified current-stable majors at kickoff** — `flutter_riverpod`, `riverpod_generator`, and the SDK majors are shown as `^3.0.0` placeholders; verify and pin the real current-stable versions (with FVM `.fvmrc`, committed lockfiles) rather than these draft numbers.

## Related

- **[State Management with Riverpod](./02-state-management.md)** — the state half of the same tool: Notifiers, `AsyncValue`, keepAlive vs autoDispose in depth.
- **[Architecture & Module Structure](./01-architecture-and-structure.md)** — the ~25 feature folders, `core`/`data`/`notifications`/`l10n`/`design_system` packages, and DAG boundary enforcement this graph sits on.
- **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)** — the encrypted Drift DB behind `appDatabaseProvider` and its scoped `.watch()` streams.
- **[Local Notifications & Background Reliability](./07-notifications.md)** — the background-isolate reschedule worker that consumes the factory-function pattern.
- **[Security, Privacy & At-Rest Encryption](./09-security-privacy.md)** — how the recoverable DB key that `bootstrap()` unwraps is stored and restored.
- **[Testing Strategy](./11-testing.md)** — `ProviderContainer` overrides, headless Notifier tests, and the RTL/locale golden matrix.
