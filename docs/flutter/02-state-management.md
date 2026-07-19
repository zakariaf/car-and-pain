# 🧬 State Management with Riverpod

> This document governs how application state, dependency injection, and reactive data flow are structured in Car and Pain — from the encrypted-DB startup gate through scoped Drift streams, derived analytics, and durability-critical async flows.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · see also [Architecture & Module Structure](./01-architecture-and-structure.md) · [Local Database, Schema, Indexing & Migrations](./03-data-persistence.md) · [Dependency Injection & Composition Root](./04-dependency-injection.md)

## Decision

Use **Riverpod 3.x with code generation** (`@riverpod` + `riverpod_generator` over `build_runner`), enforced by **`riverpod_lint`/`custom_lint`** and paired with **Freezed** for immutable state. Riverpod is the single mechanism for **both** dependency injection and state. Repositories, the encrypted database, and long-lived services are `keepAlive` providers; scoped Drift `.watch()` streams are wrapped in stream providers; analytics/TCO are auto-memoized **derived** providers. The data-safety-critical **backup / import / restore** flows are carried by a **stable `AsyncNotifier`** with `AsyncValue`-driven progress — Riverpod 3's experimental **Mutation API is optional sugar only**, never the backbone of the flagship durability surface. Pin the verified current-stable `flutter_riverpod`/`riverpod_annotation` 3.x major at kickoff; keep experimental APIs behind thin wrappers.

## Why

Car and Pain has **no network layer**. Its reactive heart is the local encrypted Drift/SQLite database, so the whole UI is best modeled as a graph of providers that `ref.watch` Drift `.watch()` streams, with the analytics/charts/TCO engine expressed as cheap, auto-memoized **derived** providers that recompute only when their underlying DB streams change. That single fact tilts the entire decision:

- **Drift `.watch()` maps 1:1 onto Riverpod stream providers.** A write anywhere in the app propagates automatically to every dependent screen with zero manual refresh.
- **Cross-module aggregation is just provider composition.** TCO = fuel + service + depreciation + projection becomes one provider that `ref.watch`es others — vs Bloc's manual bloc-to-bloc stream subscriptions and combining.
- **Compile-safe DI without `BuildContext`** is essential for the substantial out-of-tree work: the notification scheduler, the TCO/projection engines, and backup/import all run outside the widget tree and even in background isolates.
- **`AsyncValue` gives free loading/error/data**, and `ProviderContainer` gives best-in-class headless testability (no widget tree needed for the bulk of logic tests).

Riverpod 3.0 (stable Sept 2025; 3.3.x by mid-2026) folds AutoDispose/Family into a unified `Notifier`, unifies `Ref`, adds `ref.mounted` for post-`await` safety, automatic retry with exponential backoff, and `ProviderContainer.test()`.

### Alternatives considered and rejected

| Option | Verdict | Why rejected here |
| --- | --- | --- |
| **flutter_bloc (Bloc/Cubit)** | Strong runner-up | Event+state boilerplate multiplies across ~25 modules; cross-module derived state (TCO) needs manual stream combining; event-sourcing benefits target networked flows this app doesn't have. Defensible **only** if the solo dev already has deep Bloc muscle memory (see [Decisions to confirm](#decisions-to-confirm)). |
| **package:provider** | Rejected | `BuildContext`-bound — disqualifying for background/isolate work; Riverpod's own predecessor. |
| **GetX** | Rejected | Global mutable state, tight coupling, weak testability — wrong for a long-lived, buy-once, 25-module codebase. |
| **Signals** | Watch, not primary | Elegant for derived state but too immature to anchor a multi-year commercial app; thin lint/testing story. |
| **Riverpod Mutation API for backup** | Rejected for the flagship surface | Experimental in 3.x — never bet the app's real durability guarantee on an experimental API. Stable `AsyncNotifier` instead. |
| **`setState`/`InheritedWidget` only** | Use alongside | Fine for ephemeral local UI state (toggles, focus); not an app architecture. |

## How we do it

Providers are **colocated** with the feature that owns them (`presentation/<feature>_notifier.dart`), while long-lived infrastructure providers live in the packages they belong to. Feature folders never import another feature — they share via `core`/`data` or navigate by ID.

