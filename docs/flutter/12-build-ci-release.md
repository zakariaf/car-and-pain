# 🏗️ Build, Tooling, Release & CI/CD

> How Car and Pain is structured as a monorepo, linted, pinned for reproducibility, flavored, code-generated, versioned, obfuscated, and shipped to both stores through automated pipelines.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · see also [Architecture & Module Structure](./01-architecture-and-structure.md) · [Testing Strategy](./11-testing.md) · [Store Compliance, Privacy Declarations & Licensing](./17-store-compliance-licensing.md)

## Decision

Run a single-repo **Melos monorepo layered on native Dart pub workspaces** (`resolution: workspace`, Dart 3.6+): one thin runnable app shell (`apps/car_and_pain`) plus foundational `packages/*` (core, data, notifications, l10n, design_system). Lint with **`very_good_analysis`** plus a short app-oriented override block, enforced by `flutter analyze` + `dart format --set-exit-if-changed` as blocking gates. Pin the Flutter/Dart SDK with **FVM** (`.fvmrc`) and **verify current-stable package majors at kickoff** rather than trusting speculative numbers, committing `pubspec.lock` / `Podfile.lock` / `Gemfile.lock` for reproducibility. Ship **exactly two flavors** (`dev`/`prod`) for side-by-side install and distinct notification channel IDs — not API config, because there is no backend. Gitignore all generated code and regenerate via `build_runner` as the first CI step. Version `x.y.z+BUILD` with the build number injected from the CI run; release builds use `--obfuscate --split-debug-info` with symbols archived per tag. CI is **GitHub Actions** with a fast `ubuntu` PR pipeline and a `macos` release pipeline driving `fastlane` (`match`/`supply`/`upload_to_testflight`) plus a real-font golden lane — with **Codemagic** kept as a documented fallback for iOS signing.

## Why

The app is a **data-custody product with no server to hotfix**, so reproducibility is higher-stakes than a typical app and every layer is pinned. 25 feature folders need enforced compile-time boundaries where discipline is load-bearing (canonical units/money, all DB/backup access, the notification engine, i18n) — but they do **not** need 25 hand-managed pubspecs and 25 version churns. That single trade-off drives the whole tooling stack.

Alternatives considered and rejected:

- **Single flat app package** — no boundary enforcement, and whole-repo `flutter analyze`/`build_runner` gets slow across 25 modules. Rejected.
- **25 separate feature packages** — pubspec/version churn and slow cross-package codegen for zero benefit on a buy-once indie app. Rejected in favor of feature *folders* in one shell + a few cross-cutting *packages*.
- **Plain pub workspaces without Melos** — gives fast path-linking but no script orchestration, change-based CI, or versioning helpers. We layer Melos *on top* of workspaces (workspaces link, Melos orchestrates).
- **`flutter_lints` v6** — the `flutter create` default, but too permissive to keep 25 modules consistent over a multi-year lifespan. Kept only as the gentler fallback if strictness fights the solo-dev cadence.
- **Committing generated files** — faster clean checkout, but noisy reviews, merge conflicts in generated code, and silent drift from annotations. Rejected: gitignore + regenerate is the single source of truth.
- **3 flavors (dev/staging/prod)** — wasted surface for an offline app with no server tier to stage against. Use the stores' own internal/TestFlight tracks for beta instead.
- **`golden_toolkit`** — effectively in maintenance/deprecated mode; borrow only `loadAppFonts`. Use **Alchemist** for deterministic goldens.
- **Manual build-number bumps** — cause `version already exists` store-upload rejections. Inject from the CI run number.
- **Wiring any crash/analytics SDK into CI** — violates the no-telemetry posture; a CI lockfile scan actively *fails the build* if one appears.

## How we do it

### Workspace layout

