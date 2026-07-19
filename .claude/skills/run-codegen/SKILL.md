---
name: run-codegen
description: >-
  Runs the deterministic build_runner codegen pass for the Car and Pain Flutter
  Melos workspace so Drift (drift_dev, SQLCipher/sqlite3mc encrypted DB),
  Freezed, json_serializable, Riverpod (riverpod_generator), and gen-l10n ARB
  output regenerate together in one pass. All generated code is gitignored
  (*.g.dart, *.freezed.dart, *.drift.dart, l10n generated), so this MUST run
  before flutter analyze on every fresh clone, after pulling, and after editing
  any annotated source; otherwise the analyzer emits confusing "missing part
  file" and undefined-class errors. Manual-only side-effecting workflow.
  Use when regenerating codegen, fixing missing part-file or undefined
  generated-class analyzer errors, after editing a Drift table or DAO, a Freezed
  value object, a Riverpod Notifier or provider, a json_serializable backup
  model, or an l10n ARB, or after a fresh git clone or branch switch.
disable-model-invocation: true
metadata:
  project: car-and-pain
  source-doc: docs/flutter/12-build-ci-release.md
---

# Run codegen (build_runner)

Regenerate all gitignored generated code for the Car and Pain workspace in one
deterministic pass. This is a **manual, low-freedom** workflow: run the pinned
command exactly as written. Do not modify the command, add flags, or hand-edit
generated files.

## Non-negotiable rules

- **Run codegen FIRST, before `flutter analyze` / `melos run analyze`.** Generated
  code is gitignored, so a fresh clone or a freshly edited annotated file has no
  `*.g.dart` / `*.freezed.dart` / `*.drift.dart` / gen-l10n output on disk.
  Analyzing that tree produces misleading "missing part file" and
  undefined-class errors — regenerate, then analyze.
- **Run at the workspace root.** Drift, Freezed, Riverpod, json_serializable, and
  gen-l10n all regenerate together in a single pass across `apps/*` and
  `packages/*`. Do not run per-package unless deliberately scoping (see below).
- **Never commit generated code.** `.gitignore` excludes `*.g.dart`,
  `*.freezed.dart`, `*.drift.dart`, and the gen-l10n output; regenerate is the
  single source of truth. Never `git add -f` a generated file.
- **Never hand-edit a generated file.** Change the annotated source (Drift table,
  Freezed class, Riverpod Notifier, ARB) and rerun codegen.
- **Use the pinned command verbatim** — always `--delete-conflicting-outputs`.
  Stale outputs from a renamed/deleted source otherwise collide and fail the run.

## The canonical command

Run from the repository root (`car-and-pain/`):

```bash
dart run build_runner build --delete-conflicting-outputs
```

Equivalent Melos wrapper (defined in `melos.yaml`, scoped to packages that
depend on `build_runner`):

```bash
melos run gen
```

Prefer `melos run gen` when Melos is bootstrapped; both regenerate the same
outputs. This is the first step in every CI lane and on every fresh clone,
before `melos run format` and `melos run analyze`.

## Standard sequence on a fresh clone or after pull

1. `melos bootstrap` (link the pub workspace) — if not already bootstrapped.
2. `dart run build_runner build --delete-conflicting-outputs` (or `melos run gen`).
3. Only then `flutter analyze` / `melos run analyze`.

## Dev iteration (optional watch)

For an active edit loop on annotated sources, run the watcher instead of a
one-shot build; it rebuilds affected outputs on save:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

Use `--watch` only during local development. CI and the pre-analyze step always
use the one-shot `build` command, never `watch`.

## Per-package builder scoping

Builders are scoped per package via each package's `build.yaml` (for example
`packages/data/build.yaml` restricts `drift_dev` to `lib/src/db/**.dart` and
`json_serializable` to `lib/src/backup/**.dart`) so editing one feature does not
regenerate all modules. To regenerate a single package during development, run
the same command from that package directory. The root-level pass remains the
canonical full regeneration and the CI/clone default.

See `references/troubleshooting.md` for error-to-fix mapping and the full
generator inventory.
