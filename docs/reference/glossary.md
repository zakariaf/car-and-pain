# 📖 Glossary, Units, Calendars & Conventions

The shared vocabulary, unit-conversion constants, calendar and numeral rules, localized inspection terms, and cross-module naming standards that every other **Car and Pain** doc relies on — one place to settle "what does this word mean and how is it stored?" so the same term never drifts between screens, exports, and languages.

> **Why this page exists.** Car and Pain stores everything canonically (SI units, UTC / ISO-8601 dates, a single base currency) and converts only for display. That is what lets a user flip units, currency, calendar, or language without ever corrupting a single historical record. This glossary documents the canonical side of that contract and the display conventions layered on top of it. See [Canonical Data Model & Schema](./data-model.md) and [Localization, RTL & Calendars](../features/19-localization-rtl.md) for the deeper specifications.

---

## Terms

Domain vocabulary as it is used across the app. Terms are listed alphabetically. Where a concept belongs to a specific module, the linked feature doc is the authoritative source.

| Term | Meaning |
| --- | --- |
| **BEV** | Battery Electric Vehicle — a pure electric car with no combustion engine. Its "fill-up" is a charge session measured in kWh, and its running cost is energy-from-wall × price per kWh. See [Fuel & Energy](../features/02-fuel-energy.md). |
| **BIK (Benefit-in-Kind)** | The taxable value of a company car provided for private use. Car and Pain computes it as `list_price × bik_percentage(CO₂ / fuel / electric-range band) × marginal_tax_rate`, with effective-dated, country-scoped rate bands. See [Fleet, Business & Company-Car](../features/10-fleet-business.md). |
| **Break-even (EV-vs-ICE)** | The point at which an electric car's lower running cost has repaid its higher purchase premium: `months_to_payback = price_premium / (ice_cost_per_period − ev_cost_per_period)`. |
| **Break-even (repair-or-replace / rideshare)** | The number of months, or revenue miles, at which keeping the current vehicle stops being cheaper than replacing it, or at which a gig session starts making money. |
| **Canonical unit** | The single base unit a value is *stored* in, independent of how it is shown. Distance and volume in SI, dates in UTC / ISO-8601, money in a base currency. Display conversion never rewrites the stored value, so changing preferences can never corrupt history. |
| **Contrôle technique (CT)** | France's periodic roadworthiness inspection (first due at 4 years, then every 2 years). One of several localized names for the same "mandatory inspection" concept — see the [inspection terminology table](#localized-inspection-terminology). |
| **Deductible / Excess** | The fixed amount the policyholder pays out of pocket on a claim before insurance pays the rest. `net_claim = approved_payout − deductible/excess`. "Deductible" (US) and "excess" (UK) are the same thing. See [Insurance, Claims & Warranty Compliance](../features/09-insurance-claims-warranty.md). |
| **Depreciation** | The loss of a vehicle's value over time — the single largest, most-ignored cost of ownership. Modelled as a straight-line or fixed-percent curve between purchase price and current/salvage value, and realized on sale as `purchase_price − sale_price`. Feeds the TCO engine. |
| **DOT age** | The age of a tire derived from its DOT date code (`WWYY` — week and year of manufacture). `DOT age = now − manufacture_date`; an expiry warning fires past a threshold in years, because rubber degrades even unused. See [Tires, Wheels & Seasonal](../features/07-tires-wheels.md). |
| **Engine-hours** | Running-time accrual (from an hour meter) used as an alternative to distance for machines that idle or work stationary. A first-class reminder dimension alongside date and distance. |
| **First fill** | The very first fuel entry for a vehicle in the app. It establishes a starting odometer but has no known prior interval, so it is **excluded** from economy averages — you cannot compute consumption without a preceding full tank. |
| **FNOL (First Notice of Loss)** | The first report of an incident to the insurer that opens a claim. Start of the claims workflow: FNOL → adjuster → payout-vs-deductible. See [Insurance, Claims & Warranty Compliance](../features/09-insurance-claims-warranty.md). |
| **Fuel-economy state machine** | The logic that turns raw fuel entries into correct economy figures by tracking each entry's fill state (partial / full / missed / first). Economy is computed **full-to-full**: only intervals that start and end on a full tank, with no missed fill between, yield a valid figure. This is the mechanism that eliminates the "wrong MPG" complaints seen in other trackers. See [Fuel & Energy](../features/02-fuel-energy.md). |
| **Full fill** | A fill that tops the tank completely. Full fills are the anchors of economy math: the distance and fuel between two consecutive full fills give a valid consumption figure. |
| **Grey fleet** | Privately-owned (or leased) vehicles used for business travel and reimbursed by mileage, rather than company-owned cars. Tracked for compliance and per-driver cost in [Fleet, Business & Company-Car](../features/10-fleet-business.md). |
| **Hijri** | The Islamic lunar calendar (Umm al-Qura / civil variants), ~354 days a year with 12 lunar months. A display calendar; dates are still stored canonically. See [Calendars](#calendars). |
| **HU / TÜV** | Germany's periodic technical inspection — *Hauptuntersuchung* (HU), colloquially "TÜV" after the inspection bodies. Due at 3 years for new cars, then every 2 years. See [inspection terminology](#localized-inspection-terminology). |
| **ICE** | Internal-Combustion-Engine vehicle (petrol, diesel, LPG/CNG, ethanol, hydrogen). Contrasted with BEV and PHEV in the unified energy engine. |
| **km/L** | Kilometres travelled per litre of fuel — a "higher-is-better" economy metric common in parts of Asia and Latin America. |
| **L/100km** | Litres of fuel consumed per 100 kilometres — a "lower-is-better" economy metric standard across Europe. |
| **Lead-time warning** | An advance alert fired *before* a due date or due distance is reached (`notification date = due_date − lead_time`; a distance lead is converted to a date via average daily distance), so the user has time to act. Documents use staged leads such as 60/30/7/1 days. See [Reminders & Notifications](../features/04-reminders-notifications.md). |
| **LEZ / Emission zone** | Low-Emission Zone (and Ultra-Low / Zero variants) — an urban area that restricts or charges vehicles by emissions class. Car and Pain bundles emission-zone data offline for [Cross-Border, Travel & Emission Zones](../features/13-cross-border-travel.md). |
| **MOT** | The United Kingdom's annual roadworthiness test (Ministry of Transport). First due at 3 years, then annually. See [inspection terminology](#localized-inspection-terminology). |
| **MPG (US / UK)** | Miles Per Gallon — a "higher-is-better" economy metric. Critically, the **US gallon (3.785 L) and UK/imperial gallon (4.546 L) differ**, so US-MPG and UK-MPG are distinct figures; storing volume canonically in litres prevents cross-contamination. |
| **Missed fill** | A fill the user forgot to log (or explicitly flags as incomplete data). Because the intervening distance and fuel are unknown, the surrounding interval cannot yield valid economy and is **excluded** from averages until the gap is resolved. |
| **No-claims bonus (NCB)** | A premium discount earned for consecutive claim-free years. A claim "steps back" the accrued years: `post-claim discount = ncb_table[max(0, ncb_years − step_back)]`. Car and Pain projects the premium impact before you file. |
| **Partial fill** | A fill that does **not** top the tank. It correctly adds fuel volume to the running total for the enclosing full-to-full interval, but on its own it does not close an economy interval. Handled explicitly by the fuel-economy state machine. |
| **PHEV** | Plug-in Hybrid Electric Vehicle — runs on both liquid fuel and grid electricity. Requires blended cost-per-distance across an ICE fill and an EV charge session. See [Fuel & Energy](../features/02-fuel-energy.md). |
| **RAG status** | Red / Amber / Green compliance signal: **red** = expired (expiry < today), **amber** = expiring within the lead window, **green** = OK, **none** = no expiry tracked. Drives the digital-glovebox compliance dashboard. See [Documents, Glovebox & Compliance](../features/08-documents-compliance.md). |
| **State-of-Health (SoH)** | The remaining capacity of an EV traction battery relative to when new, expressed as a percentage — the EV analogue of engine wear. Distinct from 12V starter-battery health tracked in [Components, Batteries, Keys & Consumables](../features/16-components-consumables.md). |
| **TCO (Total Cost of Ownership)** | The true, all-in cost of running a vehicle: `purchase_price + Σfuel + Σservice + Σother + Σfinancing_interest + depreciation`, normalized to the base currency. Car and Pain's on-device TCO engine is a core differentiator; most rivals stop at fuel. See [Expenses & Cost of Ownership](../features/05-expenses-cost-ownership.md). |
| **Tombstone** | A deletion marker retained (instead of hard-deleting a record) so that peer-to-peer sync and merge-aware restore can propagate the deletion instead of resurrecting the record. Keyed on UUID. See [Drivers, Household & Sharing](../features/15-drivers-household.md) and [Data, Offline, Backup & Portability](../features/18-data-offline-backup.md). |
| **TPMS** | Tire-Pressure Monitoring System — the in-vehicle sensor set that reports tire pressure. Its readings and per-sensor state are logged in [Tires, Wheels & Seasonal](../features/07-tires-wheels.md). |
| **Tread depth** | The remaining depth of tire tread, in mm or 1/32 in, measured per position and often at multiple points across the tread. Drives wear-rate and projected-replacement-odometer calculations and legal-minimum warnings. |
| **VIN / WMI** | Vehicle Identification Number — the unique 17-character vehicle ID; its first three characters are the **World Manufacturer Identifier (WMI)**. Validated via the ISO 3779 weighted modulus-11 check digit. Always rendered LTR, even inside RTL text. See [Vehicles, Garage & Odometer](../features/01-vehicles-garage.md). |
| **Wh/km** | Watt-hours of electrical energy consumed per kilometre — the primary EV efficiency metric (alongside kWh/100km and mi/kWh). "Lower-is-better." |
| **Whichever-comes-first reminder** | A reminder governed by more than one dimension (e.g. every 12 months *or* 15,000 km, whichever arrives sooner). The governing dimension is `min(time threshold, projected date the distance threshold is reached)`. See [Reminders & Notifications](../features/04-reminders-notifications.md). |

---

## Units & conversions

All values are **stored in the canonical (SI) base unit** and converted only at display and export. Conversion factors are exact where an exact definition exists; rounding is applied only to the displayed result, never to the stored value.

### Distance

Canonical base: **metre (m)**; distances are typically held in kilometres internally.

| Display unit | Symbol | To canonical (km) | From canonical |
| --- | --- | --- | --- |
| Kilometre | km | ×1 | ×1 |
| Mile (international) | mi | ×1.609344 | ×0.621371 |
| Metre | m | ×0.001 | ×1000 |

### Volume (liquid fuel)

Canonical base: **litre (L)**.

| Display unit | Symbol | To canonical (L) | From canonical |
| --- | --- | --- | --- |
| Litre | L | ×1 | ×1 |
| US gallon | US gal | ×3.785411784 | ×0.264172 |
| Imperial (UK) gallon | UK gal | ×4.54609 | ×0.219969 |

> **The gallon trap.** US and UK gallons differ by ~20%. Because volume is stored canonically in litres, an MPG figure entered in US gallons and one entered in UK gallons never silently corrupt each other — the distinction is preserved through import, export, and unit switching.

### Energy (EV charging)

Canonical base: **kilowatt-hour (kWh)**.

| Display metric | Meaning |
| --- | --- |
| kWh | Energy of a charge session (the EV analogue of fill volume). |
| Wh/km | Watt-hours per kilometre (canonical-friendly EV efficiency, lower-is-better). |
| kWh/100km | Kilowatt-hours per 100 km. |
| mi/kWh | Miles per kWh (higher-is-better). |

### Fuel economy

Economy is a **derived** metric, computed full-to-full from canonical distance and volume, then presented in the user's chosen convention. Conversions below use `L/100km` as the pivot.

| Metric | Direction | Relationship |
| --- | --- | --- |
| L/100km | lower = better | canonical pivot |
| km/L | higher = better | `km/L = 100 ÷ (L/100km)` |
| MPG (US) | higher = better | `MPG_US = 235.215 ÷ (L/100km)` |
| MPG (UK) | higher = better | `MPG_UK = 282.481 ÷ (L/100km)` |
| Wh/km (EV) | lower = better | energy-from-wall ÷ distance |

### Pressure (tires)

Canonical base: **kilopascal (kPa)**.

| Display unit | Symbol | To canonical (kPa) | From canonical |
| --- | --- | --- | --- |
| Kilopascal | kPa | ×1 | ×1 |
| Bar | bar | ×100 | ×0.01 |
| Pound-force per sq. inch | psi | ×6.894757 | ×0.145038 |

### Tread depth

| Display unit | Symbol | Relationship |
| --- | --- | --- |
| Millimetre | mm | canonical |
| Thirty-second of an inch | 1/32 in | `1/32 in = 0.79375 mm`; `mm × 1.259843 = 1/32 in units` |

### Torque (service / mods)

| Display unit | Symbol | To canonical (N·m) |
| --- | --- | --- |
| Newton-metre | N·m | ×1 |
| Pound-foot | lb·ft | ×1.355818 |

### Power (mods)

| Display unit | Symbol | Relationship |
| --- | --- | --- |
| Kilowatt | kW | canonical |
| Metric horsepower | PS | `1 PS = 0.735499 kW` |
| Mechanical horsepower | hp | `1 hp = 0.745700 kW` |

### Temperature

| Display unit | Symbol | Conversion |
| --- | --- | --- |
| Celsius | °C | canonical |
| Fahrenheit | °F | `°F = °C × 9/5 + 32` |
| Kelvin | K | `K = °C + 273.15` |

### Currency

Canonical base: a single user-chosen **base currency**; every amount also records its **original currency** and the **dated exchange-rate snapshot** used.

| Concept | Rule |
| --- | --- |
| Storage | Amounts stored in base currency; the original entry currency and value are retained. |
| Conversion | `amount_base = amount_original × exchange_rate(rate_date)` — manual / historical **offline** rates only; no live FX. |
| Rate snapshots | Each conversion pins a dated rate so totals stay reproducible; changing today's rate never rewrites past entries. |
| High-magnitude currencies | Redenominated / high-inflation currencies (e.g. IRR, TRY) are handled at full magnitude without overflow or rounding drift. |
| Refunds | Net as signed negatives against the same category. |

> Consistent with the offline-honesty principle, Car and Pain never claims live FX. Rates are user-entered or bundled historical snapshots, always timestamped. See [Expenses & Cost of Ownership](../features/05-expenses-cost-ownership.md).

---

## Calendars

Language, numeral system, **and calendar are independent preferences.** Every date is stored canonically as UTC / ISO-8601 and converted to the chosen calendar only for display and entry. Reminders and recurrences are **scheduled on the absolute (canonical) date** — a reminder fires at the right real-world moment regardless of which calendar the user reads it in; only the *displayed* date changes.

| Calendar | Type | Script / typical numerals | Primary usage | Conversion notes |
| --- | --- | --- | --- | --- |
| **Gregorian** | Solar | Latin (Western-Arabic digits) | Global default; the canonical storage calendar (ISO-8601). | Baseline; no conversion. |
| **Persian / Jalali (Shamsi)** | Solar | Persian digits | Iran, Afghanistan (Persian/Farsi users). | Jalali↔Gregorian via the astronomical Nowruz leap rule; short-month clamping (e.g. Esfand 30). |
| **Hijri** | Lunar | Eastern-Arabic digits | Islamic calendar (Arabic/Sorani users), religious and civil dates. | Umm al-Qura / civil variants; ~354-day year, variable month lengths. |
| **Hebrew** | Lunisolar | Hebrew script | Hebrew-language users. | Metonic-cycle conversion with leap months (Adar I / Adar II). |

**Recurrence in non-Gregorian calendars.** Interval arithmetic respects each calendar's leap years and variable month lengths, with short-month clamping (Jan-31 → Feb-28, Esfand 30, Adar I/II). The next cycle re-anchors from the actual completion date to avoid drift. **First day of week** is locale-aware — Saturday for Persian/Arabic locales, Sunday for Hebrew — which affects weekly grouping in stats and reports. See [Localization, RTL & Calendars](../features/19-localization-rtl.md).

---

## Numeral systems

Digits are a **display and input** concern only. On input, Eastern-Arabic / Persian / Devanagari digits are normalized to canonical Western-Arabic for parsing, storage, and search ("digit folding"); on display they are shaped to the user's preference. Numeric runs, units, and IDs stay LTR even inside RTL text via bidi isolation.

| System | 0–9 sample | Notes |
| --- | --- | --- |
| **Western Arabic (Latin)** | 0 1 2 3 4 5 6 7 8 9 | Canonical storage and export form. |
| **Eastern Arabic** | ٠ ١ ٢ ٣ ٤ ٥ ٦ ٧ ٨ ٩ | Arabic-Indic digits (Arabic, Sorani Kurdish). |
| **Persian** | ۰ ۱ ۲ ۳ ۴ ۵ ۶ ۷ ۸ ۹ | Distinct glyphs for 4, 5, 6 vs Eastern Arabic (Persian/Farsi). |
| **Devanagari** | ० १ २ ३ ४ ५ ६ ७ ८ ९ | Hindi and related locales. |

### Separators and grouping

| Style | Decimal | Grouping | Example (1234567.5) |
| --- | --- | --- | --- |
| English (US/UK) | `.` | `,` every 3 | `1,234,567.5` |
| German / French (European) | `,` | `.` or thin space every 3 | `1.234.567,5` |
| Persian / Arabic | `٫` (decimal) | `٬` (grouping) every 3 | `۱٬۲۳۴٬۵۶۷٫۵` |
| **Indian (lakh / crore)** | `.` | `2-2-3` grouping | `12,34,567.5` |

> **Indian grouping** groups the last three digits, then every two digits thereafter (thousand → lakh → crore), so `10,000,000` is written `1,00,00,000` (one crore). Both parsing and formatting honor this. Fuel prices carry **3 decimals** of precision throughout.

---

## Formula reference

A consolidated cheat-sheet of the key calculations used across modules. Each formula is computed on canonical values and presented in display units. The linked feature doc is authoritative for edge cases.

### Odometer, distance & projection

| Formula | Definition |
| --- | --- |
| `current_odometer` | Latest reading across all dated entries, with cluster-swap offset applied. |
| `lifetime_distance` | `reading + cumulative_offset`. |
| `avg_daily_distance` | `(odo_latest − odo_earliest) / days_between` (rolling window from the odometer ledger). |
| `estimated_odometer_today` | `last_actual_reading + avg_daily_distance × days_since_last_reading`. |
| `projected_annual_distance` | `avg_daily_distance × 365`. |
| `gap_distance` | `next_start_odometer − prev_end_odometer` (trip continuity check). |

### Fuel & energy → [Fuel & Energy](../features/02-fuel-energy.md)

| Formula | Definition |
| --- | --- |
| Third-field solve | `total = volume × price_per_unit` (solve any one from the other two; 3-decimal precision). |
| Full-to-full economy | `distance = odo_end − odo_start`; `fuel = Σ volumes across interval` → L/100km, MPG US/UK, km/L. |
| Lifetime average | Excludes first fill and any interval containing a missed fill. |
| EV true cost/100 | `(energy_from_wall × price_per_kwh) / distance × 100`, with a ~10–15% AC loss factor. |
| EV energy from SoC | `energy = (end_soc − start_soc)/100 × usable_capacity_kwh`. |
| EV-vs-ICE break-even | `months_to_payback = price_premium / (ice_cost_per_period − ev_cost_per_period)`. |
| Range estimate | `tank_capacity ÷ rolling_avg_consumption`. |

### Service & reminders → [Service & Maintenance](../features/03-service-maintenance.md), [Reminders & Notifications](../features/04-reminders-notifications.md)

| Formula | Definition |
| --- | --- |
| Next due (time) | `next_due_date = last_done_date + interval_time`. |
| Next due (distance) | `next_due_odometer = last_done_odometer + interval_distance`. |
| Whichever-first | Governing dimension = `min(time threshold, projected date the distance threshold is reached)`. |
| Estimated due date | `today + (due_odometer − current_odometer) / avg_daily_distance`. |
| Lead notification | `due_date − lead_time` (distance lead converted to a date via avg daily distance). |
| Proximity trigger | Fire when `remaining ≤ proximity_percent × interval`. |
| Overdue | `overdue_by_days` / `overdue_by_distance` / `overdue_by_hours`. |
| Re-anchor | Next cycle recomputed from actual completion date/odometer (avoids drift). |
| Visit total | `Σ(parts + labour) + tax − discount + fees`. |
| DIY savings | `estimated_shop_cost − actual_diy_cost`. |

### Expenses, TCO & financing → [Expenses & Cost of Ownership](../features/05-expenses-cost-ownership.md)

| Formula | Definition |
| --- | --- |
| TCO | `purchase_price + Σfuel + Σservice + Σother + Σfinancing_interest + depreciation`. |
| Cost per km / day | `total_cost / distance` ; `total_cost / days_owned`. |
| Amortized monthly | `annual_or_prepaid_cost / coverage_months`. |
| Budget projection | `projected_period_total = actual_spend / elapsed_fraction`. |
| Depreciation | Straight-line or fixed-percent annual curve between purchase and salvage/current value. |
| Loan interest part | `balance × apr / 12`. |
| Loan principal part | `payment − interest_part`. |
| Early-payoff saving | `Σremaining_interest − recomputed_interest`. |
| Equity | `current_value − loan_balance`. |
| Negative equity | `loan_balance − current_value` (flag when > 0). |
| Repair-or-replace | `keep_cost/period` vs `(replacement financing + expected new running cost)` → break-even months. |
| Currency normalization | `amount × exchange_rate(rate_date)`; refunds net as signed negatives. |

### Trips & mileage → [Trips & Mileage Logbook](../features/06-trips-mileage.md)

| Formula | Definition |
| --- | --- |
| Trip distance | `end_odometer − start_odometer` (or direct entry / GPS track points). |
| Deduction | `billable_distance × applicable_rate (+ passenger_rate × passengers)`. |
| Tiered claim | Split at threshold (e.g. HMRC 45p/25p at 10,000 mi; IRS rate by trip date, effective-dated). |
| Business-use % | `business_distance / total_distance`. |

### Tires → [Tires, Wheels & Seasonal](../features/07-tires-wheels.md)

| Formula | Definition |
| --- | --- |
| Per-set accrued mileage | On swap, add `(odometer_at_change − set_install_odometer)` to the dismounted set. |
| Cost per 1000 km | `set_price / (accrued_mileage / 1000)`. |
| Wear rate | `(tread_prev − tread_now) / (distance / 1000)` per 1000 km. |
| Projected replacement odo | `current_odo + (tread_now − legal_min) / wear_rate × 1000`. |
| DOT age | `now − manufacture_date(WWYY)`; warn past threshold years. |
| Uneven-wear flag | When `|tread_outer − tread_inner|` exceeds threshold. |

### Compliance, insurance & warranty → [Documents, Glovebox & Compliance](../features/08-documents-compliance.md), [Insurance, Claims & Warranty Compliance](../features/09-insurance-claims-warranty.md)

| Formula | Definition |
| --- | --- |
| RAG status | red = `expiry < today`; amber = within lead window; green = OK; none = no expiry. |
| Warranty whichever-first | `min(expiry_date, projected date odometer reaches mileage_limit)`. |
| Net claim | `approved_payout − deductible/excess`. |
| NCB impact | `post-claim discount = ncb_table[max(0, ncb_years − step_back)]`. |
| Premium trend | Period-over-period % change across renewals. |
| Warranty compliance | All required schedule items logged within date & mileage tolerance → compliant; any missed → at-risk / void-risk. |
| LPG/CNG re-cert | `next_due = last_cert + statutory interval` (country-specific). |

### Fleet, rideshare & mods → [Fleet, Business & Company-Car](../features/10-fleet-business.md), [Rideshare, Gig & Rental Economics](../features/11-rideshare-gig-rental.md), [Modifications & Build Log](../features/12-modifications-build-log.md)

| Formula | Definition |
| --- | --- |
| BIK annual charge | `list_price × bik_percentage(band) × marginal_tax_rate`. |
| VAT reclaim | `Σ reclaimable_amount` over period (rate-aware). |
| Fuel-card delta | `statement_total − matched_logged_fills` (flag unmatched). |
| Per-driver P&L | `income − (fuel + service + share of fixed costs + mileage reimbursement)`. |
| Session profit (gig) | `net_income − fuel/energy − allocated_running_cost`. |
| Cost per revenue mile | `allocated_cost / revenue_miles`. |
| Gig break-even | `fixed_cost_period / (net_rate_per_mile − variable_cost_per_mile)`. |
| Build cost | `Σ(parts + labour)`; `power_gain = after_hp − baseline_hp`; `cost_per_hp = mod_cost / power_gain`. |

### Components, stats & disposal → [Components, Batteries, Keys & Consumables](../features/16-components-consumables.md), [Dashboard, Statistics & Reports](../features/17-dashboard-statistics-reports.md), [Sell, Dispose & Ownership Transfer](../features/24-sell-dispose.md)

| Formula | Definition |
| --- | --- |
| Remaining life % | `1 − (used_distance / expected_life_distance)`. |
| Low-stock flag | `quantity < threshold`. |
| Delta percent | Period-over-period change with semantic direction (lower spend good, lower economy bad). |
| Anomaly detection | Economy-drop when `recent < baseline − drop_threshold_pct`; spend-spike when `period_spend > mean + k×stddev`. |
| CO₂ | `fuel_volume × emission_factor + kWh × grid_factor` → gCO₂/km. |
| Realized depreciation | `purchase_price − sale_price`. |
| Final TCO | Lifetime TCO snapshot at disposal (incl. financing and depreciation). |
| Net proceeds | `sale_price − outstanding_loan_balance` (equity). |

### Data integrity & security → [Data, Offline, Backup & Portability](../features/18-data-offline-backup.md)

| Formula | Definition |
| --- | --- |
| Dedupe key | `vehicle_id + odometer + date` (idempotent re-import). |
| Checksums | SHA-256 over the backup archive and each attachment. |
| Merge conflict | Last-write-wins by `updated_at`, with field-level manual override when clocks are skewed. |
| Encryption | KDF (Argon2id / PBKDF2) + AES-256-GCM for encrypted backups. |
| VIN validation | ISO 3779 weighted modulus-11 check digit. |

---

## Localized inspection terminology

The same "mandatory periodic technical inspection" concept carries a different name in each market. Car and Pain localizes all of them, with a generic fallback, and auto-suggests the next due date from country rule tables. See [Documents, Glovebox & Compliance](../features/08-documents-compliance.md) and [Reference, Diagnostics & Recalls](../features/23-reference-diagnostics.md).

| Country | Local term | Typical schedule |
| --- | --- | --- |
| Germany | HU / TÜV (§ *Hauptuntersuchung*) | New: 3 years, then every 2 years. |
| United Kingdom | MOT | New: 3 years, then annually. |
| France | Contrôle technique (CT) | New: 4 years, then every 2 years. |
| Spain | ITV | New: 4 years → 2 years → annually. |
| Italy | Revisione | New: 4 years, then every 2 years. |
| Netherlands | APK | Age-dependent, then annually. |
| Ireland | NCT | New: 4 years, then periodic. |
| Romania | ITP | Periodic by category. |
| Sweden | Besiktning | Periodic. |
| Norway | EU-kontroll | Periodic. |
| Austria | § 57a / Pickerl | Periodic. |
| Czech Republic | Technická kontrola | Periodic. |
| Turkey | Muayene | Periodic. |
| — | Generic "inspection" fallback | Used where no specific term is bundled. |

---

## Priority tiers

Every feature doc classifies its requirements into three tiers with a consistent meaning across the product. See the [Product Overview & Architecture](../overview.md) for how these roll up into the roadmap.

| Tier | Meaning | Commitment |
| --- | --- | --- |
| **Must-have** | Core requirements that define the module and uphold the app's promises (offline-first, data ownership, correct canonical storage, deep localization, accessibility). The module is not shippable without them. | Guaranteed; never paywalled where it concerns core logging, export, reminders, or backup. |
| **Should-have** | Important capabilities that significantly improve the module and are strongly expected, but whose absence would not break the core promise. Scheduled close behind the must-haves. | Planned; may follow shortly after the initial module release. |
| **Nice-to-have** | Valuable enhancements and polish that deepen the experience for specific use-cases. Delivered opportunistically as capacity allows. | Aspirational; prioritized by user demand. |

---

## Cross-module naming standards

To keep the vocabulary above stable everywhere it appears:

- **Canonical first, display second.** Docs always distinguish the *stored* canonical value from the *shown* localized value. Never describe a stored value in display units.
- **IDs stay LTR.** VIN, license plate, paint/part numbers, policy/claim numbers, phone, and IBAN are rendered left-to-right via bidi isolation even inside RTL text.
- **Fill states are load-bearing.** The words *partial*, *full*, *missed*, and *first* have exact meanings (above) that every downstream statistic depends on; they are never used loosely.
- **Whichever-first is one concept.** Any dual/triple-dimension due date is described with the `min(...)` rule, never re-invented per module.
- **UGC is preserved.** User-defined names (nicknames, custom service types, tags, vendor and cost-centre names, notes) are preserved verbatim across languages and searchable via digit-folding and script normalization.

_This glossary is the shared source of truth; if another doc and this page disagree on a term, unit factor, or formula, this page (together with the [Canonical Data Model & Schema](./data-model.md)) wins._
