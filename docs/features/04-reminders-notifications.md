# 🔔 Reminders & Notifications

> No more discovering an expired inspection sticker at a roadside stop, or an oil change 3,000 km overdue — the app remembers so you don't have to.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Service & Maintenance](./03-service-maintenance.md) · [Tires, Wheels & Seasonal](./07-tires-wheels.md) · [Documents, Glovebox & Compliance](./08-documents-compliance.md)

## The pain

Car ownership is a slow drip of deadlines that never arrive at a convenient moment: the annual inspection, the oil change "every 10,000 km or 12 months, whichever comes first," the winter-tire swap, the insurance renewal, the LPG cylinder re-certification, the emission-zone sticker that quietly expires. Miss one and the consequences are real — a failed inspection, a voided warranty, a fine at a border, or a breakdown that a $40 service would have prevented. Most apps that try to help fail in two ways: they either need a live server and an account to schedule anything (useless in airplane mode or after a reinstall), or their notifications silently die after a phone reboot, a battery-saver kick, or the OS quietly killing the app. Car and Pain treats reliable, fully offline reminders as a core promise, not a nice-to-have.

## What it does

Reminders & Notifications is the single on-device scheduling engine that every other module feeds into. You describe *when* something is due — on a date, at an odometer reading, after a number of engine-hours, or "whichever comes first" — and the engine turns that into concrete, local notifications that fire on time with no network, no push server, and no account. Because a phone can't watch your odometer roll over, distance-based rules are handled by projecting a due *date* from your average daily distance and re-projecting that date every time you log a new reading, so the estimate sharpens as you drive.

The engine is also the reliability layer. It manages the iOS 64-pending-notification cap, re-arms every alarm after a reboot, time change, or restore from backup, respects quiet hours so nothing fires at 3 a.m., groups a busy day's items into one digest instead of a dozen buzzes, and routes each reminder to a severity-appropriate channel. One scheduler serves maintenance, documents, tires, warranty, budgets, trips, parking meters, LPG re-cert, the 12V battery, and emission-sticker validity — many sources, one dependable delivery path.

## Features

### ✅ Must-have

- **One-off date reminder** — a single dated reminder (e.g. "MOT on 14 March") that fires once and auto-completes afterward, with no recurrence to manage.
- **Recurring time-interval reminder** — repeats on a time interval (every 6 months, every year) and, crucially, re-anchors the next occurrence to the date you actually completed it, not to the original schedule.
- **Distance/mileage-interval reminder** — triggers every N kilometres or miles (e.g. oil every 10,000 km), scheduled offline via projected due dates rather than live odometer polling.
- **Engine-hour interval reminder** — triggers every N engine-hours, for machinery, generators, marine, and idle-heavy commercial use where hours matter more than distance.
- **Whichever-comes-first** — combines time OR distance OR hours so the earliest of the thresholds fires the reminder (the correct model for most real service schedules).
- **Configurable time lead-time (early warning)** — fire the alert ahead of the due moment (e.g. "1 week before") so there's time to book the shop, not just to panic.
- **Average-daily-distance estimator** — the backbone of offline distance reminders: a rolling estimate of how far you drive per day, computed from the shared odometer ledger.
- **Estimated due-date projection for distance reminders** — converts a distance threshold into a schedulable calendar date using the average-daily-distance estimate.
- **Recompute & reschedule on every new entry** — each new odometer or log entry re-derives the estimate and re-projects every distance reminder, so the schedule self-corrects as you drive.
- **Periodic odometer-update prompt** — gently asks for a current reading when the app hasn't seen one in a while, keeping distance projections honest.
- **Mark-done auto-starts next cycle** — completing a recurring reminder immediately opens the next occurrence anchored to the actual completion date and odometer.
- **Snooze reminder** — postpone with presets (a day, a week) or with a data-triggered "until next drive" option.
- **Dismiss / mark-done from notification actions** — resolve a reminder straight from the notification's action buttons without opening the app.
- **Explicit status model** — every reminder moves through a defined lifecycle: `upcoming → due-soon → due → overdue → done / snoozed / dismissed / paused`.
- **Overdue tracking & escalation** — overdue items are tracked and re-nagged on a sensible cadence rather than being shown once and forgotten.
- **Vehicle health dashboard** — an at-a-glance view of due / due-soon / overdue counts and the next item due, per vehicle.
- **Fully on-device local notification scheduling** — all scheduling happens on the device with no server and no push; it works in airplane mode and after a fresh reinstall.
- **iOS 64-pending queue management** — schedules only the soonest window of pending notifications (iOS caps pending local notifications at 64) and refreshes the queue when the app moves to foreground or background.
- **Reschedule on boot / time / timezone change** — an Android boot receiver and time-change handling re-arm every alarm after a restart or clock change.
- **Exact-alarm strategy & permission handling** — requests and manages `POST_NOTIFICATIONS` and `SCHEDULE_EXACT_ALARM` and picks an exact-alarm strategy so time-critical reminders fire precisely.
- **Notification grouping & daily digest** — collapses everything due into one grouped digest instead of firing items one at a time.
- **Notification channels by severity** — separate channels for overdue, due-soon, documents, and info so the user can tune importance and sound per severity.
- **Quiet hours / preferred delivery time** — a configurable quiet window and preferred delivery time so nothing fires in the middle of the night.
- **Per-vehicle reminders naming the vehicle** — every notification names the vehicle it belongs to, essential in a multi-vehicle garage.
- **Reminder templates / service-schedule presets** — bundled offline presets and templates so common schedules can be applied without hand-entering every interval.
- **Survive backup/import and re-arm on restore** — reminders (with live state) are part of the full backup and immediately re-arm their OS notifications after a restore.
- **Battery-optimization reliability helper** — OEM-aware guidance that walks the user through allowlisting the app on aggressive battery-killer phones so alarms aren't silently deferred.

