# M10 · Onboarding, Help & Education

> A strong first-run and ongoing-help layer beyond the language wizard — guided permission/OEM-survival onboarding, a demo vehicle, a guided tour, contextual education, and searchable in-app help/FAQ, all fully offline.

## Goal

Deliver the first-run experience and the always-available help layer that make Car and Pain approachable without any account, network, or telemetry. This is the module that decides whether a new user ever reaches the "aha": it must set locale/calendar/numeral/unit preferences **before** any data is entered (so nothing is captured in the wrong system and later mis-displayed), earn the notification and exact-alarm permissions the reminder engine depends on with honest rationale, and walk the user through the OEM battery-optimization gauntlet that otherwise silently kills scheduled reminders on many Android devices.

Beyond first-run, the module ships an **ongoing** education and self-service surface: a **demo/sample vehicle** with realistic history that a user can explore and then cleanly tear down; a **guided tour** with PULSE coach-marks over the real UI; **contextual explainers** for the genuinely non-obvious features (Total Cost of Ownership, full-to-full fuel economy, and the four calendars); and a **bundled, searchable help/FAQ** that works with the radio off. Every surface here is offline, localized across all six languages with correct RTL and numerals, re-runnable from Settings, accessible per the redundant-encoding rule, and its persisted state (onboarding progress, tour completion, help bookmarks) is included in backup/export. Built-in-first: coach-marks are a first-party `Overlay`/`CustomPainter` spotlight (no showcase dependency), help search is SQLite **FTS5** over bundled content, and the only sanctioned third-party surface is `permission_handler` for the permissions/OEM flow.

## Tier & dependencies

- **Tier:** MVP (`mvp`) — the ninth MVP module; the front door and retention layer that ties the other MVP modules together.
- **Depends on:**
  - **F2** — Encrypted data layer (Drift + SQLCipher, canonical model, migrations, soft-delete) — persists onboarding/help state and hosts the FTS5 help index.
  - **F3** — PULSE design system implementation (tokens + components) — coach-marks, explainer sheets, wizard screens.
  - **F4** — i18n / RTL / calendars / numerals engine — the wizard writes the very settings this engine consumes.
  - **F5** — Local notification engine — the permissions/exact-alarm/OEM flow exists to keep this engine reliable.
  - **M1** — Shared odometer/engine-hour ledger + canonical-contract repository foundation — the demo vehicle seeds real ledger + record rows.
  - **M2** — Vehicles, Garage & Odometer — the demo vehicle is a real `Vehicle` with real history; the tour points at the Garage room.

## References

- [docs/features/25-onboarding-help.md](../../features/25-onboarding-help.md) — feature spec: first-run flow, demo vehicle, tour, contextual education, help/FAQ, edge cases.
- [docs/flutter/16-permissions-onboarding-oem.md](../../flutter/16-permissions-onboarding-oem.md) — `permission_handler` flow, notification + exact-alarm rationale, OEM battery-optimization walkthrough, delivery-reliability surface.
- [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md) — gen-l10n/ARB, RTL mirroring, bidi isolation, calendars, numerals — governs the first-run wizard and all copy.
- [docs/design/pulse/03-screens.md](../../design/pulse/03-screens.md) — A1 first-run / add-vehicle blueprint, wizard and sheet patterns, empty/help states.
- [docs/design/pulse/04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md) — coach-mark motion, reduced-motion, RTL mirroring, redundant status encoding, Semantics.
- [docs/reference/data-model.md](../../reference/data-model.md) — canonical conventions and the entity contracts for onboarding/help state, demo-seed records, and export/backup mapping.

## Tasks

### M10-T1 · First-run language & unit wizard

