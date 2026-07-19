# 🏛️ Architecture & Module Structure

> How Car and Pain is carved into a runnable app shell, ~25 feature folders, and a small set of load-bearing packages — and how compile-time boundaries keep the canonical, offline, no-telemetry discipline from eroding across a multi-year codebase.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · See also **[Engineering Philosophy & Principles](./00-overview.md)** · **[State Management with Riverpod](./02-state-management.md)** · **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)** · Product context in **[Product Overview](../overview.md)**.

## Decision

Car and Pain is a **feature-first modular monolith on a native Dart Pub Workspace**: one runnable app package holding ~25 feature **folders**, plus a small set (5) of foundational internal packages — `core`, `data`, `notifications`, `l10n`, `design_system`. We follow Flutter's official **MVVM** layering (a UI layer + a data layer), and add a **domain/use-case layer only where logic spans multiple repositories** (TCO, projection, analytics, scheduler). Pub Workspaces (needs Dart 3.6+; pin the verified current-stable Flutter/Dart at kickoff) give the single lockfile, unified analyzer, and `resolution: workspace` linking; **Melos is layered on top only for script-running and change-based CI** — it is a convenience, not the foundation. Boundaries are used **surgically**: extract to a package only where a compile-time wall is load-bearing (canonical units/money, all DB/backup access, the notification engine, i18n), and keep everything else a folder so day-to-day iteration stays fast.

## Why

The animating fact is data custody: the user's hand-entered history exists nowhere else, there is no server to re-sync from, and no telemetry to tell us when something broke. That makes **correctness and durability** worth spending architecture on, and it makes **eroded discipline** — a widget doing raw unit math, a feature reaching into another feature's tables — the real long-term risk. Package boundaries buy exactly one thing that folders and convention cannot: the compiler refuses the import. We spend that scarce enforcement where divergence would be catastrophic (canonical units/money, DB access, the scheduler, i18n) and nowhere it would just be ceremony.

Alternatives considered and rejected:

- **Flat single app package (feature folders only, no packages).** Lowest ceremony and a fine *organizing principle* — we keep it *inside* the app. But on its own it gives no compile-time wall, so the canonical-units and offline-data disciplines rest purely on reviewer vigilance across ~25 modules. Rejected as the *whole* answer; adopted as the feature layout.
- **Layer-first global folders** (`data/`, `domain/`, `presentation/` at the top, features nested inside each). Does not scale to 25 features: one feature's change smears across every top-level folder and deleting a feature is error-prone. Rejected.
- **25 separate feature packages (full Melos monorepo).** Hard walls between every feature, but ~25 pubspecs, version/dependency churn, and slow cross-package `freezed`/`drift`/`riverpod` codegen — pure overhead for a buy-once indie app with no publishing need and co-evolving features. Rejected as the default; packages are reserved for the 5 stable cross-cutting concerns.
- **Dogmatic Clean Architecture** (per-screen interface + impl + mapper + use-case everywhere). Maximal decoupling, but boilerplate tax on the many simple CRUD modules; Flutter's own guide marks the domain layer *optional, add-when-needed*. Adopted selectively (repositories, domain models, use-cases for genuinely cross-repository logic) — not per screen.

## How we do it

### Workspace layout

```text
car-and-pain/
├── pubspec.yaml                 # workspace: [apps/car_and_pain, packages/*]
├── melos.yaml                   # scripts + change-based CI only (optional layer)
├── .fvmrc                       # pinned, verified current-stable SDK
├── build.yaml                   # shared build_runner config (drift/freezed/riverpod/gen-l10n)
├── analysis_options.yaml        # includes very_good_analysis + custom_lint
├── pubspec.lock                 # ONE shared lockfile at the root
│
├── apps/
│   └── car_and_pain/            # the runnable Flutter app shell
│       ├── pubspec.yaml         # resolution: workspace
│       └── lib/
│           ├── main_dev.dart    # flavor entrypoint → bootstrap()
│           ├── main_prod.dart   # flavor entrypoint → bootstrap()
│           └── src/
│               ├── bootstrap.dart      # composition root (see below)
│               ├── routing/            # the single GoRouter
│               └── features/           # ~25 feature FOLDERS
│                   ├── 01-vehicles-garage/
│                   ├── 02-fuel-energy/
│                   ├── 03-service-maintenance/
│                   ├── 04-reminders-notifications/
│                   ├── 05-expenses-tco/
│                   │   ...
│                   ├── 24-permissions-onboarding/
│                   └── 25-onboarding-help/
│
└── packages/
    ├── core/            # pure Dart: value objects, engines, Result/Failure, Clock port
    ├── data/            # encrypted Drift DB, DAOs, repositories, backup/export engine
    ├── notifications/   # NotificationGateway port + pure ReminderScheduler
    ├── l10n/            # gen-l10n ARB, calendars, numerals, bidi, fonts
    └── design_system/   # theme + Directional-only widgets + chart Semantics
```

