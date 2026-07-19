# M8 · Dashboard, Statistics & Reports

> The on-device analytics layer that fills the Rooms: glanceable customizable KPIs + quick-add, `CustomPainter` economy/cost/distance/CO₂ charts, rule-based insights & anomaly detection, forecasting with a min-samples fallback, gamification, and a complete localized report export.

## Goal

Turn the garage's canonical history into a **glance, a chart, and a report** — entirely on-device, correct by construction, and readable in every supported language, calendar, and numeral system.

Concretely this epic ships:

- **Aggregated KPIs over rollups.** Read the **pre-aggregated summary/rollup tables** (per vehicle, per period) rather than re-scanning raw records, so multi-year histories render instantly. KPIs (total spend, cost per distance, average/best/worst economy, distance, fill count, CO₂) resolve across scopes — one vehicle, all vehicles, fleet — driven by the shared active-vehicle selector.
- **A built-in `CustomPainter` chart suite.** Fuel-economy trend (with moving-average overlay), cost-over-time, distance-over-time, spend-by-category, and CO₂ footprint — no charting dependency. Every chart carries `Semantics`, renders locale numerals (incl. Eastern-Arabic/Persian), mirrors its chrome in RTL while preserving data orientation, and uses colour-blind-safe palettes with **pattern/label encodings** so meaning never depends on colour.
- **Insights & anomaly detection.** Rule-based, plain-language insights (economy drop below baseline, spend spike, odometer gaps/regressions/duplicates) surfaced on the Home **ache card** — scoped emotional-temperature on the card that needs care.
- **Forecasting with a min-samples fallback.** Spend/next-service projection that **refuses to guess** below a minimum-sample threshold, degrading honestly to an "insufficient data" state instead of a misleading number.
- **Customizable KPIs & quick-add.** User-arrangeable KPI tiles (show/hide/reorder, persisted locally) plus an on-dashboard quick-add surface so a fill-up or expense is one tap away.
- **A complete localized report export.** KPI-and-charts PDF and per-entity/full CSV, numeral- and calendar-aware, produced through the F6 export infrastructure (built-in-first: `dart:convert` JSON, hand-written CSV).
- **Gamification.** Streaks and badges tied to the **exhale** on completion.

Everything surfaces through PULSE components, is fully localized (LTR en/de/fr + RTL fa/ar/ckb), and is exercised by projection-fallback, aggregation-correctness, and chart-`Semantics` tests.

## Tier & dependencies

- **Tier:** mvp
- **Module:** `dashboard-statistics-reports`
- **Depends on:** F2, F3, F4, F6, M1, M3, M6, M7

## References

- [docs/features/17-dashboard-statistics-reports.md](../../features/17-dashboard-statistics-reports.md)
- [docs/flutter/10-performance-rendering.md](../../flutter/10-performance-rendering.md)
- [docs/flutter/11-testing.md](../../flutter/11-testing.md)
- [docs/design/pulse/02-components.md](../../design/pulse/02-components.md)
- [docs/design/pulse/03-screens.md](../../design/pulse/03-screens.md)
- [docs/reference/data-model.md](../../reference/data-model.md)

## Tasks

### M8-T1 · Stats aggregation over rollups

**Description.** The read layer for every KPI and stat. Consume the **pre-aggregated summary/rollup tables** (per vehicle, per period bucket) that the odometer/engine-hour ledger and the fuel/expense/service repos maintain — never a live full-table scan of raw records. Expose scope-aware aggregate queries (per-vehicle / all-vehicles / fleet) behind repository providers returning canonical values (SI measures, integer minor-unit money + ISO code, UTC instants), so the dashboard, charts, and reports all draw from one consistent source. Period bucketing is **calendar-aware** (Gregorian/Jalali/Hijri boundaries via F4) and mixed-currency scopes are surfaced safely, never silently summed.