```text
car-and-pain/
├─ pubspec.yaml                 # workspace: [apps/*, packages/*]
├─ pubspec.lock                 # ONE shared lockfile, committed
├─ melos.yaml                   # script orchestration + change-based CI
├─ .fvmrc                       # pins verified current-stable Flutter/Dart
├─ analysis_options.yaml        # include: very_good_analysis + overrides
├─ build.yaml                   # root builder scoping for codegen
├─ apps/
│  └─ car_and_pain/             # thin runnable shell (flavors, routing, bootstrap)
│     ├─ lib/main_dev.dart      # entrypoint → shared bootstrap(Flavor.dev)
│     ├─ lib/main_prod.dart     # entrypoint → shared bootstrap(Flavor.prod)
│     ├─ android/ ios/          # flavor config lives here
│     └─ pubspec.yaml           # resolution: workspace
└─ packages/
   ├─ core/                     # pure Dart engines, value objects, Result/Failure, Clock
   ├─ data/                     # encrypted Drift DB, DAOs, migrations, backup engine
   ├─ notifications/            # NotificationGateway port + pure ReminderScheduler
   ├─ l10n/                     # gen-l10n ARB, calendars, numerals, bundled fonts
   └─ design_system/            # theme + Directional-only widgets, chart Semantics
```

Root workspace pubspec:

```yaml
# /pubspec.yaml
name: car_and_pain_workspace
environment:
  sdk: ^3.6.0        # pin the VERIFIED current-stable at kickoff
workspace:
  - apps/car_and_pain
  - packages/core
  - packages/data
  - packages/notifications
  - packages/l10n
  - packages/design_system
```

Every member pubspec declares `resolution: workspace` so pub links locally and produces one shared lockfile. Packages expose narrow public APIs via barrels; feature folders never import another feature (share via `core`/`data` or navigate by ID); the dependency graph is a DAG.

### Lint & format gates

```yaml
# /analysis_options.yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore   # freezed/json noise
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/*.drift.dart"
    - "**/*.mocks.dart"
    - "**/l10n/generated/**"

# The few app-hostile rules to switch off (we ship an app, not a package):
linter:
  rules:
    public_member_api_docs: false
    lines_longer_than_80_chars: false
    sort_pub_dependencies: false

# Keep VGV's 80-col convention with the modern Dart 3.7+ "tall" formatter:
formatter:
  page_width: 80
```

A CI grep/custom-lint additionally **rejects non-Directional geometry** in feature code (`EdgeInsets.only(left/right)`, `Alignment.centerLeft`, `Positioned(left:)`, `TextAlign.left/right`) — the RTL discipline from module #1. See [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md).

### Melos scripts

```yaml
# /melos.yaml
name: car_and_pain
scripts:
  gen:
    exec: dart run build_runner build --delete-conflicting-outputs
    packageFilters: { dependsOn: ["build_runner"] }
  analyze:
    exec: flutter analyze --fatal-infos
  format:
    run: dart format --output=none --set-exit-if-changed .
  test:
    exec: flutter test --coverage
    packageFilters: { dirExists: "test" }
```

### Codegen: gitignore + regenerate

`.gitignore` excludes `*.g.dart`, `*.freezed.dart`, `*.drift.dart`, and the gen-l10n output. **`build_runner` is the first CI step, before analyze** — a tree of gitignored, un-generated part files otherwise produces confusing "missing part file" / undefined-class errors. Scope builders per package so a change in one feature doesn't regenerate all 25:

```yaml
# packages/data/build.yaml
targets:
  $default:
    builders:
      drift_dev:
        generate_for: ["lib/src/db/**.dart"]
      json_serializable:
        generate_for: ["lib/src/backup/**.dart"]
```

`build_runner` runs at the workspace root so drift/freezed/riverpod/gen-l10n regenerate together in one pass.

### Flavors (install-isolation, not endpoints)

Exactly two: `dev` and `prod`. Android product flavors with an `applicationIdSuffix`, iOS shared schemes with a bundle-id suffix, so **both install side-by-side** and a dev build's scheduled reminders never collide with prod's:

```kotlin
// apps/car_and_pain/android/app/build.gradle.kts
flavorDimensions += "default"
productFlavors {
    create("dev")  { dimension = "default"; applicationIdSuffix = ".dev"; resValue("string", "app_name", "Car&Pain Dev") }
    create("prod") { dimension = "default"; resValue("string", "app_name", "Car & Pain") }
}
```