```text
apps/car_and_pain/lib/src/
  bootstrap.dart                 # composition root: unwrap DB key → open encrypted DB → override placeholders
  features/02-fuel-energy/
    presentation/
      fuel_list_view.dart        # ConsumerWidget, watches fuelEntriesProvider(vehicleId)
      fuel_entry_notifier.dart   # autoDispose form Notifier, Freezed state
    application/
      fuel_use_cases.dart        # thin: wires pure core engines to the repository
packages/
  core/      # PURE Dart: TcoCalculator, UsageProjector, Result<T,F>, Clock — no Riverpod
  data/      # AppDatabase, repositories, scoped .watch() streams, rollup tables, backup engine
  notifications/  # NotificationGateway port + pure ReminderScheduler + isolate factories
```

### 1. Infrastructure & repositories as `keepAlive` providers

The encrypted DB and every repository are built once and disposed on app exit. **Notifiers and widgets never touch Drift directly** — always through a repository provider.

```dart
// Placeholder overridden in bootstrap() once the key is unwrapped (see §5).
@Riverpod(keepAlive: true)
String dbKey(Ref ref) => throw UnimplementedError('overridden in ProviderScope');

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase(openEncrypted(ref.watch(dbKeyProvider)));
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
FuelRepository fuelRepository(Ref ref) =>
    FuelRepository(ref.watch(appDatabaseProvider));
```

### 2. Scoped Drift streams — the reactive backbone

Wrap Drift `.watch()` in a stream provider. Critically, **scope by vehicle + time window** so one fuel entry never re-emits app-wide (see [Local Database, Schema, Indexing & Migrations](./03-data-persistence.md) for the rollup tables these read).

```dart
@riverpod
Stream<List<FuelEntry>> fuelEntries(Ref ref, String vehicleId) =>
    ref.watch(fuelRepositoryProvider).watchFuelEntries(vehicleId); // scoped query
```

```dart
// UI — small ConsumerWidget, no manual refresh anywhere.
ref.watch(fuelEntriesProvider(vehicleId)).when(
      data: (rows) => FuelList(rows),
      loading: () => const _Skeleton(),
      error: (e, _) => FailureView(e), // typed Failure, localized at the edge
    );
```

### 3. Derived analytics / TCO — memoized, isolate-offloaded

Compose stream providers into derived state. Keep the **math pure** (in `core`) and offload heavy compute off the UI thread. Use `ref.keepAlive()` for costly charts so navigating away doesn't force a recompute; recompute is keyed off the DB's revision counter, not wall-clock.

```dart
@riverpod
Future<TcoBreakdown> tco(Ref ref, String vehicleId) async {
  final fuel = await ref.watch(fuelEntriesProvider(vehicleId).future);
  final svc  = await ref.watch(serviceRecordsProvider(vehicleId).future);
  final link = ref.keepAlive();               // expensive → survive navigation
  ref.onDispose(link.close);
  return Isolate.run(() => TcoCalculator.compute(TcoInput(fuel, svc)));
}
```

### 4. Durability side-effects — stable `AsyncNotifier`, not Mutations

Backup, import, and restore drive an `AsyncNotifier` and surface progress/error through `AsyncValue`. Use `ref.listen` (not `ref.watch`) in the UI for one-shot reactions like a SnackBar or navigation.

```dart
@riverpod
class BackupController extends _$BackupController {
  @override
  FutureOr<void> build() {}

  Future<void> exportTo(String path) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(backupRepositoryProvider).exportTo(path),
    );
  }
}
```

### 5. Encrypted-DB startup gate

Opening the DB before the key is available fails. Fetch and **unwrap the recoverable key** in `bootstrap()` on the main isolate, then override the placeholder providers in the root `ProviderScope`. The root widget shows a splash while async init resolves. See [Security, Privacy & At-Rest Encryption](./09-security-privacy.md) for the recoverable-key design.

```dart
Future<void> bootstrap() async {
  final key = await SecureKeyStore.unwrapMasterKey(); // passphrase/recovery-code aware
  await initTimezone();                                // tz.local for the scheduler
  runApp(ProviderScope(
    overrides: [dbKeyProvider.overrideWithValue(key)],
    child: const CarAndPainApp(),
  ));
}
```

### 6. Cross-cutting settings notifiers

Locale, calendar system (Gregorian/Jalali/Hijri), numeral system, units, currency, and theme are small app-level `Notifier`s persisted to the encrypted DB (so they travel inside the single-file backup) and watched app-wide. `Directionality`/`Localizations` are driven from the watched `localeProvider` so an RTL↔LTR switch rebuilds cleanly. **Never** read locale/calendar from ad-hoc singletons.

