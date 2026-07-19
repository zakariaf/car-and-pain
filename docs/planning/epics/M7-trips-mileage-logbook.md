# M7 · Trips & Mileage Logbook

> Manual and optional on-device-GPS trip logging: business/personal tax classification, effective-dated IRS/HMRC/custom rate engines, odometer-gap reconciliation, and a road-trip mode linking fuel and expenses — degrading honestly without the Tier-2 offline map.

## Goal

Ship the trips & mileage logbook as an **audit-proof, 100%-offline tax record** — the numbers must survive a tax audit and a phone swap without an account or a server. Concretely this epic delivers:

- **Manual-first capture.** Log a trip by start/end odometer (distance computed and written back to the shared per-vehicle odometer ledger), by raw distance, or by picking two saved locations — whichever is fastest at that moment.
- **Business/personal/commute classification.** Every trip is tagged once against a custom taxonomy with default deductibility; commute journeys are the separately-treated non-deductible category.
- **Effective-dated rate engines.** Price each trip by IRS, HMRC, or fully custom schemes that are **effective-dated, tiered, and vehicle-class aware** — the right cents-or-pence-per-distance for the trip's actual date, with correct mid-year rate changes and HMRC 45p→25p tier crossing at 10,000 miles.
- **Odometer-gap reconciliation.** Compare each trip's start against the previous trip's end to surface gaps, catching forgotten journeys before they corrupt the business-use percentage; reconstructed trips are flagged non-contemporaneous.
- **Optional on-device GPS.** Opt-in, low-power detection with an explicit always-visible on/off state and clear permission rationale — distance derived purely from local track points, never online routing or reverse geocoding. Denied permission degrades to fully-manual logging with everything else intact.
- **Road-trip mode.** A multi-day container grouping legs, linked fuel fills, and linked expenses into one per-trip P&L with live running totals — degrading **honestly** to saved-location labels / raw coordinates where the Tier-2 offline map (`maps-location`) is not present.

Everything stores canonical values (SI distance, UTC/Gregorian dates, integer minor-unit money + ISO code) so switching units, currency, calendar, or language never rewrites history. Every surface is a PULSE component, fully localized (LTR en/de/fr + RTL fa/ar/ckb) with correct numerals/calendars, redundantly-encoded status, and included in backup/export.

## Tier & dependencies

- **Tier:** mvp
- **Module:** `trips-mileage`
- **Depends on:** F2, F3, F4, F6, M2

## References

- [docs/features/06-trips-mileage.md](../../features/06-trips-mileage.md)
- [docs/flutter/03-data-persistence.md](../../flutter/03-data-persistence.md)
- [docs/flutter/14-money-currency-fx.md](../../flutter/14-money-currency-fx.md)
- [docs/flutter/16-permissions-onboarding-oem.md](../../flutter/16-permissions-onboarding-oem.md)
- [docs/design/pulse/02-components.md](../../design/pulse/02-components.md)
- [docs/reference/data-model.md](../../reference/data-model.md)

## Tasks

### M7-T1 · Trip schema & repository

**Description.** Define the `trips` Drift schema (and supporting `saved_locations` / `rate_schemes` / `roadtrips` tables) per the data model, and the boundary repository that owns manual trip entry. Support entry by odometer (compute `distance = end_odometer − start_odometer`), by direct distance, and by from/to saved locations. Classify each trip (unclassified/business/personal/commute) against the custom taxonomy with default deductibility. On write, push `start_odometer`/`end_odometer` into the **shared per-vehicle odometer ledger** (source-tagged), keeping the series monotonic. Run **odometer-gap reconciliation**: compare each trip's start against the previous trip's end to compute `gap_distance` and surface missing-trip warnings, with a personal-use gap-fill path. All values stored canonically (SI distance, UTC/Gregorian dates, integer minor-unit money + ISO code); the boundary returns sealed `Result<T, ValidationFailure|DbFailure>` — never throws across the module edge.

