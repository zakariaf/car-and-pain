# Flavors and the three blocking CI gates

## Flavors: install-isolation, not endpoints

Exactly two flavors, `dev` and `prod`. They exist so both builds install
side-by-side and a dev build's scheduled reminders never collide with prod's on
one physical device — driven by **distinct notification channel IDs and
request-code ranges**, NOT API config (there is no backend). Never add a
`staging` flavor; use the stores' internal/TestFlight tracks for beta.

### Android

```kotlin
// apps/car_and_pain/android/app/build.gradle.kts
flavorDimensions += "default"
productFlavors {
    create("dev")  { dimension = "default"; applicationIdSuffix = ".dev"
                     resValue("string", "app_name", "Car&Pain Dev") }
    create("prod") { dimension = "default"
                     resValue("string", "app_name", "Car & Pain") }
}
```

The dev flavor omits the `INTERNET` permission so the OS itself enforces the
offline claim.

### iOS traps

- Config names must be **lowercase** and match `--flavor` (`dev`/`prod`).
- Schemes MUST be marked **"Shared"** or CI cannot select them.
- The Podfile project-config map must list every
  `Debug-/Profile-/Release-<flavor>` or `pod install` breaks.

### Entrypoints

Two thin entrypoints call one shared `bootstrap`; the flavor is read from the
compile-time `appFlavor` const (`package:flutter/services.dart`). No third-party
flavor package. `bootstrap` derives `reminders_${appFlavor}` channel IDs.

## Versioning and release build

Keep `version: x.y.z+BUILD`; inject BUILD from CI so it is unique and monotonic.

```bash
flutter build appbundle --flavor prod -t apps/car_and_pain/lib/main_prod.dart \
  --build-name="$GIT_TAG" \
  --build-number="$GITHUB_RUN_NUMBER" \
  --obfuscate --split-debug-info=build/symbols/"$GIT_TAG"
```

Never hand-bump `+N` (causes `version already exists` rejections). Always
archive the `--split-debug-info` directory per tag — it is the ONLY
symbolication path; there is no crash SaaS. Obfuscating without archiving makes
crashes permanently unreadable.

## CI topology

| Pipeline | Runner | Trigger | Does |
| --- | --- | --- | --- |
| `pr.yml` | `ubuntu-latest` | every PR | gen → format → analyze → test → gates → Android smoke build |
| `release.yml` | `macos-latest` | tags `v*` | gen → real-font golden lane → iOS build (obfuscated) → fastlane beta → archive symbols |

ubuntu is ~10x cheaper; iOS builds are gated to tags so PRs never burn macOS
minutes. `flutter-action` version must match `.fvmrc`.

## The three blocking gates

### 1. No-telemetry lockfile scan

`dart run tool/scan_no_telemetry.dart` fails the build if any analytics or crash
SDK appears in `pubspec.lock` (firebase_analytics, sentry, crashlytics, mixpanel,
amplitude, datadog, posthog, etc.). Backs the no-telemetry store privacy
declarations. The dev flavor's omitted `INTERNET` permission is the runtime
counterpart. `scripts/scan-no-telemetry.sh` is a grep-based stand-in.

### 2. DB header is not plaintext

A blocking test opens the raw DB file and asserts the first 16 bytes do NOT
decode to `SQLite format 3` — proving SQLCipher encryption is real at rest. A
plaintext DB fails the build.

```dart
final header = File(dbPath).openSync().readSync(16);
expect(utf8.decode(header, allowMalformed: true),
    isNot(startsWith('SQLite format 3')));
```

Guard at kickoff: confirm no dependency pulls a plaintext `sqlite3` library that
wins the native link over `sqlcipher_flutter_libs` / `sqlite3mc`.

### 3. Backup round-trip deep-equal

Export the whole DB to the single-file backup, wipe the database, import the
backup, and assert the restored DB is **deep-equal** to the original — with
**WAL active**. Proves backup/export/recovery is lossless across every table
(backup is a `data`-package concern that reads across all tables, never
per-feature).

## Non-CI blocking checks (also tests)

- **Directional-geometry grep** rejects `EdgeInsets.only(left/right)`,
  `Alignment.centerLeft`, `Positioned(left:)`, `TextAlign.left/right` in feature
  and design code — RTL discipline.
- **`dart format --set-exit-if-changed`** and **`flutter analyze --fatal-infos`**
  block on any diff / any info.
- **Coverage** enforced at 100% only on logic packages (`core`, the pure
  scheduler in `notifications`) via Very Good Coverage; ratchet elsewhere.