```dart
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  Locale build() => ref.watch(settingsRepositoryProvider).readLocale();
  Future<void> set(Locale l) async {
    await ref.read(settingsRepositoryProvider).writeLocale(l);
    state = l; // MaterialApp.locale watches this → clean RTL/LTR rebuild
  }
}
```

### 7. Background isolates get **no** `ProviderScope`

Notification scheduling is a **framework-agnostic service**, not a Notifier. The UI reaches it via a provider; background entrypoints (`BOOT_COMPLETED`, WorkManager) build it through plain top-level factory functions into a throwaway `ProviderContainer` or directly, with the DB key read on the main isolate and passed in. See [Local Notifications & Background Reliability](./07-notifications.md) and [Dependency Injection & Composition Root](./04-dependency-injection.md).

### Package list

```yaml
dependencies:
  flutter_riverpod: ^3.0.0        # or hooks_riverpod if pairing with flutter_hooks
  riverpod_annotation: ^3.0.0
  freezed_annotation: ^2.0.0
dev_dependencies:
  riverpod_generator: ^3.0.0
  riverpod_lint: ^3.0.0
  custom_lint: ^0.7.0
  build_runner: ^2.0.0
  freezed: ^2.0.0
  mocktail: ^1.0.0                # fakes/mocks in ProviderContainer tests, no codegen
  # riverpod_sqflite — deliberately UNUSED: Drift is already the source of truth
```

## Rules

**Do**
- Read the DB **only** through repository providers; wrap Drift `.watch()` in stream providers.
- `ref.watch` in `build`, `ref.read` in callbacks/event handlers, `ref.listen` for side-effects (SnackBar, navigate). Enforced by `riverpod_lint`.
- Use `ref.watch(p.select((s) => s.field))` and small `ConsumerWidget`s on list/analytics screens to avoid rebuild storms.
- Make repositories/DB/services `keepAlive`; keep genuinely cheap derived providers `autoDispose`; call `ref.keepAlive()` on expensive derived providers.
- Offload heavy analytics/TCO/import parsing to `Isolate.run`/`compute` — never compute synchronously in `build`.
- Keep TCO, economy, projection, next-due, calendar, numeral, and scheduler math as **pure functions in `core`** with an injected `Clock`; providers only wire them.
- Add `addTearDown(container.dispose)` (or use `ProviderContainer.test()`) in every provider test.

**Don't**
- Don't touch Drift, `flutter_secure_storage`, or platform channels from inside a widget or a feature Notifier.
- Don't build backup/import/restore on the experimental Mutation API — use a stable `AsyncNotifier`.
- Don't `ref.watch` in callbacks or `ref.read` in `build`; don't `ref.watch` for one-shot effects.
- Don't reference providers/`ProviderScope` from background isolate entrypoints.
- Don't put reboot/Doze-surviving scheduling inside a Notifier — it lives in a framework-agnostic service.
- Don't read locale/calendar/numeral/units from singletons — only from the watched settings notifiers.

**CI / lint**
- `custom_lint` + `riverpod_lint` run in the analyze lane; violations fail the PR pipeline.
- `*.g.dart` are gitignored; `build_runner` regenerates as the first CI step (drift/freezed/riverpod/gen-l10n together at the workspace root). See [Build, Tooling, Release & CI/CD](./12-build-ci-release.md).

## For Car and Pain specifically

- **Offline-first:** with no server, the provider graph *is* the app's data-flow — encrypted DB → scoped `.watch()` → derived analytics → UI. There is nothing to re-sync from, so state is a disposable cache reconstructed from the DB after process death, reboot, or restore.
- **Canonical storage:** providers pass **value objects** (`Distance`, `Volume`, `Money` with ISO-4217 exponent) from `core`, never display strings or native numerals. Conversion/formatting happen only at the presentation boundary. See [Money, Currency, Units & FX](./14-money-currency-fx.md).
- **RTL / i18n:** `MaterialApp.locale` watches `LocaleController`; calendar/numeral/direction all flow from watched settings notifiers so a Persian/Kurdish UI on an English-locale phone rebuilds deterministically. See [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md).
- **Notifications:** scheduling is a service callable from both the widget tree (via a provider) and background isolates; a data change or foreground event triggers a reconcile against the DB. Recurring schedules resolve to `TZDateTime` in the pure scheduler, not in a Notifier.
- **No-telemetry:** headless `ProviderContainer` testing plus pure engines mean correctness is verified without any SDK; nothing in the state layer opens a connection. See [Store Compliance, Privacy Declarations & Licensing](./17-store-compliance-licensing.md).

