# M5 · Reminders & Notifications

> The user-facing reminders layer riding the F5 engine: date / distance / engine-hour / whichever-first rules with live state over the shared ledger, odometer-freshness projection into schedulable dates, grouped digests, per-severity channels, and PULSE reminder surfaces that end each completion with the exhale.

## Goal

Turn the foundation notification **engine** (F5) into a complete reminders **product**. Where F5 owns the scheduling primitives (trigger evaluation, reconcile, channels, reboot/Doze survival), this epic owns everything the user actually touches: authoring rules, watching them stay live over the odometer/engine-hour ledger, and resolving them with snooze/complete.

Concretely, M5 delivers:

- **Four rule kinds with live state** — a **date** rule, a **distance** rule (a threshold in km/mi over the shared ledger), an **engine-hour** rule (for machinery / idle-heavy use), and **whichever-first** (the earliest of any combination), each carrying a live status (upcoming / due-soon / overdue / snoozed / done) recomputed as new readings and dates arrive.
- **Projection scheduling** — because a phone cannot watch the odometer roll over, distance and engine-hour rules are projected into a concrete calendar date via the rolling average-daily-distance / hours-accrual estimate, and **re-projected on every new reading** so the due date self-corrects as the user drives; stale data degrades honestly (widened window + "estimate uncertain").
- **PULSE reminder surfaces** — create/edit flows, a per-severity reminder view, and snooze/complete actions where completing a rule plays **the exhale** (the shared completion motion), status always **redundantly encoded** (icon + label + shape + position), never colour alone.
- **Grouped digests & per-severity channels** — a busy day collapses into one grouped digest; each item routes to its severity channel with **vehicle-named**, calendar- and numeral-aware localized copy.
- **Full data ownership** — reminders including their live scheduled state round-trip through backup/export and re-arm on restore.

M5 consumes the F5 engine rather than re-implementing scheduling: all OS-level arming/reconcile flows through the F5 `NotificationService`, and the projection math extends F5's next-due engine.

## Tier & dependencies

- **Tier:** MVP
- **Depends on:**
  - **F2** — encrypted data layer, canonical units/money, and the shared odometer/engine-hour ledger the rules read from
  - **F3** — PULSE design-system implementation (tokens + components + the exhale / ambient-halo motion primitives)
  - **F4** — i18n / RTL / calendars / numerals engine (localized bodies, calendar + numeral formatting)
  - **F5** — local notification engine (scheduling, reconcile, channels, trigger evaluators, reboot/Doze survival)
  - **F6** — backup / export / import + key recovery (the subsystem reminders must be included in)
  - **M2** — Fuel & Energy (a primary writer of odometer readings that drive re-projection)

## References

- [Reminders & Notifications (feature spec)](../../features/04-reminders-notifications.md)
- [Flutter · Notifications](../../flutter/07-notifications.md)
- [Flutter · i18n, RTL & calendars](../../flutter/06-i18n-rtl-calendars.md)
- [PULSE · Components](../../design/pulse/02-components.md)
- [PULSE · Motion, RTL & accessibility](../../design/pulse/04-motion-rtl-accessibility.md)
- [Reference · Data model](../../reference/data-model.md)

## Tasks

### M5-T1 · Reminder schema & repository

**Description**
Design the user-facing reminder schema on top of the F5 `reminder`/`schedule` primitives and expose it through a repository that enforces the canonical contract at the boundary. A reminder row owns: vehicle FK, title/notes, **rule kind** (date / distance / engine-hour / whichever-first) with each dimension nullable (so whichever-first can mix any subset), the rule params (target date, distance threshold in canonical metres, engine-hour threshold), lead-time(s), severity, recurrence + completion anchor, snooze state, and lifecycle status with soft-delete/tombstone. Add a derived **live-state** view (upcoming / due-soon / overdue / snoozed / done) computed from the F5 next-due output plus the shared ledger, exposed as a Drift `.watch()` stream so UI and digests react without polling. All repository methods return the sealed `Result<T, Failure>`; no plugin or raw Drift types leak past the boundary.

**Acceptance criteria**
- [ ] Reminder table extends the F5 schedule primitives with title/notes, rule kind, per-dimension nullable params, lead-times, severity, recurrence + completion anchor, snooze state, and lifecycle/soft-delete — with a migration.
- [ ] Distance thresholds are stored in canonical units (metres) and engine-hours in canonical units; conversion happens only at display/entry per the canonical contract.
- [ ] Whichever-first rules may carry any subset of dimensions (a single-dimension rule is a degenerate whichever-first).
- [ ] A live-state stream (`upcoming`/`due-soon`/`overdue`/`snoozed`/`done`) is derived from the F5 next-due engine + ledger and exposed via `.watch()`.
- [ ] All repository methods return `Result<T, Failure>`; no Drift/plugin type leaks past the module boundary.

