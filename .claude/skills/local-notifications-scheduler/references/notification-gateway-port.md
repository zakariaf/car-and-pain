# NotificationGateway port

The port isolates the plugin so all scheduling math and all tests stay off-device. `FlnNotificationGateway` is the **only** class that imports `flutter_local_notifications`; everything else — including every test — talks to this abstraction.

## The port

```dart
abstract class NotificationGateway {
  Future<void> schedule(ScheduledNotification n);
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Future<List<PendingNotification>> getPending();
}
```

- Keep it narrow: exactly these four operations. Any scheduling logic that reaches for more is a signal the logic belongs in the pure `ReminderScheduler` instead.
- Wire the concrete gateway through a Riverpod provider so tests override it with `FakeNotificationGateway` in a `ProviderContainer`.

## `ScheduledNotification` value object

Carries `id` (deterministic 32-bit), `when` (Gregorian `TZDateTime`), `channel`, and a **serializable** `payload`. The payload maps to a go_router location (`/vehicles/:vehicleId/reminders/:reminderId`) reconstructed from the encrypted DB on tap — never a non-serializable `extra`.

## Real adapter — `FlnNotificationGateway`

- The single file that imports `flutter_local_notifications`, `timezone`, and `flutter_timezone`. `scripts/check-single-fln-import.sh` enforces this.
- Set `tz.local` from `flutter_timezone` at startup before any `zonedSchedule` call.
- Use `zonedSchedule` on both platforms. Pick `AndroidScheduleMode` from `canScheduleExactAlarms()` (see `references/platform-boot-exact-alarms-oem.md`).
- Create channels up front (immutable sound/vibration/importance) and set `groupKey`/`threadIdentifier = vehicleId`.
- `getPending()` maps `pendingNotificationRequests()` to the port's `PendingNotification` list — the disposable cache the reconcile diffs against.

## Fake adapter — `FakeNotificationGateway`

- In-memory `List<ScheduledNotification>` implementing the port. `schedule` adds, `cancel` removes by id, `cancelAll` clears, `getPending` returns the list.
- No plugin, no platform channel, no `TZDateTime` resolution needed beyond what the test injects. Drives every reconcile/idempotency/budgeting/restore test deterministically.

## The reconcile contract

`syncNotifications()` (in SKILL.md and `examples/sync_notifications.dart`) is the ONLY caller of `schedule`/`cancel` in production. It:

1. computes the desired set with the pure `ReminderScheduler.compute` (budget ~50),
2. reads `getPending()`,
3. cancels pending IDs not in desired,
4. schedules desired IDs not already pending.

Because IDs are deterministic, an unchanged reminder set produces a no-op. After backup/restore, call `cancelAll()` first (OS state and exact-alarm grants do not survive import), then reconcile.

## CI enforcement

- Single-import grep (`scripts/check-single-fln-import.sh`): fail on any `flutter_local_notifications` import outside `fln_notification_gateway.dart`.
- Purity grep (`scripts/check-scheduler-purity.sh`): fail on `DateTime.now()` / plugin imports / IO inside `reminder_scheduler.dart` or `usage_projector.dart`.
- No ad-hoc `gateway.schedule(` calls outside the reconcile entrypoint.
