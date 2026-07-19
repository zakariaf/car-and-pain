# 🔔 Local Notifications & Background Reliability

> This document governs how Car and Pain schedules, delivers, and reconciles every reminder entirely on-device — time, odometer-projection, and engine-hour triggers — with the encrypted database as the single source of truth and no server, push, or telemetry.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · See also **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)**, **[Permissions, Onboarding & OEM Survival](./16-permissions-onboarding-oem.md)**, and the product spec **[Reminders & Notifications (product)](../features/04-reminders-notifications.md)**.

## Decision

One notification engine, built on **`flutter_local_notifications` (pin the verified current-stable major at kickoff — treat "v22.x" as TBD; FLN bumps majors with breaking channel/permission APIs)** using `zonedSchedule` for both platforms, with `timezone` + `flutter_timezone` for DST-correct `TZDateTime` firing. The **encrypted SQLite DB is the source of truth**; the OS pending-notification set is a disposable cache we reconcile against. All three logical trigger types — TIME (expiry/"every 6 months"), DISTANCE ("oil at 15,000 km"), and ENGINE-HOUR ("service at 250 h") — collapse into **one TIME-scheduling path**: a pure, clock-injected `UsageProjector` converts distance/engine-hour targets into a concrete future instant. The plugin lives behind a `NotificationGateway` port; all math lives in a pure `ReminderScheduler`. Android defaults to `AndroidScheduleMode.inexactAllowWhileIdle` (permission-free, pierces Doze); exact firing is an optional toggle behind `SCHEDULE_EXACT_ALARM` — **we never declare `USE_EXACT_ALARM`**.

## Why

Our hard constraints — 100% offline, account-free, no telemetry, buy-once — **forbid FCM/server push**, which is normally the most reliable delivery path. That is not a gap to paper over; it is the fact the whole architecture is designed around. Since we cannot push, **the app-foreground reconcile IS the reliability backbone** and everything else (boot receiver, WorkManager tick, exact alarms) is explicitly best-effort.

Collapsing distance and engine-hour triggers into TIME instants keeps **one homogeneous, testable scheduling path** instead of three parallel mechanisms. Storing recurring schedules as wall-clock + recurrence rule (not UTC instants) is mandatory or every DST transition mis-fires day-granular maintenance reminders. Putting the plugin behind a port and the math in a pure scheduler makes the iOS 64-cap budgeting, projection fallback, clock-tamper handling, and reboot re-arm **fully unit-testable off-device**.

Alternatives considered and rejected:

- **FCM / server push** — the industry-standard reliable path, but requires a backend, network, and per-device tokens. Violates offline / account-free / no-telemetry outright. Its absence is *why* the reconcile architecture matters.
- **`android_alarm_manager_plus` as primary** — can run Dart at fire time even when killed, but is Android-only, does **not** auto-reschedule on reboot, and its background isolate would have to open the encrypted DB itself. Kept behind the port as a future escape hatch, not shipped.
- **`workmanager` as a delivery guarantee** — iOS `BGTaskScheduler` is opportunistic and frequently never runs; aggressive OEMs throttle the periodic job. Adopted only as an **Android best-effort** daily re-projection tick.
- **`USE_EXACT_ALARM`** — auto-granted and non-revocable, but Google Play restricts it to alarm-clock/timer/calendar apps; declaring it in a maintenance app risks store rejection.
- **Storing recurring schedules as UTC instants** — drifts across DST/timezone changes. Rejected in favor of wall-clock + rule resolved at (re)schedule time.
- **A full custom native platform-channel layer** — large two-platform maintenance surface that re-implements what FLN already does well. Documented escape hatch only.

## How we do it

### Package layout

The engine is a centrally-owned package with a narrow API — never per-feature code — because it must never diverge across the ~25 modules.

