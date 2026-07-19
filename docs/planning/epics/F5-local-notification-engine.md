# F5 · Local notification engine

> One offline scheduler on `flutter_local_notifications` `zonedSchedule` (+timezone) with the DB as the single source of truth — date, distance-projection, engine-hour and whichever-first triggers, grouped digests, per-severity channels, and reboot/Doze/exact-alarm survival — ready for Reminders and every module that schedules.

## Goal

Deliver **one** on-device scheduling engine that every module (maintenance, documents/legal, tires, warranty, budgets, trips, parking meters, LPG re-cert, 12V battery, emission stickers) feeds into, so there is exactly one dependable delivery path rather than a dozen ad-hoc schedulers.

The engine is built on `flutter_local_notifications` `zonedSchedule` with `timezone` + `flutter_timezone`, and treats the **encrypted DB as the source of truth**: the OS notification queue is always a *projection* of DB rows that can be rebuilt from scratch. From a schedule row plus the shared odometer/engine-hour ledger it evaluates four trigger kinds — a **date**, a **distance projection** (a distance threshold turned into a schedulable calendar date via the rolling average-daily-distance estimate), an **engine-hour** threshold, and **whichever-comes-first** (earliest of the three) — and emits concrete zoned notifications with configurable lead-times, quiet-hours, and per-severity channels.

Because a phone cannot watch the odometer roll over, distance rules re-project their due date on every new reading and self-correct as the user drives, degrading honestly (widened lead-time + "estimate uncertain") when data is stale. The engine is also the **reliability layer**: it manages the iOS 64-pending cap, re-arms every alarm after reboot / time-change / timezone-change / restore-from-backup, chooses an exact-alarm strategy for time-critical items, and surfaces OEM battery-optimization guidance. Bodies are localized, name the vehicle, and respect the active calendar and numeral system; a busy day collapses into one grouped digest.

Scope note: this epic delivers the **engine and its primitives** (scheduling, trigger evaluation, reconciliation, channels, permissions hooks, digests). The full reminder *product* UX (lifecycle screens, templates library, snooze presets, health dashboard) is owned by the `reminders-notifications` MVP module, which consumes this engine.

## Tier & dependencies

- **Tier:** foundation
- **Depends on:**
  - **F1** — project scaffold & tooling (pub workspace, lints, CI, flavors)
  - **F2** — data layer (Drift + SQLCipher, canonical units, odometer/engine-hour ledger, migrations, soft-delete)
  - **F4** — i18n / RTL / calendars / numerals engine (localized bodies, calendar + numeral formatting)

## References

- [Reminders & Notifications (feature spec)](../../features/04-reminders-notifications.md)
- [Flutter · Notifications](../../flutter/07-notifications.md)
- [Flutter · Permissions, onboarding & OEM survival](../../flutter/16-permissions-onboarding-oem.md)
- [PULSE · Components](../../design/pulse/02-components.md)
- [Reference · Data model](../../reference/data-model.md)

## Tasks

### F5-T1 · FLN integration & channels

**Description**
Add `flutter_local_notifications` as a kept third-party runtime dependency, pinning the **verified current-stable major at kickoff** (FLN bumps majors with breaking channel/permission APIs — treat the number as TBD until verified on real iOS + Android). Initialize the `timezone` database and resolve the device zone via `flutter_timezone` at app start, injected through the async infra provider graph (a placeholder root provider overridden once `tz` is ready). Define per-severity Android notification channels (`overdue`, `due-soon`, `documents`, `info`) with appropriate importance/sound and their iOS interruption-level equivalents, created idempotently on init. Wrap all FLN calls behind a `NotificationService` façade returning the sealed `Result<T, NotificationFailure>` so no plugin type leaks past the module boundary.

**Acceptance criteria**
- [ ] FLN major is pinned in `pubspec` with a comment recording the verified version and the date/OS it was verified on.
- [ ] `timezone` is initialized and the device zone is resolved via `flutter_timezone` before any scheduling call can run.
- [ ] Per-severity channels (`overdue`, `due-soon`, `documents`, `info`) are created idempotently on both platforms with correct importance and iOS interruption levels.
- [ ] All plugin access goes through a `NotificationService` façade; callers receive `Result<T, NotificationFailure>` and never touch FLN types directly.
- [ ] Re-running init does not duplicate channels or throw.

**Size:** M
**Depends on:** F1, F2, F4
**Governing docs:** [Flutter · Notifications](../../flutter/07-notifications.md), [Reference · Data model](../../reference/data-model.md)

