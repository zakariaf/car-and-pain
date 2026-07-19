# 🔧 Service & Maintenance

> Stops the shoebox of faded receipts and half-remembered oil changes — every service, part, and DIY job in one editable, printable history that proves the car was cared for.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Reminders & Notifications](./04-reminders-notifications.md) · [Expenses & Cost of Ownership](./05-expenses-cost-ownership.md) · [Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)

## The pain

Service history is the part of car ownership most people get wrong, and it costs them real money. Receipts fade in a glovebox, the shop that did the timing belt closes down, and when it is time to sell the car nobody can prove the work was ever done — so the buyer haggles the price down. Owners forget whether the last oil change was 8,000 km ago or fourteen months ago, mix up a coolant top-up with a full flush, and let warranty-critical services lapse because no single place tracks distance and time together. This module removes that pain by making a complete, trustworthy, fully editable service record that lives on the device, survives shop closures, and is ready to print, export, or hand to the next owner.

## What it does

Service & Maintenance records what actually happens to a vehicle: multi-line-item visits mapped to a single dated receipt, a built-in catalog of common service types you can edit freely alongside your own custom types, parts with brand and part numbers, labour-versus-parts cost splits, and DIY procedure logs with torque specs and capacities. It captures the odometer at every visit into the shared vehicle ledger, so intervals stay correct even when you back-date a historical service, swap an instrument cluster, or change display units.

On top of the raw history it layers the planning tools owners need: bundled offline generic and severe-duty schedule templates you can apply to a vehicle to auto-generate reminders, per-service-type "last done / next due" status cards, appointment scheduling with calendar deep-links, pre-service multi-quote comparison, inspection checklists, powertrain-adaptive workflows (including motorcycle-specific chain and valve tasks), cost analytics, and a printable service-history report for resale and warranty. Everything works fully offline, in any supported language, with no account.

## Features

### ✅ Must-have

- **Built-in, editable service-type catalog** — Ships with the common jobs owners actually log (oil and filters, brakes, fluids, belts, spark plugs, inspection, and more), and every one of them is editable rather than locked.
- **Fully custom service types** — Create your own service types that behave identically to the built-ins, so a niche or vehicle-specific job is a first-class citizen with the same intervals, reminders, and analytics.
- **Multi-line-item service visit** — Record several jobs done in one visit under a single dated record and receipt, mirroring how a real shop invoice bundles multiple items.
- **Complete, filterable service history** — A full per-vehicle history you can filter by type, provider, date, or DIY/shop, so nothing is lost and everything is findable.
- **Odometer at every service** — Each visit captures the odometer reading into the shared per-vehicle ledger, keeping distance-based intervals and projections accurate.
- **Back-date and add historical services** — Enter services that happened before you started using the app; the recurring interval re-anchors to the true event date, not the day you typed it in.
- **Custom, editable categories** — Every category carries a name, icon, color, and default interval, and all of them are user-definable and editable.
- **Labour vs parts vs tax cost split** — Break each visit into labour, parts, and tax so cost analytics and DIY-vs-shop comparisons are meaningful rather than a single lump sum.
- **Parts used with full identification** — Log each part with its brand, an OEM or aftermarket part number, and the store it came from — the detail that matters for warranty claims and reordering.
- **Fully editable and deletable records** — Every record can be edited or deleted with created/updated history preserved, so corrections never mean losing the audit trail.
- **Attachments per record** — Attach receipts, photos, and PDFs to any service record so the proof travels with the entry.
- **Distance, time, and combined intervals** — Define intervals by distance, by time, or as a combined "whichever comes first" rule that reflects how real maintenance schedules are written.
- **DIY vs shop flag** — Mark whether work was done yourself or at a shop, both at the visit level and per line item, feeding savings analytics and labour tracking.
- **Last-done / next-due status card** — Each service type shows a card with its last-done reading and next-due projection, and a clear status of OK, due soon, or overdue.

### 🔵 Should-have