```text
packages/notifications/
  lib/
    src/
      gateway/
        notification_gateway.dart      # abstract port: schedule/cancel/cancelAll/getPending
        fln_notification_gateway.dart   # real adapter over flutter_local_notifications
        fake_notification_gateway.dart  # in-memory list, for tests
      scheduler/
        reminder_scheduler.dart         # PURE: compute(desired) -> reconcile diff
        usage_projector.dart            # PURE: distance/engine-hour -> TIME instant
        scheduled_notification.dart     # value object (id, when, channel, payload)
        deterministic_id.dart           # UUID + occurrence -> stable 32-bit id
      recurrence/
        recurrence_rule.dart            # wall-clock + rule + calendar -> TZDateTime
      boot/
        boot_rearm_android.dart         # BOOT_COMPLETED post-unlock re-arm
      clock_tamper_guard.dart           # monotonic guard for overdue detection
      factories.dart                    # isolate-safe top-level construction
  pubspec.yaml
```

`packages/core/` owns the pure `UsageProjector` math and the `Clock` port; `packages/notifications/` owns the gateway and scheduler wiring. Feature `04-reminders-notifications` reads reminders from the `data` package and calls one `syncNotifications()` entrypoint — it never touches the plugin directly.

### Dependencies

```yaml
dependencies:
  flutter_local_notifications: ^22.0.0   # PIN verified current-stable at kickoff
  timezone: ^0.10.0                      # TZDateTime for DST-correct zonedSchedule
  flutter_timezone: ^4.0.0               # read real device tz name -> tz.local
  permission_handler: ^12.0.0            # notification / scheduleExactAlarm / battery
  workmanager: ^0.9.0                    # Android-only best-effort re-projection tick
  # android_alarm_manager_plus: ^5.0.0   # OPTIONAL — keep uninstalled unless needed
```

### The port

```dart
abstract class NotificationGateway {
  Future<void> schedule(ScheduledNotification n);
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Future<List<PendingNotification>> getPending();
}
```

`FlnNotificationGateway` is the only class that imports `flutter_local_notifications`. Everything else — including all tests — talks to the port.

### The three triggers, one path

```dart
/// Pure: converts a distance/engine-hour target into a future instant, or a
/// reason it cannot be scheduled yet. No plugin, no IO, injected Clock.
sealed class Projection {}
class ProjectedAt extends Projection { final DateTime when; ProjectedAt(this.when); }
class InsufficientData extends Projection {}   // < minSamples, or unstable rate
class BeyondWindow extends Projection {}       // lands past the pending horizon

class UsageProjector {
  final Clock clock;
  final int minSamples;
  UsageProjector(this.clock, {this.minSamples = 3});

  Projection project({
    required List<Reading> history,   // odometer or engine-hour readings
    required num target,              // e.g. 15000 km, or 250 h
    required Duration horizon,        // pending-window horizon
    Duration leadTime = Duration.zero,
  }) {
    if (history.length < minSamples) return InsufficientData();
    final rate = _rollingRatePerDay(history);            // km/day or h/day
    if (rate <= 0) return InsufficientData();            // dormant / typo / decreasing
    final latest = history.last;
    if (latest.value >= target) return ProjectedAt(clock.now()); // already overdue
    final daysToTarget = (target - latest.value) / rate;
    final when = latest.at.add(Duration(
      milliseconds: (daysToTarget * Duration.millisecondsPerDay).round(),
    )).subtract(leadTime);
    if (when.difference(clock.now()) > horizon) return BeyondWindow();
    return ProjectedAt(when);
  }
}
```

Distance and engine-hour reminders are normalized to TIME instants before they reach the scheduler, so `ReminderScheduler` handles a single homogeneous list. A distance lead ("warn 500 km before") is converted to days via the same rate; a time lead ("2 weeks before") is subtracted directly.

### Wall-clock recurrence, not UTC

True instants (a fuel purchase) are UTC epoch millis. **Recurring schedules are stored as local wall-clock + recurrence rule + calendar** and resolved to a `TZDateTime` only at (re)schedule time:

```dart
// "09:00 every 6 months, Jalali calendar" -> the next concrete TZDateTime.
TZDateTime nextOccurrence(RecurrenceRule rule, TZDateTime after) {
  final civil = rule.nextCivilDateAfter(after, calendar: rule.calendar); // y/m/d/h/m
  return TZDateTime(tz.local, civil.year, civil.month, civil.day,
      rule.hour, rule.minute); // resolved in tz.local, DST-correct
}
```

The stored instant is *always* Gregorian `TZDateTime` for the OS; the displayed body is projected to the user's calendar. Storing the schedule as a UTC instant would silently shift a "9am" reminder by an hour across a DST boundary — banned.