Two entrypoints call a shared bootstrap; read the built-in `appFlavor` const — no third-party flavor package:

```dart
// apps/car_and_pain/lib/main_dev.dart
void main() => bootstrap(Flavor.dev);

// shared bootstrap reads the compile-time flavor
import 'package:flutter/services.dart' show appFlavor;

Future<void> bootstrap(Flavor flavor) async {
  // flavor drives: seeded demo garage, log verbosity, and — critically —
  // distinct local-notification CHANNEL IDs + request-code ranges.
  final channelId = 'reminders_${appFlavor}'; // never collide dev/prod
  // ... open encrypted DB, override providers in ProviderScope, init tz ...
}
```

The distinct channel IDs and request-code ranges are the whole reason flavors exist here — see [Local Notifications & Background Reliability](./07-notifications.md).

### Versioning & reproducible release

Keep `version: x.y.z+BUILD` in the app pubspec; inject the build number in CI so it is always unique and monotonic without hand-bumping:

```bash
flutter build appbundle --flavor prod -t lib/main_prod.dart \
  --build-name="$GIT_TAG" \
  --build-number="$GITHUB_RUN_NUMBER" \
  --obfuscate --split-debug-info=build/symbols/"$GIT_TAG"
```

`--obfuscate` aligns with no-telemetry and IP protection; **archive the `--split-debug-info` directory as a CI artifact per tag** — it is the *only* crash-symbolication path, since there is no crash SaaS. Reproducibility discipline: FVM `.fvmrc` pins the SDK; commit `pubspec.lock` + `Podfile.lock` + `Gemfile.lock` + `.ruby-version`; pin the Android toolchain via the Gradle wrapper and the Xcode version in the macOS job.

### GitHub Actions topology

```yaml
# .github/workflows/pr.yml — fast, cheap, every PR
name: pr
on: pull_request
jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2      # pin the same version as .fvmrc
        with: { flutter-version: "3.x.y", channel: stable }
      - run: dart pub global activate melos
      - run: melos bootstrap
      - run: melos run gen         # codegen FIRST
      - run: melos run format      # dart format --set-exit-if-changed
      - run: melos run analyze     # flutter analyze --fatal-infos
      - run: melos run test        # unit + widget + CI (Ahem) goldens
      - run: dart run tool/scan_no_telemetry.dart   # lockfile scan: fails on any analytics/crash SDK
      - run: flutter build appbundle --flavor prod -t apps/car_and_pain/lib/main_prod.dart  # smoke build only
```

```yaml
# .github/workflows/release.yml — costly macOS, tags only
name: release
on:
  push:
    tags: ["v*"]
jobs:
  ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: "3.x.y", channel: stable }
      - run: melos bootstrap && melos run gen
      - run: flutter test --tags golden-realfont    # Persian/Arabic shaping lane, one pinned OS
      - run: flutter build ipa --flavor prod -t apps/car_and_pain/lib/main_prod.dart \
               --obfuscate --split-debug-info=build/symbols/${{ github.ref_name }} \
               --build-number=${{ github.run_number }}
      - run: cd apps/car_and_pain/ios && bundle exec fastlane beta   # match(readonly) + upload_to_testflight
      - uses: actions/upload-artifact@v4
        with: { name: symbols-${{ github.ref_name }}, path: build/symbols }
```

- **ubuntu** handles analyze/test/golden/Android smoke build (10x cheaper minutes); iOS builds are gated to the tag pipeline so PRs never burn macOS minutes.
- **fastlane** structure: `android/fastlane` + `ios/fastlane`, each with a committed `Gemfile.lock`, invoked via `bundle exec`. iOS uses `match(type: 'appstore', readonly: true)` with certs in a private repo; Android decodes a base64 keystore + Play JSON key from GitHub encrypted secrets. Golden PNGs are compared on the Linux runner only and committed to the repo.

### Package baseline

