# 🧭 Engineering Philosophy & Principles

> Car and Pain is a data-custody product wearing a car app's clothes. There is no server, no account, and no telemetry — so we engineer for correctness, durability, and reboot/Doze survival before feature velocity or cleverness.

This is the contract every other document in this guide elaborates. If a decision elsewhere seems to add friction, it is almost always paying down one of the risks named here: irreplaceable user data, a lost encryption key, a mis-fired reminder, or a silent no-telemetry violation. Read this first; then read [the README index](./README.md) for the map.

---

## Philosophy

The user's years of hand-entered fuel logs, service records, VINs, plates, and insurance numbers exist **nowhere else**. There is no backend to re-sync from and no crash SaaS to tell us when something broke on a device we will never see. That single fact is the axis every engineering trade-off turns on: we optimize for the survival and integrity of that data over shipping speed or elegance. When in doubt, the answer is whatever makes a record impossible to lose, a reminder impossible to silently drop, and a key impossible to strand.

Two durability lessons are load-bearing and must never be softened into "nice to have." First, **encrypting the database is worthless if the key is lost**, so the master key is *recoverable by default* — wrapped by a user passphrase or backed by a one-time recovery code issued at first run. "Key only in secure storage" is the *risky* mode, not the default, because Keystore/Keychain loss after OEM OS updates, biometric re-enrollment, or a device restore is well documented on exactly the low-end Android hardware our audience carries. Second, **the encrypted DB is not the backup** — a proactive, verified, local backup subsystem is the app's real disaster-recovery guarantee, and it is a first-class v1 deliverable, not a menu item.

Because there is no HTTP tier, the classic Flutter layering **inverts**: "services" wrap the encrypted SQLite database, the filesystem (backup/import), platform channels (notifications, exact alarms, boot receivers), and pure compute (TCO, projections, calendars) — never a network. We store everything **canonically** and convert only at the presentation boundary, with one distinction the naive design blurs: true instants (a fuel purchase) are UTC epoch millis, but civil/recurring schedules ("remind at 09:00 every 6 months") are stored as **local wall-clock + recurrence rule + calendar** and resolved to a `TZDateTime` only at (re)schedule time, so DST and timezone changes can never silently shift a reminder. Money is integer minor units keyed to each currency's real ISO-4217 exponent — never a hardcoded two decimals, never a float. All business rules live in pure, Flutter-free Dart injected with a `Clock` and are exhaustively unit-tested. The mental model is a **reactive graph**: encrypted DB → scoped Drift `.watch()` streams backed by pre-aggregated rollup tables → derived analytics/TCO providers → UI, with side-effects (backup, import, notification scheduling) modeled as framework-agnostic services callable from both the widget tree and background isolates.

---

## Core principles