**Acceptance criteria.**
- [ ] KPIs (total spend, cost/distance fuel-only + all-in, average/best/worst economy, distance, fill count, CO₂) resolve from rollup tables, not raw-record scans.
- [ ] Every aggregate is scope-aware: one vehicle, all vehicles, and fleet toggles produce correct, distinct results driven by the shared active-vehicle selector.
- [ ] Period buckets align to the active calendar's month/year boundaries (Gregorian/Jalali/Hijri) when a calendar-aware range is chosen.
- [ ] Mixed-currency scopes are flagged/segregated, never added across currencies; each value carries its ISO currency code.
- [ ] Values returned are canonical (SI, minor-unit money + code, UTC millis); display conversion happens only at render.
- [ ] Aggregate reads run off the UI thread and stay responsive on multi-year datasets.

**Size:** M
**Depends on:** F2 (canonical repos + rollup tables), M1 (odometer ledger/vehicle scope), M3 (service), M6 (fuel economy engine), M7 (expenses/TCO)
**Governing docs:** reference/data-model.md, flutter/10-performance-rendering.md, features/17-dashboard-statistics-reports.md

### M8-T2 · CustomPainter chart suite

**Description.** The built-in-first chart layer — **no charting dependency**. Implement fuel-economy trend (with a moving-average overlay), cost-over-time, distance-over-time (per-period bars + cumulative odometer line), spend-by-category (donut), and CO₂ footprint, all drawn with `CustomPainter`/`CustomPaint`. Feed them from M8-T1 aggregates with automatic downsampling/aggregation for large histories (per flutter/10). Each chart mirrors its **chrome** (axes, legends, tooltips) in RTL while preserving plotted-data orientation, renders axis/label numerals in the active numeral system, and uses colour-blind-safe palettes paired with pattern/shape/label encodings so no series is distinguishable by colour alone. Wrap every chart in `Semantics` exposing an accessible summary and per-series/data-point descriptions.

**Acceptance criteria.**
- [ ] Economy, cost, distance, spend-by-category, and CO₂ charts render via `CustomPainter` with no third-party charting package.
- [ ] Economy trend shows a moving-average overlay; distance chart shows per-period bars + cumulative odometer line.
- [ ] Large datasets are downsampled/aggregated so multi-year histories render smoothly at 60fps without jank (per flutter/10).
- [ ] Chart chrome mirrors in RTL; the data orientation itself is preserved; VIN/plate/IDs in labels stay LTR via bidi isolation.
- [ ] Axis and label numerals honour the active numeral system (incl. Eastern-Arabic/Persian) and calendar-formatted period labels.
- [ ] Palettes are colour-blind-safe and every series is also distinguished by pattern/shape/label, never colour alone.
- [ ] Each chart carries `Semantics` with an accessible summary and data-point descriptions; screen readers announce values correctly per locale.

**Size:** L
**Depends on:** M8-T1, F3 (PULSE tokens/components), F4 (i18n/RTL/numerals/calendars)
**Governing docs:** flutter/10-performance-rendering.md, design/pulse/02-components.md, design/pulse/03-screens.md, features/17-dashboard-statistics-reports.md

### M8-T3 · Insights & anomaly detection

**Description.** A rule-based engine (pure Dart) that turns the user's own aggregates into plain-language insights and anomaly flags: economy drop below the vehicle's rolling baseline, spend spike above historical norm, and data-integrity anomalies (odometer gaps, decreasing/rollover readings, duplicate entries) that would distort statistics. Insights are localized ICU strings (no string concatenation), scoped per vehicle, and surfaced on the **Home ache card** so the emotional-temperature/ache lands on the exact card that needs care — with the review prompt letting the user confirm or override rather than silently mutating stats.

**Acceptance criteria.**
- [ ] Rules detect economy-below-baseline and spend-above-norm using the vehicle's own history (own-baseline, not a global leaderboard).
- [ ] Data-integrity anomalies (odometer gap, decreasing/rollover reading, duplicate) are flagged for review, never silently discarded or turned into negative distance.
- [ ] Insight copy is generated from localized ICU messages/plurals — no concatenated fragments; correct in all six locales incl. RTL.
- [ ] Insights/anomalies are scoped to the selected vehicle/fleet and surface on the Home ache card per PULSE scoped-emotional-temperature.
- [ ] Anomaly review offers confirm/override; overriding preserves partial/missed-fill semantics and does not corrupt the rollups.
- [ ] The insights engine is pure Dart and unit-testable in isolation (covered in M8-T8).