**Description.** The very first screen a new install shows: a short, skippable-with-defaults wizard that captures locale, script/numeral system, calendar, distance/volume/consumption units, and currency **before** any data entry, then writes them through the F4 settings so the rest of the app renders correctly from record #1. Language selection is offered in each language's own name/script; the wizard itself re-renders (including LTR↔RTL flip) live as the language changes. A sensible device-locale default is pre-selected so a user can advance with one tap. This is the language/unit foundation the epic layers everything else on; it must be re-runnable later from Settings without data loss (changing units never mutates canonically stored SI/minor-unit values, only display).

**Acceptance criteria**
- [ ] First launch on a fresh install routes into the wizard before the home/garage; a returning user (onboarding-complete flag set) never sees it.
- [ ] Locale, numeral system, calendar, distance/volume/consumption units, and currency are all selectable, pre-seeded from device locale, and persisted via the F4 settings store.
- [ ] Language options display in their own endonym/script; selecting an RTL language flips the wizard layout live before completion.
- [ ] Choices take effect app-wide immediately (numerals, calendar, units) and re-running the wizard from Settings updates display only — canonical SI/minor-unit values are never rewritten.
- [ ] Advancing with defaults requires no typing; the whole wizard is reachable/operable by screen reader with correct RTL traversal.

**Size:** M · **Depends on:** F4, F3, M10-T7 · **Governing docs:** 06-i18n-rtl-calendars.md, 03-screens.md (A1), 25-onboarding-help.md (first-run).

### M10-T2 · Permissions & OEM-survival flow

**Description.** A guided, honest permissions surface built with `permission_handler` (the sanctioned dependency) that is treated as a **delivery-reliability** feature, not a modal nag. It requests notification permission and, where the platform requires it for exact reminders, the exact-alarm permission — each preceded by a plain-language rationale screen explaining exactly what breaks without it (missed service/document/insurance reminders). It then walks the user through the OEM battery-optimization gauntlet: detect the manufacturer, deep-link to the correct "unrestricted / don't optimize" setting where an intent exists, and otherwise show illustrated per-OEM steps (the notorious Xiaomi/Huawei/Samsung/Oppo cases). Denials are non-blocking and recoverable: the app degrades honestly, records the permission state, and offers a re-prompt entry point from Settings and from the reminder module. Coordinates with F5 so the notification engine knows whether it may schedule exact vs. inexact alarms.

**Acceptance criteria**
- [ ] Notification and (where required) exact-alarm permissions are each requested only after a localized rationale screen; the OS dialog is never the first thing the user sees.
- [ ] Manufacturer is detected and, where a settings intent exists, the flow deep-links to the exact battery-optimization page; otherwise illustrated per-OEM step cards are shown.
- [ ] Every permission/optimization state is persisted and readable by F5 so scheduling chooses exact vs. inexact correctly; a denied/undecided state degrades honestly rather than crashing or silently failing.
- [ ] All denials are recoverable via a re-prompt entry from Settings and from the reminders surface; nothing in the flow is a hard block to using the app.
- [ ] Rationale and OEM steps are fully localized (six locales), RTL-mirrored, and screen-reader operable; illustrations carry text alternatives (redundant encoding, not image-only).

**Size:** M · **Depends on:** F5, M10-T7 · **Governing docs:** 16-permissions-onboarding-oem.md, 25-onboarding-help.md (permissions), 04-motion-rtl-accessibility.md.

### M10-T3 · Demo / sample vehicle

**Description.** A one-tap "explore with a sample car" path that seeds a real `Vehicle` (M2) plus realistic linked history — a spread of fuel fills (full and partial), a couple of service visits, expenses, and odometer readings on the shared ledger — so the dashboard, economy math, and TCO all have something meaningful to show a brand-new user. The demo data is clearly flagged as sample (`is_demo`), scoped so it never contaminates real analytics/averages once real data exists, and is **cleanly tearable-down** in a single transactional action that removes the vehicle and every linked record/attachment with no orphans. Re-seeding after teardown is idempotent. Available both from first-run and later from Settings/Help.