- **Reset-interval toggle per line item** — Flag whether a line item is a full change that resets the interval or a top-up that should not, so a coolant top-up never falsely restarts the full-flush clock.
- **Bundled generic and severe-duty schedule templates** — Ship editable, offline generic and severe-duty maintenance schedules, with optional community per-make schedule import for owners who want a closer starting point.
- **Apply a schedule to a vehicle** — Apply a template to auto-generate the full set of reminders, anchored to the vehicle's current odometer and date.
- **Reusable parts catalog with autocomplete** — Maintain a catalog of parts you reuse, with autocomplete so repeat entries are fast and consistent.
- **Fluid and consumable spec capture** — Record the exact spec and amount of fluids and consumables (for example 5W-30, DOT4, G12) with quantity and unit, so the right product goes back in next time.
- **Per-entry multi-currency** — Log a service in the currency it was paid in; canonical storage in the base currency keeps history consistent across borders.
- **Service cost analytics** — Analyze spending by type, vehicle, provider, and period, including how much DIY work has saved versus shop labour.
- **Workshop / mechanic directory** — Keep an offline address book of workshops, mechanics, and garages you use, so provider details are one tap away with no connectivity.
- **Warranty on parts and workmanship** — Track warranty by both date and mileage for parts and labour, feeding the warranty-compliance dashboard so coverage is never silently lost.
- **In-app document / receipt scan** — Scan a receipt or document straight into a record without leaving the app.
- **Customizable inspection checklists** — Build pass/fail/NA inspection checklists with notes and photos for periodic or pre-trip inspections.
- **DIY maintenance procedure log** — Capture the steps, torque specs, fluid capacities, tools, and time for a DIY job, turning a one-off into a repeatable reference.
- **Service-appointment scheduling** — Book a service appointment with a date, time, and shop, with a calendar/.ics deep-link — kept deliberately distinct from interval reminders.
- **Pre-service multi-quote comparison** — Collect and compare multiple estimates before booking, so the best quote is easy to spot.
- **Motorcycle workflows** — Support motorcycle-specific tasks such as chain lube, tension, and cleaning, valve-clearance checks, and fork-oil intervals.
- **Printable service-history report** — Generate a per-vehicle printable service history for resale or warranty proof.
- **Import service history** — Bring in existing history from Drivvo, aCar, Fuelio, or generic CSV, so switching apps does not mean starting from scratch.

### ⚪ Nice-to-have

- **Community schedule template import/export** — Share and load maintenance schedule templates as JSON files.
- **Warranty-expiry reminder** — Get warned before a part or workmanship warranty lapses, reusing the shared reminder engine.
- **Free-form DIY technical notes** — Keep unstructured technical notes alongside a DIY job for the details that do not fit a field.
- **Wear-item lifecycle tracking** — Track a wear item's install odometer, expected life, and remaining percentage, linking into the Components module.
- **Service cost estimator** — Estimate the cost of an upcoming job from your own history or offline typical ranges.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `visit_id` | uuid | Unique identifier for the service visit. |
| `vehicle_id` | ref | The vehicle this visit belongs to. |
| `date` | date | Actual service date (ISO-8601/UTC canonical); drives back-dating and interval anchoring. |
| `odometer_at_service` | number+unit | Reading captured into the shared per-vehicle ledger. |
| `provider_id` | ref | Workshop/mechanic from the offline directory. |
| `diy_flag` | bool | Visit-level DIY vs shop. |
| `line_items[]` | array | Each item: `service_type_id`, `parts[]`, `labour_cost`, `parts_cost`, `warranty`, `resets_interval_flag`. |
| `parts_used[]` | array | Each part: `name`, `brand`, `oem_number`, `aftermarket_number`, `quantity`, `unit_cost`, `supplier`. |
| `fluids[]` | array | Each fluid: `type`, `spec`, `quantity`, `unit` (e.g. 5W-30, DOT4, G12). |
| `total_cost` | number+currency | Sum of parts and labour plus tax minus discount plus fees. |
| `labour_hours` | number+unit | Hours of labour for the visit. |
| `labour_rate` | number+currency | Rate per hour. |
| `tax` | number+currency | Tax portion of the visit. |
| `discount` | number+currency | Discount applied to the visit. |
| `currency` | enum | Currency the visit was recorded in; converted from canonical base for display. |
| `interval_distance` | number+unit | Distance interval for the service type. |
| `interval_time` | number+unit | Time interval for the service type. |
| `interval_logic` | enum | Distance-only, time-only, or whichever-comes-first. |
| `schedule_profile` | enum | Generic, severe-duty, or custom schedule applied. |
| `warranty_until_date` | date | Warranty expiry by date. |
| `warranty_until_mileage` | number+unit | Warranty expiry by mileage. |
| `appointment` | object | `datetime`, `shop_id`, `ics_ref`, `status` for a scheduled visit. |
| `quotes[]` | array | Each quote: `shop`, `amount`, `date`, `notes` for pre-booking comparison. |
| `attachments[]` | attachment | Receipts, photos, and PDFs linked to the record. |
| `checklist[]` | array | Inspection items with pass/fail/NA, notes, and photos. |
| `procedure_steps[]` | array | Ordered DIY steps with capacities, tools, and time. |
| `torque_specs` | text | Torque specifications for the DIY procedure. |
| `tags[]` | array | User-defined tags for filtering and reporting. |
| `notes` | text | Free-form notes for the visit. |
| `created_at` | date | Record creation timestamp. |
| `updated_at` | date | Last-modified timestamp for edit history. |
| `source` | enum | Origin of the record (manual, import, template, etc.). |

## Calculations & formulas

- **Next-due projection** — `next_due_date = last_done_date + interval_time` and `next_due_odometer = last_done_odometer + interval_distance`.
- **Whichever-first governing dimension** — the earliest of the time threshold and the projected date at which the odometer threshold is reached: `governing = earliest(time_threshold, projected_date(odometer_threshold))`.
- **Projected due date from usage** — for distance intervals, project the due date from `avg_daily_distance` so a distance target maps to a calendar estimate.
- **Visit total** — `total = Σ(parts + labour) + tax − discount + fees`.
- **Running cost** — service `cost_per_km` and `cost_per_month` derived from history against distance and time.
- **DIY-vs-shop savings** — `savings = estimated_shop_cost − actual_diy_cost`.
- **Severe schedule override** — a severe-duty profile applies shortened interval overrides on top of the generic schedule.
- **Best-quote selection** — `best_quote = min(quotes.amount)`, surfaced before booking.

