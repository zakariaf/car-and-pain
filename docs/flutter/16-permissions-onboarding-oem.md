# 🛡️ Permissions, Onboarding & OEM Survival

> This document governs the guided permission/onboarding flow and the honest, per-platform strategy for surviving OEM battery-killers so that reminders actually fire.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · see also **[Local Notifications & Background Reliability](./07-notifications.md)**, **[Security, Privacy & At-Rest Encryption](./09-security-privacy.md)**, and the product spec **[Reminders & Notifications (product)](../features/04-reminders-notifications.md)**.

## Decision

The permissions/onboarding surface is a **first-class delivery-reliability feature**, not a startup nag. A guided flow built on `permission_handler` (^12.x) requests notification access and, optionally, exact-alarm access with a plain-language rationale, then walks the user through **battery-optimization exemption** (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) and **OEM autostart/protected-app** screens using device-specific deep links where they exist. The flow also hosts `local_auth` app-lock setup. The single organizing truth, stated to the user in words: **foreground reconcile is the one guaranteed delivery path; everything else is best-effort.** This flow pairs with — and is validated by — a documented **manual OEM QA matrix** (Xiaomi/MIUI, Samsung, Huawei, Oppo), never a fabricated emulator "pass."

## Why

OEM battery-killers (Huawei EMUI, Xiaomi MIUI, OnePlus/OPPO ColorOS, Samsung) silently kill background alarms, block boot receivers, and throttle WorkManager. This **cannot be fully fixed in code** — autostart and battery exemption on MIUI in particular are user-settings-only and can never be programmatically granted. The only durable software mitigation is *guiding the user to the right settings screen*. Burying that guidance in a QA checklist means real users never find it, so reminders quietly stop and — with no telemetry and no server — we never learn.

Alternatives considered and rejected (from the research):

- **Treat battery-optimization as a QA-matrix line item only** — rejected: users never discover the setting; the survival problem is left unaddressed for the people who bought the app.
- **Assume background alarms are reliable on OEM Android** — rejected: empirically false on the exact device families our audience owns.
- **A single generic "Allow notifications?" prompt with no OEM guidance** — rejected: gets the runtime permission but leaves every downstream killer in place.
- **Declare `USE_EXACT_ALARM` for guaranteed minute-precise firing** — rejected: Google Play restricts it to alarm-clock/timer/calendar apps and it risks store rejection for a maintenance app. We use the permission-free `inexactAllowWhileIdle` path by default and offer exact only behind the user-revocable `SCHEDULE_EXACT_ALARM`.

## How we do it

### Package list

```yaml
dependencies:
  permission_handler: ^12.x   # notification, scheduleExactAlarm, ignoreBatteryOptimizations
  local_auth: ^3.x            # biometric + device-credential app lock
  local_auth_android: ^3.x
  local_auth_darwin: ^3.x
  # notification engine lives in packages/notifications (see 07-notifications.md)
```

### Where it lives

The onboarding flow is feature folder `24-permissions-onboarding` (presentation + application only). All *decisions* about what to request and how to degrade live in a pure, clock-free `OnboardingPlan` in `application/`; the actual OS calls sit behind narrow ports so the flow is unit-testable without a device.

```text
lib/src/features/24-permissions-onboarding/
  application/
    onboarding_plan.dart        # pure: which steps apply on this OS/OEM, in order
    permission_gateway.dart     # port over permission_handler (real + fake)
    oem_guidance.dart           # pure: OEM detection -> deep-link intent + copy key
  presentation/
    view/onboarding_flow_view.dart
    permissions_onboarding_notifier.dart   # AsyncNotifier, ProviderContainer-testable
```

### The step sequence (best-effort, resumable, skippable)

Every step is **optional and re-entrant** — the user can skip and revisit from Settings, and the flow re-checks live status on each foreground (permissions can be revoked externally). Order matters: ask for the cheap, high-value runtime permission first.

1. **POST_NOTIFICATIONS** (Android 13+) / iOS provisional authorization — with a *pre-prompt rationale screen* before the OS dialog, so a reflexive "Deny" doesn't permanently poison the request.
2. **Battery-optimization exemption** — explain in one sentence why, then trigger the system dialog.
3. **OEM autostart / protected-app** — only shown when we detect a known aggressive OEM; deep-link to the specific settings page.
4. **Exact alarms (optional)** — a "precise reminders" toggle, off by default. Only surfaced if the user opts in.
5. **App lock (optional)** — `local_auth` enrollment (see below).

### Permission gateway (port)

```dart
abstract class PermissionGateway {
  Future<PermStatus> notificationStatus();
  Future<PermStatus> requestNotification();
  Future<bool> isBatteryOptimizationDisabled();
  Future<bool> requestIgnoreBatteryOptimizations();
  Future<PermStatus> scheduleExactAlarmStatus();
  Future<PermStatus> requestScheduleExactAlarm();
}

class RealPermissionGateway implements PermissionGateway {
  @override
  Future<PermStatus> requestNotification() =>
      Permission.notification.request().then(_map);

  @override
  Future<bool> isBatteryOptimizationDisabled() =>
      Permission.ignoreBatteryOptimizations.isGranted;

  @override
  Future<bool> requestIgnoreBatteryOptimizations() =>
      Permission.ignoreBatteryOptimizations.request().isGranted;
  // ...
}
```