**Acceptance criteria**
- [ ] Seeding creates one `is_demo` vehicle with linked fuel/service/expense/odometer rows through the real repositories, so real dashboard/economy/TCO surfaces render populated.
- [ ] Demo records are excluded from real-vehicle analytics and never merge into a real vehicle's history.
- [ ] Teardown removes the demo vehicle and all linked records + attachments in one transaction with zero orphaned rows or files; the action is confirmed before running.
- [ ] Seed/teardown/re-seed are idempotent and reachable from both first-run and Settings/Help.
- [ ] Demo content (nickname, notes) is localized and its "sample" status is redundantly encoded (icon + label), not color alone.

**Size:** S · **Depends on:** M2, M1, M10-T7 · **Governing docs:** 25-onboarding-help.md (demo vehicle), data-model.md (demo-seed mapping), 01-vehicles-garage.md.

### M10-T4 · Guided tour & contextual education

**Description.** Two related surfaces. (1) A **guided tour**: first-party PULSE coach-marks (an `Overlay` + `CustomPainter` spotlight/scrim with a callout bubble — no third-party showcase package) that highlight the real Rooms nav (Cockpit / Garage / Pit-lane), quick-add, and the active-vehicle switcher over the live UI, advanceable/dismissable, resumable, and shown once (tracked per step). (2) **Contextual explainers**: inline "what is this?" affordances that open PULSE bottom-sheets explaining the genuinely non-obvious concepts — **Total Cost of Ownership**, **full-to-full fuel economy** (why partial fills roll into the next full fill), and the **calendar systems** — using the user's own numerals/calendar in worked examples. Explainers are content-driven (same bundled content store as help/FAQ) so they stay translatable and editable. All motion respects reduced-motion; the coach-mark spotlight is never the only cue.

**Acceptance criteria**
- [ ] Coach-marks are a first-party Overlay/CustomPainter implementation (no showcase dependency) that spotlight real widgets, mirror correctly in RTL, and honor reduced-motion (fade instead of animate).
- [ ] Tour steps are shown once, individually dismissable, fully skippable, and resumable; completion/seen state persists and is re-runnable from Help.
- [ ] Contextual "explain" affordances exist on the TCO, full-to-full economy, and calendar surfaces and open localized PULSE sheets with worked examples in the user's numerals/calendar.
- [ ] Explainer copy is sourced from the bundled content store (shared with T5), not hardcoded, so it is translatable and searchable.
- [ ] Tour and explainers are screen-reader operable with correct focus order; the spotlight target is also announced/labelled, never conveyed by highlight alone.

**Size:** M · **Depends on:** F3, M2, M10-T5, M10-T7 · **Governing docs:** 03-screens.md, 04-motion-rtl-accessibility.md (coach-mark motion, reduced-motion), 25-onboarding-help.md (tour, contextual education).

### M10-T5 · Searchable help / FAQ

**Description.** A bundled, fully offline help center and FAQ. Help content authored as structured assets (Markdown/JSON with stable topic ids, categories, and localized bodies per locale) is bundled with the app and compiled into a Drift **FTS5** virtual table at first run / on content-version bump. The UI offers browse-by-category and a search box; search is built-in FTS5 (with numeral-folding and script normalization so a query in Eastern-Arabic digits or with/without diacritics still matches), returning ranked topics with snippet highlights. Topics render as PULSE article screens, deep-linkable from contextual explainers (T4) and from empty states across the app. Users can bookmark topics; bookmarks persist and export. No network: "last updated" reflects the bundled content version honestly.

**Acceptance criteria**
- [ ] Bundled help/FAQ content is authored per-locale with stable topic ids and compiled into an FTS5 index built at first run and rebuilt on content-version change (not on every launch).
- [ ] Search runs entirely offline via SQLite FTS5, returns ranked results with highlighted snippets, and matches across numeral systems (digit-folded) and diacritic variants (script-normalized).
- [ ] Browse-by-category and full-text search both resolve to PULSE article screens; articles are deep-linkable from T4 explainers and from module empty states.
- [ ] Bookmarks persist per topic id, survive re-index/content updates, and are included in backup/export.
- [ ] Content and chrome are localized for all six locales with correct RTL and numerals; a topic with no translation falls back gracefully and is flagged.

