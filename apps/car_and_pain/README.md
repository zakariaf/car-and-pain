# car_and_pain (app shell)

The thin runnable Flutter shell. Two flavor entrypoints call a shared
`bootstrap()` composition root, which installs the global error handlers, opens
infrastructure via the startup gate, and runs the single `GoRouter`. Feature
work lives in `lib/src/features/NN-*/` folders; cross-cutting concerns live in
the `packages/*` foundations.

## Flavors

Exactly two — `dev` and `prod` — for **side-by-side install** and **distinct
notification channel ids**, never API config (there is no backend). `dev` gets a
`.dev` applicationId suffix and a flavor-scoped DB filename so it never touches
prod data.

| Flavor | Entrypoint | Android appId | Label |
| --- | --- | --- | --- |
| dev  | `lib/main_dev.dart`  | `com.carandpain.car_and_pain.dev` | Car&Pain Dev |
| prod | `lib/main_prod.dart` | `com.carandpain.car_and_pain`     | Car & Pain |

### Run / build

```bash
flutter run   --flavor dev  -t lib/main_dev.dart
flutter run   --flavor prod -t lib/main_prod.dart
flutter build appbundle --flavor prod -t lib/main_prod.dart \
  --obfuscate --split-debug-info=build/symbols/<tag> \
  --build-number=$GITHUB_RUN_NUMBER
```

The Flutter/Dart SDK is pinned in `.fvmrc` at the repo root (Flutter 3.44.6).

### iOS flavor schemes (manual Xcode step — TODO)

Android flavors are fully wired in `android/app/build.gradle.kts`. iOS flavor
schemes require Xcode project edits that can't be scripted safely:

1. In Xcode → Runner target → duplicate the build configs into
   `Debug-dev`/`Release-dev`/`Profile-dev` and `…-prod` (lowercase suffixes
   matching `--flavor`).
2. Create shared schemes `dev` and `prod` selecting those configs.
3. Drive the bundle-id suffix from a build setting and add `PrivacyInfo.xcprivacy`
   (already in `ios/Runner/`) to the target's "Copy Bundle Resources".

Until then, iOS builds run single-config: `flutter run -t lib/main_dev.dart`.

## Structure

```
lib/
├── main_dev.dart / main_prod.dart   # flavor entrypoints → bootstrap()
└── src/
    ├── bootstrap.dart               # composition root + global error trio
    ├── app.dart                     # MaterialApp.router (theme, l10n, router)
    ├── flavor.dart                  # Flavor enum + flavorProvider
    ├── routing/app_router.dart      # the single GoRouter
    ├── startup/                     # startup state machine (splash/error/ready)
    ├── shell/home_screen.dart       # F1 placeholder home (M1 replaces it)
    ├── settings/locale_controller.dart
    ├── logging/app_log.dart         # local-only logger (no telemetry)
    └── features/NN-*/               # ~25 feature folders (presentation/application/domain)
```

## Compliance

Launch-blocking privacy artifacts live in `compliance/` and
`ios/Runner/PrivacyInfo.xcprivacy`. The release manifest omits `INTERNET`; CI
scans enforce no-telemetry and no-INTERNET.