**Size:** M
**Depends on:** M8-T1, M6 (economy baseline), M7 (spend history), M1 (odometer ledger)
**Governing docs:** features/17-dashboard-statistics-reports.md, design/pulse/03-screens.md, reference/data-model.md

### M8-T4 · Forecasting

**Description.** Projection engine (pure Dart) for spend forecast and predicted next-service-due date, computed from average daily distance / historical spend trend. Critically, it enforces a **minimum-sample / minimum-span threshold**: below it, the engine returns a typed **insufficient-data** result and the UI shows an honest "not enough history yet" state instead of a fabricated projection. Above threshold, it returns a projection with the basis it used (sample count, span) so the estimate is inspectable.

**Acceptance criteria.**
- [ ] Below the configured min-samples/min-span threshold the engine returns an explicit insufficient-data result — never a guessed number.
- [ ] At/above threshold it projects spend and next-service-due from average daily distance / spend trend, exposing the sample count and span used.
- [ ] Projection is a pure, deterministic function of its inputs (same inputs → same output) and unit-testable without the DB.
- [ ] The insufficient-data state renders as a PULSE empty/insufficient state, localized and redundantly encoded (icon + label), not a blank or a zero.
- [ ] Projected dates/distances render in the active calendar/numeral system; canonical values remain SI/UTC internally.

**Size:** M
**Depends on:** M8-T1, M1 (odometer/daily-distance), M7 (spend history)
**Governing docs:** flutter/11-testing.md, features/17-dashboard-statistics-reports.md, reference/data-model.md

### M8-T5 · Customizable KPIs & quick-add

**Description.** The dashboard front door. A user-arrangeable row/grid of **KPI tiles** (total spend, cost/distance, average economy, distance, fill count, CO₂ …) that the user can show/hide and reorder, with the layout persisted locally (and included in backup/export). Plus an on-dashboard **quick-add** surface (and app-shortcut entry points) that deep-links into the fuel/expense/service entry flows so the most common actions are one tap away. Built entirely from PULSE components with the active-vehicle summary header on top.

**Acceptance criteria.**
- [ ] User can pick which KPI tiles show, reorder them, and the arrangement persists across restarts.
- [ ] KPI-layout preferences are included in backup/export coverage (round-trip with the rest of settings).
- [ ] Quick-add surfaces (on-dashboard + app shortcuts) deep-link into fuel/expense/service entry and return cleanly to the dashboard.
- [ ] Tiles read from M8-T1 aggregates and reflect the active vehicle/fleet scope and selected period.
- [ ] All tiles/quick-add are PULSE components; the active-vehicle summary header states which car is shown with tap-to-switch.
- [ ] Reorder/drag interactions are accessible (screen-reader operable, min touch targets) and mirror correctly in RTL.

**Size:** M
**Depends on:** M8-T1, F3 (PULSE), F4 (i18n/RTL), M1 (active-vehicle selector), M6/M7 (entry flows for quick-add)
**Governing docs:** design/pulse/02-components.md, design/pulse/03-screens.md, features/17-dashboard-statistics-reports.md

### M8-T6 · Report export

**Description.** Localized report generation on top of the **F6 export infrastructure**. Produce a KPI-and-charts **PDF** (embedding the M8-T2 charts and headline stats) and per-entity / full **CSV** (UTF-8 + BOM, hand-written writer — built-in-first), plus a printable service/maintenance history report. Reports are numeral- and calendar-aware in their *rendered* form (language, RTL direction, numeral system, currency, calendar) while any machine-readable CSV/JSON export stays locale-neutral canonical for lossless re-import. Everything shares via the OS share sheet, fully offline.