### Anatomy of a feature folder

```text
features/02-fuel-energy/
├── presentation/
│   ├── view/                    # dumb widgets: layout, show/hide, route-by-ID
│   └── fuel_notifier.dart       # Riverpod @riverpod Notifier = the ViewModel
├── application/                 # feature-local use-cases/services (thin)
├── domain/                      # feature-local models (freezed)
└── data/                        # usually ABSENT — reads shared repos from packages/data
```

Most features are **presentation + application only**, reading shared repositories from the `data` package. MVVM per feature: a dumb `View` observes a `Notifier` (state + commands); the `Notifier` calls repositories/use-cases; widgets hold no business or conversion logic.

### What each package owns (and why it earned a wall)

| Package | Owns | Why a package, not a folder |
| --- | --- | --- |
| `core` | Canonical value objects (`Distance`, `Volume`, `Money` w/ ISO-4217 exponent, `EngineHours`) + conversion math; sealed `Result<T,F>` + `Failure` hierarchy; the `Clock` port; pure engines (`TcoCalculator`, `UsageProjector`, economy, next-due, analytics, FX). **Zero Flutter/plugin/IO deps.** | Canonical-units + business rules are the crown jewel; a compile wall stops any widget doing raw unit math or a float amount. |
| `data` | The encrypted Drift DB (SQLCipher default), per-feature `@DriftAccessor` DAOs, index plan, forward-only migrations + pre-migration snapshot, the shared odometer/engine-hour ledger + rollup tables, repositories exposing scoped `.watch()` streams, attachments pipeline, backup/export/recovery engine. | Backup needs read access across **every** table — a data-layer concern, never per-feature. One owner for the source of truth. |
| `notifications` | `NotificationGateway` port (real + fake), the pure clock-injected `ReminderScheduler` (wall-clock recurrence, iOS-64-cap budgeting, deterministic IDs, idempotent reconcile), per-platform boot/exact-alarm handling, isolate-safe factories. | The 64-pending budget and reschedule-on-boot logic must have one testable owner. |
| `l10n` | gen-l10n ARB (en/de/fr/fa/ar/ckb), calendar projection (Gregorian/Jalali/Hijri), numeral + decimal/grouping format & **parse**, bidi-isolation helpers, bundled Vazirmatn/Noto fonts, ckb fallback delegate. | i18n is used everywhere; features must never reimplement any of it. |
| `design_system` | Theme + RTL-aware **Directional-only** widgets, `Icons.adaptive.*` usage, `Semantics`-annotated chart wrappers, accessible lock UI, large-text-scale-safe layouts. | Named public API beats a `shared/` dumping ground; centralizes RTL geometry. |

### The dependency DAG

```text
design_system ─┐
               ├──► apps/car_and_pain (features + routing + bootstrap)
l10n ──────────┤
notifications ─┤        notifications ──► core
data ──────────┤        data          ──► core
core ──────────┘        design_system ──► core, l10n
```

`core` sits at the bottom and depends on nothing internal. Feature folders **never import another feature** — they share via `core`/`data` or navigate by ID. The graph must remain acyclic.

### Barrel-file public APIs

Each package exposes a narrow surface; internals stay unreachable.

```dart
// packages/core/lib/core.dart  — the ONLY entry point consumers import.
export 'src/units/distance.dart' show Distance;
export 'src/money/money.dart' show Money, Currency;
export 'src/result/result.dart' show Result, Ok, Err, Failure, DbFailure /* ... */;
export 'src/time/clock.dart' show Clock;
export 'src/engines/tco_calculator.dart' show TcoCalculator;
// NOTE: src/ is private-by-convention; nothing else is exported.
```

```yaml
# packages/core/pubspec.yaml
name: core
environment: { sdk: ^3.6.0 }
resolution: workspace          # REQUIRED on every member
# no flutter dependency — core is pure Dart
```

### Composition root (`bootstrap.dart`)

```dart
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final tzName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(tzName));

  // Read + unwrap the RECOVERABLE key on the main isolate, then open the DB.
  final key = await KeyStore.readAndUnwrap();          // passphrase/recovery-code aware
  final db  = await openEncryptedDatabase(key);         // cipher asserted, header-checked

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),      // placeholder → real
        flavorProvider.overrideWithValue(flavor),
      ],
      child: const CarAndPainApp(),
    ),
  );
}
```

