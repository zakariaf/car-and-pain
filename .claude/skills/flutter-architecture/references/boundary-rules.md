# Boundary rules — the exact CI checks and what each rejects

Grounds `docs/flutter/01-architecture-and-structure.md` (Boundary enforcement) and
`docs/flutter/00-overview.md` (Core principles 7–10). Run `scripts/check_boundaries.sh` locally
before a PR; CI runs the same checks as blocking lanes.

## The blocking checks

| # | Check | Enforces | Rejects |
| --- | --- | --- | --- |
| 1 | `dart format --set-exit-if-changed` | Formatting | Any unformatted file. |
| 2 | `flutter analyze` with `very_good_analysis` + `custom_lint` + `riverpod_lint` | Analyzer, repo lints | Cross-feature imports, Drift classes in UI, provider misuse (`ref.watch` in a callback, `ref.read` in `build`, missing deps). |
| 3 | Directional-geometry grep | RTL-safe geometry | `EdgeInsets.only(left/right:)`, `Alignment.*Left/*Right`, `Positioned(left/right:)`, `TextAlign.left/right` in `apps/**` and `packages/design_system/**`. |
| 4 | DB-header not-plaintext test | At-rest encryption is real | A raw DB file whose first 16 bytes start with `SQLite format 3` (i.e. an unencrypted DB). |
| 5 | Silent-swallow grep | Typed error handling | `catch (_) {}` / bare `catch (e)` that discards type + stack in feature/package code. |
| 6 | No-telemetry lockfile scan | The offline promise | Any analytics/crash SDK (Crashlytics/Sentry/Firebase/etc.) in `pubspec.lock`. |
| 7 | Codegen freshness (`build_runner` + `build_verify`) | Generated code never drifts | Stale `*.g.dart` / `*.freezed.dart` / typed routes. |

## 1–2. Analyzer + custom_lint

```yaml
# analysis_options.yaml
include: package:very_good_analysis/analysis_options.yaml
analyzer:
  plugins: [custom_lint]      # repo rules: no cross-feature import, no Drift class in UI
```

`custom_lint` + `riverpod_lint` run in the analyze lane; violations fail the PR. The two repo-specific
rules are: **no feature folder imports another feature folder** (share via `core`/`data` or navigate
by ID), and **no Drift-generated row/companion class in a ViewModel or widget** (map to domain models
at the repository boundary).

## 3. Directional-geometry grep

```bash
# CI grep: reject non-Directional geometry in feature/design code.
! grep -rnE 'EdgeInsets\.only\((top:.*)?(left|right):|Alignment\.(center|top|bottom)(Left|Right)|Positioned\((left|right):|TextAlign\.(left|right)' \
    apps/car_and_pain/lib packages/design_system/lib
```

Use `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`,
`Icons.adaptive.*` instead. Directional-only from module #1.

## 4. DB-header not-plaintext assertion

```dart
// CI test (blocking): prove at-rest encryption is real.
final header = File(dbPath).openSync().readSync(16);
expect(utf8.decode(header, allowMalformed: true),
    isNot(startsWith('SQLite format 3')));   // plaintext DB fails the build
```

## Package-wall invariants (verify by grep/lint, not just review)

- **Every member pubspec sets `resolution: workspace`.** One `pubspec.lock` at the root; no
  per-package lockfiles.
- **The DAG stays acyclic:** `core` → nothing internal; `data`/`notifications` → `core`;
  `design_system` → `core`, `l10n`; app shell → all. A circular provider dependency throws at runtime.
- **No `src/` import across a package boundary** — consumers import only the barrel (`core.dart`,
  `data.dart`, `notifications.dart`, `l10n.dart`, `design_system.dart`).
- **`core` has no Flutter/plugin/IO dependency** — grep its pubspec for `flutter:` under
  `dependencies:` and fail if present.
- **Exactly five packages** under `packages/` — a sixth needs an ADR.

## What is NOT a boundary bug

- A feature reading a **shared repository** from `data`, or a value object/engine from `core` — that
  is the intended path.
- Navigating to another feature's screen **by route ID** (`const VehicleDetailRoute(vehicleId: id).go(context)`)
  — allowed; it carries no compile-time coupling.
- A use-case in `application/` composing two repositories **within one feature** — allowed once logic
  spans repos.

## Local run

`scripts/check_boundaries.sh` runs codegen freshness, `dart format` check, `flutter analyze`, the
Directional-geometry grep, the silent-swallow grep, the src/-import grep, the no-telemetry lockfile
scan, and the `resolution: workspace` check, printing a per-check PASS/FAIL summary to stdout. The
DB-header assertion runs as a Dart test (`flutter test --name db_header`) — the script reminds you to
run it since it needs the test harness.