## Testing

Riverpod's testability is a primary reason to choose it. The bulk of logic needs **no widget tree**, so the suite is fast and deterministic. See [Testing Strategy](./11-testing.md).

- **Pure engines first:** unit-test `TcoCalculator`, `UsageProjector` (min-samples/insufficient-data fallback), economy, next-due, and the scheduler directly with an injected `Clock` (`package:clock`) + `fake_async` + timezone fixtures — no Riverpod at all. This keeps provider tests thin.
- **Derived reactivity:** feed a fake stream into a repository override and assert the derived TCO provider re-emits — `container.listen` captures the `AsyncLoading → AsyncData` sequence.

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

- **Durability flows:** drive `BackupController.exportTo` against a `FakeBackupRepository`; assert `AsyncLoading → AsyncData/AsyncError`.
- **Widget/golden:** wrap in `ProviderScope(overrides: [...])` and override `localeProvider` to lock RTL (fa/ar/ckb) vs LTR mirroring, Jalali/Hijri calendars, Eastern-Arabic/Persian numerals, and `textScaler` 1.5–2× RTL-overflow — explicit golden dimensions.
- **Hygiene:** always `addTearDown(container.dispose)` (or `ProviderContainer.test()`) — leaked containers bleed state and cause flaky suites.

## Pitfalls

- **Rebuild storms:** watching a whole-list provider inside a large widget rebuilds everything on any row change. Split into small `ConsumerWidget`s and use `ref.select` — especially on charts/analytics.
- **`autoDispose` surprises on expensive derived state:** TCO/chart providers dispose on navigate-away and recompute on return. Use `ref.keepAlive()` (optionally with a timed `link.close()`) for costly compute; keep cheap providers `autoDispose`.
- **Heavy work in `build`:** never run analytics/TCO/import-parse synchronously — offload to `Isolate.run`/`compute`. Jank is very visible under Impeller. See [Performance & Rendering](./10-performance-rendering.md).
- **Background isolates have no `ProviderScope`:** `BOOT_COMPLETED`/WorkManager callbacks cannot read providers. Design services to be instantiable standalone with their own Drift connection.
- **Encrypted-DB key ordering:** opening the DB before the key is unwrapped fails — gate `appDatabaseProvider` on `dbKeyProvider` and splash via `AsyncValue` until resolved.
- **`ref.watch` vs `ref.read` misuse:** watching in callbacks or reading in `build` causes subtle bugs — enforce with `riverpod_lint`; use `ref.listen` for effects.
- **build_runner friction:** pin `riverpod_generator`/`build_runner`, run `--watch` in dev, gitignore generated files consistently to avoid stale providers.
- **Experimental APIs:** Mutations and `riverpod_sqflite` are experimental — keep behind thin wrappers, pin versions, and never place the durability surface on them.
- **Test container leaks:** missing `addTearDown(container.dispose)` bleeds state between tests.

## Decisions to confirm

- **Riverpod vs the developer's existing Bloc muscle memory.** Riverpod is recommended, but Cubit-heavy `flutter_bloc` is a defensible second choice that shapes all 25 modules. Confirm existing expertise before locking this in at kickoff — this choice is expensive to reverse.

## Related

- [Architecture & Module Structure](./01-architecture-and-structure.md) — the feature-first workspace and package boundaries providers live within.
- [Local Database, Schema, Indexing & Migrations](./03-data-persistence.md) — the Drift streams, rollup tables, and revision counter the reactive graph reads from.
- [Dependency Injection & Composition Root](./04-dependency-injection.md) — Riverpod-as-DI, the bootstrap override sequence, and isolate factories.
- [Local Notifications & Background Reliability](./07-notifications.md) — why scheduling is a framework-agnostic service, not a Notifier.
- [Error Handling & Never-Lose-Data](./08-error-handling.md) — the sealed `Result<T,F>`/`Failure` values providers surface to the UI.
- [Testing Strategy](./11-testing.md) — headless `ProviderContainer` testing and the golden matrix.
