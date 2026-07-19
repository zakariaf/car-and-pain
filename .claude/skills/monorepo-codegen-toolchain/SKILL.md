---
name: monorepo-codegen-toolchain
description: >-
  Explains the Car and Pain monorepo toolchain the data, i18n, and testing skills
  build on: native Dart pub workspace linking with Melos orchestrating scripts on
  top, FVM SDK pinning via .fvmrc, gitignored generated code (*.g.dart,
  *.freezed.dart, *.drift.dart, gen-l10n output) regenerated with build_runner at
  the workspace root as the first CI step, per-package build.yaml builder scoping
  for drift_dev/freezed/riverpod/json_serializable, very_good_analysis plus flutter
  analyze --fatal-infos and dart format --set-exit-if-changed blocking gates, the
  two dev/prod flavors, and the three blocking CI gates (no-telemetry lockfile
  scan, DB header not SQLite format 3, export-wipe-import deep-equal). Use when
  editing pubspec.yaml, melos.yaml, build.yaml, analysis_options.yaml, .fvmrc,
  .gitignore, or GitHub Actions workflows; adding a package or feature folder;
  wiring codegen; fixing missing part-file or undefined-class errors; or
  diagnosing a failing CI gate. Pairs with run-codegen for manual regeneration.
metadata:
  project: car-and-pain
  area: build-tooling-ci
---

# Monorepo Codegen Toolchain

Ground rules for the Car and Pain build system: a native Dart pub workspace
(`resolution: workspace`) with **Melos layered on top for scripts and
change-based CI only**. Workspaces link; Melos orchestrates. Never mix the two
linking mechanisms.

Assume general Flutter/Dart/Melos/build_runner knowledge. What follows is only
what is project-specific and non-negotiable.

## Non-negotiable rules

- **Workspaces link, Melos orchestrates.** The root `pubspec.yaml` lists every
  member under `workspace:`; every member pubspec sets `resolution: workspace`.
  Do NOT run `melos bootstrap` for path linking — pub does the linking. Melos is
  a convenience layer for `melos run gen/format/analyze/test`. Needs Dart 3.6+
  and Melos 6.x+.
- **One lockfile at the root.** Exactly one `pubspec.lock` lives at the repo
  root. Never add a per-package lockfile. A member missing `resolution:
  workspace`, or with an incompatible SDK constraint, silently breaks
  resolution.
- **Pin the SDK with FVM.** `.fvmrc` pins the verified current-stable
  Flutter/Dart at kickoff. CI's `flutter-action` version MUST match `.fvmrc`.
  Commit `.fvmrc`, `pubspec.lock`, `Podfile.lock`, `Gemfile.lock`,
  `.ruby-version` — an app commits lockfiles.
- **Generated code is gitignored, never committed.** `.gitignore` excludes
  `*.g.dart`, `*.freezed.dart`, `*.drift.dart`, and the gen-l10n output.
  Regenerate; never edit a generated file by hand.
- **`build_runner` runs at the workspace root and is the FIRST CI step —
  before analyze.** drift/freezed/riverpod/gen-l10n regenerate together in one
  pass. Analyzing a tree of gitignored, un-generated part files produces
  confusing "missing part file" / undefined-class errors. If you see those:
  run codegen, do not chase the symptom.
- **Scope builders per package in `build.yaml`.** A change in one feature must
  not regenerate all 25. Use `generate_for:` globs to fence `drift_dev`,
  `json_serializable`, `freezed`, `riverpod` to the directories that own the
  annotations (see `references/codegen-build-runner.md`).
- **Blocking format/lint gates.** `dart format --output=none
  --set-exit-if-changed .` and `flutter analyze --fatal-infos` both block the
  build. Lint config is `very_good_analysis` plus the small documented override
  block; keep the tall formatter at `page_width: 80`.
- **Exactly two flavors: `dev` and `prod`.** Flavors exist for side-by-side
  install and distinct notification channel IDs / request-code ranges — NOT for
  API config (there is no backend). Never add a `staging` flavor. Read the
  built-in `appFlavor` const; no third-party flavor package.
