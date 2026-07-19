# 🔧 Modifications & Build Log

> The pain of a project or modified car whose history lives in scattered receipts, forum threads, and a mental list of "what's stock" — leaving you unable to prove value, plan the next step, or hand over the right parts at sale.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Expenses & Cost of Ownership](./05-expenses-cost-ownership.md) · [Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md) · [Components, Batteries, Keys & Consumables](./16-components-consumables.md)

## The pain

Enthusiasts, project-car owners, and kit/restoration builders pour money and years into their vehicles, but mainstream car apps treat every car as a bone-stock commuter. There's nowhere to record that you swapped the turbo, dropped the ride height, retained the OEM exhaust in a box in the garage, or gained 62 hp on the dyno — so the story of the build lives in receipts, camera rolls, and memory. When it's time to insure an agreed value, plan the next round of parts, prove what a mod cost, or sell to someone who needs to know exactly what's fitted and what's reversible, that missing structure becomes real, expensive pain. This module gives modifications the same first-class treatment fuel and service get: dated, costed, photographed, and rolled straight into the vehicle's true cost and value.

## What it does

The Modifications & Build Log turns every part you fit into a structured record — category, brand, part number, install date, odometer, and a clean parts-versus-labour cost split — and stitches those records into a chronological build timeline per vehicle, complete with photos, receipts, and before/after notes. It captures the things enthusiasts actually argue about: power and torque before and after, dyno baseline versus after-figures, ride height and wheel/tire changes, whether a mod is reversible, and where the stock part now lives.

Because every mod carries a cost, the module feeds the app's Total-Cost-of-Ownership engine and value estimate, so your build is never invisible in the money picture. It also connects to warranty compliance (flagging mods that may void coverage or fail inspection), to the Components module (for stock parts you've pulled and stored), and to a shareable PDF build-log you can hand to a buyer, an insurer, or the show-and-tell crowd. Like everything in Car and Pain, it works fully offline, with no account, and stores its data canonically so switching units, currency, calendar, or language never rewrites your history.

## Features

### ✅ Must-have

- **Modification entry** — Log each mod as a discrete record: part or category, brand, install date, odometer at install, and cost. This is the atomic unit the whole module is built on, and none of it is mandatory beyond a name so you can capture a mod even when you don't yet know the price or the reading.
- **Per-vehicle build-log timeline** — Every mod appears on a chronological timeline for the vehicle, with photos, so the full story of the build reads top to bottom instead of living across a dozen receipts and forum posts.
- **Mod cost rolled into TCO and value** — Each mod's cost flows into the vehicle's true Total-Cost-of-Ownership figure and into its current-value estimate, so the money you've put into the car is finally counted rather than forgotten.
- **Before/after notes per modification** — A plain-language before-and-after field on every mod records what changed and how it feels or performs, capturing the context that raw numbers miss.
- **Attach photos, receipts & instructions per mod** — Pin install photos, purchase receipts, and fitment instructions or PDFs directly to each mod, so proof of what was fitted (and what it cost) travels with the record.

### 🔵 Should-have

- **Mod categories** — Organize mods into meaningful buckets: engine/tune, suspension, wheels, brakes, exhaust, aero, interior, electronics, and cosmetic — making the build filterable and the timeline scannable by system.
- **Before/after spec capture** — Record structured specs on both sides of a mod: power, torque, weight, ride height, and wheel/tire setup, so you can see exactly what each change moved.
- **Dyno / power figures log** — Keep a dedicated dyno record with baseline versus after horsepower and torque and the run date, giving you a defensible, timestamped record of measured gains rather than claimed ones.
- **Reversibility flag & stock-part retention note** — Mark each mod as reversible or not and note whether the original stock part was retained and where it's stored — the information that decides what goes back on for sale, inspection, or warranty.
- **Install type & labour/parts split** — Flag whether a mod was DIY or shop-fitted and split its cost into labour versus parts, so both your spend analysis and your resale story reflect where the money actually went.
- **Warranty / void-warranty note per mod** — Attach a warranty-impact note to any mod and link it to the warranty-compliance workflow, so a coverage-voiding change is flagged before it becomes a denied claim.
- **Project-car parts wishlist / planned-vs-done** — Track intended future parts alongside completed ones with a planned-versus-done status, turning the module into a build planner, not just a history book.
- **Total build cost roll-up & cost-vs-value note** — See the summed cost of the whole build in one figure, alongside a note comparing what you've spent to what it adds to value — the reality check every project car needs.

### ⚪ Nice-to-have