### F5-T2 · Schedule model & DB source of truth

**Description**
Design the Drift schema that makes the DB authoritative for scheduling: a `reminder`/`schedule` definition table (owning module, vehicle FK, trigger kind, date/distance/engine-hour params, lead-times, severity/channel, quiet-hours opt, recurrence + completion anchor, lifecycle status, soft-delete/tombstone) and a derived `scheduled_notification` table (the concrete OS entries with computed fire-instant, stable notification id, digest group key). Implement a **reconcile step** that, given the current DB state, computes the desired set of OS notifications and diffs it against what the OS currently holds — cancelling stale entries, arming new ones, leaving unchanged ones — so the OS queue is always a pure projection of the DB and can be rebuilt from zero. All writes are transactional; ids are stable and deterministic so reconcile is idempotent.

**Acceptance criteria**
- [ ] `reminder`/`schedule` and `scheduled_notification` tables exist with a migration and are covered by the canonical-units/UTC-instant contract at the repository boundary.
- [ ] Reconcile is idempotent: running it twice with unchanged DB state produces zero OS mutations.
- [ ] Reconcile from an empty OS queue fully rebuilds the correct pending set from DB rows.
- [ ] Editing/deleting a reminder row cancels exactly its stale OS entries and arms replacements in one transaction.
- [ ] Notification ids are stable and deterministic per (reminder, occurrence) so no orphan or duplicate OS entries accumulate.
- [ ] Soft-deleted / paused reminders arm no OS notifications but retain their rows.

**Size:** M
**Depends on:** F5-T1
**Governing docs:** [Reference · Data model](../../reference/data-model.md), [Flutter · Notifications](../../flutter/07-notifications.md)

### F5-T3 · Trigger evaluators

**Description**
Implement the pure-Dart **next-due engine** with no Flutter/plugin dependencies. Four evaluators over a schedule row + the shared odometer/engine-hour ledger: (1) **date** — one-off and recurring time-interval, with recurrence re-anchored to the actual completion date; (2) **distance-projection** — a rolling **average-daily-distance** estimate (from the ledger, with a min-samples floor and an explicit *insufficient-data* fallback) that converts a distance threshold into a schedulable calendar date, re-projected on every new reading; (3) **engine-hour** — threshold over engine-hours for machinery/idle-heavy use; (4) **whichever-first** — earliest of the applicable dimensions, with any dimension nullable so a rule can be purely one kind. Apply configurable lead-time(s) (time and distance-expressed), quiet-hours shifting to the preferred delivery time, and a stale-data safeguard (widen lead-time + mark estimate uncertain). Output is a canonical `NextDue` value (fire-instant + confidence/uncertainty flag) consumed by T2's reconcile.

**Acceptance criteria**
- [ ] Date evaluator handles one-off (fires once, auto-completes) and recurring (re-anchored to completion date, not original schedule).
- [ ] Average-daily-distance estimator computes from the ledger, enforces a min-samples floor, and returns an explicit insufficient-data result instead of a bad guess.
- [ ] Distance-projection converts a threshold to a due date and re-projects when a newer reading is supplied.
- [ ] Engine-hour evaluator projects a due date from an hours threshold and hours-accrual rate.
- [ ] Whichever-first returns the earliest due across present dimensions; any single dimension may be null.
- [ ] Lead-times (time- and distance-expressed) and quiet-hours/preferred-time shifting are applied to the computed instant.
- [ ] Stale data widens lead-time and flags the projection uncertain rather than firing on a stale estimate.
- [ ] All evaluators are pure Dart with zero plugin/Flutter imports (unit-testable in isolation).

**Size:** L
**Depends on:** F5-T2
**Governing docs:** [Reminders & Notifications](../../features/04-reminders-notifications.md), [Reference · Data model](../../reference/data-model.md)

### F5-T4 · Reboot & Doze survival

**Description**
Guarantee alarms survive the OS. Register an Android `BOOT_COMPLETED` (plus `TIMEZONE_CHANGED` / time-set) receiver that triggers a full T2 reconcile so every alarm is re-armed after a restart or clock change. Implement the **exact-alarm** path — request/manage `SCHEDULE_EXACT_ALARM` (`USE_EXACT_ALARM` where policy allows) and select an exact vs inexact strategy per severity so time-critical items fire precisely while low-priority ones tolerate batching. Handle **Doze / battery-optimization**: detect aggressive-OEM conditions and route into the shared onboarding guidance (T6) to allowlist the app, with graceful degradation (inexact windows) when exact alarms are denied. Manage the **iOS 64-pending cap** by scheduling only the soonest window and refreshing the queue on foreground/background transitions.