**Size:** M
**Depends on:** F2, F5
**Governing docs:** [Reference · Data model](../../reference/data-model.md), [Reminders & Notifications](../../features/04-reminders-notifications.md)

### M5-T2 · Projection scheduling

**Description**
Turn distance and engine-hour rules into **schedulable calendar dates** and keep them correct as the vehicle is used. Extend the F5 next-due engine's average-daily-distance / hours-accrual estimator (rolling window over the shared ledger, min-samples floor, explicit *insufficient-data* fallback) so a distance/engine-hour threshold projects to a concrete fire-instant. Subscribe to the ledger so that **every new reading** (from fuel fills, service, trips, or manual entry) triggers a **re-projection** of affected rules and a F5 reconcile, moving the due date earlier or later as real usage diverges from the estimate. When the estimate is stale (no recent readings), widen the lead-time and mark the projection **uncertain** rather than firing on a bad guess. For whichever-first rules, project each present dimension and take the earliest. All projection math is pure Dart with zero Flutter/plugin imports.

**Acceptance criteria**
- [ ] A distance threshold projects to a due date via the rolling average-daily-distance estimate; an engine-hour threshold projects via the hours-accrual rate.
- [ ] A new ledger reading re-projects every affected rule and reconciles the F5 queue so the due date self-corrects (verified: earlier reading → sooner date, slower usage → later date).
- [ ] The estimator enforces a min-samples floor and returns an explicit insufficient-data result instead of a spurious date.
- [ ] Stale data widens the lead-time and flags the projection uncertain rather than firing on a stale estimate.
- [ ] Whichever-first projects each present dimension and schedules the earliest.
- [ ] Projection math is pure Dart (no Flutter/plugin imports) and unit-testable in isolation.

**Size:** M
**Depends on:** M5-T1
**Governing docs:** [Reminders & Notifications](../../features/04-reminders-notifications.md), [Reference · Data model](../../reference/data-model.md)

### M5-T3 · Reminder management UI

**Description**
Build the PULSE reminder surfaces. A **create/edit** flow with rule-kind selection (date / distance / engine-hour / whichever-first), calendar- and numeral-aware inputs (active Gregorian/Jalali/Hijri date picker, active-numeral thresholds), unit-aware distance entry, lead-time and severity selection, recurrence, and draft autosave / back-exit confirmation. A **reminder view** that groups items **per severity** (overdue → due-soon → upcoming), showing live projected dates and the "estimate uncertain" state honestly, with a scoped emotional-temperature ache on the card that needs care per PULSE. **Snooze** (preset intervals) and **complete** actions, where completion re-anchors recurrence to the actual completion date and plays **the exhale** (the shared completion motion). Status is **redundantly encoded** — icon + label + shape + position — never colour alone.

**Acceptance criteria**
- [ ] Create/edit supports all four rule kinds with calendar/numeral/unit-aware inputs and draft autosave + back-exit confirmation.
- [ ] The reminder view groups items per severity and surfaces the projected due date plus the "estimate uncertain" state when projection confidence is low.
- [ ] Snooze offers preset intervals; complete re-anchors recurrence to the actual completion date and dismisses the OS entry via F5 reconcile.
- [ ] Completing a reminder plays the exhale (the shared PULSE completion motion), honoring reduced-motion.
- [ ] Every status is redundantly encoded (icon + label + shape + position), never colour-only; the ache/halo follows the PULSE scoped-temperature rule.
- [ ] All screens meet minimum touch targets and expose correct Semantics.

**Size:** M
**Depends on:** M5-T1, M5-T2, F3
**Governing docs:** [PULSE · Components](../../design/pulse/02-components.md), [PULSE · Motion, RTL & accessibility](../../design/pulse/04-motion-rtl-accessibility.md)

### M5-T4 · Digests & channels

**Description**
Configure how reminders are delivered. Build the **grouped-digest** config (delivery window / preferred time, quiet-hours, group-vs-single threshold) so a busy day collapses into one digest via the F5 grouping primitive, with single-item delivery when only one is due. Map each reminder's severity to its F5 **per-severity channel** (`overdue` / `due-soon` / `documents` / `info` or the reminder-relevant subset) with correct importance and iOS interruption levels. Produce **vehicle-named** body copy through the F4 layer — the vehicle name/plate bidi-isolated LTR inside RTL text, dates in the active calendar, numbers in the active numeral system — for both the digest summary and per-item lines. All arming/delivery flows through the F5 `NotificationService`; this task adds no new scheduling path.