- **Restoration / kit-car stage tracking** — Track a build through named stages — chassis, body, paint, mechanical, and registration — so a ground-up restoration or kit build shows progress by phase, not just by individual parts.
- **Stored stock-parts inventory** — Cross-link retained OEM parts into the Components module, giving pulled stock parts a real inventory with locations rather than a note buried in a mod record.
- **Group builds by project or theme** — Cluster mods under a named project or theme (e.g. "Stage 2 turbo", "track setup", "resto-mod"), so related work reads as one coherent build.
- **Export build-log as a shareable PDF** — Generate a clean, photo-rich PDF of the build for show-and-tell or to hand a prospective buyer, packaging years of work into one document.
- **Legality / inspection-impact flag** — Flag mods that affect legality or inspection outcomes — emissions, ride height, lighting — so you know before test day what might not pass.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `mod_id` | uuid | Stable unique identifier for the modification record. |
| `vehicle_id` | ref | Links the mod to a vehicle in the garage (kit/replica identity comes from the Vehicles module, VIN optional). |
| `category` | enum | Engine/tune, suspension, wheels, brakes, exhaust, aero, interior, electronics, cosmetic (user-extendable). |
| `name` | text | Part or mod name; kept LTR even inside RTL layouts. |
| `brand` | text | Manufacturer/brand; kept LTR inside RTL. |
| `part_number` | text | Manufacturer part number; bidi-isolated so it never reorders. |
| `install_date` | date | Stored canonically (UTC/ISO-8601); displayed per the user's calendar. |
| `install_odometer` | number+unit | Odometer at install; optional for not-yet-running project cars. |
| `cost` | number+currency | Total mod cost; stored in base currency, shown in display currency. |
| `currency` | enum | Currency the cost was entered in, for correct historical conversion. |
| `diy_flag` | bool | True for DIY install, false for shop-fitted. |
| `labour_cost` | number+currency | Labour portion of the spend (0 for pure DIY). |
| `parts_cost` | number+currency | Parts portion of the spend. |
| `before_specs{}` | object | Structured pre-mod specs (power, torque, weight, ride height, wheel/tire). |
| `after_specs{}` | object | Structured post-mod specs, same shape as before. |
| `dyno{}` | object | `baseline_hp`, `after_hp`, `baseline_tq`, `after_tq`, `date`. |
| `reversible` | bool | Whether the mod can be reverted to stock. |
| `stock_part_stored` | bool | Whether the displaced OEM part was retained. |
| `stock_part_location` | text | Where the retained stock part is stored. |
| `warranty_impact` | enum | None / may-void / voids; links to warranty compliance. |
| `status` | enum | Planned vs done (and, for restorations, the current build stage). |
| `photos[]` | array attachment | Install and progress photos. |
| `receipts[]` | array attachment | Purchase receipts and invoices. |
| `notes` | text | Free-text enthusiast notes (UGC preserved across languages). |
| `tags[]` | array | User-defined tags for grouping by project/theme. |

## Calculations & formulas

- **Total build cost** — `total_build_cost = Σ (parts_cost + labour_cost)` across all mods on the vehicle.
- **Power gain** — `power_gain = after_hp − baseline_hp`, with `torque_gain = after_tq − baseline_tq` computed the same way from dyno figures.
- **Cost per horsepower** — `cost_per_hp = mod_cost / power_gain`, a quick value metric for a power-focused mod (undefined and suppressed when `power_gain` is zero or negative).
- **Contribution to TCO & value** — each mod's cost is added into the vehicle's Total-Cost-of-Ownership total and into its current-value estimate, so the build is reflected in both spend and worth.

## Offline & data

Every part of this module works with zero connectivity and no account. You can log a mod, split parts and labour, attach photos and receipts, record dyno figures, and generate a build-log PDF in airplane mode — nothing here depends on a server, and mod costs feed the on-device TCO engine locally. Odometer readings write to the shared per-vehicle odometer ledger and are validated against regression and rollover like any other reading.

All mod records, their structured before/after and dyno specs, warranty/legality flags, and every attached photo, receipt, and instruction file are captured in the single-file full backup and re-linked on restore, and are also emitted to per-entity CSV and combined JSON export. Deleting a mod goes through user-facing trash/undo, so a mis-tap never loses years of build history, and the whole module round-trips cleanly across devices and operating systems.

## Localization & RTL

Mod names, brand names, and part numbers stay left-to-right even inside right-to-left (Persian, Arabic, Sorani Kurdish) layouts, bidi-isolated so identifiers never reorder or corrupt. Power units (hp / kW / PS), torque units (Nm / lb-ft), and pressure units are localizable and stored canonically, so a user can switch between them without altering the recorded figures. Install and dyno dates render in the user's chosen calendar (Gregorian, Jalali/Shamsi, or Hijri) from the canonical UTC date, and costs display in the preferred currency with localized numerals (Western, Eastern-Arabic, or Persian). Enthusiast free-text notes are treated as user-generated content and preserved verbatim across every language switch.

## Edge cases

- **Mods can raise or lower resale value** — the module never assumes a direction; value impact is captured through the user's own cost-vs-value note, not auto-inferred.
- **Reversible mods with stored stock parts** — a reversible mod plus a retained OEM part affects the handover/sale bundle, so the sell/dispose flow can surface exactly what should be reinstalled or included.
- **Warranty-voiding or inspection-failing mods** — these are flagged on the record and linked to warranty compliance, so the risk is visible before a claim is denied or a test is failed.
- **Project car not yet running** — with no odometer available, a mod can be logged with date only and distance left optional, so a not-yet-mobile build is still fully trackable.
- **Kit or replica without a standard VIN** — vehicle identity comes as free text from the Vehicles module, so a one-off, kit, or replica build is a first-class garage citizen.

## Related features

- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — receives every mod's cost so the build is counted in true TCO and value, not left invisible.
- **[Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)** — consumes per-mod warranty-impact flags and supports agreed-value evidence for a modified car.
- **[Components, Batteries, Keys & Consumables](./16-components-consumables.md)** — holds the retained stock parts you pull during a build as a real, located inventory.
- **[Vehicles, Garage & Odometer](./01-vehicles-garage.md)** — supplies the vehicle identity (including free-text identity for kit/replica builds) and the shared odometer ledger install readings write to.
- **[Sell, Dispose & Ownership Transfer](./24-sell-dispose.md)** — uses reversibility and stored-part data to assemble an accurate handover bundle and the shareable build-log PDF.
- **[Dashboard, Statistics & Reports](./17-dashboard-statistics-reports.md)** — surfaces total build cost, power gains, and cost-per-hp alongside the rest of the vehicle's numbers.
