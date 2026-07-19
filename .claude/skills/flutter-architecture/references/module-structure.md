# Module structure — package vs folder, feature anatomy, the DAG, barrels

Grounds `docs/flutter/01-architecture-and-structure.md` and `docs/flutter/00-overview.md`.

## Workspace layout

```text
car-and-pain/
├── pubspec.yaml                 # workspace: [apps/car_and_pain, packages/*]
├── melos.yaml                   # scripts + change-based CI only (optional layer)
├── .fvmrc                       # pinned, verified current-stable SDK (Dart 3.6+ for workspaces)
├── build.yaml                   # shared build_runner config (drift/freezed/riverpod/gen-l10n)
├── analysis_options.yaml        # very_good_analysis + custom_lint
├── pubspec.lock                 # ONE shared lockfile at the root — no per-package lockfiles
│
├── apps/car_and_pain/           # the runnable Flutter app shell
│   ├── pubspec.yaml             # resolution: workspace
│   └── lib/
│       ├── main_dev.dart        # flavor entrypoint → bootstrap(flavor: Flavor.dev)
│       ├── main_prod.dart       # flavor entrypoint → bootstrap(flavor: Flavor.prod)
│       └── src/
│           ├── bootstrap.dart   # composition root (unwrap key → open DB → override placeholders)
│           ├── routing/         # the single GoRouter
│           └── features/        # ~25 numbered feature FOLDERS
│               ├── 01-vehicles-garage/
│               ├── 02-fuel-energy/
│               ├── 03-service-maintenance/
│               ├── 04-reminders-notifications/
│               ├── 05-expenses-tco/
│               │   ...
│               ├── 24-permissions-onboarding/
│               └── 25-onboarding-help/
│
└── packages/
    ├── core/            # PURE Dart: value objects, engines, Result/Failure, Clock port
    ├── data/            # encrypted Drift DB, DAOs, repositories, backup/export engine
    ├── notifications/   # NotificationGateway port + pure ReminderScheduler + isolate factories
    ├── l10n/            # gen-l10n ARB, calendars, numerals, bidi, bundled fonts
    └── design_system/   # theme + Directional-only widgets + chart Semantics wrappers
```

## What each package owns and why it earned a wall

| Package | Owns | Why a package, not a folder |
| --- | --- | --- |
| `core` | Canonical value objects (`Distance`, `Volume`, `Money` w/ ISO-4217 exponent, `EngineHours`) + conversion math; sealed `Result<T,F>` + `Failure`; the `Clock` port; pure engines (`TcoCalculator`, `UsageProjector`, economy, next-due, analytics, FX). **Zero Flutter/plugin/IO deps.** | Canonical units + business rules are the crown jewel; a compile wall stops any widget doing raw unit math or a float amount. |
| `data` | Encrypted Drift DB (SQLCipher default), per-feature `@DriftAccessor` DAOs, index plan, forward-only migrations + pre-migration snapshot, shared odometer/engine-hour ledger + revision-keyed rollup tables, repositories exposing scoped `.watch()` streams, attachments pipeline, backup/export/recovery engine. | Backup reads across **every** table — a data-layer concern, never per-feature. One owner for the source of truth. |
| `notifications` | `NotificationGateway` port (real + fake), the pure clock-injected `ReminderScheduler` (wall-clock recurrence, iOS-64-cap budgeting, deterministic IDs, idempotent reconcile), per-platform boot/exact-alarm handling, isolate-safe factories. | The 64-pending budget and reschedule-on-boot logic need one testable owner. |
| `l10n` | gen-l10n ARB (en/de/fr/fa/ar/ckb), calendar projection (Gregorian/Jalali/Hijri), numeral + decimal/grouping format **and parse**, bidi-isolation helpers, bundled Vazirmatn/Noto fonts, ckb fallback delegate. | i18n is used everywhere; features must never reimplement any of it. |
| `design_system` | Theme + RTL-aware **Directional-only** widgets, `Icons.adaptive.*`, `Semantics`-annotated chart wrappers, accessible lock UI, large-text-scale-safe layouts. | A named public API beats a `shared/` dumping ground; centralizes RTL geometry. |

