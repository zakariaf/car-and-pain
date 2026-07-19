# 🚗 Vehicles, Garage & Odometer

> Losing years of a car's history — or being unable to keep a US import, a local car, and a project bike in one place — because your app capped vehicles, forced an account, or corrupted the mileage the moment you switched units.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Fuel & Energy](./02-fuel-energy.md) · [Reminders & Notifications](./04-reminders-notifications.md) · [Data, Offline, Backup & Portability](./18-data-offline-backup.md)

## The pain

Most car apps treat your garage as an afterthought: a hard cap on vehicles, a mandatory login, and a single mileage number that quietly breaks when you change units, replace an instrument cluster, or fat-finger a reading. Owners who track more than one vehicle — a household with two cars and a motorcycle, a gig driver with a rental, an enthusiast with a project build — end up juggling apps or spreadsheets. Worse, when the odometer field is a single mutable value with no history, a typo or a US-to-metric mix-up silently poisons every fuel-economy, reminder, and cost calculation downstream. Car and Pain fixes this at the foundation: an unlimited, account-free garage built on a shared, auditable reading ledger that every other module reads from and writes to.

## What it does

The garage is the root of the whole app. You can add as many vehicles as you own or maintain — cars, motorcycles, boats, RVs, generators, EVs, plug-in hybrids, LPG/CNG conversions, and classics — each with a rich, powertrain-adaptive profile that shows exactly the fields that vehicle type needs and hides the ones it doesn't. Every vehicle carries its own units, currency, specs, photos, documents, and lifecycle state, all stored on-device with no signup.

Underneath the profiles sits the shared odometer / engine-hour ledger: a single monotonic timeline of readings per vehicle, written automatically by any dated fuel, service, expense, trip, or tire entry and read by reminders, statistics, tires, warranties, and financing. Corrections, cluster swaps, and rollovers are recorded as first-class audited events rather than overwrites, so the mileage history stays trustworthy for the life of the vehicle — through unit changes, device migrations, and eventual sale or disposal.

## Features

### ✅ Must-have

- **Unlimited multi-vehicle garage** — Add any number of vehicles with no cap, no account, and no cloud; everything lives locally on the device.
- **Quick active-vehicle switcher** — A persistent selector to jump between vehicles that remembers the last one you were working on, so logging is one tap away.
- **Nickname and cover photo** — Give each vehicle a friendly name and a locally-stored cover photo so the garage is instantly recognizable at a glance.
- **Make / model / year / trim** — Choose from a bundled offline picker, with free-text fallback always available for classics, imports, and vehicles not in the catalog.
- **License plate with country/region and plate history** — Record the plate and its country, and keep a full history of reassignments over time rather than a single field that gets overwritten.
- **Fuel/energy type that drives the whole profile** — The selected energy type reconfigures which fields and metrics appear, adapting the vehicle to petrol, diesel, LPG/CNG, EV, PHEV, or hydrogen.
- **Purchase record** — Capture purchase price, date, odometer-at-purchase, and condition to anchor depreciation and total cost of ownership.
- **Vehicle type with adaptive fields** — Selecting a type (car, motorcycle, boat, RV, equipment, etc.) sets sensible defaults for wheel/axle count, energy metrics, and icons.
- **Shared odometer / engine-hour reading timeline** — A single monotonic ledger per vehicle is the one source of truth for distance and engine hours across the app.
- **Automatic odometer updates from any entry** — Any dated fuel, service, expense, or trip entry that includes a reading advances the shared ledger, so mileage stays current without a separate chore.
- **Audited odometer corrections** — A correction entry preserves the original value plus a reason, giving a transparent audit trail instead of a silent overwrite.
- **Per-vehicle defaults** — Distance, volume, consumption, and currency defaults are set per vehicle, so an imported car and a local car coexist without conflict.
- **VIN capture with offline decode** — Scan the VIN by barcode/QR and decode the World Manufacturer Identifier, model year, and check digit offline per ISO 3779, with manual entry always available.
- **Full lifecycle states** — Mark a vehicle Active, Archived, Sold, Scrapped, Stolen, or Written-off; archived vehicles retain their complete history but are excluded from active statistics.
- **Restore or permanent delete** — Bring an archived vehicle back, or permanently delete it with an explicit confirmation and proper cascade/tombstone handling so backups and household sync stay consistent.

