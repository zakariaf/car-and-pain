# ⛽ Fuel & Energy

> No more "why is my MPG wrong?" — one honest economy engine for petrol, diesel, gas, and electrons, that never lies after a partial or a forgotten fill.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Vehicles, Garage & Odometer](./01-vehicles-garage.md) · [Expenses & Cost of Ownership](./05-expenses-cost-ownership.md) · [Dashboard, Statistics & Reports](./17-dashboard-statistics-reports.md)

## The pain

Fuel is the entry that owners make most often, and it is the one every rival app gets subtly wrong. Users abandon Drivvo and Fuelly over "wrong MPG" complaints that trace back to mishandled partial fills, forgotten fills, and the classic US-gallon-vs-UK-gallon-vs-litre corruption. EV and plug-in-hybrid drivers are treated as an afterthought — forced to fake a charge as if it were a petrol fill, with no home-vs-public tariff split, no charging-loss accounting, and no way to answer "is my EV actually cheaper than my old car yet?" And everyone loses their price history the day they switch phones. Car and Pain treats a charge session as the exact analogue of a fill-up, keeps the economy math correct across every fill state, and stores it all on-device so it survives forever.

## What it does

Fuel & Energy is a single unified entry-and-economy engine for every way a vehicle takes on energy: petrol, diesel, LPG/CNG, ethanol, and hydrogen fills, plus EV and PHEV charge sessions. Pump-side entry is fast and forgiving — smart per-vehicle defaults, enter-any-two auto-calculation, and the freedom to log without an odometer reading or without a cost. Underneath, a precise full/partial/missed/first-fill state machine drives a full-to-full consumption algorithm so the numbers are always trustworthy, whatever the fill pattern.

Because everything is stored canonically (SI volume and energy, ISO/UTC dates, base currency) and converted only for display, a driver can log in litres today and read economy in MPG UK tomorrow without a single historical value shifting. The same engine powers multi-fuel and bi-fuel vehicles, blended PHEV cost-per-distance, home-vs-public EV tariffs, battery State-of-Health, and an EV-vs-ICE break-even calculator — all fully offline, with saved stations and personal price memory instead of a live price feed it cannot honestly provide.

## Features

### ✅ Must-have

- **Quick fill-up entry with smart defaults** — Opening a new fill pre-fills the last station, fuel type, and price for that specific vehicle, so a routine top-up is a two-tap confirmation rather than a form.
- **Enter-any-two auto-calculate** — Type any two of price-per-unit, volume, and total cost and the third is computed automatically at 3-decimal pricing precision; the user marks which field is authoritative so rounding never fights the receipt.
- **Full vs partial fill toggle** — A partial fill is flagged and defers economy until the next full tank, instead of producing a nonsense figure from an unknown starting level.
- **Missed / forgotten fill flag** — When a fill was skipped in the log, the flag excludes that gap from the economy calculation while still keeping its cost in the spend totals.
- **First-fill baseline handling** — The very first fill (or the first after a reset) shows economy as "pending" rather than a misleading 0 or infinity, because there is no prior full tank to measure from.
- **Full-to-full consumption algorithm** — Economy is computed across a full-to-full interval, summing every partial fill in between, which is the only mathematically correct way to derive real-world consumption.
- **Multi-fuel & bi-fuel support** — Vehicles that run on more than one energy source keep separate per-fuel statistics so petrol and LPG (or fuel and electric) never get blended into a meaningless average.
- **Fuel type & grade selector** — Records the exact product: octane/RON rating, E5/E10/E85 ethanol blends, and diesel/HVO variants, so grade-sensitive economy and cost comparisons stay honest.
- **EV charging session logging** — A charge is a first-class entry capturing kWh delivered, cost, charger type, network, and state-of-charge — the direct analogue of a fill-up, not a bolted-on afterthought.
- **Multi-mode economy engine** — Presents economy in whichever format the driver thinks in: L/100km, MPG (US), MPG (UK), km/L, Wh/km, mi/kWh, and kWh/100km.
- **Multi-unit volume & energy** — Accepts and displays litres, US gallons, UK gallons, kWh, kilograms, and cubic metres, matching how each fuel is actually sold.
- **Per-vehicle distance unit** — Each vehicle carries its own distance unit (km or miles) so a mixed garage never forces a single global choice.
- **Running, rolling-N, and lifetime averages** — Shows the latest interval, a rolling average over the last N fills, and the lifetime figure, so both spikes and long-term trends are visible.
- **Odometer entry with trip-meter support** — Enter an absolute odometer reading or a trip-meter distance-since-last, whichever is on the dash, and the engine reconciles them.
- **Canonical SI storage with display-only conversion** — Every value is stored in base units and converted purely for display, so toggling units or currency never rewrites or corrupts history.
- **Log without mileage and without cost** — A fill can be saved with no odometer (logged later) and with no cost at all, covering free or rewards fuel without breaking the record.
- **Data-integrity validation on save** — On save the entry is checked for over-capacity volume, outlier economy, and duplicate double-tap submissions, warning the user while still allowing an override.