**Acceptance criteria.**
- [ ] Trip can be created by odometer, by direct distance, or by from/to saved location; distance is computed and validated (zero/negative rejected with a typed `ValidationFailure`).
- [ ] Odometer readings write to the shared per-vehicle ledger, source-tagged as `trip`, and keep the series monotonic (rollover/offset events respected).
- [ ] Gap reconciliation computes `gap_distance = next_start_odometer − prev_end_odometer` and surfaces a warning with override; a personal-use gap-fill entry reconciles the series without inventing business miles.
- [ ] Each trip carries `classification_status`, `is_deductible`, `category`, and `is_contemporaneous`; reconstructed trips are flagged non-contemporaneous.
- [ ] All measures stored SI-canonical with per-vehicle/per-record unit overrides; money as integer minor units + ISO code; dates as UTC/Gregorian instants.
- [ ] Repository is stream-backed (Drift `.watch()`), scoped by active vehicle, and returns sealed `Result` at the boundary.

**Size:** M
**Depends on:** F2 (canonical repos, odometer ledger, validation), M2 (fuel entities for later linking)
**Governing docs:** flutter/03-data-persistence.md, reference/data-model.md, features/06-trips-mileage.md

### M7-T2 · Optional GPS logging

**Description.** Opt-in, low-power on-device GPS trip capture with an **always-visible active/inactive status** so the user knows exactly when location is being read. Route the permission request through the guided rationale flow (`permission_handler`): a clear pre-prompt explaining why, granular and revocable, with a graceful **manual fallback** if denied or revoked. Distance is derived purely from local `gps_track_points` — **no online routing, no reverse geocoding**. Handle GPS drift / tunnels / signal loss (manually correctable), OS killing the tracker (fragments recoverable via merge), and duplicate trips from overlapping auto-detection + manual entry (de-duplicated). Detected trips arrive unclassified for later one-tap classification.

**Acceptance criteria.**
- [ ] Location permission is requested behind a localized rationale pre-prompt; denial or later revocation degrades to fully-manual logging with every other feature intact.
- [ ] An always-visible indicator shows whether GPS logging is currently active; the feature is off by default and opt-in.
- [ ] Distance is computed only from on-device track points — no network call, no reverse geocoding; works in airplane mode.
- [ ] GPS-inflated/truncated distance is manually correctable; a fragmented (OS-killed) track is recoverable by merging pieces.
- [ ] Auto-detected trips that overlap a manual entry are de-duplicated; detected trips land as `unclassified` with `auto_detected = true`.
- [ ] Permission/sensor failures return a typed failure surfaced as a PULSE state; no crash on denied permission.

**Size:** M
**Depends on:** M7-T1, F2 (ledger)
**Governing docs:** flutter/16-permissions-onboarding-oem.md, features/06-trips-mileage.md

### M7-T3 · Rate engines

**Description.** A pure-Dart, **effective-dated** mileage-rate engine covering IRS, HMRC, and fully custom schemes. Rates are tiered (HMRC 45p below / 25p above the 10,000-mile threshold), vehicle-class aware (car/van, motorcycle, bicycle), and optionally carry per-passenger add-ons (HMRC 5p/passenger). Given a trip's date, distance, vehicle class, and running tax-year total, resolve `applicable_rate` and `tier_applied`, then compute `deduction = billable_distance × applicable_rate (+ passenger_rate × passenger_count)`. Correctly split a single claim across an **IRS mid-year rate change** and an **HMRC tier crossing**, and respect **tax-year boundaries** (UK 6 April, US 1 January) for YTD totals and threshold resets. Roll classified trips into running YTD deduction/reimbursement and business-use-percentage totals.

**Acceptance criteria.**
- [ ] Rate schemes are effective-dated; the rate applied is the one in force on the trip's actual date, tested across a mid-year IRS change.
- [ ] Tiered schemes split a claim at the threshold (HMRC 45p→25p at 10,000 mi) using the correct running tax-year total, not per-trip distance.
- [ ] Vehicle-class rates and per-passenger add-ons are applied distinctly and correctly.
- [ ] Tax-year boundaries (UK 6 April, US 1 January) drive YTD totals and threshold resets; a trip near the boundary lands in the correct year.
- [ ] Custom schemes are user-definable (tiers, rates, effective dates, vehicle classes) and persist in backup/export.
- [ ] `business_use_percentage = business_distance / total_distance` and running YTD deduction/reimbursement totals are exposed for reports; engine is pure, deterministic, and side-effect-free.

**Size:** M
**Depends on:** M7-T1, F4 (calendars/tax-year math), F2 (canonical money)
**Governing docs:** flutter/14-money-currency-fx.md, features/06-trips-mileage.md, reference/data-model.md

