# F1 · Project scaffold, tooling & app kernel

> Stand up the feature-first modular monolith, tooling, CI/CD and the app kernel (DI graph, sealed error kernel, async bootstrap) that every other epic builds on — built-in-first, minimal-dependency.

## Goal

Establish the runnable skeleton for **Car and Pain** before any feature work begins. This epic delivers:

- A **feature-first modular monolith** on a **native Dart pub workspace** (`resolution: workspace`, Dart 3.6+): one thin runnable app package holding ~25 feature folders, plus foundational internal packages (`core/`, and the shared kernels below), orchestrated with **Melos** scripts.
- A **lint & format baseline** (`very_good_analysis` + a short app-oriented override block) enforced by `flutter analyze` and `dart format --set-exit-if-changed`.
- **Build flavors** (`dev`/`prod`), a pinned verified current-stable Flutter/Dart SDK, and app-id/bundle configuration.
- A **GitHub Actions CI/CD pipeline** running analyze, format-check, tests with coverage, and iOS + Android build artifacts, with dependency/build caching.
- The **Riverpod DI/provider graph**: `keepAlive` infra providers plus placeholder root providers overridden at bootstrap (encrypted DB, secure key store, app dirs, timezone) — Riverpod as the single unified mechanism for both DI and state.
- The **sealed `Result<T,F>` / `Failure` error kernel**: hand-rolled over a Dart 3 sealed `Failure` hierarchy (`DbFailure`/`BackupFailure`/`ImportFailure`/`NotificationFailure`/`ValidationFailure`) with stable codes and typed params — never user-facing strings.
- **App bootstrap**: `runApp` gated on async initialization of the encrypted DB, secure store, app directories and timezone, with explicit error and splash states.
- A **testing harness & coverage gate**, and **store-compliance scaffolding** (`PrivacyInfo.xcprivacy`, omitted-`INTERNET` manifest, Data-Safety / nutrition-label stubs declaring no collection and no tracking).

This is pure foundation: no product feature ships here, but the shape of the entire codebase — module boundaries, error contract, injection strategy, and the offline-first / account-free / no-telemetry posture — is locked in.

## Tier & dependencies

- **Tier:** `foundation`
- **Depends on:** none (this is the root epic; all other epics depend on it, directly or transitively).

## References

- [docs/flutter/00-overview.md](../../flutter/00-overview.md)
- [docs/flutter/01-architecture-and-structure.md](../../flutter/01-architecture-and-structure.md)
- [docs/flutter/02-state-management.md](../../flutter/02-state-management.md)
- [docs/flutter/04-dependency-injection.md](../../flutter/04-dependency-injection.md)
- [docs/flutter/08-error-handling.md](../../flutter/08-error-handling.md)
- [docs/flutter/12-build-ci-release.md](../../flutter/12-build-ci-release.md)
- [docs/flutter/17-store-compliance-licensing.md](../../flutter/17-store-compliance-licensing.md)
- [docs/reference/data-model.md](../../reference/data-model.md)

## Tasks

### F1-T1 · Initialize pub workspace & app shell

**Description.** Create one runnable app package (thin shell) plus the foundational internal packages on a **native Dart pub workspace** (`resolution: workspace`). The app package hosts ~25 **feature folders** (one per module in the roadmap: `vehicles-garage`, `fuel-energy`, `service-maintenance`, … `onboarding-help`), each with a consistent internal layout (`data/`, `domain/`, `application/`, `presentation/`). Extract cross-cutting concerns into foundational packages (e.g. `packages/core` for the Result/Failure kernel, canonical units/money value types, and shared utilities). Wire **Melos** with scripts for `bootstrap`, `analyze`, `format`, `test`, and `build`.

**Acceptance criteria**
- [ ] Root `pubspec.yaml` declares `resolution: workspace` and lists every workspace member.
- [ ] One runnable app package builds and launches to a placeholder screen on iOS and Android.
- [ ] ~25 feature folders scaffolded with a uniform `data/domain/application/presentation` sub-structure and a barrel/README per folder.
- [ ] At least the `core` foundational package exists as a workspace member and is importable from the app.
- [ ] `melos.yaml` defines `bootstrap`, `analyze`, `format`, `test`, `build` scripts; `melos bootstrap` resolves the whole workspace with a single lockfile.
- [ ] No runtime third-party dependency added beyond the policy's kept list; each addition is justified in the package README.

**Size:** M · **Depends on:** none · **Governing docs:** [01-architecture-and-structure.md](../../flutter/01-architecture-and-structure.md), [12-build-ci-release.md](../../flutter/12-build-ci-release.md)

### F1-T2 · Lint & format baseline

**Description.** Adopt `very_good_analysis` as the base ruleset with a **short** app-oriented override block (documented rationale for every relaxed/added rule). Enforce `flutter analyze` (zero warnings) and `dart format --set-exit-if-changed` locally and in CI. Add `riverpod_lint`/`custom_lint` wiring so the DI graph is statically checked.