### 🔵 Should-have

- **Last-3-digits odometer shortcut** — For fast pump-side entry, the driver can type only the last three digits of the odometer and the app expands it against the known reading.
- **LPG/CNG gaseous-fuel pricing** — Gaseous fuels are priced per kilogram or per cubic metre rather than per litre, because the unit model must match how the pump sells them.
- **Charge start/end battery % with derived energy** — Logging start and end state-of-charge lets the app derive delivered energy from the battery's usable capacity when a meter reading is not available.
- **Home vs public charging separation** — Home and public charges are tracked separately, each with its own time-of-use tariff, so the true cost mix is visible instead of a single averaged rate.
- **PHEV blended fuel + electric logging** — A plug-in hybrid logs both fuel and electricity against one shared odometer, blended into a single cost-per-distance rather than incorrectly added together.
- **Home electricity tariff & TOU store** — An offline store of home electricity tariffs and time-of-use rates auto-costs home charges without any online lookup.
- **EV true cost-per-distance including losses** — EV efficiency and running cost account for charging losses (the energy drawn from the wall versus the energy that reached the battery), giving an honest cost figure.
- **Battery State-of-Health tracker** — Tracks traction-battery degradation over time so the driver can watch usable capacity and range decline.
- **EV-vs-ICE / PHEV running-cost comparison** — Compares electric versus fuel running costs and computes the payback/break-even point for any price premium paid up front.
- **Tank/battery capacity for range checks** — Storing tank or battery capacity powers range estimates and drives the over-capacity validation on save.
- **Dual/twin-tank & bi-fuel economy** — Twin-tank and bi-fuel setups get per-tank figures plus a combined view, so nothing is lost by splitting.
- **Station name/brand/GPS capture** — Captures station name, brand, and raw GPS coordinates fully offline, dropping a pin on the bundled offline map with no reverse-geocoding dependency.
- **Offline saved-stations & price memory** — A personal library of saved stations and their remembered prices, built entirely from the user's own history.
- **Multi-currency fills with manual rate** — Fills abroad accept a manual per-trip exchange rate while preserving the original amount, so travel spend converts correctly without a live FX feed.
- **Best/worst tank tracking** — Highlights the most and least efficient tanks to surface driving-style or mechanical changes.
- **Cost-per-distance & fuel-spend metrics** — Standing metrics for cost-per-distance and total fuel spend, scoped per vehicle.
- **Economy/price/consumption/spend charts** — On-device charts for economy, price, consumption, and spend trends over time.
- **Backdated / out-of-order entry** — Entries added out of chronological order trigger a deterministic recompute of every affected interval, so late logging never leaves stale numbers.
- **Charging network membership & card wallet** — Stores EV network memberships and an RFID/charge-card wallet reference for quick recall at the charger.
- **Fuel-price logging & comparison** — Logs and compares fuel prices from the user's own offline history — honestly, with no claim of live market pricing.

### ⚪ Nice-to-have