The same infra is reachable from background isolates through **plain top-level factory functions** (no `ProviderScope`) — see [Dependency Injection & Composition Root](./04-dependency-injection.md).

### Boundary enforcement (three checks)

```yaml
# analysis_options.yaml
include: package:very_good_analysis/analysis_options.yaml
analyzer:
  plugins: [custom_lint]      # repo rules: no cross-feature import, no Drift class in UI
```

```bash
# CI grep: reject non-Directional geometry in feature/design code.
! grep -rnE 'EdgeInsets\.only\((top:.*)?(left|right):|Alignment\.(center|top|bottom)(Left|Right)|Positioned\((left|right):|TextAlign\.(left|right)' \
    apps/car_and_pain/lib packages/design_system/lib
```

```dart
// CI test (blocking): prove at-rest encryption is real.
final header = File(dbPath).openSync().readSync(16);
expect(utf8.decode(header, allowMalformed: true),
    isNot(startsWith('SQLite format 3')));   // plaintext DB fails the build
```

## Rules

- **Every member pubspec sets `resolution: workspace`** and shares compatible SDK constraints. One `pubspec.lock` lives at the root; do not add per-package lockfiles.
- **Features are folders, foundations are packages.** Promote to a package only for a truly cross-cutting concern with a stable, narrow API. New feature = new folder under `features/`, never a new package.
- **A feature folder never imports another feature folder.** Interact through `core`/`data` or navigate by route ID. `custom_lint` enforces this.
- **Never leak Drift-generated row/companion classes into ViewModels or widgets.** Repositories map DB rows → domain models at the boundary.
- **No unit math or numeral/calendar formatting inside widgets.** Conversions live in `core`; formatting/parsing lives in `l10n`. Widgets receive value objects.
- **All packages export through a single barrel** (`export 'src/...' show ...`); `src/` is private by convention. Do not import a package's `src/` path directly.
- **Business logic is pure Dart injected with a `Clock`.** No Flutter/plugin/IO in `core`; providers only wire.
- **Add a domain/use-case layer only when logic spans multiple repositories** (TCO, projection, analytics, scheduler) — Flutter's stated trigger. No use-case on trivial CRUD.
- **`build_runner` runs at the workspace root** so `drift`/`freezed`/`riverpod`/`gen-l10n` regenerate together; generated files are gitignored and regenerated as the first CI step.
- **CI is blocking on:** `dart format --set-exit-if-changed`, `flutter analyze`, the Directional-geometry grep, and the DB-header not-plaintext assertion.

## For Car and Pain specifically

- **Offline-first reshapes the data layer.** There is no HTTP tier; the `data` package's "services" wrap the encrypted SQLite DB, the filesystem (backup/import), and platform channels (notifications, exact alarms, `BOOT_COMPLETED`). Repositories over Drift are the single source of truth and expose reactive `.watch()` streams — see [Local Database, Schema, Indexing & Migrations](./03-data-persistence.md).
- **Canonical storage is a package wall, not a guideline.** `core` is the one home for `Distance`/`Volume`/`Money`/`EngineHours` and their conversions, so distance, volume, currency (integer minor units keyed to the real ISO-4217 exponent), and engine time are stored canonically and converted only at the presentation edge — see [Money, Currency, Units & FX](./14-money-currency-fx.md) and the [Canonical Data Model](../reference/data-model.md).
- **The notification engine has exactly one owner.** The `notifications` package holds the pure `ReminderScheduler`, so the iOS 64-pending budget, wall-clock recurrence, and reboot re-arm are reasoned about and tested in one place — see [Local Notifications & Background Reliability](./07-notifications.md) and the product spec [Reminders & Notifications (product)](../features/04-reminders-notifications.md).
- **Backup is a `data`-package citizen** because it reads across every table; it is never per-feature — see [Backup, Export & Disaster Recovery](./13-backup-export-recovery.md) and [Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md).
- **No-telemetry simplifies the composition root.** There is no auth/sync/analytics-upload module to design around; DI wiring is purely local, and a CI lockfile scan (plus omitted `INTERNET` permission on the offline flavor) enforces the claim.
- **RTL/i18n lives in `l10n` + `design_system`.** Full RTL (fa/ar/ckb) and LTR (en/de/fr), Jalali/Hijri/Gregorian, and Eastern-Arabic/Persian numerals are foundational — features never reimplement them. See [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md) and [Localization, RTL & Calendars (product)](../features/19-localization-rtl.md).