**Acceptance criteria**
- [ ] Digest config (delivery window / preferred time, quiet-hours, group-vs-single threshold) persists and drives the F5 grouping so multiple due items deliver as one digest and a lone item delivers ungrouped.
- [ ] Each reminder routes to its severity channel with correct Android importance and iOS interruption level.
- [ ] Every body names its vehicle (plate/VIN bidi-isolated LTR) and is produced via F4 — no hardcoded strings.
- [ ] Digest summary and per-item copy render dates in the active calendar and numbers in the active numeral system.
- [ ] Delivery flows entirely through the F5 `NotificationService`; no parallel scheduler is introduced.

**Size:** M
**Depends on:** M5-T1, M5-T3, F5
**Governing docs:** [Flutter · Notifications](../../flutter/07-notifications.md), [PULSE · Components](../../design/pulse/02-components.md)

### M5-T5 · i18n strings

**Description**
Author every reminder-facing string as ICU-plural-correct ARB entries across the six locales (en/de/fr LTR + fa/ar/ckb RTL): rule-kind labels, status labels, create/edit form copy, snooze presets, digest titles, and per-item notification titles/bodies. Body templates interpolate vehicle name, projected date, and remaining distance/hours with correct plural forms, active-calendar date formatting, and active-numeral formatting (Western / Eastern-Arabic / Persian, correct grouping). No user-facing literal escapes the ARB pipeline; failure codes remain typed (never user strings).

**Acceptance criteria**
- [ ] All reminder UI + notification strings exist as ARB entries in en/de/fr + fa/ar/ckb with ICU-correct plurals.
- [ ] Body templates interpolate vehicle name, date, and distance/hours with active-calendar and active-numeral formatting.
- [ ] No hardcoded user-facing string remains in reminder code; typed failure codes carry no user text.
- [ ] Missing-translation and pluralization are validated in CI (analyzer / l10n check).

**Size:** S
**Depends on:** M5-T3, M5-T4, F4
**Governing docs:** [Flutter · i18n, RTL & calendars](../../flutter/06-i18n-rtl-calendars.md), [Reminders & Notifications](../../features/04-reminders-notifications.md)

### M5-T6 · Export/backup mapping

**Description**
Include reminders — with their **live scheduled state** — in the first-class backup/export subsystem. Map reminder rows (rule params, lead-times, severity, recurrence/completion anchor, snooze state, lifecycle) plus their derived projection/next-due state into the single-file backup and the combined JSON + per-entity CSV exports, schema-versioned and checksummed. On **restore/import**, reminders re-hydrate and immediately re-arm the OS queue via the F5 reconcile so a reinstall-then-restore reproduces the identical pending set. Provide the optional read-only `.ics` export of due dates as a convenience that does not mutate engine state.

**Acceptance criteria**
- [ ] Reminder rows including live scheduled/projection state are covered by the single-file backup and the JSON + per-entity CSV exports, schema-versioned and checksummed.
- [ ] Restore/import re-hydrates reminders and triggers F5 reconcile so all reminders re-arm immediately with no manual step.
- [ ] Reinstall-then-restore reproduces the identical pending set (no orphans, no duplicates).
- [ ] `.ics` export of due dates round-trips dates correctly and does not mutate engine state.

**Size:** S
**Depends on:** M5-T1, M5-T2, F6
**Governing docs:** [Reference · Data model](../../reference/data-model.md), [Reminders & Notifications](../../features/04-reminders-notifications.md)

### M5-T7 · Tests

**Description**
Comprehensive suite following the diamond-topped-pyramid strategy. **Exhaustive table-driven unit tests** on the pure-Dart projection/next-due logic: projection-to-date for distance and engine-hour rules, whichever-first ordering with nullable dimensions, the min-samples floor and insufficient-data fallback, stale-data widening, lead-time and quiet-hours shifting, and recurrence re-anchoring — including calendar/numeral boundary cases (DST, leap days, Jalali/Hijri month lengths). A dedicated **reschedule-on-reading** test asserts that injecting a new ledger reading re-projects the due date and drives a correct F5 reconcile diff. Widget/golden tests cover the reminder surfaces in RTL and LTR (redundant status encoding, the exhale on complete honoring reduced-motion). Restore-re-arm is covered by a fake-clock + injected-`tz` integration test.