### M7-T4 · Road-trip mode

**Description.** A multi-day road-trip container that groups individual legs (each with its own odometer reading and `leg_sequence`), **links fuel fills** (from M2) and **linked expenses** (tolls/parking/lodging) into one per-trip P&L. Compute live running totals: distance, spend, fuel economy (aggregated full-tank-to-full-tank so partial fills defer, never producing a wrong figure), days elapsed, daily average (`avg_cost_per_day`), `cost_per_distance = per_trip_cost / distance`, and `per_person_share = total_cost / companion_count`. Handle EV/PHEV and mixed-energy trips (kWh alongside volume). Where the Tier-2 offline map module (`maps-location`) is absent, degrade **honestly**: render leg/waypoint labels from saved locations, manual labels, or raw coordinates with a clear "map unavailable" affordance — never a broken or blank map, never a fabricated route.

**Acceptance criteria.**
- [ ] A road trip groups its legs, linked fuel fills, and linked expenses into one container producing a per-trip P&L.
- [ ] Running totals (distance, spend, days elapsed, daily average, per-person share, cost-per-distance) update live as legs/receipts are added.
- [ ] Aggregated fuel economy is computed full-to-full across fills; a partial fill defers the figure rather than reporting a wrong one; EV/PHEV energy is handled in the user's chosen units.
- [ ] Midnight-spanning / multi-day / DST / cross-border trips are aggregated without double-counting.
- [ ] With no offline map available, waypoints/endpoints show saved-location or manual labels or raw coordinates behind a clear "map unavailable" state — no blank map, no invented route.
- [ ] Linked fuel/expense records resolve after backup/restore (re-linked, not dangling).

**Size:** M
**Depends on:** M7-T1, M2 (fuel/charge fills), F2 (linked-expense refs)
**Governing docs:** features/06-trips-mileage.md, flutter/14-money-currency-fx.md, reference/data-model.md

### M7-T5 · Trip UI

**Description.** The user-facing PULSE surface: a logbook list, a trip detail/edit screen, a road-trip screen, and fast **classification toggles** (swipe / one-tap to clear an unclassified backlog). Follow PULSE conventions — the exhale on completion, scoped emotional temperature where a trip needs attention (e.g. an unclassified or gap-flagged trip), Rooms navigation. Every status (unclassified, business, personal, commute, contemporaneous vs reconstructed, gap-detected, GPS active) is **redundantly encoded** (icon + label + shape/position), never color alone. Search/filter/sort by date, vehicle, client, category, or classification with summary statistics on the filtered set.

**Acceptance criteria.**
- [ ] Logbook list, trip detail/edit, and road-trip screens are built from PULSE components and reachable through Rooms navigation.
- [ ] Classification is one-tap / swipeable; an unclassified backlog can be cleared quickly; a completion triggers the PULSE exhale.
- [ ] Every trip status (classification, contemporaneous flag, gap warning, GPS-active) is redundantly encoded (icon + label + shape/position), not color-only.
- [ ] Filter/sort/search operate over date, vehicle, client, category, and classification with summary stats on the filtered set.
- [ ] Custom charts and stat tiles carry `Semantics`; touch targets meet the minimum; reduced-motion honored.
- [ ] Draft autosave and back/exit confirmation prevent data loss during entry.

**Size:** M
**Depends on:** M7-T1, M7-T3, M7-T4, F3 (PULSE)
**Governing docs:** design/pulse/02-components.md, features/06-trips-mileage.md

### M7-T6 · i18n strings & unit display

**Description.** All user-facing strings in ARB across en/de/fr/fa/ar/ckb — no hardcoded text. Distances render with **distance projections** in the user's chosen unit (mi / km), converting only at display while the stored value stays SI-canonical; EV energy shows in kWh, mi/kWh, or kWh/100km. Dates render in Gregorian/Jalali/Hijri/Hebrew from the canonical value; numerals in Latin/Eastern-Arabic/Persian/Devanagari with locale-correct decimal separators and Indian grouping where applicable. First-day-of-week follows the locale (matters for weekly summaries and work-hours rules). VIN/plate/phone/IBAN-style identifiers stay LTR via bidi isolation.

