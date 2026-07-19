# 🧭 Trips & Mileage Logbook

> No more shoeboxes of scribbled odometer readings or a spreadsheet you rebuild every April just to prove which miles were for work.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Fleet, Business & Company-Car](./10-fleet-business.md) · [Rideshare, Gig & Rental Economics](./11-rideshare-gig-rental.md) · [Offline Maps & Location](./14-maps-location.md)

## The pain

Business drivers, freelancers, and gig workers lose real money every year because they cannot reconstruct a defensible mileage log. The rules are fiddly and change: IRS rates shift mid-year, HMRC drops from 45p to 25p once you cross 10,000 miles, and a "commute" is quietly non-deductible. Most apps force an account, sync your GPS trails to a server, then lose the lot on reinstall — exactly the disaster no tax auditor forgives. And when you finally sit down to file, the odometer doesn't add up because forgotten trips left invisible gaps between fill-ups.

Car and Pain treats the logbook as a tax record that must survive an audit and a phone swap. Every trip is captured on-device, classified once, priced by an effective-dated rate engine, and reconciled against the same shared odometer ledger that fuel, service, and expenses already write to — so the numbers reconcile instead of arguing with each other.

## What it does

The Trips & Mileage Logbook lets you record a trip in whatever way is fastest at that moment: type a start and end odometer, punch in a raw distance, pick two saved locations, or let an opt-in low-power on-device GPS detector notice the drive and ask you to classify it later. Each trip is tagged business or personal, priced against a tiered, effective-dated IRS / HMRC / custom rate scheme, and rolled into running year-to-date deduction and business-use totals that respect the correct tax-year boundary for your jurisdiction.

On top of everyday logging sits a road-trip mode: a multi-day container that groups individual legs, links every fuel fill and expense along the way, and shows live running totals for distance, spend, fuel economy, days elapsed, daily average, and per-person share. When it's time to file or claim, a filterable, jurisdiction-aware report generator produces a contemporaneous, compliance-checked mileage report you can export to CSV, PDF, or JSON. All of it works in airplane mode, with no account, and stores canonical values (SI distance, UTC dates, base currency) so switching units, currency, calendar, or language never rewrites your history.

## Features

### ✅ Must-have

- **Manual entry by odometer** — Log a trip by typing its start and end odometer readings; the distance is computed for you and written back to the shared per-vehicle odometer series.
- **Manual entry by distance** — When you already know the mileage (a fixed client run, a quoted route), enter the distance directly without touching the odometer.
- **From / To locations** — Record an origin and destination as a named place or address, with optional coordinates and an offline-map pin so the route is meaningful even with no signal.
- **Trip purpose & description with presets** — Describe why the trip happened, and reuse saved presets ("Client site visit", "Depot run") so repeat journeys are one tap.
- **Business vs personal classification** — Mark every trip business or personal, with commute journeys flag-able as the non-deductible category that tax authorities treat separately.
- **Tax mileage-rate engine** — Price trips against IRS, HMRC, or fully custom schemes that are effective-dated, tiered, and vehicle-class aware, so the right pence-or-cents-per-mile applies for the trip's actual date.
- **Deduction / reimbursement amount with YTD totals** — Each classified trip produces a claim amount that rolls into running year-to-date deduction and reimbursement totals.
- **Odometer reconciliation & gap detection** — Compare each trip's start reading against the previous trip's end to surface gaps, catching forgotten journeys before they corrupt your business-use percentage.
- **Favourite / named locations** — Keep an address book of frequent places so "home", "the workshop", or a regular client is reusable and searchable.
- **Road-trip mode** — Group a multi-day journey into one container that holds its legs, fuel fills, and expenses together as a single record.
- **Road-trip live running totals** — See a road trip's distance, fuel, spend, days elapsed, and daily average update live as you add legs and receipts.
- **Aggregated road-trip fuel economy** — Combine multiple fills across a road trip into one accurate per-trip economy figure rather than noisy per-fill numbers.
- **Link fuel fill-ups to trips** — Attach a fill-up (from the [Fuel & Energy](./02-fuel-energy.md) module) to a trip or road trip so cost-per-distance is real, not estimated.
- **Reimbursement / mileage report generator** — Produce filterable, jurisdiction-aware reports for a client, a period, a vehicle, or a driver, ready to hand to an accountant or employer.
- **Export report to CSV / PDF / JSON** — Get the report out in the format your accountant, expense system, or tax portal expects — you own the file.
- **IRS / HMRC compliance check & contemporaneous flag** — Validate that a log meets contemporaneous-record expectations and flag any trip reconstructed after the fact.
- **Multi-vehicle attribution** — Attribute every trip to a specific vehicle, each with its own independent odometer series, across your unlimited garage.
- **Unit system & conversion** — Work in miles or kilometres, gallons or litres, and EV energy units, converting only at display so the stored value stays canonical.
- **Multi-currency per trip / expense** — Record costs in the trip's real currency with a manual exchange rate, preserving the original amount for cross-border journeys.
- **Privacy by design** — Everything stays on the device with no account, and location access is a granular, revocable permission rather than an all-or-nothing demand.

