# 🛞 Tires, Wheels & Seasonal

> No more guessing which winter set is which, whether the DOT date makes them unsafe, or how many kilometers your summers really have left — every set, position, and reading is tracked.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Service & Maintenance](./03-service-maintenance.md) · [Reminders & Notifications](./04-reminders-notifications.md) · [Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)

## The pain

Most car apps treat tires as an afterthought — a single "tire" line item, if that. But real ownership means two, three, or four sets of tires that swap with the seasons, each accruing its own mileage, each with its own tread wearing unevenly across positions, its own DOT age quietly ticking toward the 6–10 year safety limit, and its own storage location you forget by October. Owners lose track of which set is mounted, whether the winters are still legal, when rotation and alignment were last done, and what a set actually costs per kilometer. When the tread is uneven or the TPMS light won't clear after a rotation, there's nothing on hand to explain why. This module makes tires a first-class citizen — the gap competitors leave wide open.

## What it does

Car and Pain models tires as **switchable sets** attached to your vehicle: a summer set, a winter set, an all-season, a track set, an off-road set, a spare — each a named unit you can mount or dismount. When you record a seasonal changeover, the app reads the swap odometer and automatically accrues mileage to the set coming off, so every set carries an honest lifetime distance without you ever doing the math. Below the set sits per-position tracking (front-left, front-right, rear-left, rear-right, spare, and dual/6-wheel configurations), with tread history that follows each individual tire as it rotates around the vehicle.

On top of that foundation the module layers the full safety and cost picture: multi-point tread readings with wear projection, per-position pressure against front/rear recommendations, TPMS sensor IDs and relearn events, DOT-age expiry warnings, alignment and balancing logs, damage and repair records, storage location, wheel/rim specs, and cost-per-1000 km comparison across sets. Everything is stored canonically (SI distance, ISO dates, base currency) and converted for display, so switching between psi/bar/kPa, mm/32nds, or calendars never rewrites your history. It all works fully offline, with no account.

## Features

### ✅ Must-have

- **Tire set manager** — Create and manage multiple named sets (summer, winter, all-season, track, off-road, spare) as switchable units, mounting one set and dismounting another so the garage always reflects what is actually on the car.
- **Seasonal changeover log with automatic accrual** — Record each swap once; the app reads the swap odometer and automatically adds the distance traveled to the set being removed, giving every set an accurate lifetime mileage without manual bookkeeping.
- **Tire rotation tracking** — Log the rotation pattern used and compute the next rotation due by both distance and elapsed time, so you never over-run a rotation interval.
- **Per-position tire tracking** — Track each tire by position (FL/FR/RL/RR, spare, and dual/6-wheel layouts), with each tire's history following it as it moves around the vehicle rather than staying fixed to a corner.
- **Multi-point tread depth log with wear projection** — Record tread at outer, center, and inner points per tire and project remaining life and a replacement odometer from the measured wear rate.
- **Tire pressure log** — Capture measured pressure per position and compare it against the vehicle's recommended front and rear pressures.
- **TPMS sensor tracking** — Store sensor IDs, monitor sensor battery health, set thresholds, and record relearn events (needed when direct-TPMS positions change after a rotation or swap).
- **Tire age / DOT-expiry reminder** — Parse the DOT manufacture code and warn as the set approaches the 6–10 year age-safety limit, even if tread still looks fine.
- **Tire specifications** — Store size, load and speed index, seasonal marking (M+S / 3PMSF), DOT code, and flags for run-flat, XL/reinforced, plus max load and pressure ratings.
- **Pressure unit selection** — Choose psi, bar, or kPa; values are stored canonically and shown in your preferred unit.
- **Tread-depth unit selection** — Choose millimeters or 1/32 inch, with conversion that does not drift on rounding.
- **Wheel alignment & balancing log** — Record the last alignment/balancing by date and odometer, the next-due target, any symptoms (pulling, vibration), the type, and the cost.

### 🔵 Should-have

- **Damage / puncture / repair log** — Record punctures, sidewall damage, and repairs per position, so a repaired tire's history is visible when deciding whether it is safe to keep.
- **Purchase cost & warranty feeding compliance** — Store each set's purchase price and its mileage/time warranty, which flows into the warranty-compliance workflow so you can prove and claim tire warranties.
- **Storage location** — Note where the off-season set lives (home, garage, tire hotel), the provider, and the storage cost — so retrieval in spring is not a scavenger hunt.
- **Wheel/rim tracking** — Track rims separately (steel or alloy, size, offset, width, bolt pattern), since wheels and tires have independent lifecycles.
- **Seasonal readiness checklist & prompts** — A checklist and prompts to prepare for changeover season, so nothing (inspection, storage, TPMS relearn) is missed.
- **Recommended-pressure reference** — Keep recommended pressures per axle and per load condition (e.g. laden vs unladen), so the target you compare against is always correct.
- **Cost-per-1000 km per set and cross-set comparison** — Compute and compare the running cost of each set, revealing which brand or type actually earns its keep.