Every request returns a **typed status** the UI switches on exhaustively (see [Error Handling & Never-Lose-Data](./08-error-handling.md)); a permanently-denied result routes to `openAppSettings()` with localized copy, never a dead end.

### OEM guidance & deep links

Detect the manufacturer (e.g. via `device_info_plus`) and map it to the correct settings intent plus a localized instruction key. Where no reliable deep link exists (MIUI autostart varies by version), fall back to `openAppSettings()` plus step-by-step localized text and a link to `dontkillmyapp.com`.

```dart
OemGuidance? guidanceFor(String manufacturer) => switch (manufacturer.toLowerCase()) {
  'xiaomi' || 'redmi' || 'poco' => OemGuidance(
      intent: 'miui.intent.action.OP_AUTO_START',
      copyKey: 'oem_autostart_miui'),
  'huawei' || 'honor'          => OemGuidance(
      intent: 'huawei.intent.action.HSM_PROTECTAPP',
      copyKey: 'oem_protected_huawei'),
  'oppo' || 'realme' || 'oneplus' => OemGuidance(copyKey: 'oem_autostart_coloros'),
  'samsung'                    => OemGuidance(copyKey: 'oem_sleeping_apps_samsung'),
  _ => null, // stock/AOSP: battery-optimization dialog is enough
};
```

Deep-link intents are inherently version-fragile; **always** ship a text fallback and never assume the intent resolves. Wrap the launch in a try/catch that degrades to `openAppSettings()`.

### `local_auth` setup realities (the load-bearing gotchas)

- **Android needs `FlutterFragmentActivity`, not `FlutterActivity`.** `local_auth` uses a `BiometricPrompt` that requires a `FragmentActivity` host. Ship this from module #1 — retrofitting it later touches `MainActivity`, the manifest, and every plugin that assumes the default activity.

  ```kotlin
  // android/app/src/main/kotlin/.../MainActivity.kt
  import io.flutter.embedding.android.FlutterFragmentActivity
  class MainActivity : FlutterFragmentActivity()
  ```

- **Always allow the device-credential fallback:** `authenticate(options: AuthenticationOptions(biometricOnly: false, stickyAuth: true))`. Biometric-only locks users out permanently when nothing is enrolled or after lockout — fatal for offline, account-free data with no recovery channel.
- **Enrollment invalidation:** adding/removing a fingerprint or Face ID can invalidate Keystore-bound keys. Because the DB master key is **recoverable by default** (passphrase-wrapped or recovery code — see [Security, Privacy & At-Rest Encryption](./09-security-privacy.md)), an enrollment change degrades to the recovery path, never to data loss. `local_auth` is only a UI gate; the passphrase/Argon2id KEK wrap is what makes the lock cryptographically real.
- iOS requires `NSFaceIDUsageDescription`; Android requires `USE_BIOMETRIC`.

