---
name: flutter-architecture
description: Map and enforce the top-level architecture of Car and Pain — the feature-first modular monolith on a native Dart Pub Workspace. One runnable app shell (apps/car_and_pain) holds ~25 numbered feature folders over exactly five foundational packages (core, data, notifications, l10n, design_system), a strict acyclic dependency DAG, barrel-only public APIs over private src/, the single go_router with refreshListenable and navigate-by-ID, and Riverpod 3.x as the one context-free mechanism for BOTH dependency injection and state. Decides package versus folder, where Notifiers, repositories, and use-cases live, and how bootstrap.dart composes the object graph. Use when adding a feature folder, deciding package versus folder, writing bootstrap.dart or a placeholder root provider, wiring a keepAlive DB or scheduler singleton or a .watch stream provider, setting up the GoRouter or a payload-to-location mapper, defining a barrel export, writing ProviderContainer override tests, or running the boundary checks.
metadata:
  project: car-and-pain
  pairs-with: monorepo-codegen-toolchain, custompainter-charts
  sources: docs/flutter/00-overview.md, docs/flutter/01-architecture-and-structure.md, docs/flutter/02-state-management.md, docs/flutter/04-dependency-injection.md, docs/flutter/05-navigation.md, docs/flutter/08-error-handling.md, docs/planning/01-dependencies-and-decisions.md
---

# Flutter Architecture (Car and Pain)

Carve every change into the fixed shape: a thin runnable **app shell** (`apps/car_and_pain`)
holding ~25 numbered feature **folders**, over exactly five foundational **packages** —
`core`, `data`, `notifications`, `l10n`, `design_system`. This is a **feature-first modular
monolith on a native Dart Pub Workspace** following Flutter MVVM (UI + data layer), adding a
domain/use-case layer **only where logic spans multiple repositories**. This skill is the map that
cross-links every other skill: state/DI (Riverpod), data (`monorepo-codegen-toolchain` for the
build_runner toolchain), charts (`custompainter-charts`), i18n, and design tokens.

State/DI is **locked to Riverpod 3.x** — ADR-1 is `Superseded → Riverpod 3.x adopted`
(`docs/planning/01-dependencies-and-decisions.md`). There is no second DI container; `get_it`,
`injectable`, and `package:provider` are rejected app-wide.

Read the reference the task touches:
- `references/module-structure.md` — package-vs-folder table, feature-folder anatomy, the DAG, barrels.
- `references/state-di-riverpod.md` — keepAlive vs autoDispose, placeholder-override startup, isolate factories, `ProviderContainer` tests.
- `references/navigation-go-router.md` — the single GoRouter, `refreshListenable`, navigate-by-ID, payload→location.
- `references/boundary-rules.md` — the exact CI checks and what each rejects.
- Run `scripts/check_boundaries.sh` before opening a PR.

## Non-negotiable rules

- **Features are FOLDERS; foundations are PACKAGES.** A new feature is a new numbered folder under
  `apps/car_and_pain/lib/src/features/` — **never** a new package. Promote to a package only for a
  truly cross-cutting concern with a stable, narrow API. The set is frozen at **five**: `core`,
  `data`, `notifications`, `l10n`, `design_system`. Do not add a sixth without an ADR.
- **A feature folder NEVER imports another feature folder.** Share via `core`/`data`, or navigate
  by route **ID** (`const VehicleDetailRoute(vehicleId: id).go(context)`). The dependency graph is a
  strict **DAG**: `core` depends on nothing internal; `data`/`notifications` → `core`;
  `design_system` → `core`, `l10n`; the app shell → everything. `custom_lint` enforces this.
- **Barrel-only public APIs.** Each package exposes one entry point (`core.dart`, `data.dart`, …)
  with `export 'src/…' show …`. `src/` is private by convention — **never** import a package's
  `src/` path from outside it.
- **Riverpod is the single mechanism for BOTH DI and state.** No `get_it`/`injectable`/`provider`.
  Context-free DI is load-bearing: the same repositories and engines are reachable from a screen, a
  notification callback, and a background isolate with **zero `BuildContext`**.
- **Async infra is injected via placeholder root providers overridden in `bootstrap.dart`.** The
  key-unwrapped encrypted DB, secure key store, app dirs, and timezone are `throw UnimplementedError()`
  placeholders `overrideWithValue`d in the root `ProviderScope`. DB/scheduler/repositories are
  **`keepAlive`**; per-screen controllers are **`autoDispose`**.
- **Background isolates get NO `ProviderScope`.** `BOOT_COMPLETED` / WorkManager entrypoints build
  infra through **plain top-level factory functions** (e.g. `openAppDatabase(key, path)`) into a
  throwaway `ProviderContainer`, with the DB key **read on the main isolate and passed in**. Never
  reference the UI container or share a `ProviderContainer` across isolates.
- **Never leak Drift-generated row/companion classes into a Notifier or widget.** Repositories map
  Drift rows → domain models at the boundary. Widgets receive **value objects** (`Distance`,
  `Volume`, `Money` with ISO-4217 exponent, `EngineHours`).
- **No unit math or numeral/calendar formatting in widgets.** Conversions live in `core`;
  formatting/parsing lives in `l10n`. A widget never divides litres or hardcodes two decimals.