**Acceptance criteria.**
- [ ] 100% of trip/road-trip/report strings are in ARB across en/de/fr/fa/ar/ckb; no hardcoded UI text.
- [ ] Distances convert to the active unit at display only; the stored value remains SI-canonical; EV energy honors the chosen energy unit.
- [ ] Dates render per active calendar and numeral system with correct decimal separators; first-day-of-week follows the locale.
- [ ] Numeric/odometer columns stay aligned in RTL; VIN/plate/phone/IBAN held LTR via bidi isolation.
- [ ] Unit/numeral/calendar changes never rewrite stored data — a re-render only.

**Size:** S
**Depends on:** M7-T5, F4 (i18n/RTL/calendars/numerals)
**Governing docs:** flutter/03-data-persistence.md, features/06-trips-mileage.md

### M7-T7 · Export/backup mapping

**Description.** Map the trip entities — trips, road-trip containers, rate schemes, saved locations, GPS tracks/GPX refs, and per-trip attachments — into the F6 subsystem: included in the single-file full backup (attachments round-tripped and re-linked on restore), per-entity **hand-written CSV** (built-in-first, no CSV dependency), and combined `dart:convert` JSON. All exported values are locale-neutral canonical (SI distance, integer minor-unit money + ISO code, UTC instants, Western-ASCII numerals) so files diff cleanly and re-import losslessly. Register field mappings so competitor imports (Fuelio, Drivvo, MileIQ) coerce into the canonical trip model.

**Acceptance criteria.**
- [ ] Trips, road-trips, rate schemes, saved locations, GPS tracks/GPX refs, and per-trip attachments are all in the single-file backup and re-link correctly on restore.
- [ ] Per-entity CSV is hand-written with correct quoting/escaping and deterministic columns; combined JSON covers every trip entity with schema/format version.
- [ ] Exported values are canonical (SI distance, minor-unit money + ISO code, UTC instants, ASCII numerals) regardless of display locale.
- [ ] Trip data round-trips through export→wipe→import with distances, amounts, and business-use percentages unchanged.
- [ ] Foreign-preset import of at least one competitor sample maps mi-vs-km and US-vs-UK gallon correctly without silent corruption.

**Size:** S
**Depends on:** M7-T1, M7-T4, F6 (backup/export/import + merge)
**Governing docs:** flutter/03-data-persistence.md, reference/data-model.md, features/06-trips-mileage.md

### M7-T8 · Tests

**Description.** Table-driven, logic-heavy tests on the pure-Dart engines and repository boundary. Exhaustively cover rate-engine **effective-dating** (mid-year IRS change, HMRC tier crossing at 10,000 mi, vehicle-class and passenger add-ons, tax-year boundary resets), **gap reconciliation** (detection, override, personal-use gap-fill, rollover/offset), and **classification** (business/personal/commute deductibility, YTD totals, business-use percentage). Add road-trip aggregate tests (full-to-full deferral, per-person share, mixed-energy) and export round-trip tests.

**Acceptance criteria.**
- [ ] Rate-engine effective-dating is tested table-driven: mid-year IRS change, HMRC 45p→25p tier split, vehicle-class rates, passenger add-ons, and UK/US tax-year boundary resets.
- [ ] Gap-reconciliation tests cover detection, override, personal-use gap-fill, and monotonic-series preservation across rollover/offset.
- [ ] Classification tests assert deductibility, YTD deduction/reimbursement totals, and business-use-percentage math.
- [ ] Road-trip aggregate tests cover full-to-full economy deferral on partial fills, `avg_cost_per_day`, per-person share, and mixed EV/ICE energy.
- [ ] Export→wipe→import round-trip is green for every trip entity plus attachments.
- [ ] `flutter analyze` and `dart format --set-exit-if-changed` are clean.

**Size:** M
**Depends on:** M7-T1 … M7-T7
**Governing docs:** flutter/03-data-persistence.md, features/06-trips-mileage.md

### M7-T9 · Saved locations & address book (added)

**Description.** A reusable, searchable address book of named places (home, work, workshop, a regular client) with optional coordinates and an offline-map pin reference. Designating **home** and **work** enables automatic commute-exclusion rules on the correct legs. Locations are custom taxonomy citizens: created inline during trip entry, editable, soft-deletable, and reassigned (not orphaned) when a referenced location is removed. Included in backup/export.