- **Per-station price history** — A Fuelio-style, fully offline price history for each saved station, built from the driver's own visits.
- **Distance-to-empty / trip-cost / next-fill predictor** — Predicts remaining range, the cost of an upcoming trip, and when the next fill is due, from rolling averages.
- **Wall-to-wheel charging-loss tracking** — Explicitly tracks the loss between wall energy and energy stored, for drivers who want the full efficiency picture.
- **Solar / self-generated charging cost** — Prices self-generated home charging with net-metering awareness, so solar owners cost their electrons realistically.
- **Receipt / pump-display photo attachment** — Attaches a photo of the receipt or pump display to the entry through the shared, encrypted-optional attachments pipeline.
- **Remaining-fuel & range estimate** — Estimates fuel left in the tank and the range it buys, from capacity and rolling consumption.
- **Splash-fill / jerrycan exclusion** — Marks a splash-fill or jerrycan top-up so its cost is kept but its volume is excluded from economy math.
- **AdBlue/DEF & additive tracking** — Tracks AdBlue/DEF and other additives as a separate consumable, not as fuel volume.
- **Free / fuel-card / payment-method handling** — Records the payment method — including free fuel and fuel cards — which feeds Fleet fuel-card reconciliation downstream.
- **Tags & trip-purpose per fill** — Each fill can carry tags and a trip purpose for later filtering, budgeting, and business/personal splits.
- **Fuel-log & low-fuel reminders** — Optional local reminders to log a fill or that fuel is running low.
- **Rising-consumption / anomaly alert** — Flags a rising-consumption trend or an anomalous tank that may signal a mechanical issue.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `entry_id` | uuid | Stable identifier; survives export/import and peer-to-peer sync. |
| `vehicle_id` | ref | Links the fill/charge to a vehicle in the garage. |
| `date` | date | Stored as ISO/UTC; displayed in the vehicle's chosen calendar. |
| `time` | text (time) | Time of the fill/charge, for TOU tariff matching. |
| `odometer` | number+unit (distance) | Absolute reading on the shared odometer ledger. |
| `trip_meter` | number+unit (distance) | Distance-since-last alternative to an absolute reading. |
| `volume` | number+unit (volume) | Fuel volume; canonical SI storage. |
| `volume_unit` | enum | L, US gal, UK gal, kWh, kg, m³. |
| `price_per_unit` | number+unit (currency) | 3-decimal pricing precision. |
| `total_cost` | number+unit (currency) | Enter-any-two auto-calculated when not authoritative. |
| `currency` | enum | Per-record currency; converts to base for aggregates. |
| `fuel_type` | enum | Petrol, diesel, LPG, CNG, ethanol, hydrogen, electric. |
| `octane_grade` | enum | Octane/RON, E5/E10/E85, diesel/HVO grade. |
| `secondary_fuel_type` | enum | For bi-fuel vehicles. |
| `is_full_tank` | bool | Drives the full-to-full economy interval. |
| `is_partial` | bool | Defers economy to the next full tank. |
| `is_missed_previous` | bool | Excludes the prior gap from economy, keeps cost. |
| `estimated_fuel_remaining` | number+unit (volume) | Optional remaining-fuel estimate for range. |
| `exclude_from_economy` | bool | Splash-fill/jerrycan flag: cost kept, volume excluded. |
| `tank_number` | number | Identifies the tank on twin-tank/bi-fuel setups. |
| `station_id` | ref | Links to a saved station. |
| `station_name` | text | UGC/foreign string, bidi-isolated. |
| `station_brand` | text | Brand label for grouping and price memory. |
| `latitude` | number | Raw GPS coordinate; offline map pin. |
| `longitude` | number | Raw GPS coordinate; offline map pin. |
| `payment_method` | enum | Cash/card/fuel-card/free; feeds Fleet reconciliation. |
| `fuel_card_id` | ref | Links to a fuel card for business reconciliation. |
| `is_free` | bool | Free/rewards fuel; must not distort price averages. |
| `energy_kwh` | number+unit (energy) | kWh delivered for an EV/PHEV charge. |
| `price_per_kwh` | number+unit (currency) | Charge price per kWh. |
| `charger_type` | enum | AC/DC and level. |
| `charge_network` | text | UGC/foreign network string, bidi-isolated. |
| `charge_membership_id` | ref | EV network membership / RFID card reference. |
| `connector_type` | enum | Physical connector standard. |
| `start_soc_pct` | number (%) | Battery state-of-charge at start. |
| `end_soc_pct` | number (%) | Battery state-of-charge at end. |
| `is_home_charge` | bool | Separates home vs public charging cost. |
| `tou_rate` | ref | Time-of-use tariff applied for auto-costing. |
| `self_generated_kwh` | number+unit (energy) | Solar/self-generated energy in the session. |
| `energy_from_wall_kwh` | number+unit (energy) | Wall energy billed; basis for true cost/distance. |
| `receipt_photo_ref` | attachment | Receipt or pump-display photo. |
| `tags[]` | array | User-defined tags and trip purpose. |
| `trip_id` | ref | Links a fill to a trip in the logbook. |
| `notes` | text | Free-form note. |