**Acceptance criteria**
- [ ] `analysis_options.yaml` includes `very_good_analysis` and a minimal, commented override block.
- [ ] `custom_lint` + `riverpod_lint` enabled and passing.
- [ ] `flutter analyze` returns zero issues across the workspace.
- [ ] `dart format --set-exit-if-changed .` passes (repo is fully formatted).
- [ ] Overrides are limited to a short block and each carries a one-line justification comment.

**Size:** S · **Depends on:** F1-T1 · **Governing docs:** [12-build-ci-release.md](../../flutter/12-build-ci-release.md), [02-state-management.md](../../flutter/02-state-management.md)

### F1-T3 · Build flavors & SDK pinning

**Description.** Configure `dev` and `prod` **flavors** across Android (`productFlavors`, per-flavor `applicationId` suffix) and iOS (schemes/configurations, per-flavor bundle id). Pin the **verified current-stable** Flutter and Dart SDK (Dart 3.6+ required for pub workspaces) via `pubspec` constraints and a pinned toolchain file (e.g. FVM/`.tool-versions`). Set app display name, app-id/bundle-id, and per-flavor app icons/labels.

**Acceptance criteria**
- [ ] `dev` and `prod` flavors build and install side-by-side (distinct application/bundle ids) on Android and iOS.
- [ ] SDK versions pinned and documented; workspace requires Dart >= 3.6.
- [ ] App-id/bundle-id, display name, and flavor-differentiated icon/label configured.
- [ ] `flutter run --flavor dev` and `--flavor prod` both launch.
- [ ] Flavor selection wired to bootstrap (e.g. distinct DB filename / config per flavor) without leaking prod data into dev.

**Size:** M · **Depends on:** F1-T1 · **Governing docs:** [12-build-ci-release.md](../../flutter/12-build-ci-release.md)

### F1-T4 · CI/CD pipeline

**Description.** GitHub Actions workflow(s) that, on PR and main, run: `flutter analyze`, `dart format --set-exit-if-changed`, `flutter test` with coverage, and produce iOS + Android build artifacts. Cache pub, Gradle, and Flutter SDK. Fail the build on lint, format, test, or coverage-threshold violations.

**Acceptance criteria**
- [ ] Workflow triggers on PR and pushes to the default branch.
- [ ] Jobs: analyze, format-check, test-with-coverage, android-build, ios-build.
- [ ] Coverage report generated and the coverage gate (see F1-T8) enforced in CI.
- [ ] Pub/Gradle/Flutter caching reduces cold-run time; cache keys keyed on lockfiles.
- [ ] Android APK/AAB and iOS build artifacts uploaded (unsigned build acceptable for CI).
- [ ] Any red step blocks merge (branch protection documented).

**Size:** M · **Depends on:** F1-T1, F1-T2, F1-T8 · **Governing docs:** [12-build-ci-release.md](../../flutter/12-build-ci-release.md)

### F1-T5 · Riverpod DI/provider graph

**Description.** Establish Riverpod as the single mechanism for DI and state. Create `keepAlive` infrastructure providers for repositories/services/engines, and **placeholder root providers** for async-initialized infra — the opened encrypted DB, the secure key store, app directories, and the resolved timezone — that throw `UnimplementedError` until **overridden at bootstrap** with real instances. Use `@riverpod` codegen (`riverpod_generator`) and Freezed for provider state where applicable.

**Acceptance criteria**
- [ ] Root `ProviderScope` with overrides for DB, secure store, app-dirs, and timezone providers.
- [ ] Placeholder root providers throw a clear error if read before bootstrap override.
- [ ] Infra/repository/service providers marked `keepAlive`; feature/UI providers auto-dispose by default.
- [ ] Codegen (`build_runner` + `riverpod_generator`) runs clean and is wired into a Melos script.
- [ ] A sample repository provider consumes the DB provider purely through DI (no globals/singletons/service-locator).
- [ ] `riverpod_lint` passes with no provider-graph violations.

**Size:** M · **Depends on:** F1-T1 · **Governing docs:** [04-dependency-injection.md](../../flutter/04-dependency-injection.md), [02-state-management.md](../../flutter/02-state-management.md)

### F1-T6 · Sealed Result/Failure kernel

**Description.** Hand-roll a Dart 3 sealed `Result<T, F extends Failure>` (`Ok`/`Err`) over a sealed `Failure` hierarchy in `packages/core`. Each concrete failure (`DbFailure`, `BackupFailure`, `ImportFailure`, `NotificationFailure`, `ValidationFailure`, plus a catch-all `UnknownFailure`) carries a **stable machine code** and **typed params** — never a user-facing string. Provide ergonomic combinators (`map`, `flatMap`/`then`, `fold`, `getOrElse`) and an exhaustive `switch` contract at module boundaries. User-facing message rendering is deferred to the i18n layer keyed off the stable code.