## The dependency DAG

```text
design_system ─┐
               ├──► apps/car_and_pain (features + routing + bootstrap)
l10n ──────────┤
notifications ─┤        notifications ──► core
data ──────────┤        data          ──► core
core ──────────┘        design_system ──► core, l10n
```

`core` sits at the bottom and depends on nothing internal. Feature folders never import another
feature — they share via `core`/`data` or navigate by ID. The graph must remain acyclic; a circular
provider dependency throws at runtime.

## Feature-folder anatomy (MVVM per feature)

```text
features/02-fuel-energy/
├── presentation/
│   ├── view/                 # dumb widgets: layout, show/hide, navigate-by-ID
│   └── fuel_notifier.dart    # @riverpod Notifier = the ViewModel (Freezed state)
├── application/              # thin use-cases — ONLY where logic spans repos
├── domain/                   # feature-local Freezed models
└── data/                     # usually ABSENT — reads shared repos from packages/data
```

- Most features are **presentation + application only**.
- A dumb `View` observes a `Notifier` (state + commands); the `Notifier` calls repositories/use-cases.
- Widgets hold no business or conversion logic — they receive value objects.
- Add `domain/` + `application/` use-cases **only when logic spans multiple repositories**
  (TCO, projection, analytics, scheduler). No use-case on trivial CRUD.

## When something earns a package vs a folder

| Situation | Verdict |
| --- | --- |
| A new screen/flow in the product (fuel entry, TCO wizard, onboarding step) | **Folder** under `features/`. |
| Canonical unit/money math, a pure engine, `Result`/`Failure`, the `Clock` port | **`core`**. |
| Any DB table, DAO, repository, migration, rollup, backup/import | **`data`**. |
| Reminder scheduling, the 64-pending budget, boot re-arm | **`notifications`**. |
| ARB strings, a calendar/numeral formatter, bidi helper, bundled font | **`l10n`**. |
| A reusable Directional widget, theme token surface, chart Semantics wrapper | **`design_system`**. |
| "It'd be handy to share this helper between two features" | **Neither a new package nor a cross-feature import** — put it in `core` (pure) or the relevant existing package, or navigate by ID. Never a `shared/` folder, never a sixth package without an ADR. |

Rejected structural alternatives (do not resurrect): flat single package with no walls (no
compile-time enforcement of canonical/offline discipline), layer-first global folders
(`data/`/`domain/`/`presentation/` at the top — smears one feature across everything), 25 feature
packages (pubspec + codegen churn), dogmatic per-screen Clean Architecture (boilerplate tax on
simple CRUD).

## Barrel-file public APIs

```dart
// packages/core/lib/core.dart — the ONLY entry point consumers import.
export 'src/units/distance.dart' show Distance;
export 'src/money/money.dart'    show Money, Currency;
export 'src/result/result.dart'  show Result, Ok, Err, Failure, DbFailure /* … */;
export 'src/time/clock.dart'     show Clock;
export 'src/engines/tco_calculator.dart' show TcoCalculator;
// src/ is private-by-convention; nothing else is exported.
```

```yaml
# packages/core/pubspec.yaml
name: core
environment: { sdk: ^3.6.0 }
resolution: workspace          # REQUIRED on EVERY member
# no flutter dependency — core is pure Dart
```

- Every member pubspec sets `resolution: workspace` and shares compatible SDK constraints.
- Never import a package's `src/` path directly from outside the package.
- `build_runner` runs at the **workspace root** so drift/freezed/riverpod/gen-l10n regenerate
  together; generated files are gitignored and regenerated as the first CI step. See the
  `monorepo-codegen-toolchain` skill.

## Naming

`HomeScreen`, `HomeNotifier`, `VehicleRepository`, `AppDatabase`. Avoid a `widgets/` folder (SDK
collision) — use `design_system`. Feature folders are zero-padded and numbered (`01-…`, `02-…`).