**Acceptance criteria**
- [ ] Table-driven unit tests cover projection-to-date (distance + engine-hour) and whichever-first ordering with nullable dimensions at 100% line/branch on the pure-Dart logic.
- [ ] Min-samples floor, insufficient-data fallback, and stale-data widening have explicit cases.
- [ ] A reschedule-on-reading test proves a new ledger reading re-projects the date and produces the correct reconcile diff.
- [ ] Recurrence re-anchoring and DST / leap-day / Jalali / Hijri boundaries are tested.
- [ ] Widget/golden tests verify reminder surfaces in RTL + LTR with redundant status encoding and the exhale (reduced-motion respected).
- [ ] A fake-clock + injected-`tz` test verifies restore re-arms the identical pending set; the suite runs in CI with no real device.

**Size:** M
**Depends on:** M5-T2, M5-T3, M5-T4, M5-T6
**Governing docs:** [Flutter · Notifications](../../flutter/07-notifications.md), [Reminders & Notifications](../../features/04-reminders-notifications.md)

### M5-T8 · Motion, RTL & accessibility polish *(added — vertical-slice completeness)*

**Description**
Bring the reminder surfaces to the PULSE motion/RTL/accessibility bar. Wire the **exhale** completion motion and the scoped emotional-temperature **ache** (with the capped ambient halo) to reminder state, all honoring the reduced-motion preference. Verify full **RTL** correctness in fa/ar/ckb: mirrored layout and focus/traversal order, plate/VIN/threshold IDs bidi-isolated LTR, and calendar/numeral rendering inside mirrored surfaces. Ensure screen-reader labels read status **and** projected date correctly (including Eastern-Arabic/Persian numerals), every interactive target meets the minimum touch size, and status is conveyed by icon + label + shape + position so the UI is fully usable with colour removed.

**Acceptance criteria**
- [ ] The exhale plays on completion and the ache/halo follow the PULSE scoped-temperature rule; both collapse gracefully under reduced-motion.
- [ ] Reminder surfaces mirror correctly in fa/ar/ckb with correct focus/traversal order and LTR-isolated plate/VIN/threshold values.
- [ ] Screen readers announce status + projected date (with active numerals) in correct RTL reading order.
- [ ] All interactive targets meet the minimum touch-target size and expose correct Semantics.
- [ ] The reminder view is fully usable with colour removed (redundant icon + label + shape + position).

**Size:** S
**Depends on:** M5-T3, M5-T5
**Governing docs:** [PULSE · Motion, RTL & accessibility](../../design/pulse/04-motion-rtl-accessibility.md), [Flutter · i18n, RTL & calendars](../../flutter/06-i18n-rtl-calendars.md)

## Definition of Done

- [ ] **All four rule kinds** (date, distance, engine-hour, whichever-first) are authorable, carry correct live state over the shared ledger, and schedule through the single F5 engine — no parallel scheduler exists.
- [ ] **Projection is live:** distance/engine-hour rules project to dates via the ledger estimate and re-project on every new reading, degrading honestly (widened window + "estimate uncertain") on stale data.
- [ ] **PULSE surfaces:** create/edit, per-severity reminder view, and snooze/complete are implemented; completion plays the exhale; the ache/halo follow the scoped-temperature rule; status is redundantly encoded (icon + label + shape + position), never colour alone.
- [ ] **Digests & channels:** grouped digests and per-severity channel mapping work with vehicle-named copy.
- [ ] **Tests:** projection-to-date, whichever-first, and reschedule-on-reading are covered by 100% table-driven unit tests on the pure-Dart logic; RTL/LTR widget/golden and restore-re-arm tests are green in CI with no real device.
- [ ] **i18n complete:** every reminder UI and notification string is localized across en/de/fr + fa/ar/ckb, ICU-plural-correct, with active-calendar dates and active-numeral formatting; no hardcoded copy.
- [ ] **RTL verified:** all reminder surfaces and notification bodies render correctly mirrored in fa/ar/ckb with correct focus/reading order and plate/VIN/IDs bidi-isolated LTR.
- [ ] **In backup/export:** reminders including live scheduled state are in the single-file backup and JSON/CSV export (versioned + checksummed) and re-arm on restore; optional `.ics` export available.
- [ ] **Accessible:** minimum touch targets, correct Semantics reading status + projected date, reduced-motion honored, and status conveyed without colour per the redundant-encoding rule.
- [ ] **Boundary & dependency policy honored:** repository/APIs return sealed `Result<T, Failure>` with typed codes; no new runtime dependency is added beyond what F5 already carries.