### 🔵 Should-have

- **Ignore-a-dimension** — allow a time or distance field to be left null so a reminder can be purely date-based or purely distance-based.
- **Configurable distance lead-time** — an early warning expressed in distance (e.g. "1,000 km before"), converted to a date via average daily distance.
- **Multiple staged lead-time alerts** — several graduated warnings for the same item (e.g. 30 / 7 / 1 days before).
- **Confirm/edit computed next interval on completion** — on mark-done, show and let the user adjust the computed next interval instead of silently defaulting to one year.
- **Completion creates a linked record** — optionally spin up a linked service or expense record from a completed reminder so the work is logged, not just cleared.
- **Skip / pause / archive without deleting** — set a reminder aside without losing its history or completion record.
- **Global & per-reminder preferences** — notification settings at both the app level (including a mute-all option) and the individual reminder level.
- **Manufacturer/default interval library** — a bundled library of default intervals, with distinct ICE and EV presets.
- **Free-form custom reminder** — a fully user-defined reminder for anything the presets don't cover.
- **Mileage-update nudge when stale** — prompt for a reading specifically when the odometer is stale enough to make distance projections unreliable.
- **Stale-data safeguard** — when data is old, widen the lead-time and flag the estimate as uncertain rather than firing on a bad guess.
- **Recalculate-due after odometer correction** — a corrected reading cascades and recomputes every affected due point.
- **Auto-reschedule on renewal** — renewing a document or policy rolls the expiry and its reminders forward automatically.

### ⚪ Nice-to-have