### The reconcile (reliability backbone)

```dart
Future<void> syncNotifications(NotificationGateway gw, Clock clock) async {
  final desired = ReminderScheduler.compute(         // pure
    reminders: await repo.activeReminders(),
    readings: await repo.latestReadings(),
    now: clock.now(),
    budget: 50,                                       // headroom under iOS 64 cap
  );
  final current = await gw.getPending();
  final desiredById = {for (final d in desired) d.id: d};
  final currentIds = {for (final c in current) c.id};

  for (final c in current) {                          // cancel stale
    if (!desiredById.containsKey(c.id)) await gw.cancel(c.id);
  }
  for (final d in desired) {                          // schedule new / changed
    if (!currentIds.contains(d.id)) await gw.schedule(d);
  }
}
```

`compute` is **pure and side-effect-free**. IDs are deterministic 32-bit hashes of `reminderUuid + occurrenceIndex` with **reserved ID ranges per module**, so reconcile is idempotent — a no-op when nothing changed, a targeted cancel/add when something did.

Call `syncNotifications()` on: **app foreground/resume, reminder CRUD, new odometer/engine-hour reading, backup import/restore, exact-alarm permission granted, Android boot, and the daily WorkManager tick**.

### iOS 64-cap budgeting

iOS silently keeps only the **last 64** scheduled notifications; the 65th never fires, with no error. With ~25 modules we will blow past it. `ReminderScheduler` sorts all future instants ascending, takes the **nearest ~50** as a rolling window, and refills on every foreground. Genuinely calendar-recurring items use a single repeating notification (`matchDateTimeComponents`) consuming one slot; projected reminders are one-shots.

### Re-arm on new reading (with debounce)

On a new reading, re-project. Only cancel + reschedule when the projected date **moves beyond a threshold (>1 day)** — otherwise every km entry triggers a reschedule storm. If the new reading already crosses the target, fire an immediate "overdue" notification and drop the pending one.

### Android setup (load-bearing)

```gradle
// android/app/build.gradle
android {
  compileSdk 35
  compileOptions {
    coreLibraryDesugaringEnabled true      // REQUIRED or scheduling silently breaks
  }
}
dependencies {
  coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.x'
}
```

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/> <!-- optional toggle -->
<!-- NEVER: <uses-permission android:name="android.permission.USE_EXACT_ALARM"/> -->

<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```

### Exact-alarm strategy

```dart
final canExact = await androidImpl.canScheduleExactAlarms();
final mode = canExact
    ? AndroidScheduleMode.exactAllowWhileIdle
    : AndroidScheduleMode.inexactAllowWhileIdle; // day-granular default