## Testing

The packaged structure makes each layer independently testable — the point of the whole design.

- **`core` engines** — exhaustive, table-driven unit tests at 100% with an injected `Clock` (`package:clock`) + `fake_async`. Conversions get round-trip properties (convert-and-back is lossless within tolerance) and boundary/rounding goldens; this is the highest-value suite in the app.
- **Repositories (`data`)** — run against a real in-memory Drift engine (`NativeDatabase.memory()`); no encryption/platform channels needed for logic. Add a scoped-`.watch()`/rollup recompute test and an index/query-plan check.
- **Use-cases** (TCO, projection, analytics) — unit-test with fake repositories and the fake clock; freezed value objects give free equality.
- **Scheduler (`notifications`)** — pure unit tests with a fake clock, timezone fixtures, and a `FakeNotificationGateway`: verify the 64-cap budgeting, idempotent reconcile diff, and reboot-reschedule computation off-device.
- **Notifiers/ViewModels** — headless via Riverpod `ProviderContainer` with DB/repository overrides (`NativeDatabase.memory()`), no widget pump.
- **Boundary checks are tests too** — the Directional-geometry grep and DB-header not-plaintext assertion run as blocking CI lanes.
- **Golden/RTL** — trimmed matrix (i18n primitives + representative screens across locale × direction × calendar × numeral, sampled elsewhere) with large-text-scale and RTL-overflow as explicit dimensions — see [Testing Strategy](./11-testing.md).

Use `mocktail` (no codegen) and **prefer fakes over mocks**. 100% coverage is enforced only on the logic packages.

## Pitfalls

- **Over-modularization.** Do not create 25 feature packages — it multiplies pubspecs, version churn, and cross-package codegen time for zero benefit. Reserve packages for the 5 stable cross-cutting concerns.
- **Leaking Drift classes into UI.** A schema migration then ripples into every ViewModel and widget, and tests turn brittle. Map to domain models at the repository boundary.
- **Scattering conversion/formatting in widgets** — the #1 way canonical discipline erodes. Centralize in `core` (conversions) and `l10n` (formatting/parsing).
- **Cross-feature imports creating cycles.** Enforce with `custom_lint`; share via `core`/`data` or navigate by ID.
- **A `shared/`/`common/` dumping ground.** Promote deliberately to a *named* package with a public API instead.
- **Embedding notification/backup/TCO logic in a feature.** Reboot/Doze rescheduling, the iOS 64-cap, and whole-DB export need a single central owner to reason about and test.
- **Pub Workspace setup gotchas.** A member missing `resolution: workspace`, or incompatible SDK constraints, silently breaks resolution. There is one root `pubspec.lock`.
- **Cross-package codegen drift.** Run `build_runner` at the root (or a Melos `build` script) so all packages regenerate together; stale generated code across packages is a classic time sink.
- **Naming collisions with SDK types.** Avoid a `widgets/` folder; use `design_system`. Keep conventions consistent (`HomeScreen`, `HomeNotifier`, `VehicleRepository`, `AppDatabase`).

## Decisions to confirm

- **Riverpod vs. the developer's existing Bloc muscle memory.** The recommendation is Riverpod 3.x; Cubit-heavy Bloc is a defensible second choice that shapes all 25 modules. Confirm existing expertise before locking this in at kickoff — see [State Management with Riverpod](./02-state-management.md).
- **Household peer-to-peer sync out of MVP?** The schema (UUIDv7 + tombstones + `updated_at` + `row_revision`) is designed to enable it later. Confirm it is OUT of MVP, because if in-scope it changes the merge/conflict design and the backup + notification-reconcile work must account for it.
- **Pin verified current-stable SDK and package majors at kickoff** (Flutter/Dart, `flutter_local_notifications`, `go_router`, `drift`) rather than the speculative numbers in the draft; confirm no dependency pulls a plaintext `sqlite3` library that wins the native link.

## Related

- **[Engineering Philosophy & Principles](./00-overview.md)** — the data-custody thesis these boundaries serve.
- **[State Management with Riverpod](./02-state-management.md)** — how Notifiers/providers wire the layers.
- **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)** — the `data` package internals.
- **[Dependency Injection & Composition Root](./04-dependency-injection.md)** — bootstrap and isolate-safe factories.
- **[Build, Tooling, Release & CI/CD](./12-build-ci-release.md)** — Melos, workspaces, lint, and the boundary CI lanes.
- **[Canonical Data Model](../reference/data-model.md)** — the tables the `data` package and rollups are built on.