**Acceptance criteria**
- [ ] A device reboot re-arms all pending notifications via reconcile (verified with an integration/instrumented check).
- [ ] Timezone/time-set changes trigger reconcile so fire-instants stay correct.
- [ ] Exact-alarm permission is requested/managed; per-severity strategy chooses exact vs inexact and degrades gracefully when denied.
- [ ] iOS never exceeds 64 pending entries; the soonest-window queue is refreshed on foreground and background.
- [ ] Doze/battery-optimization is detected and handed to the onboarding guidance rather than silently failing.

**Size:** M
**Depends on:** F5-T2, F5-T3
**Governing docs:** [Flutter · Notifications](../../flutter/07-notifications.md), [Flutter · Permissions, onboarding & OEM survival](../../flutter/16-permissions-onboarding-oem.md)

### F5-T5 · Grouped digests & localized copy

**Description**
Collapse everything due in a delivery window into **one grouped digest** (Android group + summary notification; iOS thread identifier) instead of firing items individually, while still allowing single-item delivery when only one is due. Build notification **bodies through the F4 i18n layer**: ICU-plural-correct, naming the vehicle (bidi-isolated so plate/VIN stay LTR inside RTL text), formatting dates in the active calendar (Gregorian/Jalali/Hijri) and numbers in the active numeral system (Western/Eastern-Arabic/Persian, correct grouping). Route each item to its severity channel from T1. Respect PULSE tone in any in-app surfaces the engine renders (e.g. a delivered-digest sheet), with status **redundantly encoded** (icon + label + shape/position), never colour alone.

**Acceptance criteria**
- [ ] Multiple items due in one window deliver as a single grouped/summary notification; a lone item delivers ungrouped.
- [ ] Every body names its vehicle and is produced via the F4 localization layer (no hardcoded strings).
- [ ] Dates render in the active calendar and numbers in the active numeral system, with plate/VIN/IDs bidi-isolated LTR.
- [ ] ICU plurals are correct across en/de/fr and fa/ar/ckb.
- [ ] Items route to the correct per-severity channel; any in-app engine surface encodes status redundantly (not colour-only) per PULSE.

**Size:** M
**Depends on:** F5-T1, F5-T3, F5-T4
**Governing docs:** [PULSE · Components](../../design/pulse/02-components.md), [Reminders & Notifications](../../features/04-reminders-notifications.md)

### F5-T6 · Permissions rationale hooks

**Description**
Provide reusable permission surfaces (built with `permission_handler`) that both the standalone reminders flow and the F-tier **onboarding** flow share: request `POST_NOTIFICATIONS` and, optionally, `SCHEDULE_EXACT_ALARM`, each preceded by a clear **rationale** explaining why the app needs it (offline reliability, precise firing). Expose a permission-state stream so callers can react to grant/deny/permanently-denied, deep-link to system settings when needed, and drive the OEM battery-optimization walkthrough. Requests must be non-blocking and re-entrant (safe to invoke from onboarding or from first reminder creation), and denial must degrade the engine gracefully rather than crash.

**Acceptance criteria**
- [ ] Notification and (optional) exact-alarm requests are each gated behind a rationale surface shown before the OS prompt.
- [ ] The permission hook is shared, unmodified, by both onboarding and the reminder-creation entry point.
- [ ] A permission-state stream reports granted/denied/permanently-denied and offers a settings deep-link on permanent denial.
- [ ] Denied exact-alarm or notification permission degrades the engine to its best available mode without crashing.
- [ ] Rationale copy is fully localized via F4 and follows PULSE tone/redundant-encoding.

**Size:** S
**Depends on:** F5-T4
**Governing docs:** [Flutter · Permissions, onboarding & OEM survival](../../flutter/16-permissions-onboarding-oem.md), [PULSE · Components](../../design/pulse/02-components.md)

### F5-T7 · Backup / export & restore re-arm *(added — vertical-slice completeness)*

**Description**
Ensure the notification engine participates in the first-class backup/export subsystem: reminder/schedule rows and their **live lifecycle state** are included in the single-file backup and the combined JSON/CSV exports (schema-versioned, checksummed), and a restore/import **immediately re-arms** the OS notification queue by running the T2 reconcile against the restored DB. A fresh reinstall + restore must reproduce the exact pending set with no lost or duplicated reminders. Provide the optional `.ics` export of due dates as a read-only convenience without affecting the on-device engine.