**Size:** M · **Depends on:** F2, F3, M10-T7 · **Governing docs:** 25-onboarding-help.md (help/FAQ), 06-i18n-rtl-calendars.md (numeral folding, RTL), 03-screens.md.

### M10-T6 · i18n strings & flow tests

**Description.** Externalize every user-facing string in this module — wizard, rationale/OEM steps, demo copy, tour callouts, explainer sheets, help chrome — to ARB via gen-l10n across en/de/fr (LTR) and fa/ar/ckb (RTL), keeping structural identifiers bidi-isolated where they appear. Then verify the flows end-to-end: table-driven unit tests for help-search numeral-folding/normalization and FTS ranking, and for demo seed/teardown idempotency and orphan-freeness; widget tests for the first-run wizard (defaults path, live RTL flip), the permission/OEM flow branches (granted / denied-recoverable / OEM-with-intent / OEM-manual), the coach-mark tour (once-only, resumable, reduced-motion), and help search→article deep-link. RTL/pseudolocale render checks and Semantics/a11y assertions on every screen in the module.

**Acceptance criteria**
- [ ] No hardcoded user-facing strings remain; all wizard/permission/OEM/demo/tour/explainer/help strings resolve through ARB for all six locales; VIN/plate/IDs in any demo content stay LTR via bidi isolation.
- [ ] Help-search folding/normalization and FTS ranking, plus demo seed/teardown idempotency and orphan-freeness, are covered by table-driven unit tests.
- [ ] Widget tests cover the wizard defaults path + live RTL flip, all four permission/OEM branches, coach-mark once-only/resumable/reduced-motion behavior, and help-search→article deep-link.
- [ ] RTL/pseudolocale render checks and Semantics/a11y assertions pass on the wizard, permission/OEM, demo, tour, explainer, and help screens.
- [ ] `flutter analyze` + `dart format --set-exit-if-changed` are clean.

**Size:** S · **Depends on:** M10-T1..T5, M10-T7, M10-T8, F4 · **Governing docs:** 11-testing.md, 06-i18n-rtl-calendars.md, 15-accessibility-dynamic-type, 25-onboarding-help.md.

### M10-T7 · Onboarding & help-state schema & repository (added)

**Description.** The persistence foundation the rest of the module writes through — added to complete the schema→repo layer of the vertical slice. Define the Drift tables/rows for onboarding state (`onboarding_completed`, wizard-step progress, permission + battery-optimization state per platform, tour step-seen map, `is_demo`-active flag) and help state (bundled `content_version`, per-topic bookmarks), plus the FTS5 virtual table for T5. Build an `OnboardingHelpRepository` over the F2 canonical boundary exposing Drift `.watch()` streams for reactive UI (e.g. "should we show the wizard/tour?") and returning a sealed `Result<T, Failure>` at every boundary. All state uses stable enum/string codes (no user strings) so it is portable, backup-safe, and future-P2P-safe.

**Acceptance criteria**
- [ ] Drift tables cover onboarding completion + step progress, permission/OEM state, tour seen-map, demo-active flag, help content-version, and topic bookmarks — each with the universal audit/soft-delete columns where applicable.
- [ ] The FTS5 virtual table for help content is defined and migration-guarded (forward-only, snapshot-guarded, `schema_version` bump).
- [ ] Repository exposes reactive `watch*` streams driving routing decisions (show wizard? show tour step? is demo active?) and CRUD returning `Result` over a sealed `Failure` hierarchy with stable codes.
- [ ] All persisted state is code-based (enums/ids), contains no localized user strings, and is readable by F5 (permission state) and F6 (export).