### 🔵 Should-have

- **Round-trip / return toggle** — Flip a switch to auto-create the swapped return leg instead of entering the journey home by hand.
- **Swipe / one-tap classification** — Clear a backlog of unclassified trips quickly by swiping or tapping each as business or personal.
- **Custom categories & tags with default deductibility** — Define your own trip categories and tags, each with a default deductible/non-deductible behaviour, so classification is consistent.
- **Client / project tagging** — Tag trips to a client or project with a billable flag and rate, feeding straight into [Fleet, Business & Company-Car](./10-fleet-business.md) and [Rideshare, Gig & Rental Economics](./11-rideshare-gig-rental.md) P&L.
- **Auto-classify rules** — Teach the app that frequent A→B routes are always business (or personal) so recurring drives classify themselves.
- **On-device GPS automatic trip detection** — Opt in to low-power background detection that logs drives automatically, always with a clear on/off status so you know exactly when it's active.
- **GPS route recording & GPX export** — Record the actual route, preview it on the offline map, and export it as GPX for your own records or other tools.
- **Quick-add widget & notification classify** — Log or classify a trip from a home-screen widget, a shortcut, a notification action, or a one-tap Watch/Wear complication.
- **Trip templates & recurring trips** — Save templates for repeat journeys and schedule recurring trips so the daily commute or weekly delivery run logs itself.
- **Personal-use gap fill** — Absorb a detected odometer gap into a single personal-use entry so the series reconciles without inventing business miles.
- **Merge / split trips** — Defragment trips that automatic detection broke into pieces, or split a multi-stop journey into its billable segments.
- **Home & work special locations** — Designate home and work so commute exclusion rules apply automatically to the correct legs.
- **Road-trip legs, waypoints & stops** — Break a road trip into legs with waypoints and stops, each carrying its own odometer reading.
- **Road-trip budget & spend by category** — Set a trip budget and watch spend break down by category (fuel, tolls, lodging, food) as the journey unfolds.
- **Road-trip cost & cost-per-distance summary** — Close out a road trip with total cost and cost-per-mile / per-kilometre, blending fuel and linked expenses.
- **Link tolls / parking / lodging to a trip** — Attach expense records (from [Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)) to a trip so the true cost is captured, not just the mileage.
- **Annual odometer & business-use summary** — Generate year-end summaries that respect UK (6 April) and US (1 January) tax-year boundaries, including threshold resets.
- **Trip edit history / audit trail** — Keep a per-trip edit log so any change to a tax-relevant record is traceable.
- **Trip search / filter / sort with summary stats** — Find and slice trips by date, vehicle, client, category, or classification, with summary statistics on the filtered set.
- **CSV / JSON import & migration** — Import and migrate existing logs from Fuelio, Drivvo, and MileIQ, turning disgruntled competitor users into a clean starting point.
- **Log-trip reminders & odometer nudges** — Gentle reminders to log trips and periodic odometer nudges keep the record contemporaneous and gap-free.