`very_good_analysis`, `melos`, `build_runner`, `drift`/`drift_dev`, `freezed`/`json_serializable`, gen-l10n (`intl` + `flutter_localizations`), `alchemist`, `mocktail`, `integration_test` + `patrol`, `custom_lint`/`riverpod_lint`, `fvm`, `fastlane` (`match`/`supply`/`upload_to_testflight`), `very_good_cli`/`coverage`. **Verify the current-stable major of each load-bearing package at kickoff** (`flutter_local_notifications`, `go_router`, `drift`) — do not trust speculative numbers.

## Rules

- **Do** run `build_runner` before `analyze` in every pipeline and on every fresh clone. Never analyze a tree with gitignored, un-generated part files.
- **Do** commit `pubspec.lock`, `Podfile.lock`, `Gemfile.lock`, `.ruby-version`, `.fvmrc`. An app commits lockfiles (unlike a published package).
- **Do** gitignore `*.g.dart`, `*.freezed.dart`, `*.drift.dart`, and gen-l10n output. Never commit generated code.
- **Do** inject the build number from CI (`--build-number=$GITHUB_RUN_NUMBER`). **Don't** hand-bump `+N` in pubspec — it causes `version already exists` upload rejections.
- **Do** ship exactly two flavors; give each a distinct notification channel ID and request-code range. **Don't** use flavors for API config (there is none) or add a third `staging` flavor.
- **Do** release with `--obfuscate --split-debug-info` and archive symbols per tag. **Don't** obfuscate without archiving — stack traces become permanently unreadable and there is no telemetry fallback.
- **Do** keep `flutter analyze --fatal-infos` and `dart format --set-exit-if-changed` as blocking gates.
- **Do** run the no-telemetry lockfile scan in CI; **don't** add any analytics/crash SDK, and the offline flavor omits the `INTERNET` permission.
- **Do** generate and compare goldens on **one** OS (ubuntu) with bundled real fonts. **Don't** compare goldens on device/emulator or with hardware rendering.
- **Do** mark iOS schemes "Shared" and list every `Debug-/Profile-/Release-<flavor>` in the Podfile config map, with lowercase flavor names matching `--flavor`.
- **Don't** mix Melos's own bootstrap linking with pub-workspace linking; workspaces link, Melos orchestrates (needs Dart 3.6+, Melos 6.x+).

## For Car and Pain specifically

- **Offline-first & no-telemetry:** the CI lockfile scan is a hard gate that fails the build if any analytics/crash SDK appears; release obfuscation protects IP while archived symbols preserve the *only* symbolication path. The dev flavor's omitted `INTERNET` permission makes the OS enforce the offline claim — the store [privacy declarations](./17-store-compliance-licensing.md) back it up.
- **Encrypted DB & backup as codegen dependencies:** `drift_dev` (encrypted SQLite) and `json_serializable` (the single-file backup/export) both flow through `build_runner`, so codegen-before-analyze is mandatory, not optional. See [Local Database, Schema, Indexing & Migrations](./03-data-persistence.md) and [Backup, Export & Disaster Recovery](./13-backup-export-recovery.md).
- **RTL/i18n as a release gate:** the real-font golden lane on the macOS release pipeline catches Persian/Arabic shaping; the ubuntu Ahem lane catches mirroring. Large text-scale and RTL-overflow are explicit golden dimensions, and the non-Directional-geometry grep is a CI check. See [Accessibility & Dynamic Type](./15-accessibility-dynamic-type.md).
- **Notifications & flavors:** dev and prod carry distinct channel IDs and request-code ranges precisely so a dev build's scheduled reminders never collide with prod's on the same physical device during development.
- **Reproducibility over feature velocity:** because there is no server to hotfix, everything is pinned and lockfiles committed, and versions are *verified* at kickoff rather than guessed.

## Testing