- **One `GoRouter`, navigate by ID.** A single `StatefulShellRoute.indexedStack` shell (~6 branches),
  full-screen flows above it via `rootNavigatorKey`, guards as pure `redirect` fed by a Riverpod
  `refreshListenable`. Deep-linkable identity lives in **path params**, never `state.extra` (null on
  cold start). Notification payloads map to a location through a **pure** `payload → location` function.
- **Add a use-case/domain layer only when logic spans multiple repositories** (TCO, projection,
  analytics, scheduler). No use-case on trivial CRUD — Flutter's stated trigger.
- **Errors are typed values at every boundary.** Repositories/use-cases return sealed
  `Result<T, F>` over a sealed `Failure` (stable code + typed params, never user strings); the UI
  `switch`es exhaustively with no `default`. Exceptions are for bugs only → a local rotating log.

## The canonical composition root

`bootstrap.dart` is the ONE place async infra is constructed and placeholder providers are
overridden. The same `openAppDatabase` factory it calls is what a background isolate calls — that
symmetry is what makes reschedule-after-reboot work without a `BuildContext`.

```dart
// apps/car_and_pain/lib/src/bootstrap.dart — the composition root.
Future<void> bootstrap({required Flavor flavor}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));

  final dirs     = await resolveAppDirs();
  final keyStore = await SecureKeyStore.open();
  final dbKey    = await keyStore.readAndUnwrapDbKey();       // recoverable key, MAIN isolate only
  final db       = await openAppDatabase(dbKey, dirs.dbPath); // plain factory; cipher + header asserted

  // Notification tap that cold-started the app → initial location, rebuilt from IDs alone.
  final launch  = await flnp.getNotificationAppLaunchDetails();
  final initial = (launch?.didNotificationLaunchApp ?? false)
      ? mapNotificationPayload(launch!.notificationResponse?.payload)
      : '/';

  runApp(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),   // placeholder → real
      secureKeyStoreProvider.overrideWithValue(keyStore),
      appDirsProvider.overrideWithValue(dirs),
      flavorProvider.overrideWithValue(flavor),
      initialLocationProvider.overrideWithValue(initial),
    ],
    child: const CarAndPainApp(),
  ));
}
```

`main_dev.dart` / `main_prod.dart` are one-liners: `bootstrap(flavor: …)`. See
`references/state-di-riverpod.md` for the placeholder providers and the isolate `rescheduleWorker`,
and `references/navigation-go-router.md` for `mapNotificationPayload` and the router wiring.

## Feature-folder anatomy

```text
features/02-fuel-energy/
├── presentation/
│   ├── view/                 # dumb widgets: layout, show/hide, navigate-by-ID
│   └── fuel_notifier.dart    # @riverpod Notifier = the ViewModel (Freezed state)
├── application/              # thin use-cases — ONLY where logic spans repos
├── domain/                   # feature-local Freezed models
└── data/                     # usually ABSENT — reads shared repos from packages/data
```

Most features are **presentation + application only**, reading shared repositories from `data`.
A dumb `View` observes a `Notifier`; the `Notifier` calls repositories/use-cases; widgets hold no
business or conversion logic. Naming stays consistent: `HomeScreen`, `HomeNotifier`,
`VehicleRepository`, `AppDatabase`. See `references/module-structure.md`.

## Package-vs-folder decision

Extract to a package **only** when a compile-time wall is load-bearing — divergence would be a
data-integrity or reliability bug. Everything else stays a folder to keep iteration fast. The five
walls and their rationale (canonical units/money → `core`, all DB/backup → `data`, the one
scheduler → `notifications`, i18n → `l10n`, RTL geometry → `design_system`) are tabulated in
`references/module-structure.md`. Avoid a `shared/`/`common/` dumping ground — promote deliberately.

## Boundary enforcement

Three blocking CI checks defend the shape (`references/boundary-rules.md`):
1. `custom_lint` + `riverpod_lint` — no cross-feature import, no Drift class in UI, provider misuse.
2. A grep rejecting non-Directional geometry in `apps/**` and `packages/design_system/**`.
3. A test asserting the raw DB file header is **not** `SQLite format 3` (encryption is real).

Run all of them plus `flutter analyze` and codegen freshness via `scripts/check_boundaries.sh`.

## Pitfalls

- **Over-modularization** — 25 feature packages multiply pubspecs and codegen time for zero benefit.
  Reserve packages for the five stable concerns; features are folders.
- **Leaking Drift classes into UI** — a schema change then ripples into every ViewModel. Map at the repo.
- **Scattering conversion/formatting in widgets** — the #1 way canonical discipline erodes.
- **Cross-feature imports creating cycles** — share via `core`/`data` or navigate by ID.
- **`state.extra` for deep-linkable data** — null on cold start/reboot; carry IDs in path params.
- **Sharing a `ProviderContainer` across isolates** — impossible; rebuild infra via factory functions.
- **`autoDispose` on the DB/scheduler** — torn down mid-operation; mark infra `keepAlive`.
- **A member pubspec missing `resolution: workspace`** — silently breaks Pub Workspace resolution.