- **Inject the build number from CI** (`--build-number=$GITHUB_RUN_NUMBER`).
  Never hand-bump `+N` in pubspec — it causes `version already exists` upload
  rejections. Release with `--obfuscate --split-debug-info` and archive the
  symbols directory per tag — it is the ONLY symbolication path (no crash SaaS).
- **Three blocking CI gates enforce the product's core promises** (see
  `references/flavors-and-ci-gates.md`):
  1. **No-telemetry lockfile scan** — `dart run tool/scan_no_telemetry.dart`
     fails the build if any analytics/crash SDK appears in `pubspec.lock`. The
     dev flavor also omits the `INTERNET` permission.
  2. **DB-header not plaintext** — a test asserts the raw DB file's first 16
     bytes do NOT decode to `SQLite format 3`; a plaintext DB fails the build.
  3. **Backup round-trip deep-equal** — export, wipe, import, and assert the DB
     is deep-equal to the original, with WAL active.

## Canonical Melos config

The single source of truth for orchestration. Codegen filters to packages that
depend on `build_runner`; test filters to packages with a `test/` dir.

```yaml
# /melos.yaml — orchestration on top of pub-workspace linking
name: car_and_pain
scripts:
  gen:
    # Runs at the workspace root: drift/freezed/riverpod/gen-l10n in one pass.
    exec: dart run build_runner build --delete-conflicting-outputs
    packageFilters: { dependsOn: ["build_runner"] }
  format:
    run: dart format --output=none --set-exit-if-changed .
  analyze:
    exec: flutter analyze --fatal-infos
  test:
    exec: flutter test --coverage
    packageFilters: { dirExists: "test" }
```

CI order is fixed: `gen` → `format` → `analyze` → `test` → the three gates →
smoke build. Never reorder `gen` after `analyze`.

## Adding a member or wiring codegen

- **New feature = new folder** under `apps/car_and_pain/lib/src/features/`,
  never a new package. Promote to `packages/*` only for a truly cross-cutting
  concern with a stable, narrow barrel API (the five are frozen: `core`, `data`,
  `notifications`, `l10n`, `design_system`).
- **New package** (rare): add it to root `workspace:`, set `resolution:
  workspace` and a compatible SDK constraint in its pubspec, expose a single
  barrel (`export 'src/...' show ...`), and add a scoped `build.yaml` if it
  carries codegen. Keep the dependency graph a DAG; `core` depends on nothing
  internal.
- **After touching any annotation** (Drift table, freezed model, riverpod
  Notifier, json_serializable): run `melos run gen` (or the run-codegen skill),
  then `melos run analyze`. See the run-codegen skill for the manual loop.

## References

- `references/workspace-and-melos.md` — workspace vs. Melos responsibilities,
  member checklist, FVM pinning, resolution-failure edge cases.
- `references/codegen-build-runner.md` — per-package `build.yaml` scoping tables,
  builder-to-directory map, gitignore list, fresh-clone and error recovery.
- `references/flavors-and-ci-gates.md` — dev/prod flavor wiring, the two CI
  workflows, and the three blocking gates in detail.

## Scripts

- `scripts/regen.sh` — regenerate all codegen at the root with
  `--delete-conflicting-outputs`, then analyze.
- `scripts/check-gates.sh` — run the format/analyze gates plus grep-based
  parity checks (every member has `resolution: workspace`; no committed
  generated files; no per-package lockfile).
- `scripts/scan-no-telemetry.sh` — grep `pubspec.lock` for banned
  analytics/crash SDKs and fail on any hit.

## Examples & assets

- `examples/build.yaml` — a correctly scoped per-package builder config.
- `examples/main_dev.dart` — flavor entrypoint reading `appFlavor`.
- `assets/package-pubspec.yaml.tmpl` — a new workspace-member pubspec skeleton.
