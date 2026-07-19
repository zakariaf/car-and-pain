---
name: local-notifications-scheduler
description: >-
  Authors and reviews Car and Pain's on-device reminder scheduling engine
  (packages/notifications) — the pure clock-injected ReminderScheduler plus UsageProjector,
  the NotificationGateway port over flutter_local_notifications, deterministic idempotent
  reconcile, wall-clock recurrence with timezone TZDateTime for DST correctness, iOS 64-cap
  budgeting, boot re-arm, WorkManager tick, SCHEDULE_EXACT_ALARM toggle, and OEM survival.
  Grounds work in real decisions: encrypted Drift plus SQLCipher DB as source of truth, OS
  pending set as disposable cache, Riverpod DI, canonical SI metres/minutes/UTC storage,
  gen-l10n bodies, FakeNotificationGateway tests. Use when writing or editing
  reminder_scheduler.dart, usage_projector.dart, notification_gateway.dart,
  fln_notification_gateway.dart, recurrence_rule.dart, boot_rearm_android.dart,
  syncNotifications, zonedSchedule wiring, distance or engine-hour or date reminders,
  odometer projection, snooze, mark-done re-anchoring, or diagnosing missed or wrong-hour
  notifications.
license: Proprietary
metadata:
  project: Car and Pain
  domain: notifications, background-reliability, scheduling
  source-docs: docs/flutter/07-notifications.md, docs/flutter/16-permissions-onboarding-oem.md, docs/features/04-reminders-notifications.md
---

# Local Notifications Scheduler

Author, review, and extend Car and Pain's single on-device reminder engine. The engine lives in the centrally-owned `packages/notifications/` package with a narrow API — never per-feature code — because it must not diverge across the ~25 modules that feed it. Feature `04-reminders-notifications` reads reminders from the `data` package and calls one `syncNotifications()` entrypoint; it never touches the plugin.

## Non-negotiable rules

- Treat the encrypted **Drift + SQLCipher DB as the ONLY source of truth**. The OS pending-notification set is a disposable cache you reconcile against — never the store of record. Every reminder must be reconstructible from the DB alone after process death, reboot, Doze, or restore.
- Route EVERY scheduling change through the single `syncNotifications()` reconcile entrypoint. Never call `gateway.schedule()` ad hoc from feature or UI code.
- Import `flutter_local_notifications` in **exactly one file** — `fln_notification_gateway.dart`. Everything else, including all tests, talks to the `NotificationGateway` port. `scripts/check-single-fln-import.sh` fails the build on any other import.
- Keep ALL scheduling math in the pure, side-effect-free `ReminderScheduler` and `UsageProjector`. Never put plugin calls, IO, or `DateTime.now()` inside them — inject a `Clock` (`package:clock`). Purity is what makes off-device unit testing via `FakeNotificationGateway` possible.
- Collapse all three logical triggers — TIME, DISTANCE, ENGINE-HOUR — into **one TIME-scheduling path**. The pure `UsageProjector` converts a distance or engine-hour target into a concrete future instant before it reaches the scheduler, so `ReminderScheduler` handles a single homogeneous list.
- Store recurring schedules as **wall-clock + recurrence rule + calendar** and resolve to a `TZDateTime` only at (re)schedule time. Never persist a recurring schedule as a UTC instant — it drifts an hour across every DST boundary. True instants (a fuel purchase) stay UTC epoch millis.
- Set `tz.local` from `flutter_timezone` at startup. The `timezone` default is UTC — forget this and every `zonedSchedule` fires at the wrong local hour.
- Default to `AndroidScheduleMode.inexactAllowWhileIdle` (permission-free, pierces Doze). Gate exact firing behind the user-revocable `SCHEDULE_EXACT_ALARM` via `canScheduleExactAlarms()` with silent fallback to inexact. **Never** declare `USE_EXACT_ALARM` — Play policy restricts it to alarm-clock/timer/calendar apps and it risks store rejection.
- Budget to ~50 pending on iOS (headroom under the silent 64-cap). Never schedule an unbounded set — the 65th+ silently never fires, with no error.
- Use deterministic 32-bit IDs from `reminderUuid + occurrenceIndex` with **reserved ID ranges per module**; test uniqueness. Idempotent reconcile depends on stable IDs — a no-op when nothing changed, a targeted cancel/add when something did.
- The **app-foreground reconcile IS the reliability backbone.** Boot receiver, WorkManager daily tick, exact-alarm toggle, and OEM survival on Huawei / Xiaomi-MIUI / OnePlus / Samsung are all explicitly best-effort. No FCM, no server push, no account, no telemetry — that constraint is why the reconcile architecture exists, not a gap to paper over.