**Acceptance criteria**
- [ ] Reminder/schedule tables (with live state) are covered by the single-file backup and JSON/CSV export, schema-versioned and checksummed.
- [ ] Restore/import triggers reconcile so all reminders re-arm immediately, with no manual step.
- [ ] Reinstall-then-restore reproduces the identical pending set (no orphans, no duplicates).
- [ ] `.ics` export of due dates round-trips dates correctly and does not mutate engine state.

**Size:** S
**Depends on:** F5-T2, F5-T5
**Governing docs:** [Reference · Data model](../../reference/data-model.md), [Reminders & Notifications](../../features/04-reminders-notifications.md)

### F5-T8 · Notification engine tests *(from epic F5-T7)*

**Description**
Comprehensive test suite for the logic-heavy engine, following the diamond-topped-pyramid strategy. **Exhaustive table-driven unit tests at 100%** on the pure-Dart next-due/projection engine: each trigger kind, whichever-first ordering, nullable dimensions, average-daily-distance with min-samples floor and insufficient-data fallback, lead-times, quiet-hours shifting, stale-data widening, and recurrence re-anchoring — including calendar/numeral edge cases (DST boundaries, leap days, Jalali/Hijri month lengths). **Fake-timezone scheduling tests** using a controllable clock and injected `tz` to assert reconcile diffs, idempotence, the iOS 64-cap window, id stability, and reboot/restore re-arm behavior — all without a real device or plugin.

**Acceptance criteria**
- [ ] Table-driven unit tests cover every trigger kind and whichever-first ordering at 100% line/branch on the pure-Dart engine.
- [ ] Average-daily-distance min-samples and insufficient-data fallback paths are explicitly tested.
- [ ] Lead-time, quiet-hours shifting, stale-data widening, and completion re-anchoring have dedicated cases.
- [ ] DST / leap-day / Jalali / Hijri boundary cases are tested.
- [ ] Fake-clock + injected-`tz` tests assert reconcile idempotence, diff correctness, iOS 64-cap windowing, id stability, and reboot/restore re-arm.
- [ ] The suite runs in CI with no real device and no live plugin.

**Size:** M
**Depends on:** F5-T3, F5-T4, F5-T7
**Governing docs:** [Flutter · Notifications](../../flutter/07-notifications.md), [Reminders & Notifications](../../features/04-reminders-notifications.md)

## Definition of Done

- [ ] **Single engine, DB-authoritative:** all scheduling flows through one `NotificationService`; the OS queue is a pure, rebuildable projection of the DB, and reconcile is idempotent.
- [ ] **All four trigger kinds** (date, distance-projection, engine-hour, whichever-first) work offline with correct lead-times, quiet-hours, and stale-data degradation.
- [ ] **Reliability:** reboot, time/timezone change, and restore-from-backup all re-arm every alarm; exact-alarm strategy and iOS 64-cap windowing are in place; Doze/battery-optimization guidance is wired to onboarding.
- [ ] **Tests:** pure-Dart next-due/projection engine at 100% table-driven coverage; fake-timezone scheduling/reconcile tests green in CI with no real device.
- [ ] **i18n complete:** every notification body and rationale string is localized across en/de/fr + fa/ar/ckb via F4, ICU-plural-correct, with active-calendar dates and active-numeral formatting; no hardcoded copy.
- [ ] **RTL verified:** bodies and any in-app engine surfaces render correctly mirrored in fa/ar/ckb, with plate/VIN/IDs bidi-isolated LTR and correct reading/focus order.
- [ ] **Backup/export:** reminder/schedule rows and live state are in the single-file backup and JSON/CSV export (versioned + checksummed) and re-arm on restore; `.ics` export available.
- [ ] **Accessible:** any engine-rendered UI meets minimum touch targets, exposes correct Semantics, and encodes status **redundantly** (icon + label + shape/position), never colour alone, per the redundant-encoding rule.
- [ ] **Dependency policy honored:** only `flutter_local_notifications`, `timezone`/`flutter_timezone`, and `permission_handler` are added as runtime deps, each pinned to a verified version; no framework or extra deps introduced.
- [ ] **Boundary contract:** all engine APIs return sealed `Result<T, NotificationFailure>` with stable typed failure codes (no user strings); no plugin type leaks past the module.
