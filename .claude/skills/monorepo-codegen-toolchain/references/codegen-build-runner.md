# Codegen with build_runner: scoping, gitignore, recovery

## The generators in play

| Generator | Emits | Annotation / trigger | Lives in |
| --- | --- | --- | --- |
| `drift_dev` | `*.drift.dart` | `@DriftDatabase`, `@DriftAccessor`, table classes | `packages/data` |
| `freezed` | `*.freezed.dart` | `@freezed` domain/value models | `core`, feature `domain/`, backup DTOs |
| `json_serializable` | `*.g.dart` | `@JsonSerializable` (backup/export single-file DTOs) | `packages/data`, `core` |
| `riverpod_generator` | `*.g.dart` | `@riverpod` Notifiers / providers | app feature `presentation/`, packages |
| `gen-l10n` | generated l10n Dart | ARB files + `l10n.yaml` | `packages/l10n` |

`build_runner` at the workspace root regenerates drift/freezed/riverpod/json in
one pass. gen-l10n runs via the Flutter tool (`flutter gen-l10n`) but its output
is treated identically: gitignored, regenerated first.

## Gitignore list (never commit these)

```
**/*.g.dart
**/*.freezed.dart
**/*.drift.dart
**/*.mocks.dart
packages/l10n/lib/src/generated/**   # gen-l10n output
```

The same globs are excluded from analysis in `analysis_options.yaml` so the
analyzer never lints machine output. Committing generated files causes noisy
reviews, merge conflicts in generated code, and silent drift from annotations —
gitignore + regenerate is the single source of truth.

## Per-package builder scoping

Fence each builder to the directories that actually own the annotations so a
change in one feature does not regenerate all 25.

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

Rules of thumb:

- Give every codegen-carrying package its own `build.yaml`; do not rely on a
  single root config to fan out to all annotations.
- `generate_for:` globs should point at the narrowest directory that owns the
  annotation (`lib/src/db/**`, `lib/src/backup/**`, `presentation/**`).
- Keep `riverpod_generator` scoped to the feature `presentation/` dirs and
  package sources that declare `@riverpod`.
- A root `build.yaml` may hold shared options; per-package files override scope.

## The regenerate loop (manual — see run-codegen skill)

```bash
# from the repo root
dart run build_runner build --delete-conflicting-outputs
# or, filtered to packages that depend on build_runner:
melos run gen
```

Always pass `--delete-conflicting-outputs`; stale part files from a renamed
class otherwise block the build. Use `watch` only for tight local loops, never
in CI.

## Fresh clone / CI ordering

`build_runner` is the FIRST step, before `analyze`, on every fresh clone and in
every pipeline. Because generated files are gitignored, a clean checkout has
`part '...';` directives pointing at files that do not exist yet.

**Fixed order:** `gen` → `format` → `analyze` → `test` → gates → smoke build.

## Error recovery table

| Error | Real cause | Fix |
| --- | --- | --- |
| `Missing part 'foo.g.dart'` / `part file` errors | codegen not run on a fresh/gitignored tree | run `melos run gen` first — do NOT create the file by hand |
| `Undefined class _$Foo` / `_Foo` | freezed/json output stale or absent | regenerate with `--delete-conflicting-outputs` |
| `Conflicting outputs` on build | leftover generated file from a rename | `--delete-conflicting-outputs` (already default in `melos run gen`) |
| Analyzer flags generated file | glob missing from `analysis_options.yaml exclude` | add the `**/*.<kind>.dart` glob |
| Only one package regenerated | ran `build_runner` inside a package dir | run at the root via `melos run gen` |
| gen-l10n output missing | `flutter gen-l10n` not run / `l10n.yaml` misconfigured | run gen-l10n; verify ARB template + output-dir |