## Reminders & notifications

This module is a primary producer for the shared [local notification engine](./04-reminders-notifications.md). Applying a schedule template auto-generates reminders anchored to the vehicle's current odometer and date, and each service type can trigger on distance, on time, or on whichever comes first. Distance-based reminders use projection from average daily distance, so a "due in 1,000 km" reminder resolves to an estimated date and warns ahead of time. Early-warning lead times (for example "1 week before" or "1,000 km before" a service comes due) give owners room to book. When several services fall due together, they surface as one grouped reminder rather than a burst of separate alerts.

Two reminder classes are kept deliberately separate. **Interval reminders** track when a recurring service is next due. **Appointment reminders** track a specific booked date and time with a shop, and can deep-link to the device calendar via .ics. Cancelling one never clears the other. Optional warranty-expiry reminders reuse the same engine to warn before a part or workmanship warranty lapses by date or mileage.

## Offline & data

Every capability here works in airplane mode with no account and no sync. Schedule templates are bundled on-device, service types and categories are stored locally, cost math and projections run on the device, and appointment scheduling writes a local calendar file — nothing waits on a server. Because all measures are stored canonically (SI distance, ISO-8601/UTC dates, base currency) and converted only for display, changing units, currency, calendar, or language never rewrites your history.

In backup and export, service visits and their line items, parts, fluids, quotes, checklists, procedure logs, and schedule state are all included: they round-trip through the single-file full backup (with attachments re-linked), per-entity CSV, and combined JSON. Merge-aware restore and user-facing trash/undo mean a reinstall or device migration never orphans a service record. Imports from Drivvo, aCar, Fuelio, and generic CSV bring existing history in with column mapping.

## Localization & RTL

Service-type and category names are localized, and custom service-type names are user-generated content preserved across languages with search-folding so they stay findable regardless of the interface language. Part numbers, VIN, and phone numbers stay left-to-right even inside right-to-left (Persian, Arabic, Sorani Kurdish) layouts and exports, so identifiers never get visually reordered. Localized numerals (Western, Eastern-Arabic, Persian) and decimal separators round-trip through CSV and JSON without corrupting numeric parsing.

Interval arithmetic is calendar-aware: Jalali/Shamsi, Hijri, and Hebrew calculations handle leap years and variable month lengths by storing the absolute date and converting only for display. Torque units (Nm / lb-ft), fluid volumes (L / qt), and currency all follow the user's per-preference settings. Appointment .ics files respect the display calendar and first-day-of-week. See [Localization, RTL & Calendars](./19-localization-rtl.md) for the shared rendering rules.

## Edge cases

- **Back-dated service re-anchors intervals** — the recurring interval anchors to the true event date, not the date the entry was created.
- **Odometer regression, unit change, or cluster swap** — interval math must survive a lower reading, a units switch, or an instrument-cluster replacement without breaking.
- **Unknown or estimated historical odometer** — when the reading at a historical service is unknown, fall back to time-only or projection rather than guessing a distance.
- **Interval stored in km, vehicle displays miles** — store the canonical value and convert for display, so rounding never fires a reminder early or late.
- **Partial service does not reset a full-change interval** — a coolant top-up leaves the full-change clock running unless explicitly flagged to reset.
- **Whichever-first with one dimension known** — when only time or only distance is known, use average-usage projection to fill the gap.
- **Multiple services due together** — surface them in a single grouped reminder.
- **Offline OEM limits** — bundled generic and severe-duty templates plus manual entry cover scheduling; per-make OEM schedules are honestly labelled "generic," ship as user-overridable, and are treated as optimistic to source.
- **Deleting an anchor service** — if a reminder's last-done anchor depends on a deleted service, recompute from the previous valid record.
- **Multi-currency history** — always state the currency assumption for a visit and never silently mix currencies.
- **Appointment vs interval independence** — cancelling an appointment reminder must not clear the interval reminder, and vice versa.
- **Shared ledger reconciliation** — a same-day fuel fill and service reconcile into one monotonic odometer timeline.

## Related features

- **[Reminders & Notifications](./04-reminders-notifications.md)** — Consumes this module's intervals, schedules, appointments, and warranty limits to deliver reliable offline alerts.
- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — Service costs feed the total-cost-of-ownership engine and per-km/per-month spending.
- **[Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)** — Parts and workmanship warranties and the completed service schedule prove coverage stays valid.
- **[Vehicles, Garage & Odometer](./01-vehicles-garage.md)** — Provides the vehicle context and the shared odometer/engine-hour ledger each service writes to.
- **[Components, Batteries, Keys & Consumables](./16-components-consumables.md)** — Receives wear-item lifecycle links from service line items for install-odometer and remaining-life tracking.
- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md)** — Guarantees every service record, attachment, and schedule state round-trips through backup, export, and import.
