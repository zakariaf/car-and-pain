# Scheduler & Projector rules

Detailed rules for the two pure classes — `UsageProjector` and `ReminderScheduler` — plus deterministic IDs and the clock-tamper guard. Everything here is unit-testable off-device with an injected `Clock` and `FakeNotificationGateway`.

## Why exactly one testable owner

There is ONE scheduler for ~25 modules. Maintenance, documents, tires, warranty, budget, trips, parking, LPG re-cert, 12V battery, and emission-sticker validity all feed the same `syncNotifications()`. A per-feature scheduler would diverge, duplicate the iOS-cap logic, and make the reconcile impossible to reason about. Keep the math pure and the plugin behind a port so the whole engine is verifiable without a device.

## `UsageProjector.project` — the three-triggers-into-one-path core

Signature (pure, clock-injected):

```dart
Projection project({
  required List<Reading> history,   // canonical: odometer in whole metres, engine time in whole minutes
  required num target,              // e.g. 15_000_000 m (15 000 km), or 15_000 min (250 h)
  required Duration horizon,        // pending-window horizon
  Duration leadTime = Duration.zero,
});
```

Sealed result: `ProjectedAt(when)` | `InsufficientData` | `BeyondWindow`.

| Input condition | Result | Reason |
| --- | --- | --- |
| `history.length < minSamples` (default 3) | `InsufficientData` | Not enough data for a confident rate |
| rolling rate ≤ 0 | `InsufficientData` | Dormant vehicle, odometer typo, or decreasing reading |
| `latest.value >= target` | `ProjectedAt(clock.now())` | Already overdue — fire now |
| projected `when - now > horizon` | `BeyondWindow` | Lands past the pending window; re-project later |
| otherwise | `ProjectedAt(when)` | `when = latest.at + daysToTarget − leadTime` |

- `daysToTarget = (target − latest.value) / rate`, converted to `Duration` via `Duration.millisecondsPerDay`.
- **Distance lead** ("500 km before"): convert the distance offset to days via the same rolling rate, then subtract. **Time lead** ("2 weeks before"): subtract directly.
- Rate is a rolling per-day estimate (EWMA or simple average over a recent window). Widen the window and lower `confidence_level` on missed/skipped entries rather than emitting wild km/day figures.
- **Clamp** very-high (rideshare) or near-zero mileage; fall back to the reminder's time leg when the odometer is stale.
- **Odometer rollback / cluster swap:** a documented offset means a single decreasing reading is not a permanent error — apply the offset before computing the rate.

## `ReminderScheduler.compute` — pure diff producer

- Input: active reminders (from encrypted DB), latest readings, `now`, `budget`. Output: the desired `List<ScheduledNotification>`. No IO, no plugin, no `DateTime.now()`.
- **iOS 64-cap budgeting:** sort all future instants **ascending**, take the nearest `budget` (~50, headroom under 64). Calendar-recurring items use ONE repeating notification (`matchDateTimeComponents`) consuming a single slot; projected reminders are one-shots. Refill on every foreground.
- **Idempotent:** identical inputs → identical output → reconcile is a no-op. A changed input yields a targeted cancel/add diff only.
- **Overdue on boundary-crossing reading:** when a new reading crosses the target, emit an immediate overdue notification and drop the pending projected one.
- **Re-arm debounce:** only cancel+reschedule when the projected date moves **> 1 day**, to avoid reschedule storms on every km entry.

## Deterministic IDs

- ID = deterministic 32-bit hash of `reminderUuid + occurrenceIndex`.
- **Reserve an ID range per module** so cross-module hashing cannot collide silently. Test uniqueness across all modules in a single exhaustive test.
- Stable IDs are what make reconcile idempotent — the same desired reminder always maps to the same OS id, so `getPending()` diffing works.

## Clock-tamper guard

- Overdue detection uses a **monotonic clock guard** (not just wall-clock) so a user winding the device clock forward/back cannot spuriously mark reminders overdue or suppress genuine ones.
- Store the last-seen monotonic + wall-clock pair; a wall-clock jump that the monotonic clock does not corroborate is treated as tampering and does not trigger overdue transitions.

## Wall-clock vs UTC storage

- **True instants** (a fuel purchase timestamp): UTC epoch millis.
- **Recurring schedules:** wall-clock hour/minute + recurrence rule + calendar. Resolve to `TZDateTime(tz.local, y, m, d, hour, minute)` only at (re)schedule time. Storing a recurring schedule as UTC shifts "9am" by an hour across DST — banned.
- DST/manual clock change must NOT shift a date-only reminder off its intended day.

## Test matrix (pure-Dart, no device)

| Area | Cases |
| --- | --- |
| `UsageProjector` | single reading; zero/negative rate; decreasing-odometer typo; long dormancy gap; EWMA vs simple average; distance-lead→days; `InsufficientData`/`BeyondWindow`/already-overdue |
| `ReminderScheduler` | nearest-N window at the iOS-64 boundary; idempotent no-op; correct cancel/add diff; overdue on boundary-crossing reading; deterministic-ID uniqueness across modules; clock-tamper via monotonic guard |
| Recurrence/DST | schedule across a DST boundary in a non-UTC device tz; assert correct wall-clock fire time; Jalali/Hijri leap years and short months |
| Restore/import | after import, `cancelAll()` + full reconcile equals exactly the restored reminder set, no stale IDs |
| Localization goldens | title/body with Persian/Eastern-Arabic numerals, Jalali/Hijri display, bidi isolation for embedded LTR numbers |

Integration (`integration_test` + Patrol, CI-testable): after a reconcile, `pendingNotificationRequests()` equals the desired set; short-fuse delivery smoke; `adb reboot` then assert still pending; Doze via `dumpsys deviceidle force-idle`; exact-alarm revocation → silent inexact fallback; enqueue 70 → only ~50 nearest survive.