### 🔵 Should-have

- **Garage search, sort, filter, custom order, and pinned default** — Organize a large garage the way you think about it, and pin the vehicle you use most as the default.
- **Groups and tags** — Bucket vehicles into household, personal, business, fleet, project, or gig groups and apply free custom tags for filtering and reporting.
- **Per-vehicle home dashboard summary card** — A compact card surfaces each vehicle's key status and next actions at a glance.
- **Detailed engine and drivetrain specs** — Record engine spec, transmission/drivetrain, exterior color, and paint code.
- **Valuation history and depreciation curve** — Track current or estimated value with a manual valuation history and a depreciation curve that feeds cost-of-ownership.
- **Registration and secondary identification numbers** — Store registration and any secondary IDs the vehicle carries.
- **Factory reference specs** — Keep OEM tire size and pressure, oil spec and capacity, tank capacity, battery group, bulb and wiper sizes, and the fuse map handy for quick reference.
- **Owner's manual storage with bookmarks** — Attach the handbook PDF and bookmark quick-reference sections so the manual is available offline at the roadside.
- **Cluster-swap / odometer replacement event** — Record an instrument-cluster replacement with its offset so the app can present a continuous lifetime distance across the swap.
- **Odometer anomaly detection with override** — Flag implausible jumps, regressions, and rollbacks, warning the user while still allowing an explicit override.
- **Estimated current odometer** — Project today's likely reading from average daily distance when no fresh reading exists.
- **Optional distance tracking per vehicle** — Time-only vehicles (e.g. a stored classic) are never blocked by a required odometer.
- **Engine-hour / secondary meter tracking** — Track engine hours for boats, RVs, equipment, and generators alongside or instead of distance.
- **EV profile** — Record battery capacity, usable capacity, connector types, and a manual State-of-Health log.
- **Hybrid / PHEV dual-energy configuration** — Configure both energy sources and split EV-versus-fuel distance for blended economics.
- **Photo gallery and condition/damage photos** — Keep a gallery plus timestamped condition and damage photos for evidence and history.
- **Per-vehicle document locker** — A vehicle-scoped attachment store keeps that vehicle's paperwork together.
- **License-plate OCR capture** — Snap the plate and let OCR prefill it, reducing typing.

### ⚪ Nice-to-have