### ⚪ Nice-to-have

- **Weather-based changeover suggestion** — An offline "7°C rule" hint using manually entered or historical temperatures only — it never claims a live forecast.
- **Puncture-repair-vs-replace guidance** — Guidance drawn from current tread depth and tire age on whether a puncture is worth repairing or the tire should be replaced.
- **Wheel-lock/key location note** — A note recording where the wheel-lock key lives, so it is on hand when the wheels have to come off.
- **Set photo gallery** — A per-set photo gallery to visually document tread wear over time.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `tire_set_id` | uuid | Identifier for a tire set. |
| `vehicle_id` | ref | The vehicle the set belongs to. |
| `set_name` | text | User-given name (e.g. "Winter Michelins"). |
| `season` | enum | summer / winter / all-season / track / off-road / spare. |
| `is_mounted` | bool | Whether this set is currently on the vehicle. |
| `tire_count` | number | Tires in the set (2/4/6, spare optional). |
| `set_price` | number+currency | Purchase price of the set, in base currency. |
| `brand` | text | Manufacturer. |
| `model` | text | Tire model/line. |
| `size` | text | e.g. `205/55 R16` — kept LTR under RTL. |
| `load_speed_index` | text | Load index + speed rating (e.g. `91V`). |
| `season_marking` | enum | M+S / 3PMSF / none. |
| `run_flat` | bool | Run-flat construction flag. |
| `dot_date_code` | text | DOT WWYY manufacture code, parsed for age. |
| `install_odometer` | number+unit | Odometer when the set was mounted. |
| `remove_odometer` | number+unit | Odometer when the set was dismounted. |
| `accrued_mileage` | number+unit | Lifetime distance accrued to the set. |
| `storage_location` | text | Where the set is stored when off the car. |
| `tire_id` | uuid | Identifier for an individual tire. |
| `position` | enum | FL / FR / RL / RR / spare / dual positions. |
| `position_history[]` | array | Ordered record of positions this tire has held. |
| `serial_dot` | text | Per-tire serial / DOT identifier. |
| `tread_outer` | number+unit | Tread at the outer point (mm or 1/32in). |
| `tread_center` | number+unit | Tread at the center point. |
| `tread_inner` | number+unit | Tread at the inner point. |
| `measurement_odometer` | number+unit | Odometer at the tread/pressure reading. |
| `pressure_unit` | enum | psi / bar / kPa display preference. |
| `measured_pressure` | number+unit | Measured pressure for the position. |
| `recommended_front` | number+unit | Recommended front-axle pressure. |
| `recommended_rear` | number+unit | Recommended rear-axle pressure. |
| `tpms_sensor_id` | text | TPMS sensor identifier. |
| `sensor_battery_health` | enum/number | Health/estimate of the sensor battery. |
| `relearn_date` | date | Date of the last TPMS relearn event. |
| `alignment_log[]` | array | Entries of `{date, odometer, type, cost}`. |
| `balancing_log[]` | array | Balancing events (date, odometer, cost). |
| `warranty_mileage` | number+unit | Mileage limit of the tire warranty. |
| `warranty_expiry` | date | Expiry date of the tire warranty. |
| `damage_incidents[]` | array | Punctures, damage, and repairs per position. |
| `rim` | object | `{material, size, width, offset, bolt_pattern}`. |

## Calculations & formulas

- **Per-set accrued mileage** — On each swap, add `odometer_at_change − set_install_odometer` to the set being dismounted. Accrual is always recomputed from the odometer-at-change, never from wall-clock time, so a late or out-of-order swap date self-corrects.
- **Cost per 1000 km** — `cost_per_1000km = set_price / (accrued_mileage / 1000)`.
- **Wear rate and projected replacement** — `wear_rate_per_1000 = (tread_prev − tread_now) / (distance / 1000)`, then `projected_replacement_odometer = current_odo + (tread_now − legal_min) / wear_rate × 1000`.
- **DOT age** — `DOT age = now − manufacture_date(WWYY)`, with an expiry warning fired at the configured threshold years.
- **Unit conversions** — Pressure converts between `psi/bar/kPa`; tread converts between `mm` and `1/32in`, guarding against rounding drift.
- **Next-due targets** — `next_rotation_due = odometer + interval` and `next_alignment_due = odometer + interval`.
- **Uneven-wear flag** — Raise a flag when `|tread_outer − tread_inner|` exceeds the threshold, signaling a likely alignment or inflation problem.

## Reminders & notifications

This module feeds the shared [local notification engine](./04-reminders-notifications.md), which fires reliable on-device alerts that survive reboot, Doze, and app-kill:

- **DOT-age / expiry** — Time-based warning as a set approaches the 6–10 year age limit, with lead-time early warning (e.g. "expires this year") so you can plan a purchase before the set is unsafe.
- **Rotation due** — Whichever-comes-first of a distance target (projected from average daily distance) or an elapsed-time interval, with early warning ahead of the due point (e.g. "1000 km before").
- **Alignment / balancing due** — Distance- or date-based next-due reminders, plus symptom-triggered nudges.
- **Seasonal changeover** — Readiness prompts as the season turns, optionally informed by the offline 7°C temperature hint (manual/historical temperatures only).
- **Low tread / projected replacement** — When wear projection estimates the legal minimum is near, a distance-based heads-up before you run out of tread.
- **TPMS relearn** — A prompt to record a relearn after a rotation or swap changes direct-TPMS positions.

All notifications name the vehicle and the specific set, and re-arm automatically after a backup/restore.

## Offline & data

Every tire, set, reading, and log is stored locally and works with zero connectivity — no account, no sync, no cloud. Accrual, wear projection, cost-per-1000 km, DOT parsing, and unit conversion all run on-device. The only feature touching the outside world, the weather-based changeover hint, uses manual or historical temperatures and never claims a live forecast.

For export and backup, the module participates in the app's full [data ownership pipeline](./18-data-offline-backup.md): every set, per-tire history, tread/pressure reading, alignment/balancing log, TPMS record, warranty, damage incident, and rim spec is included in the single-file backup (with any set photos re-linked), in per-entity CSV, and in the combined JSON. Restore is merge-aware and non-destructive, reminders restore with live state, and nothing is orphaned when you migrate devices.

## Localization & RTL

Per the module's i18n notes, tire data is fully localized while keeping technical values unambiguous:

- **Units** — Pressure displays in psi, bar, or kPa and tread in mm or 1/32 inch per your preference; canonical storage means switching units never corrupts stored readings.
- **Calendars** — Purchase, DOT, and changeover dates render in Gregorian, Jalali/Shamsi, Hijri, or Hebrew, converted from the canonical UTC/ISO date.
- **Numerals & currency** — Localized numerals (Western/Eastern-Arabic/Persian) with correct grouping; set cost shown in the vehicle/display currency.
- **RTL layout** — In right-to-left languages the wheel/tire diagram mirrors, but FL/FR (left/right) position labels and numeric values stay correct via bidi handling, so a mirrored layout never mislabels a corner.
- **Technical strings** — Tire size, load/speed index, and DOT codes stay LTR-isolated even inside RTL text. Alignment and balancing terminology is translated across all launch languages.

See [Localization, RTL & Calendars](./19-localization-rtl.md) and [Accessibility & Inclusive Design](./20-accessibility.md) for the shared infrastructure.

## Edge cases

- **Variable tire count** — Vehicles have 2, 4, or 6 wheels with an optional spare; the position model and diagrams adapt to the axle/wheel configuration.
- **Space-saver / temporary spares** — Excluded from rotation patterns and from wear projection, since they are not part of normal rotation.
- **Direct TPMS relearn** — When positions change after a rotation or swap, direct TPMS needs a relearn; the app prompts you to record it.
- **Late or out-of-order swaps** — Seasonal set mileage recomputes correctly if a swap date is entered late or out of sequence, because accrual is odometer-based.
- **Uneven multi-point wear** — Differences between outer/center/inner readings surface alignment or inflation issues via the uneven-wear flag.
- **Conversion drift** — mm ↔ 32nds conversion must not drift on rounding.
- **Cold vs warm pressure** — Ambient temperature and cold-vs-warm state affect pressure readings and are accounted for in interpretation.
- **Storage retrieval** — The off-season set's storage location is recorded so it can be found again.
- **RTL wheel diagram** — The diagram mirrors under RTL while FL/FR labels stay correct.
- **DOT WWYY parsing** — The DOT week/year code is parsed for age and expiry calculations.
- **Offline weather** — The weather-based changeover suggestion uses manual/historical temperatures only and never claims a live forecast.

## Related features

- **[Service & Maintenance](./03-service-maintenance.md)** — Rotation, alignment, balancing, and tire fitting are service events; costs and intervals interlock with the maintenance schedule.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — Consumes tire triggers (DOT age, rotation, alignment, seasonal, low tread) through the shared offline scheduler.
- **[Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)** — Tire purchase cost and mileage/time warranty feed the warranty-compliance workflow and claims.
- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — Set prices, storage, and alignment costs roll into total cost of ownership and cost-per-km analysis.
- **[Vehicles, Garage & Odometer](./01-vehicles-garage.md)** — The shared odometer ledger drives swap accrual, wear projection, and next-due distance targets.
- **[Components, Batteries, Keys & Consumables](./16-components-consumables.md)** — Companion module for other tracked hardware (wheel-lock keys, wear items) alongside tires and wheels.