1. **Store canonical, convert at the edge — and distinguish instants from wall-clock.** True instants are UTC epoch millis; recurring schedules are local wall-clock + recurrence rule + calendar resolved to a `TZDateTime` at (re)schedule time so DST/timezone changes cannot shift them. Distance in metres, volume in millilitres, engine time in whole minutes, money in ISO-4217 minor units. Conversion and formatting live only in the core and l10n packages; widgets receive value objects.
2. **The encrypted DB is the single source of truth.** The OS pending-notification set and any provider memory are disposable caches reconstructed from it. After process death, reboot, Doze, or restore, everything rebuilds from the database alone.
3. **Durability = a recoverable key + a proactive, verified backup — not the encryption itself.** The master key is passphrase-wrapped or recovery-code-backed by default; scheduled auto-backup, "last backup N days ago" nagging, and an un-skippable passphrase-loss warning are first-class v1 subsystems, because with no cloud and no account they are the only defense against device loss.
4. **Business logic is pure Dart with zero Flutter/plugin/IO dependencies.** TCO, economy, projections, next-due, calendars, numerals, currency, and backup serialization are plain functions injected with a `Clock`; providers only wire them. This is the highest-leverage testability decision in the app.
5. **Never block an entry and never lose one.** Transactional multi-table writes (WAL), debounced draft autosave, soft-delete + Trash + Undo (a shared query layer filters `is_deleted` from *every* read including analytics), forward-only migrations guarded by a mandatory pre-migration snapshot, and backups via `VACUUM INTO` after a WAL checkpoint — verified by re-opening before success is reported.
6. **Distance and engine-hour reminders are not a separate mechanism.** A pure, clock-injected `UsageProjector` converts each to a concrete future *time* instant via a rolling usage-rate model with a min-samples guard, and explicitly falls back to time-only or refuses to schedule when data is insufficient or the projection lands beyond the pending-window horizon. One homogeneous, testable scheduling path.
7. **Geometry is Directional-only from module #1.** `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`, `Icons.adaptive.*`. A CI grep / custom_lint rejects `EdgeInsets.only(left/right)`, `Alignment.centerLeft`, `Positioned(left:)`, and `TextAlign.left/right` in feature code.
8. **Errors are typed values at every boundary, not thrown strings.** Repositories and use-cases return a Dart 3 sealed `Result<T,F>` carrying a sealed `Failure` hierarchy (stable code + typed params, never user-facing text); the UI switches exhaustively and localizes. Exceptions are reserved for bugs and funneled to a *local* rotating log — never a crash SaaS.
9. **No-telemetry is enforced, not promised.** A CI lockfile scan fails the build if any analytics/crash SDK appears; the offline flavor omits the `INTERNET` permission so the OS enforces the claim; iOS ships `PrivacyInfo.xcprivacy` and the Play Data-Safety form declares no collection.
10. **Background isolates get no `ProviderScope`.** All infrastructure (open encrypted DB, read the key from secure storage on the main isolate then pass it in, build the scheduler) is constructed by plain top-level factory functions that both the app and a fresh in-isolate container can call. Baked in from day one.
11. **Golden tests are the RTL/i18n safety net — scoped to stay maintainable.** Golden the i18n primitives (numerals, calendars, bidi, mirroring) and a few representative screens *exhaustively* across locale × direction × calendar × numeral; sample the rest. Large text-scale (1.5–2×) and RTL overflow are explicit dimensions. A CI Ahem lane catches mirroring; a narrow real-font lane catches Persian/Arabic shaping.
12. **Heavy compute never runs on the UI thread.** TCO/economy/statistics read from pre-aggregated rollup tables updated on ledger writes, are scoped by vehicle + time window, and recompute via `Isolate.run` keyed off a revision counter; encrypted-DB queries run on Drift's background isolate. Memoize computed and formatted values; recompute only when underlying rows change.
13. **Accessibility and dynamic type are first-class from the start.** `Semantics` on custom charts, correct TalkBack/VoiceOver behavior with RTL and Eastern-Arabic/Persian numerals, mirrored focus order, an accessible biometric/PIN lock, and verified WCAG-AA contrast in both themes.
14. **Reboot/Doze/OEM-battery-killer survival cannot be honestly green-lit by emulators.** Foreground reconcile is the *one* guaranteed delivery path; everything else is best-effort. Survival is a documented manual real-device QA matrix (Xiaomi/MIUI, Samsung, Huawei, Oppo) plus a guided battery-optimization/permission onboarding flow, and Impeller is validated on low-end OEM hardware in week one — not at the end.

---

## Stack decisions at a glance

Every row is the *default*, chosen for a buy-once, offline, multi-year commercial codebase. Follow the linked topic doc for the full rationale, rejected alternatives, and enforcement rules.