- **Duplicate vehicle as template** — Clone spec fields to quickly set up a second, similar vehicle.
- **Body and capacity attributes** — Record doors, seats, kerb weight, GVWR, and towing capacity.
- **Ownership period and prior-owner note** — Note how long you've owned it and any prior-owner context.
- **Motorcycle-specific fields** — Capture chain/belt type and separate front/rear tire specs.
- **LPG/CNG / bi-fuel secondary tank** — Configure a secondary gas tank for bi-fuel conversions.
- **Driver/user assignment** — Assign drivers to a vehicle, linking to [Drivers, Household & Sharing](./15-drivers-household.md).
- **Fleet bulk view and cross-vehicle roll-up** — See all vehicles at once with aggregated totals.
- **Import vehicle profiles** — Bring vehicles in from Fuelio, aCar, or Drivvo during onboarding.
- **Per-vehicle full-history export and sale-handoff bundle** — Export one vehicle's complete history and generate a sale handoff bundle as CSV/JSON/PDF/QR.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| vehicle_id | uuid | Stable primary key; used by tombstones and household sync. |
| nickname | text | User-facing name; UGC, searchable via digit-folding/script normalization. |
| make / model / trim / generation | text | Bundled picker with free-text fallback for classics and imports. |
| model_year | number | Model year; cross-checked against VIN decode. |
| vehicle_type | enum | Car, motorcycle, boat, RV, equipment, etc.; drives adaptive fields. |
| wheel_count / axle_config | number / enum | Set from vehicle type; feeds tire layout diagrams. |
| license_plate | text | Kept LTR inside RTL text via bidi isolation. |
| plate_country | enum | Country/region of registration. |
| plate_history[] | array | Time-ordered plate reassignments, not a single mutable field. |
| vin | text | Kept LTR; validated by ISO 3779 check digit. |
| vin_scanned | bool | Whether the VIN came from a barcode/QR scan. |
| vin_checksum_valid | bool | Result of check-digit validation. |
| wmi_decoded | text | Manufacturer/region decoded offline from the WMI. |
| color_name / paint_code | text | Paint code kept LTR inside RTL text. |
| engine_code / displacement_cc / power_hp_kw | text / number+unit | Engine identity and output. |
| transmission_type / drivetrain | enum | Gearbox and drive configuration. |
| energy_type / secondary_energy_type | enum | Primary and secondary energy sources (PHEV, bi-fuel). |
| tank_capacity | number+unit | Fuel tank capacity in canonical volume. |
| battery_capacity_kwh / usable_capacity_kwh | number+unit | EV pack nominal and usable capacity. |
| connector_types[] | array | EV charge connectors supported. |
| state_of_health_log[] | array | Manual EV battery State-of-Health readings over time. |
| engine_hour_meter | number+unit | Secondary meter for boats, RVs, equipment, generators. |
| distance_unit / volume_unit / consumption_unit / currency | enum | Per-vehicle display defaults; canonical storage is SI/base currency. |
| purchase_date | date | Local calendar date; stored canonical ISO. |
| purchase_price | number+currency | Anchors depreciation and TCO. |
| odometer_at_purchase | number+unit | Starting point of the reading ledger. |
| condition | enum | Condition at purchase. |
| current_value | number+currency | Latest manual or estimated valuation. |
| valuation_history[] | array | Dated valuation snapshots for the depreciation curve. |
| status | enum | Active / Archived / Sold / Scrapped / Stolen / Written-off. |
| status_changed_at | date | When the lifecycle state last changed. |
| sold_date / sold_price / final_odometer | date / number | Disposal close-out values. |
| current_odometer / current_odometer_date | number+unit / date | Latest reading and its date, derived from the ledger. |
| reading_timeline[] | array | The shared monotonic ledger; each reading records its source. |
| offset_after_cluster_swap | number+unit | Offset applied for continuous lifetime distance after a cluster swap. |
| factory_reference_specs{} | object | OEM tire/pressure, oil, tank, battery, bulbs, wipers, fuse map. |
| owners_manual_ref | attachment | Handbook PDF with quick-reference bookmarks. |
| cover_photo_ref | attachment | Locally-stored cover image. |
| photo_gallery[] | array | Gallery plus timestamped condition/damage photos. |
| group_id / tags[] | ref / array | Grouping and free custom tags. |
| assigned_driver_ids[] | array | Links to Drivers & Household. |
| created_at / updated_at | date | Record audit timestamps; updated_at drives sync reconciliation. |
| is_default | bool | Marks the pinned default vehicle. |

## Calculations & formulas

- **Current odometer** — `current_odometer = latest reading across all dated entries (with cluster offset applied)`, and `lifetime_distance = reading + cumulative_offset` so a cluster swap never breaks the running total.
- **Average daily distance** — `avg_daily_distance = (odo_latest − odo_earliest) / days_between`, the projection basis used across reminders and stats.
- **Estimated odometer today** — `estimated_odometer_today = last_actual_reading + avg_daily_distance × days_since_last_reading`.
- **Depreciation curve** — Straight-line or fixed-percent between `purchase_price` and the current/salvage value.
- **Equity** — `equity = current_value − loan_balance`.
- **VIN check-digit validation** — ISO 3779 weighted modulus-11 (`VIN check-digit validation (ISO 3779 weighted modulus-11)`); a barcode-decoded VIN is validated through the exact same path.
- **Final TCO close-out on disposal** — `realized_depreciation = purchase_price − sale_price`.

## Reminders & notifications

The garage does not schedule reminders itself, but it is the projection engine every reminder depends on. Distance-based reminders in [Service & Maintenance](./03-service-maintenance.md), [Tires, Wheels & Seasonal](./07-tires-wheels.md), and [Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md) read the shared ledger's `avg_daily_distance` to project *when* a distance threshold will be crossed — for example warning "1,000 km before" a service is due, or on a whichever-comes-first basis when a date and a distance target compete. Engine-hour meters feed the same machinery for boats, RVs, and equipment. When a reading is unknown or only estimated, distance reminders gracefully fall back to time-based or projection-based scheduling so a stale odometer never suppresses an alert. See [Reminders & Notifications](./04-reminders-notifications.md) for trigger types, lead-time early warnings, and delivery reliability.