## Calculations & formulas

- **Enter-any-two third field** — `total = volume × price_per_unit`, `volume = total / price_per_unit`, `price_per_unit = total / volume`, at 3-decimal precision; the user selects which field is authoritative so rounding never corrupts the receipt.
- **Full-to-full economy** — `distance = odo_end − odo_start` and `fuel = Σ volumes across the interval`, expressed as L/100km, MPG (US), MPG (UK), and km/L.
- **Lifetime average** — Averaged across all valid intervals, excluding the first-fill baseline and any missed-fill intervals.
- **EV economy** — Wh/km, mi/kWh, and kWh/100km, with true cost `cost/100 = (energy_from_wall × price_per_kwh) / distance × 100`, applying a `loss_factor` of roughly 10–15% for AC charging.
- **EV energy from SoC** — `energy = (end_soc − start_soc) / 100 × usable_capacity_kwh` when no meter reading is available.
- **EV-vs-ICE break-even** — `months_to_payback = price_premium / (ice_cost_per_period − ev_cost_per_period)`.
- **Unit constants** — `US gal = 3.785 L`, `UK gal = 4.546 L`, plus CNG mass conversions for per-kg/m³ pricing.
- **Range estimate** — `range = tank_capacity ÷ rolling_avg_consumption`.

## Reminders & notifications

This module both consumes and produces reminders through the shared [local notification engine](./04-reminders-notifications.md):

- **Fuel-log reminders** — Optional prompts to record a fill that may have been missed, keeping the economy chain intact.
- **Low-fuel reminders** — Local alerts when the remaining-fuel estimate falls below a threshold, based on rolling consumption rather than a live sensor feed.
- **Next-fill / range prediction** — Projection from rolling averages that can warn ahead of an expected empty tank.
- **Rising-consumption anomaly alert** — Fires when an interval's economy degrades beyond a tolerance, flagging a possible mechanical issue early.

All of these are delivered as reliable on-device local notifications that survive reboot, Doze, and app-kill, name the specific vehicle, and re-arm after a backup restore.

## Offline & data

Every part of Fuel & Energy works in airplane mode with no account. Entry, enter-any-two math, the full/partial/missed/first-fill state machine, economy in every format, saved stations, personal price memory, and offline map pins all run entirely on-device. There is no live fuel-price feed, no live charging tariff, and no live FX — by design. Instead the app remembers the driver's own prices, stores home and public tariffs locally for auto-costing, and takes a manual exchange rate for foreign fills, always preserving the original amount. GPS coordinates are captured raw and pinned on the bundled offline map with no reverse-geocoding dependency.

Fuel and charge records — with their full-tank, partial, missed, and exclusion flags, their attachments, and their live economy state — are included in the single-file full backup, per-entity CSV, and combined JSON export, so nothing is orphaned on a device migration. Exports carry explicit units and currency labels so the canonical values are never ambiguous on the other side. Backdated and duplicate entries are reconciled deterministically, and merge-aware restore plus trash/undo protect against the data loss that drives owners off competing apps. See [Data, Offline, Backup & Portability](./18-data-offline-backup.md) for the full portability model.