- **One-off odometer-target reminder** — a single "remind me when the car hits X km" without a repeating interval.
- **Whichever-comes-last / both-required** — the inverse of whichever-first: fire only when *all* thresholds are met.
- **Percentage-proximity threshold** — trigger when the remaining amount falls within a set percentage of the interval (e.g. within 10%).
- **Prediction confidence / uncertainty indicator** — surface how confident the projected due date is, based on driving variance and data freshness.
- **Quick odometer entry widget** — a one-tap reading entry, including a Watch/Wear companion, to keep projections fresh with minimal friction.
- **Clone / bulk-apply reminders across vehicles** — copy a reminder or a whole set to other vehicles in the garage at once.
- **Seasonal / date-anchored recurring reminder** — recurring on a calendar anchor (e.g. winter tires each October) rather than an elapsed interval.
- **Estimated cost preview on reminder** — show a rough expected cost alongside the reminder to help with budgeting.
- **Calendar (.ics) export of due dates** — export due dates as an `.ics` file for the user's own calendar app.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `reminder_id` | uuid | Stable primary key; survives backup/restore and re-arms OS notifications. |
| `vehicle_id` | ref | Vehicle this reminder is scoped to; named in every notification. |
| `title` | text | User-facing label; localized display, LTR-isolated embedded plate/VIN. |
| `trigger_type` | enum | `date` / `distance` / `hours` / combined. |
| `due_date` | date | Canonical ISO/UTC; displayed in the user's calendar. |
| `due_odometer` | number+unit | Target distance reading (stored SI, displayed in preferred unit). |
| `due_hours` | number+unit | Target engine-hours. |
| `interval_value` | number | Magnitude of a recurring time interval. |
| `interval_unit` | enum | Time unit for recurrence (days / weeks / months / years). |
| `interval_distance` | number+unit | Distance step for recurring distance rules. |
| `distance_unit` | enum | Preferred display distance unit (km / mi). |
| `combine_mode` | enum | `whichever-first` / `whichever-last` / `both-required`. |
| `lead_offsets[]` | array | One or more staged early-warning offsets (time and/or distance). |
| `recurring` | bool | Whether a completion opens the next cycle. |
| `auto_refresh_on_complete` | bool | Re-anchor next occurrence to actual completion. |
| `last_completed_date` | date | Anchor date for the next cycle. |
| `last_completed_odometer` | number+unit | Anchor reading for the next distance cycle. |
| `completion_history[]` | array | Prior completions (date + odometer + optional linked record). |
| `status` | enum | `upcoming` / `due-soon` / `due` / `overdue` / `done` / `snoozed` / `dismissed` / `paused`. |
| `status_changed_at` | date | Timestamp of the last status transition. |
| `snooze_until` | date | Wake time for a time-based snooze. |
| `snooze_trigger` | enum | Distinguishes timed snooze from "until next drive" (data-triggered). |
| `avg_daily_distance` | number+unit | Rolling estimate driving the date projection. |
| `estimated_due_date` | date | Projected due date for distance/hour rules. |
| `confidence_level` | enum | Uncertainty of the projection (from variance + data age). |
| `channel_id` | ref | Severity channel the notification routes to. |
| `importance` | enum | Channel importance (overdue / due-soon / documents / info). |
| `quiet_start` | text | Start of the quiet-hours window (local time). |
| `quiet_end` | text | End of the quiet-hours window (local time). |
| `notify_time_of_day` | text | Preferred delivery time. |
| `os_notification_id` | text | Handle to the scheduled OS notification, for cancel/reschedule. |
| `linked_service_type` | ref | Service type a completion should create/attach. |
| `linked_record_id` | ref | The service/expense record generated on completion. |
| `source_module` | enum | Which module produced the reminder (maintenance, documents, tires, warranty, budget, trips, parking, LPG, 12V, emission-sticker). |

## Calculations & formulas

- **Average daily distance** — computed over a rolling window from the shared odometer ledger: `avg_daily_distance = Δodometer / Δdays` across recent readings.
- **Estimated due date** — `estimated_due_date = today + (due_odometer − current_odometer) / avg_daily_distance`.
- **Lead-time notification date** — time lead: `notify_date = due_date − lead_time`; distance lead is first converted to a date via average daily distance, then the same subtraction applies.
- **Overdue amounts** — `overdue_by_days`, `overdue_by_distance`, and `overdue_by_hours` measure how far past due an item is, feeding the escalation cadence.
- **Re-anchoring next cycle** — the next occurrence is computed from the *actual* completion date/odometer, not the scheduled one, so recurring reminders don't drift earlier or later over time.
- **iOS pending-queue policy** — schedule only the soonest `N` pending notifications where `N < 64`, and rotate the queue on foreground/background transitions.
- **Percentage-proximity trigger** — fires when `remaining ≤ proximity_percent × interval`.
- **Confidence** — derived from usage variance and days since the last odometer reading; higher variance or staler data lowers confidence.

## Reminders & notifications

This module *is* the reminder engine — it both produces its own reminders and consumes reminder requests from every other module. Triggers come in four base shapes, freely combined:

- **Date** — a fixed calendar deadline (inspection, insurance renewal, emission sticker).
- **Distance** — every N km/mi, scheduled offline by projecting a date from average daily distance and re-projecting on each new reading.
- **Engine-hours** — every N hours, for hour-metered use.
- **Whichever-comes-first / -last / both-required** — combine the above so the earliest (or latest, or all) threshold governs.

**Lead-time early warnings** can be expressed in time ("1 week before") or distance ("1,000 km before", converted to a date), and several can be staged together (e.g. 30 / 7 / 1 days). Delivery is shaped by **quiet hours** and a **preferred delivery time** so nothing fires at midnight, and by **per-severity channels** (overdue, due-soon, documents, info) so the user can tune each independently. When several items land the same day they **collapse into one grouped digest**. Every notification **names its vehicle**, and actions (mark-done, snooze, dismiss) resolve items without opening the app. Reliability engineering — iOS 64-pending rotation, Android boot/exact-alarm re-arming, Doze and OEM battery-optimization handling — ensures the alerts actually arrive.

