# notifications

The **one** local-notification engine. A single owner for the iOS 64-pending
budget, wall-clock recurrence, deterministic ids, idempotent reconcile, and
reboot re-arm — reasoned about and tested in one place.

## F1 scope

- `NotificationGateway` — the platform-scheduling **port** (schedule/cancel/
  pendingIds), returning `Result<void, NotificationFailure>` from `core`.
- `FakeNotificationGateway` — a deterministic recording fake for unit tests.
- `ScheduledNotification` — an absolute-instant schedule request carrying
  localization **codes**, never user-facing strings.

Flutter-free by design (`notifications → core` only). The real gateway wrapping
`flutter_local_notifications` `zonedSchedule` lives in the app and is wired in
**F5**, along with the pure clock-injected `ReminderScheduler`, the
`UsageProjector` bridge for distance/engine-hour rules, per-severity channels,
and boot/Doze/exact-alarm survival.
