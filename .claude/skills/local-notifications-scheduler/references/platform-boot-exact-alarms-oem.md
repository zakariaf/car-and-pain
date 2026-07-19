# Platform: boot re-arm, exact alarms, OEM survival

The honest per-platform reliability story. **App-foreground reconcile is the guaranteed path; everything below is best-effort.** No FCM, no server, no account, no telemetry — so there is no way to learn that a reminder was dropped except the next foreground reconcile diff. Do not collapse the two platforms into one mechanism — that reasoning is factually wrong.

## Per-platform reboot re-arm

- **Android:** `BOOT_COMPLETED` fires **post-unlock** (not direct-boot). The plugin's `ScheduledNotificationBootReceiver` rehydrates pending; the app-open reconcile corrects drift. The DB key is stored with the `AfterFirstUnlock` accessibility class so the receiver-equivalent flow can read it while locked. Also handle `QUICKBOOT_POWERON`.
- **iOS:** the app runs **no boot code**. Scheduled notifications persist in the OS across reboot; projection re-arm happens **only on next foreground**. iOS has no OEM-killer problem but the 64-cap is silent and permission is provisional — a wholly different survival story.

## Exact-alarm strategy

```dart
final canExact = await androidImpl.canScheduleExactAlarms();
final mode = canExact
    ? AndroidScheduleMode.exactAllowWhileIdle
    : AndroidScheduleMode.inexactAllowWhileIdle; // day-granular default
```

- Default is `inexactAllowWhileIdle` — permission-free and pierces Doze at day granularity.
- `SCHEDULE_EXACT_ALARM` is **user-revocable, NOT pre-granted on Android 13+ fresh installs, and DENIED after a backup-restore**. When revoked the plugin just logs an error and recurring reminders silently stop. Re-check on resume and reconcile with silent fallback to inexact. Re-request only on the opt-in "precise reminders" toggle, never silently.
- **Never** declare `USE_EXACT_ALARM`. It is auto-granted and non-revocable but Google Play restricts it to alarm-clock/timer/calendar apps; declaring it in a maintenance app risks rejection.

## Android manifest & Gradle (survival prerequisites)

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/> <!-- optional toggle -->
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
<!-- NEVER: android.permission.USE_EXACT_ALARM -->

<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```

```gradle
android {
  compileSdk 35
  compileOptions { coreLibraryDesugaringEnabled true }  // REQUIRED or scheduling silently breaks
}
dependencies { coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.x' }
```

`coreLibraryDesugaringEnabled` is mandatory — omit it and the Android build fails or scheduled notifications silently break. The current FLN major also needs AGP 8.11+, Java 17, compileSdk 35+.

## WorkManager tick

Android-only, best-effort **daily re-projection tick**. Not a delivery guarantee — iOS `BGTaskScheduler` is opportunistic and frequently never runs; aggressive OEMs throttle the periodic job. It only re-triggers a reconcile when the app cannot come to foreground; it never replaces the foreground reconcile.

## Background isolate + encrypted DB

The `@pragma('vm:entry-point')` tap/action handler runs in a **separate isolate with no main-isolate state**. Do NOT write to the SQLCipher DB from it — concurrent encrypted-DB access from two isolates risks corruption. Record a lightweight pending-action intent (or nothing) and act on the next foreground reconcile. Construct any in-isolate infra via top-level factories with the DB key passed in from the main isolate.

## Channels, grouping, actions

- Create channels up front **by urgency** — `service_due`, `document_expiry`, `overdue` (high importance), plus `due_soon`/`info`. **Sound/vibration/importance is immutable after first creation** — version the channel ID if behavior must change.
- **Group by vehicle:** Android `groupKey = vehicleId` + a group-summary; iOS `threadIdentifier = vehicleId`. Multi-vehicle owners get per-car threads.
- Collapse a busy day's items into one grouped **digest** instead of a dozen buzzes. Honor **quiet hours** (local time) and a preferred delivery time.
- Actions resolve without opening the app: **"Mark done"** (logs completion + arms next interval, re-anchored to actual completion date/odometer) and **"Snooze 1 week / 500 km"** (distance snooze is data-triggered by the next reading).
- iOS `UNTimeIntervalNotificationTrigger` must be ≥ 60 s — prefer concrete one-shots for projected reminders.

## OEM survival matrix (manual, never faked)

OEM battery-killers drop AlarmManager alarms, block the boot receiver, and kill WorkManager. This **cannot be fully fixed in code** — autostart/battery exemption on MIUI in particular is user-settings-only. The only durable mitigation is guiding the user to the right settings screen (see `docs/flutter/16-permissions-onboarding-oem.md`). Foreground reconcile is the only dependable recovery.

| OEM family | Manufacturer strings | Guidance |
| --- | --- | --- |
| Xiaomi / MIUI | xiaomi, redmi, poco | `miui.intent.action.OP_AUTO_START`; text fallback + `openAppSettings()` |
| Huawei / EMUI | huawei, honor | `huawei.intent.action.HSM_PROTECTAPP` protected-app |
| OPPO/OnePlus / ColorOS | oppo, realme, oneplus | ColorOS autostart copy; no reliable intent |
| Samsung | samsung | "Sleeping apps" / battery copy |
| Stock / AOSP | others | battery-optimization dialog is enough |

- Deep-link intents are version-fragile — **always** ship a localized text fallback and wrap the launch in try/catch degrading to `openAppSettings()` plus a link to `dontkillmyapp.com`.
- Battery-exemption granted ≠ background guaranteed; some OEMs re-enable optimization after an OS update. Re-surface a gentle nudge when the foreground reconcile diff suggests reminders were missed.
- **Emulators lie about survival.** Reboot/Doze/OEM-killer behavior is green-lit only on the real device matrix: Xiaomi/MIUI, Huawei, Samsung, OnePlus × battery-optimization ON/OFF × killed-from-recents × after reboot × after 24 h idle. Track "fired vs expected" during dogfooding as the real reliability metric.