### Android manifest & Gradle (survival prerequisites)

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
<!-- Do NOT declare USE_EXACT_ALARM (Play policy risk) -->
```

`coreLibraryDesugaringEnabled true` plus the desugaring dependency are mandatory or scheduled notifications silently break. See [Local Notifications & Background Reliability](./07-notifications.md) for the boot receiver and the notification engine itself.

## Rules

- **Do** frame the whole surface honestly: foreground reconcile is guaranteed; background is best-effort. This exact sentence appears in the UI, localized in all six languages.
- **Do** show a rationale screen *before* every OS permission dialog. **Don't** fire a cold OS prompt on first launch.
- **Do** make every step skippable and re-checkable from Settings; **don't** hard-gate app usage behind any permission except the app-lock the user themselves enabled.
- **Do** use `FlutterFragmentActivity` on Android from day one. **Don't** use `FlutterActivity` if `local_auth` is in the app.
- **Do** default to `AndroidScheduleMode.inexactAllowWhileIdle`; offer exact only behind an opt-in toggle guarded by `canScheduleExactAlarms()`. **Never** declare `USE_EXACT_ALARM`.
- **Do** always pair `local_auth` with `biometricOnly: false` and an app-defined PIN escape path. **Never** ship biometric-only.
- **Do** always provide a localized text fallback + `openAppSettings()` for every OEM deep link. **Don't** assume an OEM intent resolves.
- **Do** re-check live permission status on every app foreground and reconcile notifications accordingly.
- **CI/lint:** the onboarding copy strings live in ARB and must exist in all six locales (missing-key check fails CI); permission-manifest entries are asserted in a build test.

## For Car and Pain specifically

- **Offline / no-telemetry:** we cannot use FCM push, so foreground reconcile *is* the reliability backbone and this onboarding flow is what makes it effective. There is no server to tell us a reminder was dropped, which is exactly why we invest in guiding the user to prevent drops. The flow makes zero network calls.
- **Notifications:** battery-exemption + autostart guidance directly protects the odometer-projection / engine-hour / date-based reminder engine described in [Local Notifications & Background Reliability](./07-notifications.md). After any backup import, permission state and exact-alarm grants do **not** survive — the flow re-checks and the engine runs a full `cancelAll()` + reconcile.
- **Canonical storage / recovery:** the app-lock never becomes a data-loss vector because the master key is recoverable by default; enrollment invalidation routes to recovery, keeping the "never lose an entry" principle intact.
- **RTL / i18n:** every rationale, OEM instruction, PIN pad, and biometric prompt string is localized (fa/ar/ckb RTL + en/de/fr LTR), mirrored, and rendered with the user's numerals. PINs are normalized to ASCII digits before storage — never locale-specific numerals. See [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md).

## Testing

- **Unit (pure, most confidence):** `OnboardingPlan` — assert the correct ordered step list per OS version and per OEM; assert stock/AOSP skips OEM steps. `guidanceFor()` — table-driven over manufacturer strings including unknown → `null`. Drive the flow's `AsyncNotifier` headlessly through a `FakePermissionGateway` in a `ProviderContainer`, asserting state transitions for grant / deny / permanently-denied / revoke-on-resume.
- **Widget/golden:** the rationale and OEM-instruction screens across locale × direction, plus a large-text-scale (textScaler 1.5–2×) dimension where tall Persian/Arabic glyphs and long German strings overflow. Mirror the PIN pad in RTL.
- **Integration (`integration_test` + Patrol):** Patrol drives the *native* permission dialogs — the one place OS behavior is real — asserting grant and deny paths and the `openAppSettings()` route. Assert app-lock: biometric success; biometric fail → PIN; nothing enrolled → PIN.
- **Manual OEM matrix (unavoidable, never faked):** Xiaomi/MIUI, Huawei, Samsung, OnePlus/OPPO × battery-optimization ON/OFF × app killed from recents × after reboot × after 24 h idle. Verify each in-app guidance link reaches the correct autostart/battery page for that OEM/version. Track "reminders fired vs expected" during dogfooding as the real reliability metric. See [Testing Strategy](./11-testing.md).

## Pitfalls

- **`SCHEDULE_EXACT_ALARM` is user-revocable, not pre-granted on Android 13+, and denied after a backup-restore.** When revoked, the plugin just logs and recurring reminders silently stop — always degrade to inexact, and re-request on the exact-alarm toggle, not silently.
- **A cold OS notification prompt that the user reflexively denies is expensive to recover from** — on Android a second automatic request is suppressed. Hence the pre-prompt rationale.
- **`FlutterActivity` + `local_auth` = runtime crash** on the biometric prompt. Easy to miss until a device test.
- **OEM autostart on MIUI cannot be granted programmatically** — no intent, no API; text guidance is the only tool. Don't promise more than "we'll take you to the setting."
- **Deep-link intents break across OEM OS versions.** Every one needs a `openAppSettings()` fallback in a try/catch.
- **Battery-exemption granted ≠ background guaranteed.** Some OEMs re-enable optimization after an OS update or when the app is unused for days. Re-surface a gentle nudge if reminders appear to be missing (detectable via the foreground reconcile diff), and keep the honest framing.
- **Emulators lie about survival.** Reboot/Doze/OEM-killer behavior can only be honestly green-lit on the real device matrix; never report an automated OEM pass.
- **iOS has no boot code and no OEM-killer problem**, but scheduled notifications silently cap at 64 and permission is provisional — the survival story is entirely different per platform and must not be collapsed into one.

## Decisions to confirm

- **Argon2id parameters for the PIN/passphrase KEK** that backs the app lock: settle the FFI/native library and device-calibrated memory/iteration params (with a low-end fallback), benchmarked on the slowest target device so unlock does not take multiple seconds or OOM. (Shared with [Security, Privacy & At-Rest Encryption](./09-security-privacy.md).)
- **Default key-recovery mechanism** (passphrase-wrap vs one-time recovery code vs both) and its exact first-run placement relative to the app-lock step in this flow — since recovery, not the lock, is the durability guarantee.

## Related

- [Local Notifications & Background Reliability](./07-notifications.md) — the reconcile engine, boot receiver, and exact-alarm degradation this flow feeds.
- [Security, Privacy & At-Rest Encryption](./09-security-privacy.md) — `local_auth` as a UI gate, the Argon2id KEK, and recoverable keys behind enrollment invalidation.
- [Backup, Export & Disaster Recovery](./13-backup-export-recovery.md) — why permission and exact-alarm state must be re-reconciled after every import.
- [Store Compliance, Privacy Declarations & Licensing](./17-store-compliance-licensing.md) — Play policy on exact alarms and the privacy declarations the omitted-permission posture backs.
- [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md) — localizing and mirroring every rationale, PIN pad, and OEM instruction.
- [Reminders & Notifications (product)](../features/04-reminders-notifications.md) — the product-side promise this reliability work upholds.