**Size:** S · **Depends on:** F2, M1 · **Governing docs:** data-model.md (onboarding/help entities), 03-data-persistence, 25-onboarding-help.md.

### M10-T8 · Export/backup mapping & Settings re-entry (added)

**Description.** Wire this module's durable state into the F6 export/backup subsystem and expose its re-runnable entry points — added to complete the export/backup and settings-integration slice. Onboarding preferences, permission/OEM state, tour progress, and help bookmarks map into the combined JSON/ZIP backup and (where meaningful) per-entity CSV, round-tripping losslessly and reconciling merge-aware by UUID with tombstones honored. Explicitly **exclude** demo-vehicle rows from real backups (or clearly mark them so a restore does not resurrect sample data as real). Add the Settings/Help re-entry points that re-run the language/unit wizard, re-open the permission/OEM flow, replay the guided tour, and seed/tear-down the demo vehicle — so the whole module is reachable after first-run, not one-shot.

**Acceptance criteria**
- [ ] Onboarding preferences, permission/OEM state, tour progress, and help bookmarks are included in the combined JSON/ZIP backup and restore losslessly; restore reconciles by UUID last-write-wins and honors tombstones.
- [ ] Demo-vehicle data is excluded from (or unambiguously flagged in) real backups so a restore never turns sample data into real history.
- [ ] Settings/Help expose working re-entry points for: re-run wizard, re-open permission/OEM flow, replay tour, and seed/teardown demo.
- [ ] A round-trip export→import of the module's state is verified lossless and idempotent.

**Size:** S · **Depends on:** F6, M10-T7, M10-T1, M10-T2, M10-T3, M10-T4, M10-T5 · **Governing docs:** data-model.md (export/backup mapping), 25-onboarding-help.md, 18-data-offline-backup.

## Definition of Done

- **Functionality:** Fresh installs run the language/unit wizard before any data entry; the permission/OEM flow requests notification + exact-alarm with rationale and walks the battery-optimization gauntlet with honest, recoverable degradation; a demo vehicle seeds and tears down cleanly; a first-party coach-mark tour and contextual TCO/economy/calendar explainers work over the live UI; and a bundled FTS5 help/FAQ is searchable and browsable — all fully offline, and all re-runnable from Settings/Help.
- **Built-in-first:** No new runtime third-party dependency beyond the sanctioned set; `permission_handler` is the only added surface, coach-marks are a first-party `Overlay`/`CustomPainter` spotlight, help search is SQLite FTS5, help/explainer content is bundled assets, and state is DB streams + repositories returning `Result`/`Failure`.
- **Tests:** Pure-Dart help-search folding/ranking and demo seed/teardown idempotency covered by table-driven unit tests; wizard, permission/OEM branches, tour, and help-deep-link widget/integration tests green; `flutter analyze` + `dart format --set-exit-if-changed` clean.
- **i18n complete:** Every user-facing string (wizard, rationale/OEM steps, demo copy, tour, explainers, help chrome and bundled content) externalized to ARB for en/de/fr/fa/ar/ckb; numerals and calendars honored in worked examples; untranslated help topics fall back gracefully and are flagged.
- **RTL verified:** Wizard, permission/OEM, demo, tour, explainer, and help screens mirror layout and traversal order; coach-mark spotlight and callouts mirror in RTL; any structural identifiers stay LTR via bidi isolation; RTL/pseudolocale check passes.
- **Backup/export:** Onboarding preferences, permission/OEM state, tour progress, and help bookmarks round-trip losslessly through the combined JSON/ZIP backup with merge-aware, tombstone-honoring restore; demo data is excluded from (or clearly flagged in) real backups.
- **Accessible:** Coach-mark targets, permission/OEM illustrations, and demo/sample status are redundantly encoded (icon + label + shape/position, plus text alternatives), never color or highlight alone; all screens carry Semantics labels, reflow under dynamic type, honor reduced-motion, and meet minimum touch targets.