### ⚪ Nice-to-have

- **Passenger add-on & tiered thresholds** — Track passengers for schemes that pay extra (HMRC 5p per passenger) and handle tier boundaries like the 10,000-mile rate step.
- **Work-hours auto-classify rule** — Automatically treat trips during defined working hours as business unless told otherwise.
- **Bluetooth / OBD / power auto-start** — Trigger trip tracking when the phone connects to the car's Bluetooth, an OBD dongle, or car power, so drives start recording hands-free.
- **Bulk / batch trip entry** — Enter many trips at once across a date range for someone catching up on a whole month or quarter.
- **Missed-trip reconstruction helper** — Rebuild forgotten trips from odometer gaps, clearly flagged as non-contemporaneous so the record stays honest.
- **Geofence / radius per location** — Give saved locations a geofence radius so arrivals and departures are detected reliably.
- **Recent & auto-suggested locations** — Speed entry with recently used and intelligently suggested locations.
- **Road-trip cost split & settle-up** — Split a road trip's costs among companions and produce a settle-up so everyone pays their share.
- **Photo / document attachment per trip** — Attach receipts, permits, or photos to a trip; they round-trip through the full backup.
- **Multiple drivers per vehicle** — Attribute trips to different drivers on the same vehicle, linking into [Drivers, Household & Sharing](./15-drivers-household.md).
- **Offline road-trip fuel / charge-stop estimator** — Estimate where you'll need to refuel or recharge along a planned route, entirely offline.
- **Toll / vignette / LEZ log with expiry reminders** — Log tolls, vignettes, and low-emission-zone permits with expiry reminders, linking to [Cross-Border, Travel & Emission Zones](./13-cross-border-travel.md).

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `trip_id` | uuid | Stable primary key; survives export/import and sync. |
| `vehicle_id` | ref | Vehicle this trip is attributed to; drives the odometer series used. |
| `date` | date | Trip date; stored canonical UTC/Gregorian, rendered per locale/calendar. |
| `start_time` / `end_time` | date (time) | Optional; used for midnight-spanning and work-hours rules. |
| `start_odometer` / `end_odometer` | number+unit | Odometer readings; write to the shared per-vehicle ledger. |
| `distance` | number+unit | Computed from odometers or entered directly. |
| `distance_unit` | enum | mi / km; per-vehicle default, convert at display only. |
| `from_location_id` / `to_location_id` | ref | Named places from the location address book. |
| `purpose` | text | Free-text or preset reason for the trip. |
| `category` | ref | Custom trip category with default deductibility. |
| `classification_status` | enum | unclassified / business / personal / commute. |
| `is_deductible` | bool | Whether the trip contributes to a claim. |
| `client_id` / `project_id` | ref | Billable client/project tagging feeding Fleet/Rideshare. |
| `cost_centre` | ref | Fleet cost-centre allocation. |
| `billable` | bool | Marks the trip as billable to a client/project. |
| `driver_id` | ref | Driver attribution for household/fleet P&L. |
| `platform_id` | ref | Rideshare/gig platform this trip belongs to. |
| `auto_detected` | bool | True when logged by GPS auto-detection. |
| `gps_track_points` | array | On-device track points; source of GPS-derived distance. |
| `gpx_ref` | ref | Reference to an exported/stored GPX track. |
| `map_pin_refs[]` | array (ref) | Offline-map pins for origin/destination/waypoints. |
| `rate_scheme_id` | ref | IRS/HMRC/custom effective-dated rate scheme applied. |
| `applicable_rate` | number+unit | Resolved per-distance rate for this trip's date/tier. |
| `tier_applied` | enum | Which tier (e.g. HMRC 45p vs 25p) the distance fell into. |
| `passenger_count` | number | Passengers, for per-passenger add-on schemes. |
| `computed_amount` | number+unit | Deduction/reimbursement value in currency. |
| `currency` | enum | Currency of the computed amount and linked costs. |
| `roadtrip_id` | ref | Parent road-trip container, if any. |
| `leg_sequence` | number | Ordering of this leg within a road trip. |
| `linked_fillup_ids[]` | array (ref) | Fuel/charge fills linked to the trip. |
| `linked_expense_ids[]` | array (ref) | Tolls, parking, lodging and other linked expenses. |
| `fuel_used` | number+unit | Fuel consumed on the trip (volume). |
| `energy_used` | number+unit | EV energy consumed (kWh) for electric/PHEV trips. |
| `cost` | number+unit | Total trip cost (fuel + linked expenses). |
| `tags[]` | array | Custom tags for filtering and reporting. |
| `is_contemporaneous` | bool | False when reconstructed after the fact. |
| `edit_log[]` | array | Audit trail of edits to this record. |
| `notes` | text | Free-form notes. |