| Area | Decision | Why (short) |
| --- | --- | --- |
| [Architecture & module structure](./01-architecture-and-structure.md) | Feature-first modular monolith on a native Dart Pub Workspace: one runnable app package with ~25 feature *folders* + foundational packages (core, data, notifications, l10n, design_system); Melos only for scripts/CI. | Folders keep iteration fast; extracting only cross-cutting concerns gives compile-time boundary enforcement exactly where discipline is load-bearing. |
| [State management](./02-state-management.md) | Riverpod 3.x + codegen (`@riverpod`) + riverpod_lint + Freezed; Drift `.watch()` in stream providers; **stable** `AsyncNotifier` for backup/import/restore (Mutation API is optional sugar only). | No network means the local DB is the reactive heart; `.watch()` maps 1:1 onto stream providers and DI works without `BuildContext` for out-of-tree engines. |
| [Local database, schema & migrations](./03-data-persistence.md) | Drift over encrypted SQLite; **SQLCipher default** unless a week-one spike proves `sqlite3mc` build-hooks link/encrypt on real iOS *and* Android. Per-feature DAOs, UUIDv7 PKs, forward-only transactional migrations + pre-migration snapshot. | Deeply relational data fights NoSQL; pinning at-rest encryption to an experimental toolchain is the single most dangerous bet, so the proven library is the default. |
| [Canonical storage & recompute at scale](./10-performance-rendering.md) | Repositories enforce the canonical contract; the shared odometer/engine-hour ledger feeds revision-keyed rollup tables written in the same transaction; scoped `.watch()` + `Isolate.run` recompute the affected slice only. | A ledger written by ~6 modules over years is the likeliest jank/battery hotspot; pre-aggregation collapses recompute to O(changed window). |
| [Dependency injection](./04-dependency-injection.md) | Riverpod as the single mechanism for DI *and* state; async infra injected via placeholder root providers overridden at `main()`; isolates build infra through plain factory functions into a throwaway container. | Context-free DI reaches repositories/engines from notification callbacks and background isolates; decentralized providers avoid a merge-conflict god-object. |
| [Navigation & routing](./05-navigation.md) | go_router (first-party) + `go_router_builder`, `StatefulShellRoute.indexedStack` for ~6 tabs, `rootNavigatorKey` for full-screen flows, declarative redirect guards, `restorationScopeId` end-to-end. | First-party longevity is decisive; notifications are the real deep links, so a pure payload→location mapper rebuilds screens from the DB alone. |
| [i18n / RTL / calendars / numerals](./06-i18n-rtl-calendars.md) | Built-in gen-l10n (ARB, `generate:true`); app-controlled locale in the encrypted DB; Jalali via `shamsi_date`, Hijri via `hijri`; Eastern digits via `NumberFormat`, all numeric input normalized to ASCII (including `٫`/`٬`) before math; Vazirmatn + Noto bundled. | Compile-time safety and zero runtime/network dependency beat runtime loaders; `google_fonts` is disqualified for fetching over the network. |
| [Local notifications & background reliability](./07-notifications.md) | ONE engine on `flutter_local_notifications` `zonedSchedule`; DB is source of truth, OS pending-set is a reconciled cache; wall-clock recurrence; `UsageProjector` for distance/engine-hour; Android `inexactAllowWhileIdle` default, exact behind a toggle; per-platform boot re-arm. | No FCM allowed, so foreground reconcile *is* the reliability backbone; one time-scheduling path stays testable off-device. |
| [Backup, export & disaster recovery](./13-backup-export-recovery.md) | First-class v1 subsystem: `VACUUM INTO` after a WAL checkpoint → AES-GCM (Argon2id-derived key) → atomic rename → verify-by-reopen; mandatory pre-import snapshot; auto-backup + nagging + passphrase-loss warning; sanitized CSV (formula-injection + BOM). | With no cloud, backups are the only defense against device loss; a raw copy of a live WAL file yields corrupt, unrestorable backups. |
| [Money, currency & FX](./14-money-currency-fx.md) | Integer minor units keyed to real ISO-4217 exponents (0 IRR/JPY, 2 USD/EUR, 3 KWD/BHD/OMR) + ISO code; explicit Rial/Toman display; FX is user-entered, dated, staleness-flagged. | A hardcoded 2-decimal assumption corrupts amounts for exactly the MENA/Iranian audience; an offline app cannot fetch live rates. |
| [Error handling & functional patterns](./08-error-handling.md) | Sealed `Result<T,F>` over a sealed `Failure` hierarchy at every boundary (codes not strings); exceptions reserved for bugs, caught globally and routed to a local rotating log; fpdart selectively for form validation. | No server/telemetry means error handling protects irreplaceable records; exhaustive switches force the UI to handle every failure and localize it. |
| [Security & privacy architecture](./09-security-privacy.md) | Whole-DB AES-256 at rest; a **recoverable-by-default** 256-bit master key (passphrase KEK via native Argon2id and/or recovery code); app-lock via `local_auth` (in a `FragmentActivity`) + PIN escape; per-file attachment encryption; no-telemetry enforced by CI. | Highly sensitive PII justifies full-DB encryption, but "key only in secure storage" is an existential single point of failure on our target OEMs. |
| [Accessibility & dynamic type](./15-accessibility-dynamic-type.md) | `Semantics` on all custom charts/tiles, correct RTL + Eastern-numeral screen-reader reading, mirrored focus order, accessible lock flow, WCAG-AA in both themes, layouts survive `textScaler` 1.5–2×. | The RTL + tall-glyph + Eastern-numeral combination is where screen readers and text scaling actually break — invisible to the emulator default locale. |
| [Permissions, onboarding & OEM survival](./16-permissions-onboarding-oem.md) | Guided onboarding (via `permission_handler`): notification + optional exact-alarm rationale, battery-optimization exemption, OEM autostart deep links; honest "foreground reconcile is the one guaranteed path". | OEM battery-killers silently kill background alarms; guiding the user to exempt the app is the only durable software mitigation. |
| [Testing strategy](./11-testing.md) | Logic-heavy "diamond-topped pyramid": 100% table-driven unit tests on pure engines (injected `Clock` + `fake_async`); in-memory Drift + keyed-encryption + forced-mid-migration suites; flagship export→wipe→import round-trip with WAL active; trimmed golden matrix; `mocktail`, fake over mock. | The app's value is in its compute engines, so keeping them pure and deterministic is the highest-leverage testing decision. |
| [Build, tooling, release & CI/CD](./12-build-ci-release.md) | Melos on native pub workspaces; `very_good_analysis`; FVM-pinned SDK + committed lockfiles; exactly two flavors (dev/prod) for install isolation + distinct notification channels; GitHub Actions (fast Ubuntu PR + macOS release); `--obfuscate --split-debug-info`. | No server to hotfix makes reproducibility high-stakes; flavors are install isolation, not endpoints; archived symbols are the only crash-symbolication path. |
| [Store compliance, privacy declarations & licensing](./17-store-compliance-licensing.md) | Launch-blocking: Play Data-Safety + iOS privacy label both declaring no collection, RTL screenshots + six-language listings, in-app OSS + font-license (Vazirmatn/Noto OFL) attributions. | `PrivacyInfo.xcprivacy` alone satisfies neither store; a declaration mismatch is a rejection/removal risk; OFL/package licenses legally require attribution. |