## Offline & data

Everything in the garage works with zero connectivity and no account. Adding vehicles, capturing photos, decoding a VIN's WMI/year/check digit, editing specs, correcting the odometer, and changing lifecycle state all run entirely on-device. The only functions that inherently need a network — full VIN trim/options decode, live valuations — degrade honestly: they cache last results with a "last checked" timestamp and always leave a mandatory free-text fallback, never blocking an entry.

In export and backup, every vehicle profile, its complete reading ledger (including corrections and cluster-swap offsets), valuation and plate history, factory specs, and all attachments (cover photo, gallery, owner's manual, documents) are included in the single-file full backup, per-entity CSV, and combined JSON. Attachments are bundled and re-linked so they round-trip across devices and operating systems. Because vehicle_id is a stable UUID with tombstone handling, archives, deletions, and household peer-to-peer sync reconcile cleanly. The per-vehicle full-history export and sale-handoff bundle let you hand one car's entire record to a buyer without exposing the rest of your garage. See [Data, Offline, Backup & Portability](./18-data-offline-backup.md).

## Localization & RTL

Localization is a data-integrity concern here, not a skin. Units and currency are per-vehicle, so an imported US car (mi / US-gal / USD) and a local car (km / L / EUR) live side by side without either corrupting the other — canonical SI distance is stored and converted only for display, and each reading records the unit in effect at the time. Purchase, registration, and valuation dates are entered and displayed in Gregorian, Jalali/Shamsi, Hijri, or Hebrew calendars while stored as canonical ISO, and date-only records (like registration) are kept as local calendar dates to avoid timezone off-by-one errors.

Under full RTL layout mirroring, structural identifiers stay correct: VIN, license plate, paint code, and tire-position labels such as FL/FR remain LTR inside RTL text via bidi isolation, and wheel/axle diagrams mirror visually while the position labels themselves stay accurate. Value and numeric fields render in Latin, Eastern-Arabic, Persian, or Devanagari numerals with correct grouping, including Indian lakh/crore. Free-text nicknames and notes are user-generated content, searchable via digit-folding and script normalization. See [Localization, RTL & Calendars](./19-localization-rtl.md) and [Accessibility & Inclusive Design](./20-accessibility.md).

## Edge cases

- **Odometer reads lower than the previous value** (typo, unit mix-up, or genuine rollback) — warn, allow a logged correction, and never silently break the sequence.
- **5/6-digit rollover and cluster replacement** — handled through an explicit offset event that preserves continuous lifetime distance.
- **Distance unit change mid-life** (e.g. an imported car switching mi→km) — store canonical SI and record the unit in effect at each reading.
- **Logging fuel or an expense with no odometer** — permitted per vehicle; never block the entry.
- **Unknown or estimated historical odometer** — flagged as such, with distance reminders falling back to time or projection.
- **Offline VIN decode limits** — offline decode covers WMI/year/checksum only; full trim/options still needs a network, so a free-text fallback is mandatory.
- **Vehicle absent from the bundled catalog** (classics, imports, kit cars) — free-text make/model/trim is always allowed.
- **Sold / archived / stolen / written-off vehicles** — retained for history and export yet excluded from active dashboards and averages.
- **Same plate reassigned across vehicles or owners** over time — kept as plate history rather than a single mutable field.
- **Date-only records** (registration) — stored as a local calendar date to avoid timezone off-by-one.
- **Varying VIN barcode formats** (Code39 or Data Matrix, door jamb versus etched windshield) — accept manual correction of any scan.

## Related features

- **[Fuel & Energy](./02-fuel-energy.md)** — Writes readings to the shared ledger and depends on correct per-vehicle units for accurate economy math.
- **[Service & Maintenance](./03-service-maintenance.md)** — Reads projected distance to schedule interval-based service and logs readings back on each visit.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — Uses average daily distance to project when date/distance/engine-hour thresholds will be crossed.
- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — Consumes purchase price, valuation history, and depreciation to build true TCO.
- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md)** — Includes every vehicle profile, ledger, and attachment in backup, export, and merge-aware restore.
- **[Sell, Dispose & Ownership Transfer](./24-sell-dispose.md)** — Uses lifecycle states, final odometer, and the handoff bundle to close out a vehicle with realized depreciation.