## Calculations & formulas

- **Distance:** `distance = end_odometer − start_odometer`, or the value from direct entry when no odometer is used.
- **Deduction:** `deduction = billable_distance × applicable_rate (+ passenger_rate × passenger_count)`.
- **Tiered claims:** split the claim at the `10,000-mile` HMRC threshold (`45p` below, `25p` above); for IRS, select the rate by trip date from effective-dated tables so mid-year changes apply correctly.
- **Business-use percentage:** `business_use_percentage = business_distance / total_distance`.
- **Odometer gap:** `gap_distance = next_start_odometer − prev_end_odometer` to detect missing trips.
- **Per-trip economy & cost:** economy computed full-tank-to-full-tank; `per_trip_cost = fuel_cost + linked_expenses`; `cost_per_distance = per_trip_cost / distance`.
- **Road-trip aggregates:** running totals plus `avg_cost_per_day` and `per_person_share = total_cost / companion_count`.
- **GPS distance:** derived purely from on-device track points, with `no online routing` required.

## Reminders & notifications

This module both produces and consumes reminders through the app's single offline notification engine (see [Reminders & Notifications](./04-reminders-notifications.md)).

- **Log-trip reminders** prompt you to record recent drives before the details fade, keeping the log contemporaneous — the single most important property of an audit-proof record.
- **Odometer nudges** ask periodically for a fresh reading so gap detection stays accurate between logged trips.
- **Toll / vignette / LEZ expiry reminders** (nice-to-have) fire on a date trigger with lead-time early warnings (for example, "1 week before" a vignette lapses), linked to Cross-Border compliance.
- **Road-trip and parking-meter reminders** ride the same scheduler used across the app, so trip-related alerts survive reboot, Doze, and app-kill, and re-arm automatically after a backup restore.

## Offline & data

Every part of the logbook works with zero connectivity. Manual entry, classification, rate calculation, reconciliation, report generation, and road-trip totals are all pure on-device computation. GPS tracking, when enabled, uses only the device's location sensor and derives distance from local track points — never online routing or reverse geocoding. Where no bundled place name exists, endpoint labels fall back to saved locations, manual labels, or raw coordinates, while the bundled offline vector map still renders the route and pins (see [Offline Maps & Location](./14-maps-location.md)).

For export and backup (see [Data, Offline, Backup & Portability](./18-data-offline-backup.md)), trips, road-trip containers, rate schemes, saved locations, GPS tracks/GPX, and per-trip attachments are all included in the single-file full backup and re-linked on restore, plus per-entity CSV and combined JSON. Reports export independently to CSV, PDF, or JSON so you can hand a filing to an accountant or employer. Because everything is stored canonically, a restore onto a new device or OS reproduces the same distances, amounts, and business-use percentages exactly.