---

## Module & folder structure

A **feature-first modular monolith on a native Dart Pub Workspace**: one runnable app shell holding ~25 feature *folders*, plus foundational internal packages that carry the concerns that must never diverge. Feature folders never import each other (they share via `core`/`data` or navigate by ID); the dependency graph is a strict DAG.

```text
workspace root
├── pubspec.yaml              # workspace members
├── melos.yaml                # script running + change-based CI only
├── .fvmrc                    # verified current-stable SDK, pinned at kickoff
├── build.yaml                # workspace-root build_runner (drift/freezed/riverpod/gen-l10n)
├── analysis_options.yaml     # includes very_good_analysis + custom_lint
├── pubspec.lock              # one root lockfile; every member sets resolution: workspace
│
├── apps/car_and_pain/                       # runnable Flutter app shell
│   └── lib/src/
│       ├── main_dev.dart / main_prod.dart   # two entrypoints → shared bootstrap
│       ├── bootstrap.dart                   # composition root: unwrap recoverable
│       │                                    #   DB key (main isolate), open encrypted
│       │                                    #   DB (cipher asserted + header-checked),
│       │                                    #   override placeholder providers, init tz,
│       │                                    #   wire notification cold-start
│       ├── routing/                         # the single GoRouter (indexedStack shell,
│       │                                    #   typed routes, guards, payload→location)
│       └── features/                        # ~25 folders, e.g.
│           ├── 01-vehicles-garage/
│           ├── 02-fuel-energy/
│           ├── 03-service-maintenance/
│           ├── 04-reminders-notifications/
│           ├── 05-expenses-tco/
│           │   ├── presentation/{view, expenses_notifier}
│           │   ├── application/<use_cases>   # only where logic spans repos
│           │   ├── domain/<feature-local models>
│           │   └── data/<thin/absent local repo>
│           └── … 24-permissions-onboarding, 25-onboarding-help
│
└── packages/
    ├── core/           # PURE Dart, zero Flutter/plugin/IO deps: value objects
    │                   #   (Distance, Volume, Money w/ ISO-4217 exponent, EngineHours) +
    │                   #   conversion math, sealed Result<T,F> + Failure, the Clock port,
    │                   #   and the engines (TcoCalculator, UsageProjector, economy,
    │                   #   next-due, analytics, currency/FX with dated staleness)
    ├── data/           # encrypted Drift DB (SQLCipher default), per-feature @DriftAccessor
    │                   #   DAOs, index plan, forward-only migrations + pre-migration
    │                   #   snapshot, the shared odometer/engine-hour ledger + rollup tables
    │                   #   (revision-keyed), scoped .watch() repositories, attachments
    │                   #   pipeline (hash-plaintext / per-file AES-GCM + refcount GC),
    │                   #   backup/export/recovery engine (VACUUM INTO, verify-by-reopen)
    ├── notifications/  # NotificationGateway port (real + fake), pure clock-injected
    │                   #   ReminderScheduler (wall-clock recurrence, iOS-64-cap budgeting,
    │                   #   deterministic IDs, idempotent reconcile, clock-tamper guard),
    │                   #   per-platform boot/exact-alarm handling, isolate-safe factories
    ├── l10n/           # gen-l10n ARB (en/de/fr/fa/ar/ckb), calendar projection
    │                   #   (Gregorian/Jalali/Hijri), numeral + decimal/grouping
    │                   #   format/parse, bidi-isolation helpers, bundled fonts, ckb delegate
    └── design_system/  # theme + RTL-aware Directional-only widgets, Icons.adaptive,
                        #   Semantics-annotated chart wrappers, accessible lock UI,
                        #   large-text-scale-safe layouts
```