**Acceptance criteria.**
- [ ] Named locations can be created inline during trip entry and reused/searched across trips.
- [ ] Home and work can be designated so commute-exclusion applies automatically to the correct legs.
- [ ] Deleting a location with linked trips reassigns or soft-deletes them (no dangling refs); locations are in backup/export.
- [ ] Location labels degrade to manual labels or raw coordinates offline where no bundled place name exists.
- [ ] Location UI is PULSE, localized, RTL-correct, and screen-reader navigable.

**Size:** S
**Depends on:** M7-T1, F3 (PULSE), F4 (i18n)
**Governing docs:** reference/data-model.md, features/06-trips-mileage.md

### M7-T10 · Reimbursement / mileage report generator (added)

**Description.** A filterable, **jurisdiction-aware** report generator producing a contemporaneous, compliance-checked mileage report for a client, period, vehicle, or driver. Runs an **IRS/HMRC compliance check**, flags any non-contemporaneous (reconstructed) trip, and correctly splits a report across mid-year rate changes and tier crossings. Exports independently to **CSV, PDF, and JSON** for handing to an accountant, employer, or tax portal — the user owns the file. PDF renders fully RTL with aligned numeric/odometer columns.

**Acceptance criteria.**
- [ ] Reports filter by client/period/vehicle/driver and respect the correct tax-year boundary and thresholds.
- [ ] A compliance check validates contemporaneous-record expectations and flags reconstructed trips explicitly.
- [ ] A single report correctly splits an IRS mid-year rate change and an HMRC tier crossing.
- [ ] Report exports to CSV, PDF, and JSON; totals reconcile with the rate engine and YTD figures.
- [ ] PDF and on-screen report render fully RTL with aligned numeric/odometer columns; identifiers held LTR via bidi isolation.

**Size:** M
**Depends on:** M7-T3, M7-T5, M7-T7
**Governing docs:** flutter/14-money-currency-fx.md, features/06-trips-mileage.md

## Definition of Done

- **Vertical slice complete:** schema/repository + odometer ledger writes → GPS capture → rate engines → road-trip mode → PULSE UI → i18n/units → saved locations → report generator → export/backup mapping → tests, all landed and wired.
- **Built-in-first honored:** rate/gap/classification engines are pure Dart; CSV hand-written; JSON via `dart:convert`; no new runtime dependency beyond the sanctioned stack (`permission_handler` for the GPS rationale flow is the only added surface, and GPS is optional).
- **Offline-honesty upheld:** every calculation, classification, reconciliation, and report is pure on-device computation working in airplane mode; GPS distance uses local track points only (no routing, no reverse geocoding); missing offline map degrades to saved-location/manual/coordinate labels behind a clear state, never a blank or fabricated map.
- **Tests:** table-driven unit tests green on rate-engine effective-dating (mid-year change, tier crossing, vehicle-class, passenger add-ons, tax-year boundaries), gap reconciliation, and classification; road-trip aggregates and export→wipe→import round-trip covered; `flutter analyze` and `dart format --set-exit-if-changed` clean.
- **i18n complete:** 100% of user-facing strings in ARB across en/de/fr/fa/ar/ckb; no hardcoded text; distances/energy/dates/numerals render per active unit/calendar/numeral system while stored and exported values stay locale-neutral canonical.
- **RTL verified:** trip cards, lists, road-trip screens, charts, and PDF reports mirror correctly with mirrored focus/traversal order; numeric/odometer columns stay aligned; VIN/plate/phone/IBAN held LTR via bidi isolation.
- **In backup/export:** trips, road-trip containers, rate schemes, saved locations, GPS tracks/GPX refs, and per-trip attachments are all included in the single-file backup (re-linked on restore), per-entity CSV, and combined JSON, round-tripping canonically.
- **Accessible per the redundant-encoding rule:** every trip status (classification, contemporaneous flag, gap warning, GPS-active) is encoded with icon + label + shape/position beyond color; custom widgets carry `Semantics`; screen readers announce classification, distances, amounts, and warnings correctly in every locale including Eastern-Arabic/Persian numerals.
- **Failure discipline:** all module-boundary APIs return sealed `Result<T, ValidationFailure|DbFailure>` with stable codes + typed params (never user strings); invalid distances, denied permissions, and reconciliation conflicts fail closed with typed, localized states — no crash, no corruption of the shared odometer ledger.