## Localization & RTL

Trip cards, maps, route polylines, charts, and PDF reports render fully right-to-left for Persian, Arabic, Sorani Kurdish, Hebrew, and Urdu without breaking numeric or odometer column alignment — VIN, plate, phone, and IBAN-style identifiers stay left-to-right via bidi isolation. Dates display in Gregorian, Jalali/Shamsi, Hijri, or Hebrew calendars, converted from the canonical UTC/Gregorian value, with Latin, Eastern-Arabic, Persian, or Devanagari numerals and comma decimal separators where the locale expects them. First-day-of-week follows the locale — Saturday for Persian/Arabic, Sunday for Hebrew — which matters for weekly summaries and work-hours rules. Multi-currency uses manual, dated FX rates, and EV energy appears in the user's chosen units (kWh, mi/kWh, kWh/100km). Offline map labels degrade gracefully to coordinates where no bundled place name exists, in any language.

## Edge cases

- **Partial fills defer economy** — Per-trip fuel economy waits until the next full tank so partial fills never produce a wrong figure.
- **Missed / forgotten trips** — Odometer gaps are detected, reconstruction is allowed, and rebuilt trips are flagged non-contemporaneous.
- **Odometer rollover / cluster swap** — An offset event keeps the reading series monotonic when the cluster rolls over or is replaced.
- **Mixed odometer units in one garage** — Two vehicles can use different units; each stores its own unit and converts only at display.
- **Import unit assumptions** — Import detects mi vs km and US vs UK gallon so migrated data isn't silently corrupted.
- **Multi-currency cross-border trips** — Manual FX is applied while the original amounts are preserved.
- **Mid-year rate & tier crossings** — A single report correctly splits an IRS mid-year rate change and an HMRC tier crossing.
- **Vehicle-class rates** — Car/van, motorcycle, and bicycle rates plus passenger add-ons are handled distinctly.
- **Tax-year boundaries** — UK (6 April) and US (1 January) boundaries drive summaries and threshold resets.
- **Trips spanning midnight / days** — Multi-day trips, timezones, and DST changes during cross-border road trips are handled without double-counting.
- **GPS drift / tunnels / signal loss** — Distance inflated or truncated by poor signal can be manually corrected.
- **OS killing the tracker** — Background-tracker kills that fragment a trip are recoverable by merging the pieces.
- **Duplicate trips** — Overlapping auto-detection and manual entry are de-duplicated.
- **Invalid distances & deletions** — Zero/negative distances are validated, and deleting a vehicle or location with linked trips reassigns or soft-deletes them.
- **EV / PHEV energy** — Electric "fuel" is expressed in kWh/100km or mi/kWh, including mixed-energy road trips.
- **No reverse geocoding offline** — Endpoint naming falls back to saved locations or manual labels while the offline vector map still renders route and pins.
- **Location permission denied** — With location off, logging is fully manual and everything else still works.

## Related features

- **[Fuel & Energy](./02-fuel-energy.md)** — Fill-ups and charge sessions link to trips and road trips to produce real per-trip economy and cost-per-distance.
- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — Tolls, parking, and lodging attach to trips, and mileage feeds the true cost of ownership.
- **[Fleet, Business & Company-Car](./10-fleet-business.md)** — Client/project/cost-centre tagging and business-use percentages flow into fleet P&L, BIK, and VAT workflows.
- **[Rideshare, Gig & Rental Economics](./11-rideshare-gig-rental.md)** — Platform-attributed trips and billable mileage drive gig earnings and per-platform economics.
- **[Offline Maps & Location](./14-maps-location.md)** — The bundled offline map renders route polylines, pins, and saved locations with no online dependency.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — Log-trip reminders, odometer nudges, and permit-expiry alerts are delivered by the reliable offline scheduler.