- **Wire each test layer into CI after the codegen step.** Pure-Dart engine tests (TCO, projection, calendars, numerals, backup round-trip) run per-package via `melos run test`; DB tests use an in-memory Drift engine; see [Testing Strategy](./11-testing.md).
- **Golden determinism is a build concern:** use **Alchemist**, load bundled fonts via a `flutter_test_config.dart` (borrowing `loadAppFonts`), generate locally with `--update-goldens`, and **compare only on the ubuntu runner** — Mac-generated goldens fail on Linux due to anti-aliasing. Keep goldens in `flutter test` (software rendering); never compare with Impeller/hardware.
- **Coverage gates:** `flutter test --coverage` with `--min-coverage` enforced at **100% only on the logic packages** (core, and the pure scheduler in notifications) via Very Good Coverage; ratchet upward elsewhere rather than chasing a global vanity number.
- **CI-topology tests:** a no-telemetry negative test (lockfile scan + zero-outbound-connection assertion) and the blocking DB-header assertion (raw file is NOT `SQLite format 3`) run as ordinary CI steps.
- **Native flows:** `integration_test` + **Patrol** smoke the notification/permission surfaces on the release lane; reboot/Doze/OEM-battery survival is **documented manual real-device QA** (Xiaomi/MIUI, Samsung, Huawei, Oppo) — never a fabricated automated pass.

## Pitfalls

- **Forgetting codegen in CI or on a fresh clone** → confusing "missing part file"/undefined-class errors. Always regenerate first.
- **Golden flakiness across platforms** → Mac-generated goldens churn endlessly on Linux CI. Use Alchemist, one OS, bundle the exact font files.
- **Impeller + goldens** → don't run golden comparisons on device/emulator or hardware rendering; keep them in software `flutter test` for deterministic pixels.
- **`very_good_analysis` over-strictness** → leaving `public_member_api_docs`, `lines_longer_than_80_chars`, or `sort_pub_dependencies` on buries you in warnings across 25 packages. Add the deliberate override block.
- **iOS flavor config traps** → config names must be lowercase and match `--flavor`; schemes MUST be "Shared" or CI can't select them; the Podfile project-config map must list every `Debug-/Profile-/Release-<flavor>` or `pod install` breaks.
- **Manual build-number bumps** → store-upload rejections. Inject from the CI run number.
- **Not committing lockfiles** → silent reproducibility loss; a floating transitive dep can change encrypted-DB or notification-plugin behavior between builds.
- **Melos + pub-workspaces version mismatch** → needs Dart 3.6+ / Melos 6.x+; mixing both link mechanisms causes duplicate/inconsistent resolution.
- **Obfuscation without archiving symbols** → user-reported crashes become impossible to symbolicate, with no telemetry to fall back on.
- **Full `flutter build ios` on every PR** → burns macOS minutes; gate iOS to the tag pipeline.

## Decisions to confirm

- **Encryption spike & version pinning (week one):** does drift's `sqlite3mc` build-hook path link and encrypt on real iOS *and* Android, or does v1 ship on `sqlcipher_flutter_libs`? Pin the verified current-stable Flutter/Dart SDK and all load-bearing package majors (`flutter_local_notifications`, `go_router`, `drift`) at that time rather than the speculative numbers, and confirm no dependency pulls a plaintext sqlite3 library that wins the native link. This directly determines the pinned versions this doc's pipelines build against.
- **State management (Riverpod vs Bloc):** if the solo developer already has deep `flutter_bloc` muscle memory, that changes the state package and its `*_lint` dependency in the workspace; confirm before locking the codegen/lint stack at kickoff.
- **Binary-size & asset-bundling strategy:** the offline map layer, bundled datasets, and subsetted Vazirmatn/Noto fonts have significant size implications that affect build tooling, startup performance, and store download limits — decide the size-budget strategy separately, as it shapes the release build config.

## Related

- [Architecture & Module Structure](./01-architecture-and-structure.md) — the feature-folder + cross-cutting-package layout this build system pins and orchestrates.
- [Testing Strategy](./11-testing.md) — the test layers wired into the CI lanes described here.
- [Store Compliance, Privacy Declarations & Licensing](./17-store-compliance-licensing.md) — the Play Data-Safety form and iOS privacy label the no-telemetry gates back up.
- [Security, Privacy & At-Rest Encryption](./09-security-privacy.md) — the encryption spike that fixes the pinned `drift`/cipher versions.
- [Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md) — the product-side offline/backup guarantees the reproducibility discipline serves.
- [Glossary & Conventions](../reference/glossary.md) — shared terminology for flavors, canonical storage, and build conventions.
