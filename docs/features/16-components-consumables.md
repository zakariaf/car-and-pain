# 🔋 Components, Batteries, Keys & Consumables

> The pain of a dead 12V battery on a cold morning, a lost key you can't afford to re-code, and a glovebox spare-parts stash nobody can find — all the discrete bits that outlive a single service visit but never get their own home.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Service & Maintenance](./03-service-maintenance.md) · [Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md) · [Reminders & Notifications](./04-reminders-notifications.md)

## The pain

Most car apps stop at fuel and service, so the parts that quietly age between visits fall through the cracks. Your 12V starter battery has no service interval — it just dies, usually in winter, usually in a hurry — and nobody wrote down when it was installed or what group size fits. Keys and fobs are a silent liability: you don't know how many exist, where the spare lives, or that a fob's coin cell is about to strand you, and a lost key can cost hundreds to re-code. Meanwhile fluids, bulbs, fuses, wiper blades, and spare parts pile up in the garage with no inventory, so you re-buy things you already own and run out of the ones you need. This module gives every one of those discrete, long-lived items a record, a reminder, and a warranty — distinct from the EV traction battery, which has its own health model.

## What it does

The components tier is a lightweight parts-and-consumables ledger scoped to each vehicle in your garage. It tracks physical items with a lifecycle: the 12V starter battery (with a voltage/health log and a projected replacement date), keys and fobs (with fob-battery reminders and a private spare-key location), wear items counted down by odometer, and a stock inventory of fluids, bulbs, fuses, wipers, and spare parts with low-stock flags. Each item can carry its own warranty (date plus mileage), its own reminders, and a cost that rolls into the vehicle's service total and Total-Cost-of-Ownership.

Everything is stored canonically — SI units, UTC/ISO dates, base currency — and converted only for display, so switching your voltage units, currency, calendar, or language never rewrites the history of a battery you logged three years ago. Like every module, it works fully offline with no account, and every record round-trips through the single-file backup with its attachments intact.

## Features

### ✅ Must-have

- **12V starter-battery record** — Log the battery's install date and install odometer, its brand and group/case size, its warranty terms, and a replacement reminder, so the one part with no factory service interval finally has a paper trail and a heads-up before it fails.
- **12V health/voltage log with replacement projection** — Record resting/cranking voltage readings over time; the app trends the decline and projects a likely replacement window, turning "it just died" into an early warning you can act on.
- **Vehicle key/fob inventory** — Record how many keys and fobs exist for the vehicle and where the spare is kept, so you always know your true key count (critical for resale, insurance, and knowing when one has gone missing).
- **Key-fob battery replacement tracking** — Track each fob's coin-cell type and last-change date with a reminder, so a weakening fob battery never leaves you locked out or unable to start.
- **Wear-item lifecycle tracking** — Capture an item's install odometer and expected life (distance and/or time) and see a live remaining-percentage that counts down as you drive, for the parts that wear gradually rather than fail on a schedule.

### 🔵 Should-have

- **Spare-parts stock inventory** — Keep an inventory of spare parts linked to specific vehicles, each with part number, quantity, and storage location, so you stop re-buying things you already own and can find them when you need them.
- **Consumables/fluids inventory** — Track fluids and consumables — engine oil, coolant, brake fluid, washer fluid, AdBlue/DEF — with a low-stock note so you top up before you run dry, not after the warning light.
- **Component warranty (date + mileage)** — Attach a warranty with both a date limit and a mileage limit to any component; these feed the [Warranty Compliance](./09-insurance-claims-warranty.md) dashboard so a still-covered part gets claimed, not replaced out of pocket.
- **Lost-key / re-code record** — Log a lost-key event and the subsequent re-code, keeping a clear history for insurance, security, and resale (a re-code invalidates old keys, and buyers ask).
- **Bulb / wiper / fuse reference and replacement log** — A quick reference of the vehicle's factory bulb, wiper, and fuse specs plus a log of what you replaced and when, so the right size and fitment are one tap away in a dark car park.
- **Component cost rolled into service/TCO** — Every component and consumable cost flows into the vehicle's service total and the [Expenses & Cost of Ownership](./05-expenses-cost-ownership.md) engine, so parts you buy and fit yourself still count toward true cost of ownership.

### ⚪ Nice-to-have