```

`SCHEDULE_EXACT_ALARM` is user-revocable and denied after restore; re-check on resume and reconcile with silent fallback to inexact.

### Per-platform reboot re-arm

- **Android**: `BOOT_COMPLETED` fires **post-unlock** (not direct-boot). The plugin's boot receiver rehydrates pending; our app-open reconcile corrects drift. The DB key is stored with the `AfterFirstUnlock` accessibility class so the receiver-equivalent flow can read it while locked.
- **iOS**: the app runs **no boot code**. Scheduled notifications persist in the OS across reboot; projection re-arm happens **only on next foreground**. Do not model these as one mechanism — that reasoning is factually wrong.

### Background isolate + encrypted DB

The background tap/action handler needs `@pragma('vm:entry-point')` and runs in a **separate isolate with no main-isolate state**. Combined with the encrypted SQLCipher DB, we do **not** write from it. The handler records a lightweight "pending action" intent (or nothing) and the real work happens on the next foreground reconcile — avoiding concurrent encrypted-DB access from two isolates. Infrastructure for any legitimate in-isolate work is built via plain top-level factory functions (`factories.dart`), with the DB key read on the main isolate and passed in.

### Channels, grouping, actions

Create channels up front by urgency — `service_due`, `document_expiry`, `overdue` (high importance) — because **sound/vibration/importance is immutable after first creation**; version the channel ID if behavior must change. Group by vehicle: Android `groupKey = vehicleId` + a group-summary; iOS `threadIdentifier = vehicleId`, so multi-vehicle owners get per-car threads. Actions: "Mark done" (logs completion + arms next interval) and "Snooze 1 week / 500 km". Bodies are fully localized with Eastern-Arabic/Persian numerals, the user's calendar (Jalali/Hijri), and bidi isolation for embedded LTR numbers — but the schedule instant is always a Gregorian `TZDateTime`.

## Rules

- **Do** treat the encrypted DB as the only source of truth; the OS pending-set is a cache you reconcile — never the store of record.
- **Do** route every scheduling change through the single `syncNotifications()` reconcile entrypoint. **Don't** call `gateway.schedule()` ad hoc from feature code.
- **Do** import `flutter_local_notifications` in exactly one file (`fln_notification_gateway.dart`). A CI grep fails the build on any other import.
- **Do** store recurring schedules as wall-clock + rule + calendar. **Don't** ever persist a recurring schedule as a UTC instant.
- **Do** set `tz.local` from `flutter_timezone` at startup. **Don't** rely on the default (UTC → every reminder fires at the wrong hour).
- **Do** default to `inexactAllowWhileIdle`; gate exact behind `SCHEDULE_EXACT_ALARM` with `canScheduleExactAlarms()` and silent fallback. **Don't** declare `USE_EXACT_ALARM` (Play-policy rejection risk).
- **Do** budget to ~50 pending on iOS. **Don't** schedule an unbounded set — the 65th+ silently never fires.
- **Do** use deterministic per-module ID ranges and test uniqueness. **Don't** let UUID→32-bit hashing collide silently.
- **Do** re-project only when the date moves >1 day. **Don't** cancel/reschedule on every km entry (reschedule storms).
- **Don't** write to the encrypted DB from the background tap isolate — record intent, act on next foreground.
- **Don't** assume backup/restore carries OS notification state or exact-alarm grants — after import, `cancelAll()` then full reconcile.
- **Do** keep all scheduling math in the pure `ReminderScheduler` / `UsageProjector`. **Don't** put plugin calls inside them.

## For Car and Pain specifically

- **Offline-first**: no FCM means the foreground reconcile is the guaranteed path. Every reminder is reconstructible from the encrypted DB alone after process death, reboot, Doze, or restore — nothing lives only in the OS.
- **No-telemetry**: the notification engine has zero network dependency; delivery reliability is measured during dogfooding as a "fired vs expected" count, never via a crash/analytics SDK.
- **RTL / i18n**: bodies render with the user's numerals, calendar, and bidi isolation (see **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)**), while the underlying schedule instant stays Gregorian.
- **Canonical storage**: distance in whole metres, engine time in whole minutes, wall-clock schedules distinct from UTC instants — the projector consumes canonical readings and emits a resolved `TZDateTime`.
- **Clock-tamper guard**: overdue detection uses a monotonic clock guard so a user winding the device clock forward/back cannot spuriously mark reminders overdue or suppress genuine ones.
- **Deep links**: a notification tap maps a serializable payload → route (`/vehicles/:vehicleId/reminders/:reminderId`) reconstructed from the DB — never a non-serializable `extra` (see **[Navigation & Routing](./05-navigation.md)**).

## Testing

Push almost all confidence into pure-Dart unit tests driven by a fake `Clock` (`package:clock`), `fake_async`, timezone fixtures, and `FakeNotificationGateway` — no device, no plugin.

- **`UsageProjector`** (table-driven, exhaustive): single reading, zero/negative rate, decreasing-odometer typo, long dormancy gap, EWMA vs simple-average, distance-lead→days conversion, `InsufficientData` / `BeyondWindow` / already-overdue branches.
- **`ReminderScheduler`**: nearest-N window selection at the iOS-64 budget boundary; idempotent reconcile (no-op when unchanged, correct cancel/add diff when changed); overdue detection on a boundary-crossing reading; deterministic-ID uniqueness across all modules; clock-tamper via the monotonic guard.
- **Recurrence/DST**: schedule across a DST boundary with a non-UTC device tz and assert the correct wall-clock fire time.
- **Restore/import**: after import, assert `cancelAll()` + full reconcile produces exactly the restored reminder set with no stale IDs.
- **Localization goldens**: title/body render with Persian/Eastern-Arabic numerals, Jalali/Hijri display, and correct bidi isolation for embedded LTR numbers.
- **Integration (`integration_test` + Patrol)**: after a reconcile, assert `pendingNotificationRequests()` equals the desired set (CI-testable, unlike actual delivery); short-fuse delivery smoke test; `adb reboot` then assert still pending; Doze via `dumpsys deviceidle force-idle` + `step`; exact-alarm revocation → assert silent inexact fallback; enqueue 70 → assert only ~50 nearest survive.
- **Manual OEM QA matrix (unavoidable, never faked)**: Xiaomi/MIUI, Huawei, Samsung, OnePlus × battery-optimization ON/OFF × killed-from-recents × after reboot × after 24h idle; verify in-app guidance links reach the correct autostart/battery pages. See **[Testing Strategy](./11-testing.md)**.

## Pitfalls

- **`tz.local` defaults to UTC** — forget `flutter_timezone` and every `zonedSchedule` fires at the wrong local hour. Classic and easy to miss.
- **Missing `coreLibraryDesugaringEnabled`** — Android build fails or scheduled notifications silently break; the current major also needs AGP 8.11+, Java 17, compileSdk 35+.
- **`SCHEDULE_EXACT_ALARM` assumptions** — it is NOT pre-granted on Android 13+ fresh installs, is user-revocable, and is DENIED after restore; when revoked the plugin just logs an error and recurring reminders silently stop.
- **`USE_EXACT_ALARM`** — triggers Play policy review, allowed only for alarm-clock/timer/calendar apps; declaring it risks rejection.
- **iOS 64-cap is silent** — exceed it and later notifications never fire, with no error. The budget window is mandatory, not optional.
- **OEM battery-killers** (Huawei #1, Xiaomi/MIUI, OnePlus, Samsung) drop AlarmManager alarms, block the boot receiver, and kill WorkManager. Autostart/battery-exemption are largely user-settings-only and can't be fully granted programmatically — foreground reconcile is the only dependable recovery.
- **Immutable channel config** — sound/vibration/importance locks at first creation; changing it later has no effect. Version the channel ID.
- **Background-isolate DB writes** — `@pragma('vm:entry-point')` handler has no main-isolate state; writing to the encrypted DB from it risks concurrent access. Record intent, act on foreground.
- **Reschedule storms** — recomputing on every km entry cancels/reschedules constantly. Debounce with a >1-day threshold.
- **Projection garbage** — rate ≤ 0, single reading, decreasing/typo odometer, or long gaps produce negative/nonsense dates. Gate scheduling on a valid, sufficiently-confident rate.
- **Deterministic-ID collisions** — UUID→32-bit hashing can collide; reserve per-module ranges and test uniqueness.
- **iOS repeat constraints** — `UNTimeIntervalNotificationTrigger` must be ≥60s; prefer concrete one-shots for projected reminders.

## Decisions to confirm

- **Household peer-to-peer sync** — if it is IN scope for MVP (QR/Wi-Fi Direct/NFC with UUIDv7 + tombstone + `updated_at` + `row_revision` merge), the notification reconcile must account for merged/remotely-edited reminders and conflicting readings. Confirm it is OUT of MVP scope before locking the reconcile design.
- **Verified version pins** — confirm the current-stable `flutter_local_notifications`, `timezone`, `flutter_timezone`, and `permission_handler` majors at kickoff rather than the speculative numbers here, and re-check the Android desugaring/AGP/Java/compileSdk floor each major.

## Related

- **[Permissions, Onboarding & OEM Survival](./16-permissions-onboarding-oem.md)** — the guided battery-optimization / exact-alarm flow that makes delivery reliable.
- **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)** — localized bodies, numerals, and calendars for notification text.
- **[Navigation & Routing](./05-navigation.md)** — payload→location mapping for notification-tap deep links.
- **[Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)** — why post-restore requires `cancelAll()` + full re-arm.
- **[Testing Strategy](./11-testing.md)** — the pure-scheduler unit tiers and the manual OEM device matrix.
- **[Reminders & Notifications (product)](../features/04-reminders-notifications.md)** — the product behavior this engine implements.