Packages expose narrow public APIs via barrel files; the app shell is thin. Only truly cross-cutting concerns are promoted to packages — canonical units/money (`core`), all DB/backup access (`data`), the notification engine, and i18n — because those are the parts where a per-feature divergence would be a data-integrity or reliability bug. Everything else stays a folder to keep iteration fast. CI enforces the boundaries with `custom_lint`, a non-Directional-geometry grep, and a blocking DB-header (not-plaintext) assertion. See [Architecture & Module Structure](./01-architecture-and-structure.md) for what earns promotion to a package and when to add a domain/use-case layer.

---

## Testing posture

The app's value is in its **compute engines**, so we push almost all correctness into pure, Flutter-free Dart and cover it exhaustively — a **logic-heavy "diamond-topped pyramid"** rather than a UI-heavy pyramid.

- **Pure engines at 100%.** Table-driven unit tests for TCO, economy (partial/full/missed/first-fill), projection *including* its usage-rate estimation, min-samples guard, and insufficient-data/beyond-window fallback, next-due, calendar conversions, numeral + `٫`/`٬` separator round-trips, currency exponents + Rial/Toman + dated-FX staleness, and the scheduler (wall-clock recurrence resolved across a DST boundary, iOS-64-cap window, idempotent reconcile, clock-tamper detection via a monotonic guard). All driven with injected `Clock` (`package:clock`) + `fake_async` + timezone fixtures + a `FakeNotificationGateway`.
- **Data layer.** Real in-memory Drift with an index/query-plan check and a scoped-`.watch()`/rollup recompute test; migration tests on a realistically large seeded DB **including a forced mid-migration failure** that must restore the pre-migration snapshot; one keyed-encryption suite proving the raw file header is **not** `SQLite format 3`; attachment orphan-blob GC + shared-blob refcount tests.
- **Flagship blocking CI tests.** Export→wipe→import→deep-equal with **WAL active** (VACUUM-INTO source, attachment SHA-256 + preserved fill flags) — because a raw-copy backup passes a naive test and fails in the field — plus a CSV formula-injection + Persian-digit/separator round-trip, and a no-telemetry negative test (lockfile scan + zero-outbound assertion).
- **UI & i18n.** A *trimmed* golden matrix — i18n primitives + a few representative screens exhaustively across locale × direction × calendar × numeral, sampled elsewhere — with large-text-scale (1.5–2×) and RTL overflow as explicit dimensions, plus `fl_chart` RTL and chart `Semantics` assertions. Headless Notifier tests via `ProviderContainer`; a few `integration_test` smoke flows + Patrol for native permission/notification surfaces. `mocktail`, fake over mock.
- **Honest gaps.** Reboot/Doze/OEM-battery-killer survival and week-one Impeller-on-low-end validation are a **documented manual real-device matrix** (Xiaomi/MIUI, Samsung, Huawei, Oppo) — never a fabricated automated pass. Coverage is 100%-enforced only on the logic packages and ratchets upward elsewhere.