## Offline & data

Everything here runs with zero connectivity. There is no push server and no account: notifications are scheduled entirely on-device through the OS's local-notification and exact-alarm facilities. Because the phone can't observe the odometer in the background, distance and engine-hour rules are realized as projected *dates* computed from your driving history, and every new log entry re-projects them — so the system stays accurate without ever phoning home.

In export and backup, reminders are first-class entities: each reminder — including its **live status, snooze state, projection, and OS-notification handle** — is written into the single-file full backup and into the per-entity CSV/JSON exports, with schema versioning and checksums. On **import/restore**, reminders are recreated and their OS notifications are **immediately re-armed**, so migrating to a new phone never silently drops a deadline. Deleting a vehicle cancels and cleans up its scheduled OS notifications so nothing fires for a car you no longer own.

## Localization & RTL

Notification titles and bodies are **fully localized**, including into Tier-2 languages — not just the app's UI chrome. For `fa`, `ar`, `ckb`, `he`, and `ur` the notification text renders **right-to-left** with localized numerals (Eastern-Arabic / Persian / Devanagari as appropriate), localized units, and localized dates, while embedded Latin vehicle names, plates, and numbers stay **LTR via bidi isolation** so an identifier never scrambles.

Due dates are stored canonically as ISO/UTC and displayed in the user's chosen calendar — **Gregorian, Jalali/Shamsi, Hijri, or Hebrew** — and recurrence math respects each calendar's leap years and short months rather than assuming 365-day years or 30-day months. **First-day-of-week** differs by locale (Saturday for `fa`/`ar`, Sunday for `he`), which affects weekly grouping and digests. **Quiet hours honor local time**, and daylight-saving or manual clock changes must not shift date-only reminders off their intended day.

## Edge cases

- **Distance rules can't push offline** — the engine projects a date and re-projects it on every new reading rather than trying to watch the odometer.
- **Missed/skipped entries** — widen the estimator window and lower confidence instead of producing wild km/day figures.
- **Wrong baseline odometer** — a bad baseline poisons every future due point, so a correction cascades and recomputes all affected reminders.
- **Odometer rollback / cluster swap** — a documented offset means a decreasing reading isn't treated as a permanent error.
- **iOS 64-pending cap exceeded** — multi-vehicle gardens multiplied by staged lead-times can blow past 64 pending; the queue is rotated to keep the soonest items armed.
- **Android Doze / OEM battery-killers** — exact single-fire alarms, reschedule-on-boot, and an allowlist prompt counter deferred or killed alarms.
- **Reboot / timezone / manual clock change** — all alarms re-arm, and DST changes must not shift date-only reminders.
- **Notification permission denied** — degrades gracefully to an in-app due list and re-prompts with a clear rationale.
- **Multiple items due at once** — collapse into a single grouped digest.
- **Long-idle / seasonal vehicle** — a stale odometer pauses distance misfires and the reminder falls back to its time legs.
- **"Snooze until next drive"** — is data-triggered by the next odometer entry, not a background poll.
- **Interval changed mid-cycle** — recomputes the current open occurrence, not only future ones.
- **Very high (rideshare) or near-zero mileage** — clamps projections and falls back to time-based scheduling.
- **Deleting a vehicle** — cancels and cleans its scheduled OS notifications.
- **One engine, many sources** — serves reminders for maintenance, documents, tires, warranty, budget, trips, parking meter, LPG re-cert, 12V battery, and emission-sticker validity.

## Related features

- **[Service & Maintenance](./03-service-maintenance.md)** — the largest producer of reminders; its schedules, custom types, and completions feed and re-anchor recurring maintenance reminders.
- **[Vehicles, Garage & Odometer](./01-vehicles-garage.md)** — the shared odometer ledger supplies the readings that drive average-daily-distance projection and per-vehicle scoping.
- **[Tires, Wheels & Seasonal](./07-tires-wheels.md)** — seasonal swap and rotation reminders, including date-anchored recurrences like winter tires each October.
- **[Documents, Glovebox & Compliance](./08-documents-compliance.md)** — inspection, registration, emission-sticker, and LPG re-cert deadlines flow in as document reminders with renewal roll-forward.
- **[Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)** — policy renewals and warranty date/mileage limits schedule reminders here so coverage never lapses.
- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md)** — carries reminder state (with live status) through the single-file backup and re-arms alarms on restore.