**Acceptance criteria.**
- [ ] KPI-and-charts PDF bundles headline KPIs, totals, and embedded charts; layout mirrors correctly in RTL and honours the active calendar/numeral/currency.
- [ ] Full and per-entity CSV are produced by the F6 hand-written writer (UTF-8 + BOM, correct quoting/escaping) — no CSV dependency.
- [ ] A printable service-history report suitable for resale/warranty/insurance renders localized and shareable.
- [ ] Rendered reports use display formatting (locale numerals/dates/currency); machine-readable exports stay canonical (SI, minor-units + code, UTC) for lossless re-import.
- [ ] Reports generate off the UI thread and are shared via the OS share sheet with no network access.
- [ ] Report generation returns a sealed `Result<T, Failure>` at the boundary; failure surfaces as a localized PULSE error state.

**Size:** M
**Depends on:** M8-T1, M8-T2, F6 (export/CSV/JSON infra), F4 (i18n/RTL/calendars/numerals)
**Governing docs:** features/17-dashboard-statistics-reports.md, reference/data-model.md, design/pulse/03-screens.md

### M8-T7 · Gamification

**Description.** Lightweight streaks and badges that reward consistent logging, tied to the PULSE **exhale** on completion. Streaks (e.g. consecutive fill-ups logged, on-time services) and badges (milestones like distance/economy achievements against the user's own baseline) computed from existing aggregates — no new tracking, no leaderboards, no telemetry. Awarding a badge triggers the exhale micro-moment on the relevant card.

**Acceptance criteria.**
- [ ] Streaks/badges are computed from existing on-device aggregates; no network, no telemetry, no external leaderboard.
- [ ] Milestones are measured against the user's own baseline/history (private, self-referential).
- [ ] Earning a streak/badge fires the PULSE exhale completion moment on the relevant card (respecting reduced-motion).
- [ ] Badge/streak state is persisted locally and included in backup/export.
- [ ] Badge visuals are redundantly encoded (icon + label + shape), not colour-only, and screen-reader announced.

**Size:** S
**Depends on:** M8-T1, F3 (PULSE motion/exhale), M6/M7 (source events)
**Governing docs:** design/pulse/02-components.md, features/17-dashboard-statistics-reports.md

### M8-T8 · Tests

**Description.** The correctness guarantee for the analytics layer. Table-driven, pure-Dart unit tests on the aggregation, insights, projection, and gamification engines, plus widget/`Semantics` tests on the chart suite. Prioritize the **projection min-samples/insufficient-data fallback**, **aggregation correctness** across scopes and mixed currency, and **chart `Semantics`** (accessible summaries + data-point descriptions, correct numeral announcement).

**Acceptance criteria.**
- [ ] Projection tests cover below-threshold (insufficient-data result) and above-threshold (correct projection) boundaries exhaustively.
- [ ] Aggregation tests assert correct KPIs across per-vehicle / all-vehicles / fleet scopes and mixed-currency segregation.
- [ ] Chart `Semantics` tests assert accessible summaries and per-data-point labels, including Eastern-Arabic/Persian numeral rendering.
- [ ] Insights/anomaly rules tested for economy-drop, spend-spike, and odometer gap/regression/duplicate cases.
- [ ] Gamification streak/badge computation tested for boundary cases (streak break, milestone crossing).
- [ ] `flutter analyze` and `dart format --set-exit-if-changed` are clean.

**Size:** M
**Depends on:** M8-T1 … M8-T7
**Governing docs:** flutter/11-testing.md, features/17-dashboard-statistics-reports.md

### M8-T9 · Period filter, scope toggle & dashboard shell (added)

**Description.** The connective UI tissue that scopes every KPI, chart, insight, and report. A **period filter** (this month / year / all-time presets plus a **calendar-aware custom range** aligning to Jalali/Hijri/Gregorian boundaries) and a **per-vehicle vs all-vehicles/fleet toggle**, both flowing through the whole dashboard via the shared active-vehicle selector. Assembles the PULSE dashboard screen: active-vehicle summary header, KPI row (M8-T5), cards, and charts (M8-T2), with helpful empty/onboarding states for a fresh garage instead of blank charts.

**Acceptance criteria.**
- [ ] Period presets + a calendar-aware custom range are available and re-scope all KPIs/charts/insights/reports consistently.
- [ ] The per-vehicle / all-vehicles / fleet toggle re-scopes the entire dashboard and is driven by the shared active-vehicle selector.
- [ ] Empty/onboarding states guide a fresh install (no data) into onboarding rather than rendering blank/zero charts.
- [ ] The dashboard screen is composed from PULSE components per design/pulse/03-screens.md.
- [ ] Filter/toggle state is announced to screen readers and mirrors correctly in RTL.

**Size:** M
**Depends on:** M8-T1, M8-T2, M8-T5, F3 (PULSE), F4 (i18n/calendars), M1 (scope selector)
**Governing docs:** design/pulse/03-screens.md, design/pulse/02-components.md, features/17-dashboard-statistics-reports.md

### M8-T10 · Localization & accessibility pass (added)

**Description.** The cross-cutting completion pass over the whole module: every user-facing string (KPI labels, insight copy, chart labels/tooltips, report headings, badge names, empty states) in ARB across en/de/fr/fa/ar/ckb; all numerals/dates/currencies rendered per the active locale/calendar/numeral system; full RTL mirroring with mirrored focus/traversal; and redundant-encoding compliance (status/series never colour-only) verified with a screen reader in each locale.

**Acceptance criteria.**
- [ ] 100% of user-facing strings are in ARB across en/de/fr/fa/ar/ckb; no hardcoded UI text; insights use ICU messages/plurals.
- [ ] Numerals, dates, and currencies render per the active locale/calendar/numeral system across dashboard, charts, and rendered reports.
- [ ] Every screen mirrors correctly in RTL with mirrored focus/traversal order; VIN/plate/IDs/checksums held LTR via bidi isolation.
- [ ] All status/series are redundantly encoded (icon + label + shape/position) beyond colour; verified against the colour-blind-safe palette.
- [ ] Screen readers (TalkBack/VoiceOver) announce KPIs, chart summaries, insights, and warnings correctly in every locale.

**Size:** M
**Depends on:** M8-T2, M8-T3, M8-T5, M8-T6, M8-T9, F4 (i18n/RTL engine)
**Governing docs:** design/pulse/02-components.md, flutter/11-testing.md, features/17-dashboard-statistics-reports.md

## Definition of Done

- **Vertical slice complete:** rollup reads → aggregation/insights/projection/gamification engines → `CustomPainter` charts → PULSE dashboard shell (KPIs, quick-add, period/scope filters) → localized PDF/CSV report export via F6 → tests, all landed and wired.
- **Tests:** table-driven pure-Dart unit tests on aggregation, insights/anomaly, projection (both min-samples fallback and above-threshold paths), and gamification; widget/`Semantics` tests on the chart suite. `flutter analyze` and `dart format --set-exit-if-changed` clean.
- **Built-in-first honored:** all charts drawn with `CustomPainter` (no charting package); reports on the F6 `dart:convert` JSON + hand-written CSV infra; no new runtime dependency introduced by this epic.
- **i18n complete:** 100% of user-facing strings in ARB across en/de/fr/fa/ar/ckb; insights via ICU messages/plurals; numerals/dates/currencies localized on display while machine-readable exports stay locale-neutral canonical.
- **RTL verified:** every dashboard/chart/report screen mirrors correctly with mirrored focus order; chart chrome mirrors while plotted-data orientation is preserved; VIN/plate/IBAN/IDs held LTR via bidi isolation.
- **In backup/export:** KPI-layout preferences and gamification (streak/badge) state are included in backup/export coverage; reports export offline via the OS share sheet.
- **Accessible per the redundant-encoding rule:** all statuses and chart series encoded with icon + label + shape/position beyond colour on a colour-blind-safe palette; every custom chart/tile carries `Semantics`; screen readers announce KPIs, chart summaries, insights, forecasts, and the insufficient-data state correctly (incl. Eastern-Arabic/Persian numerals) in every locale.
- **Correctness & honesty:** aggregates read from rollups (no raw-scan drift); mixed currencies never silently summed; forecasting returns an explicit insufficient-data state below threshold rather than guessing; anomalies prompt review instead of corrupting stats.
- **Failure discipline:** report/export module-boundary APIs return sealed `Result<T, Failure>` with stable codes/typed params (never user strings); no partial or misleading artifact on any failure path.