## Localization & RTL

Drawn from the module's i18n requirements:

- **3-decimal price parsing & rendering** — Fuel prices always carry three decimals, and the app parses and renders them across locale conventions, including Persian `٫` decimal and `٬` grouping separators.
- **Numeral systems** — Western, Eastern-Arabic, Persian, and Devanagari digits are all accepted for input and shown on output, with Indian 2-2-3 lakh/crore grouping supported alongside Western grouping.
- **Numbers and units stay LTR in RTL text** — Volumes, prices, units, VINs, plates, and IDs are bidi-isolated and rendered left-to-right even inside Persian, Arabic, or Sorani Kurdish layouts.
- **Charts mirror for RTL** — Chart chrome mirrors and the time axis inverts so trends read naturally right-to-left; see [Localization, RTL & Calendars](./19-localization-rtl.md).
- **Multiple calendars** — Dates display in Gregorian, Jalali/Shamsi, Hijri, or Hebrew while always stored as ISO, so switching calendars never shifts a record.
- **Per-vehicle units & currency** — Each vehicle keeps its own units and currency, with canonical SI storage preventing conversion drift and exports carrying explicit units and currency.
- **UGC/foreign strings preserved** — Charging-network and station names are user-generated foreign strings, preserved verbatim with bidi isolation so mixed-script names display correctly.

## Edge cases

- Partial fills defer economy to the next full tank, and consecutive partials are summed across the whole span.
- A missed fill excludes its interval from economy while keeping its cost in spend totals.
- The first-ever fill, or the first after a reset, shows "pending" — never 0 and never infinity.
- Filling by money not volume ("$40 worth") derives the volume, and a cost-only entry with no volume is allowed.
- Free, rewards, or $0 fills must not distort per-unit price averages.
- The classic US-gallon vs UK-gallon vs litre "wrong-MPG" bug is avoided by storing canonical values and labelling exported units explicitly.
- CNG is sold by kilogram or cubic metre, not litres, so the unit model never assumes litres.
- EV charging losses mean billing is on wall energy and cost-per-distance uses wall kWh; self-generated energy is priced at the marginal or opportunity cost the user chooses.
- A PHEV shares one odometer, so fuel and electric costs are blended, never added.
- Bi-fuel attributes distance to the tank actually used, producing separate and combined statistics.
- Fills abroad take a manual exchange rate while keeping the original amount intact.
- 3-decimal pricing must not corrupt the enter-any-two calculation.
- A backdated insert re-sorts the timeline and recomputes affected intervals deterministically.
- Duplicate double-tap or re-import entries are detected and offered a merge or skip.
- A volume larger than the tank, or an implausible economy figure, is validated on save with an override path.
- Charging-network availability and live tariffs are online-only, so the app uses saved networks and manual tariffs offline and never claims live pricing.

## Related features

- **[Vehicles, Garage & Odometer](./01-vehicles-garage.md)** — Fuel entries write to the shared per-vehicle odometer ledger and read tank/battery capacity and fuel-type configuration from the vehicle profile.
- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — Fuel and charging spend feed directly into the true Total-Cost-of-Ownership engine and budgets.
- **[Dashboard, Statistics & Reports](./17-dashboard-statistics-reports.md)** — Economy, price, consumption, and spend charts and rolling averages surface here per vehicle and across the garage.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — Fuel-log, low-fuel, next-fill, and rising-consumption alerts are scheduled through the shared offline notification engine.
- **[Fleet, Business & Company-Car](./10-fleet-business.md)** — Payment-method and fuel-card fields feed fuel-card reconciliation, per-driver P&L, and VAT handling.
- **[Offline Maps & Location](./14-maps-location.md)** — Station GPS coordinates render as pins on the bundled offline map with no online routing or geocoding.