- **Stored stock-parts unified view** — Surface parts you removed and kept (logged from the [Modifications & Build Log](./12-modifications-build-log.md), e.g. original wheels or an OEM exhaust) alongside spares, for one complete picture of everything you own for the car.
- **Major-component life clock** — Track long-life components — timing belt or chain, clutch, water pump — with their own life clock in distance and time, so the expensive scheduled-but-distant jobs don't sneak up on you.
- **Component replacement history timeline** — A per-vehicle timeline of what was replaced and when, so you can see at a glance the battery's third life or the second set of wipers this year.
- **Warranty / return tracking for purchased parts** — Track purchase-and-return windows and manufacturer warranties for parts you bought, so a faulty component goes back before the return window closes.
- **Emergency kit inventory & expiry** — Inventory the emergency/roadside kit (first-aid items, flares, warning triangle, extinguisher) with expiry dates, linked to [Safety, Incidents & Roadside](./22-safety-incidents-roadside.md), so legally required and life-safety items are current when you need them.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `component_id` | uuid | Stable primary key; survives edits, export, and merge-aware restore. |
| `vehicle_id` | ref | Links the component to a vehicle in the garage; scopes all views and reminders. |
| `type` | enum | Battery-12V, key/fob, wear item, fluid/consumable, spare part, bulb/fuse/wiper, emergency-kit item. |
| `name` | text | User-facing name; localized, with UGC preserved for custom entries. |
| `brand` | text | Manufacturer/brand of the part or consumable. |
| `group_size` | text | Battery group/case-size code (e.g. BCI/EN); kept LTR inside RTL layouts. |
| `part_number` | text | Manufacturer part number; kept LTR inside RTL. |
| `install_date` | date | Stored UTC/ISO-8601; displayed in the user's chosen calendar. |
| `install_odometer` | number+unit | Reading at install, from the shared odometer ledger; canonical SI. |
| `expected_life_distance` | number+unit | Expected service life in distance; drives remaining-% for wear items. |
| `expected_life_time` | number (duration) | Expected service life in time; used as fallback when distance is unknown. |
| `warranty_date` | date | Warranty expiry by date. |
| `warranty_mileage` | number+unit | Warranty expiry by mileage; whichever-first with `warranty_date`. |
| `health_log[]` | array | Entries of `{date, value, note}` for general component health readings. |
| `voltage_log[]` | array | 12V voltage readings over time; feeds the replacement projection. |
| `quantity` | number | On-hand count for stock parts and consumables. |
| `location` | text | Storage location (garage shelf, boot, spare-key hiding spot). |
| `key_count` | number | Number of keys/fobs held for the vehicle. |
| `fob_battery_type` | text | Coin-cell type for the fob (e.g. CR2032); kept LTR. |
| `last_fob_battery_change` | date | Last fob-battery change; drives the fob-battery reminder. |
| `cost` | number+currency | Purchase/replacement cost; rolls into service and TCO. |
| `currency` | enum | Currency the cost was entered in; converted to base for display. |
| `status` | enum | Active, in-stock, installed, expired, replaced, lost, returned. |
| `notes` | text | Free-form notes; localized, UGC preserved. |

## Calculations & formulas

- **Remaining wear-item life** — `remaining_life_pct = 1 − (used_distance / expected_life_distance)`, where `used_distance = current_odometer − install_odometer` from the shared ledger; falls back to a time-based estimate when install distance is unknown.
- **12V replacement projection** — Projects a likely replacement window from battery `age` combined with the voltage-decline trend across `voltage_log[]`, so ageing and measured weakness together set the warning date.
- **Next fob-battery / wear-item due** — `next_due = install_or_last_change + interval`, expressed in date and/or distance so the soonest trigger wins.
- **Low-stock flag** — Raised when `quantity < threshold` for a consumable or spare part.
- **Component contribution to cost** — Each component `cost` is summed into the vehicle's service cost and the on-device TCO engine, so DIY-fitted parts count toward true cost of ownership.

## Reminders & notifications

This module produces reminders through the shared offline [local notification engine](./04-reminders-notifications.md), which fires reliable local notifications that survive reboot, Doze, and app-kill. It generates:

- **12V battery replacement** — Age-based by default (a battery has no mileage interval), escalated when the voltage trend projects an early failure; an early warning (e.g. before winter, or a set lead-time before the projected date) gives you time to buy on your terms rather than at a breakdown.
- **Key-fob battery** — Date-based from `last_fob_battery_change` plus its interval, with a lead-time nudge before the cell is likely to weaken.
- **Wear-item end-of-life** — Dual-trigger on date and/or distance, whichever comes first, using the shared odometer projection to warn ahead of the threshold (e.g. 1,000 km or one week before remaining life reaches zero).
- **Component warranty expiry** — Fires before a warranty lapses by date or mileage (whichever-first), so a covered part is claimed while it still can be.
- **Low-stock / consumable** — Optional nudge when a fluid or spare part drops below its threshold.
- **Emergency-kit expiry** — Optional reminders before first-aid, flare, or extinguisher items expire.

Notifications always name the vehicle, respect quiet hours and per-severity channels, and re-arm automatically after a backup restore or device migration.

## Offline & data

Every part of this module works with zero connectivity and no account. Logging a battery voltage reading, adding a fob, decrementing a consumable during a DIY service, or setting a warranty all happen entirely on-device; there is no lookup that requires the network. Optional part-number or spec references come from bundled data, never a live call.

All component records — including `health_log[]`, `voltage_log[]`, warranties, reminder state, and any attached photos or receipts — are included in the single-file full backup, in per-entity CSV, and in the combined JSON export, with checksums and schema versioning. Restore is merge-aware and non-destructive, deletions pass through user-facing trash/undo, and attachments are bundled and re-linked so a battery photo or a parts receipt round-trips across devices and operating systems. Because values are stored canonically, exporting and re-importing never drifts a voltage, a distance, or a cost. Self-hosted (WebDAV/Nextcloud/SFTP/SD-card) and strictly opt-in cloud targets are available, but nothing here is ever gated behind them.

## Localization & RTL

From `i18n_notes`: part numbers and battery group codes are treated as identifiers and stay left-to-right even inside a right-to-left (Persian, Arabic, Sorani Kurdish) layout, bidi-isolated so surrounding text mirrors correctly without scrambling the code. Voltage values and their units, dates in any of the supported calendars (Gregorian, Jalali/Shamsi, Hijri, Hebrew), and costs are all localized — including Eastern-Arabic/Persian numerals and per-preference units and currency. Component and consumable names are fully translatable, and user-entered custom names (UGC) are preserved verbatim and remain searchable across languages. Reminder text is fully localized, and the entire screen — labels, tables, timelines, and charts — mirrors under RTL through the shared logical-property rendering layer. See [Localization, RTL & Calendars](./19-localization-rtl.md) for the underlying model.

## Edge cases

- **12V vs. EV traction battery** — The 12V starter battery is a distinct entity with its own age/voltage health model and is never conflated with the EV traction battery, whose State-of-Health lives in the energy module.
- **Climate-sensitive battery health** — Because battery life varies sharply with climate, the default is an age-based reminder, with the voltage log as an optional refinement rather than a requirement.
- **Lost key re-code** — Losing a key creates a re-code event that updates the key count and history; the spare-key location can optionally be hidden behind the app lock for security.
- **Unknown install date** — A wear item logged without a known install date falls back to a time-based life estimate instead of blocking the entry.
- **Consumable used in DIY service** — Recording a DIY service that uses a consumable decrements that item's inventory automatically, keeping stock counts honest.
- **Part warranty whichever-first** — A component warranty with both a date and a mileage limit expires on whichever comes first, consistent with every other warranty in the app.

## Related features

- **[Service & Maintenance](./03-service-maintenance.md)** — DIY services consume parts and fluids from this inventory and log fitted components, and component costs roll into the service record.
- **[Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)** — Component warranties (date + mileage) feed the red/amber/green warranty-compliance dashboard so covered parts get claimed.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — The shared offline scheduler delivers all battery, fob, wear-item, warranty, and low-stock reminders reliably.
- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — Every component and consumable cost flows into the true on-device TCO engine.
- **[Modifications & Build Log](./12-modifications-build-log.md)** — Original parts you remove and keep appear in the unified stored-stock view alongside spares.
- **[Safety, Incidents & Roadside](./22-safety-incidents-roadside.md)** — The emergency-kit inventory and expiry reminders link into the safety and roadside tooling.