**Acceptance criteria**
- [ ] `Result<T,F>` is a Dart `sealed class` with `Ok`/`Err` variants; exhaustive `switch` compiles without a default.
- [ ] `Failure` is a `sealed class`; each subtype has a stable `code` (enum/const) and typed, structured params.
- [ ] No `Failure` type stores or exposes a localized/user-facing string.
- [ ] Combinators (`map`, `flatMap`, `fold`, `getOrElse`) implemented and unit-tested.
- [ ] The module-boundary convention (return `Result`, never throw across boundaries) is documented in `core`'s README.
- [ ] Table-driven unit tests cover every combinator and every failure variant's code/params.

**Size:** M · **Depends on:** F1-T1 · **Governing docs:** [08-error-handling.md](../../flutter/08-error-handling.md)

### F1-T7 · App bootstrap & async infra init

**Description.** Implement the bootstrap sequence that gates `runApp` on async initialization of: the **encrypted DB** (opened with its key), the **secure key store**, **app directories**, and the **timezone** database. Bootstrap resolves these, feeds them into the Riverpod root overrides (F1-T5), and drives a state machine with **splash**, **error**, and **ready** states. Errors surface via the Result/Failure kernel (F1-T6) into a recoverable error screen — never a raw crash or silent hang.

**Acceptance criteria**
- [ ] `main()` calls a single `bootstrap()` that returns the resolved infra and the configured `ProviderScope` overrides.
- [ ] Splash state shown while async init runs; ready state shows the app shell; error state shows a retry-capable failure screen.
- [ ] Init failures are represented as `Failure` values, not thrown exceptions crossing `runApp`.
- [ ] DB open, secure-store read, dirs, and timezone init are awaited before the first frame that needs them.
- [ ] Bootstrap is flavor-aware (uses the F1-T3 per-flavor config).
- [ ] Widget/integration test covers splash → ready and splash → error paths.

**Size:** M · **Depends on:** F1-T5, F1-T6 · **Governing docs:** [00-overview.md](../../flutter/00-overview.md), [04-dependency-injection.md](../../flutter/04-dependency-injection.md), [08-error-handling.md](../../flutter/08-error-handling.md)

### F1-T8 · Testing harness & coverage gate

**Description.** Wire `flutter_test` and establish **table-driven test conventions** for pure-Dart engines (the "diamond-topped pyramid": exhaustive unit tests on pure logic). Provide shared test helpers (fixtures, in-memory DB harness stub, provider-override helpers). Generate combined coverage (`lcov`) across the workspace and enforce a coverage threshold in CI.

**Acceptance criteria**
- [ ] `flutter test` runs green across all workspace members via a Melos script.
- [ ] A documented table-driven test pattern (parameterized cases) with at least one worked example on the Result kernel.
- [ ] Shared test utilities: provider-override helper and an in-memory DB harness stub.
- [ ] Combined `lcov` coverage produced for the workspace.
- [ ] Coverage threshold defined and enforced as a CI gate (build fails below threshold).

**Size:** S · **Depends on:** F1-T1, F1-T6 · **Governing docs:** [12-build-ci-release.md](../../flutter/12-build-ci-release.md)

### F1-T9 · Store-compliance scaffolding

**Description.** Add the launch-blocking privacy/compliance artifacts up front so they cannot drift: iOS `PrivacyInfo.xcprivacy` declaring **no tracking and no collected data types**; an Android manifest that **omits the `INTERNET` permission** (backing the 100%-offline claim); and stubs for the Play **Data-Safety** form and iOS **privacy nutrition label** both declaring no collection / no tracking. Include a licensing/third-party-notices scaffold enumerating the kept runtime deps.

**Acceptance criteria**
- [ ] `PrivacyInfo.xcprivacy` present and declares no tracking + no collected data types (+ required-reason API entries as needed).
- [ ] Android `AndroidManifest.xml` does **not** request `INTERNET`; a build-time check/comment guards against reintroduction.
- [ ] Play Data-Safety and iOS nutrition-label stub docs committed, both stating no data collection and no tracking.
- [ ] Third-party license/notices scaffold lists each kept runtime dependency and its license.
- [ ] Compliance docs are referenced from the repo and marked launch-blocking.

**Size:** S · **Depends on:** F1-T1, F1-T3 · **Governing docs:** [17-store-compliance-licensing.md](../../flutter/17-store-compliance-licensing.md)

### F1-T10 · Canonical value types & shared kernel primitives (added)