Full lanes, fixtures, and the golden dimensions live in [Testing Strategy](./11-testing.md).

---

## Open decisions for the owner

These shape all 25 modules and must be confirmed **before or at kickoff** — locking them late means rework across the whole codebase.

1. **State management: Riverpod vs Bloc.** Riverpod is the recommendation, but if the solo developer already has deep `flutter_bloc` muscle memory, Cubit-heavy Bloc is a defensible second choice. Confirm existing expertise before locking this in.
2. **Household P2P sync in or out of MVP.** The schema (UUIDv7 + tombstone + `updated_at` + `row_revision`) is *designed to enable* later peer-to-peer sync. Confirm it is **out** of MVP — if in-scope it changes the merge/conflict design and forces the backup and notification-reconcile work to account for it.
3. **Key-recovery UX default.** Decide the default recovery mechanism — user passphrase that wraps the key, an auto-issued one-time recovery code, or both — and the exact first-run flow, since it is now the app's *primary* durability guarantee, not an opt-in high-security mode.
4. **Argon2id parameters.** Settle the FFI/native library and device-calibrated memory/iteration params (with a defined low-end fallback), benchmarked against the slowest target device so unlock/backup does not take multiple seconds or OOM.
5. **Run the week-one encryption spike and record the decision.** Does drift's `sqlite3mc` build-hook path link and encrypt on real iOS **and** Android, or does v1 ship on `sqlcipher_flutter_libs`? Pin the verified current-stable Flutter/Dart SDK and all load-bearing package majors (`flutter_local_notifications`, `go_router`, `drift`) at that time — not the speculative numbers — and confirm no dependency pulls a plaintext `sqlite3` library that wins the native link.
6. **FX provenance and Rial/Toman UX.** Confirm the user-entered-dated-rate model and the default Rial-vs-Toman display with a representative user before building the money-entry surface.
7. **Asset-bundling and size budget.** The offline map layer (feature 14), bundled datasets (emission zones, schedules, dictionaries), and subsetted Vazirmatn/Noto fonts have significant binary-size implications. Decide the asset-bundling and size-budget strategy separately — it affects build tooling, startup performance, and store download limits.

---

## How to read this guide

- Start at the **[Flutter Engineering Guide — Index](./README.md)** for the reading order and the canonical stack table.
- This document is the **contract**; each row of the table above links to the topic doc that elaborates it. Follow those for full rationale, rejected alternatives, code, and enforcement rules.
- Topic docs, in build order: [Architecture & Module Structure](./01-architecture-and-structure.md) · [State Management with Riverpod](./02-state-management.md) · [Local Database, Schema, Indexing & Migrations](./03-data-persistence.md) · [Dependency Injection & Composition Root](./04-dependency-injection.md) · [Navigation & Routing](./05-navigation.md) · [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md) · [Local Notifications & Background Reliability](./07-notifications.md) · [Error Handling & Never-Lose-Data](./08-error-handling.md) · [Security, Privacy & At-Rest Encryption](./09-security-privacy.md) · [Performance & Rendering](./10-performance-rendering.md) · [Testing Strategy](./11-testing.md) · [Build, Tooling, Release & CI/CD](./12-build-ci-release.md) · [Backup, Export & Disaster Recovery](./13-backup-export-recovery.md) · [Money, Currency, Units & FX](./14-money-currency-fx.md) · [Accessibility & Dynamic Type](./15-accessibility-dynamic-type.md) · [Permissions, Onboarding & OEM Survival](./16-permissions-onboarding-oem.md) · [Store Compliance, Privacy Declarations & Licensing](./17-store-compliance-licensing.md).
- For product context, cross-reference the source-of-truth product docs: [Product Overview](../overview.md), [Canonical Data Model](../reference/data-model.md), [Glossary & Conventions](../reference/glossary.md), [Reminders & Notifications (product)](../features/04-reminders-notifications.md), [Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md), and [Localization, RTL & Calendars (product)](../features/19-localization-rtl.md).
