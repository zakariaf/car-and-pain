# Workspace + Melos: responsibilities and edge cases

## Two mechanisms, one job each

| Concern | Owner | Notes |
| --- | --- | --- |
| Local path linking of members | **pub workspace** | `resolution: workspace` on every member + `workspace:` list at root. Pub produces ONE shared `pubspec.lock`. |
| Script running (`gen`/`format`/`analyze`/`test`) | **Melos** | `melos run <script>` fans a command across filtered packages. |
| Change-based CI selection | **Melos** | `melos ... --since` / packageFilters keep PR CI fast. |
| Versioning helpers | **Melos** | convenience only; app versioning is `x.y.z+BUILD` with BUILD from CI. |

Requires **Dart 3.6+** and **Melos 6.x+**. Never use `melos bootstrap` to link
paths — that is the pre-workspace mechanism and mixing it with
`resolution: workspace` causes duplicate/inconsistent resolution. In this repo
`melos bootstrap` is effectively a no-op wrapper around `dart pub get`; the
linking is pub's.

## Root workspace pubspec

```yaml
# /pubspec.yaml
name: car_and_pain_workspace
environment:
  sdk: ^3.6.0        # the VERIFIED current-stable pinned at kickoff
workspace:
  - apps/car_and_pain
  - packages/core
  - packages/data
  - packages/notifications
  - packages/l10n
  - packages/design_system
```

## New-member checklist

1. Add the path to the root `workspace:` list.
2. In the member pubspec set:
   - `resolution: workspace`
   - an SDK constraint compatible with the root (`sdk: ^3.6.0`)
   - `flutter:` dependency ONLY if the package needs Flutter (`core` is pure
     Dart — no Flutter/plugin/IO deps).
3. Expose a single barrel `lib/<name>.dart` with `export 'src/...' show ...`;
   keep `src/` private-by-convention. Never import another package's `src/`.
4. If it carries annotations, add a scoped `build.yaml`
   (see `codegen-build-runner.md`).
5. Run `dart pub get` at the root, then `melos run gen`.

## FVM SDK pinning

- `.fvmrc` pins the verified current-stable Flutter/Dart at kickoff.
- Run tooling through FVM (`fvm flutter ...`, `fvm dart ...`) so local matches
  CI.
- CI's `subosito/flutter-action` `flutter-version` MUST equal the `.fvmrc`
  version. A drift here reproduces "works on my machine" codegen/format churn.
- Commit for reproducibility: `.fvmrc`, `pubspec.lock`, `Podfile.lock`,
  `Gemfile.lock`, `.ruby-version`. Pin the Android toolchain via the Gradle
  wrapper and the Xcode version in the macOS job.

## The dependency DAG (must stay acyclic)

```
design_system ─► core, l10n
data          ─► core
notifications ─► core
core          ─► (nothing internal)
apps/car_and_pain ─► all five packages
```

Feature folders never import another feature — share via `core`/`data` or
navigate by route ID. `custom_lint` enforces the no-cross-feature-import and
no-Drift-class-in-UI rules.

## Resolution-failure edge cases

| Symptom | Cause | Fix |
| --- | --- | --- |
| Member's changes not seen; stale package resolved | member missing `resolution: workspace` | add it, re-run `dart pub get` at root |
| `version solving failed` on `dart pub get` | member SDK constraint incompatible with root | align `environment.sdk` across members |
| Two lockfiles appear | a `dart pub get` was run inside a package dir before workspace was set up, or a stray per-package lockfile committed | delete the per-package lockfile; only the root `pubspec.lock` is tracked |
| Duplicate/inconsistent dependency versions | `melos bootstrap` path-linking mixed with workspace linking | remove Melos bootstrap linking; let pub link |
| Codegen output stale across packages | ran `build_runner` inside one package only | run `melos run gen` (root) so all packages regenerate together |