## Package layout

```text
packages/notifications/lib/src/
  gateway/
    notification_gateway.dart       # abstract PORT: schedule/cancel/cancelAll/getPending
    fln_notification_gateway.dart    # ONLY file importing flutter_local_notifications
    fake_notification_gateway.dart   # in-memory list, for tests
  scheduler/
    reminder_scheduler.dart          # PURE: compute(desired) -> reconcile diff
    usage_projector.dart             # PURE: distance/engine-hour -> TIME instant
    scheduled_notification.dart      # value object (id, when, channel, payload)
    deterministic_id.dart            # UUID + occurrence -> stable 32-bit id
  recurrence/
    recurrence_rule.dart             # wall-clock + rule + calendar -> TZDateTime
  boot/
    boot_rearm_android.dart          # BOOT_COMPLETED post-unlock re-arm
  clock_tamper_guard.dart            # monotonic guard for overdue detection
  factories.dart                     # isolate-safe top-level construction
```

`packages/core/` owns the pure `UsageProjector` math and the `Clock` port; `packages/notifications/` owns the gateway and scheduler wiring. Wire construction through Riverpod providers — never global singletons or per-feature instances.

## The canonical reconcile (the backbone)

`compute` is pure. The gateway diff is the only IO. This is the ONE entrypoint every scheduling change flows through:

```dart
Future<void> syncNotifications(NotificationGateway gw, Clock clock) async {
  final desired = ReminderScheduler.compute(        // PURE — no IO, injected clock
    reminders: await repo.activeReminders(),        // from encrypted Drift DB
    readings: await repo.latestReadings(),          // canonical: metres, minutes
    now: clock.now(),
    budget: 50,                                      // headroom under iOS 64 cap
  );                                                 // sorts future instants ascending,
                                                     // takes nearest ~50 as rolling window
  final current = await gw.getPending();
  final desiredById = {for (final d in desired) d.id: d};
  final currentIds = {for (final c in current) c.id};

  for (final c in current) {                         // cancel stale
    if (!desiredById.containsKey(c.id)) await gw.cancel(c.id);
  }
  for (final d in desired) {                          // schedule new / changed
    if (!currentIds.contains(d.id)) await gw.schedule(d);
  }
}
```

Call `syncNotifications()` on: **app foreground/resume, reminder CRUD, new odometer/engine-hour reading, backup import/restore, exact-alarm permission granted, Android boot, and the daily WorkManager tick.**

See `examples/sync_notifications.dart` for the full annotated version and `examples/usage_projector.dart` for the projection math.

## Projection, recurrence, budgeting — the load-bearing details