**Description.** Seed `packages/core` with the canonical, dependency-free value types every downstream module will store and validate against, so the boundary contract exists before the data layer (F2) lands: **money as integer minor units + ISO-4217 code + real exponent** (0 for IRR/JPY, 2 for USD/EUR, 3 for KWD/BHD/OMR — never a hardcoded two decimals or a float), SI-base **unit quantities** (distance in metres, volume in litres, engine-hours), and **UTC-instant vs wall-clock-schedule** temporal types. These are pure Dart, exhaustively table-tested, and produce/consume `Result`/`ValidationFailure`. This is the smallest slice needed to make the kernel a *complete* boundary contract rather than just an error type; full schema/repository work stays in the data-layer epic.

**Acceptance criteria**
- [ ] `Money` value type: integer minor units + currency code + exponent; construction validates against the ISO exponent and returns `Err(ValidationFailure)` on mismatch.
- [ ] Iranian Rial/Toman handling explicitly covered (exponent 0, Toman as a display concern).
- [ ] SI-base quantity types (distance/volume/duration) with conversion helpers that convert only at the edge, never in storage.
- [ ] UTC-instant and wall-clock-schedule types distinguished at the type level.
- [ ] Zero third-party runtime deps in these types; all pure Dart.
- [ ] Exhaustive table-driven unit tests for exponents, rounding, and conversion round-trips.

**Size:** M · **Depends on:** F1-T6 · **Governing docs:** [08-error-handling.md](../../flutter/08-error-handling.md), [data-model.md](../../reference/data-model.md)

### F1-T11 · App-shell i18n & RTL/theming scaffold (added)

**Description.** Wire the *scaffolding* (not the full engine — that is the i18n epic) so the placeholder app shell is correctly localizable and directional from day one, preventing retrofit debt: enable `flutter_localizations` + `intl` gen-l10n (`generate: true`, `l10n.yaml`), add ARB files for the six shipping locales (en/de/fr LTR, fa/ar/ckb RTL) with the handful of bootstrap/splash/error strings, feed an app-controlled `locale`/`textDirection` into `MaterialApp`, and stand up the PULSE warm-paper/ink dual-theme `ThemeData` shells with the redundant-encoding (never colour-alone) rule baked into the base widget conventions.

**Acceptance criteria**
- [ ] gen-l10n configured (`l10n.yaml`, `generate: true`); ARB files present for en/de/fr/fa/ar/ckb.
- [ ] All bootstrap/splash/error strings are localized (no hardcoded user-facing strings in the shell).
- [ ] `MaterialApp` respects an app-controlled locale and renders RTL correctly for fa/ar/ckb (mirrored layout verified).
- [ ] Light (warm-paper) and dark (ink) PULSE theme shells defined via tokens; theme switch works.
- [ ] Base status/indicator convention documented to require redundant encoding (icon+label+shape+position), not colour alone.

**Size:** S · **Depends on:** F1-T1, F1-T7 · **Governing docs:** [00-overview.md](../../flutter/00-overview.md), [01-architecture-and-structure.md](../../flutter/01-architecture-and-structure.md)

## Definition of Done

- **Builds & runs:** `dev` and `prod` flavors build and launch on iOS and Android; `melos bootstrap` resolves the workspace with a single lockfile.
- **Quality gates green:** `flutter analyze` zero issues, `dart format --set-exit-if-changed` clean, `riverpod_lint`/`custom_lint` clean — all enforced in CI.
- **Tests:** `flutter test` green across the workspace; the Result/Failure kernel and the canonical value types have exhaustive table-driven tests; the coverage gate passes in CI. Bootstrap splash→ready and splash→error paths covered by a widget/integration test.
- **DI & kernel contract:** infra is injected exclusively through Riverpod placeholder providers overridden at bootstrap (no globals/service-locator); module boundaries return sealed `Result<T,F>` and never throw across boundaries; no `Failure` carries a user-facing string.
- **i18n complete:** every user-facing string in the app shell (splash/error/bootstrap) is localized across all six shipping locales (en/de/fr/fa/ar/ckb) with no hardcoded strings.
- **RTL verified:** the shell renders correctly mirrored in fa/ar/ckb (layout, focus/traversal order), confirmed manually and by test where feasible.
- **In backup/export:** N/A for feature data at this stage, but the kernel's canonical value types (money exponent, SI units, UTC instants) are defined so that every future entity is backup/export-serializable from birth; no design decision here blocks full backup/export coverage.
- **Accessible per the redundant-encoding rule:** the base theming/status conventions enforce status encoded redundantly (icon + label + shape + position), never colour alone; the app shell meets minimum touch-target and dynamic-type reflow expectations.
- **Offline & privacy posture locked:** Android manifest omits `INTERNET`; `PrivacyInfo.xcprivacy` and the Data-Safety / nutrition-label stubs declare no collection and no tracking; no telemetry or analytics dependency is present; every kept runtime dependency is justified against the built-in-first policy and listed in the license/notices scaffold.
