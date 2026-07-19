# Codegen troubleshooting & generator inventory

## Generators that flow through this one pass

| Source you edited | Generator | Output (gitignored) |
| --- | --- | --- |
| Drift table / DAO / migration (`packages/data`, encrypted SQLite via sqlite3mc/SQLCipher) | `drift_dev` | `*.drift.dart` |
| Freezed value object, Result/Failure, sealed union (`packages/core`) | `freezed` | `*.freezed.dart` |
| Riverpod Notifier / provider annotation | `riverpod_generator` | `*.g.dart` |
| json_serializable backup/export model (`packages/data` backup engine) | `json_serializable` | `*.g.dart` |
| ARB translation file (`packages/l10n`) | gen-l10n (`flutter gen-l10n` / build integration) | l10n generated Dart |

All regenerate together from the root `build_runner build` pass.

## Error → fix

- **"Missing part file" / "Target of URI hasn't been generated"** → codegen never
  ran (fresh clone, branch switch, or newly annotated source). Run
  `dart run build_runner build --delete-conflicting-outputs` first, then analyze.
- **"Undefined class `_$Foo` / `$FooTable`"** → same cause; the generated part is
  absent. Regenerate.
- **"Conflicting outputs" / build fails on a renamed or deleted source** → a stale
  generated file collides. The pinned `--delete-conflicting-outputs` flag clears
  it; ensure you are using the full command.
- **Analyzer errors on generated files themselves** → generated globs are excluded
  in `analysis_options.yaml` (`**/*.g.dart`, `**/*.freezed.dart`, `**/*.drift.dart`,
  `**/l10n/generated/**`). If they surface, verify that exclude block is intact
  rather than editing generated code.

## Reminders

- Generated code is never committed; regenerate is the single source of truth.
- Never hand-edit generated output — change the annotated source and rerun.
- CI order is fixed: `gen` → `format` → `analyze` → `test`. Codegen is always first.
- Use `watch` only for local dev loops; CI and pre-analyze use one-shot `build`.