- **Projection** (`UsageProjector.project`): pure, clock-injected. Returns a sealed `Projection` — `ProjectedAt(when)`, `InsufficientData` (< `minSamples`, or rate ≤ 0: dormant/typo/decreasing odometer), or `BeyondWindow` (lands past the pending horizon). A distance lead ("warn 500 km before") converts to days via the same rolling rate; a time lead ("2 weeks before") subtracts directly. Consumes canonical readings (whole metres, whole minutes), emits a resolved instant. See `references/scheduler-rules.md`.
- **Re-arm on new reading (debounced):** re-project on each reading, but only cancel + reschedule when the projected date **moves > 1 day** — otherwise every km entry triggers a reschedule storm. If a new reading already crosses the target, fire an immediate "overdue" notification and drop the pending one.
- **Recurrence:** resolve wall-clock + rule + calendar to a `TZDateTime` in `tz.local` at schedule time (DST-correct). The stored/scheduled instant is always Gregorian `TZDateTime`; the displayed body projects to the user's calendar (Jalali/Hijri) via gen-l10n. Genuinely calendar-recurring items use one repeating notification (`matchDateTimeComponents`), consuming a single slot; projected reminders are one-shots.
- **iOS 64-cap budgeting:** iOS silently keeps only the last 64 scheduled. Sort all future instants ascending, take the **nearest ~50**, refill on every foreground.
- **Mark-done re-anchoring:** the next occurrence is computed from the *actual* completion date/odometer, not the scheduled one, so recurring reminders don't drift.

Full tables (projection branches, budgeting edge cases, ID ranges, clock-tamper) are in **`references/scheduler-rules.md`**. The port contract and channel/grouping/deep-link rules are in **`references/notification-gateway-port.md`**. Boot re-arm, exact-alarm degradation, background-isolate DB safety, and the OEM survival matrix are in **`references/platform-boot-exact-alarms-oem.md`**.

## Background isolate + encrypted DB

The background tap/action handler needs `@pragma('vm:entry-point')` and runs in a **separate isolate with no main-isolate state**. Do **not** write to the SQLCipher DB from it — record a lightweight "pending action" intent (or nothing) and let the next foreground reconcile do the real work, avoiding concurrent encrypted-DB access from two isolates. Build any legitimate in-isolate infrastructure via plain top-level factory functions in `factories.dart`, with the DB key read on the main isolate and passed in.

## Deep links & localization

A notification tap maps a serializable payload → route (`/vehicles/:vehicleId/reminders/:reminderId`) reconstructed from the DB via go_router — never a non-serializable `extra`. Bodies are fully localized through gen-l10n with the user's numerals (Eastern-Arabic/Persian), calendar (Jalali/Hijri), and bidi isolation for embedded LTR plate/VIN numbers — but the schedule instant is always a Gregorian `TZDateTime`.

## After backup/restore

Backup does NOT carry OS notification state or exact-alarm grants. After import, run `cancelAll()` then a full reconcile — never assume restored pending IDs are valid.

## Verify

- `scripts/check-single-fln-import.sh` — fails if `flutter_local_notifications` is imported outside `fln_notification_gateway.dart`.
- `scripts/check-scheduler-purity.sh` — flags `DateTime.now()`, plugin imports, or IO inside the pure scheduler/projector.
- `scripts/check-manifest-permissions.sh` — asserts required permissions present and `USE_EXACT_ALARM` absent.
- `scripts/analyze-and-gen.sh` — runs `dart run build_runner build --delete-conflicting-outputs` then `flutter analyze` on the notifications package.

## Testing

Push almost all confidence into pure-Dart unit tests driven by a fake `Clock`, `fake_async`, timezone fixtures, and `FakeNotificationGateway` — no device, no plugin. Cover `UsageProjector` branches table-driven (single reading, zero/negative rate, decreasing-odometer typo, dormancy gap, distance-lead→days, `InsufficientData`/`BeyondWindow`/already-overdue); `ReminderScheduler` nearest-N at the 64 boundary, idempotent reconcile, overdue on a boundary-crossing reading, deterministic-ID uniqueness, clock-tamper; recurrence across a DST boundary in a non-UTC tz; and restore → `cancelAll()` + reconcile equals exactly the restored set. See `references/scheduler-rules.md` for the full matrix. OEM survival (Xiaomi/MIUI, Huawei, Samsung, OnePlus) is a manual device matrix — never a faked emulator pass.
