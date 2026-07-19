# 🚕 Rideshare, Gig & Rental Economics

> Stop guessing whether a shift, a delivery run, or a Turo booking actually made money after the platform's cut, the fuel, and the wear it burned — see real per-mile profit instead of a payout screen that lies by omission.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Trips & Mileage Logbook](./06-trips-mileage.md) · [Expenses & Cost of Ownership](./05-expenses-cost-ownership.md) · [Fleet, Business & Company-Car](./10-fleet-business.md)

## The pain

Rideshare, delivery, and peer-to-peer rental drivers are the most underserved car-owner segment on the market: their platforms show a headline payout but hide the true cost of earning it. The gross number on the Uber, Lyft, Bolt, or delivery screen ignores the platform's commission, the fuel burned on dead miles between fares, the accelerated wear that high-mileage use inflicts, and the depreciation that quietly eats every revenue mile. A Turo or peer-to-peer host has the mirror problem — a booking looks profitable until a renter returns the car dirty, low on fuel, and with a scratch nobody photographed at handover. On top of that, tax season demands a defensible business-use percentage split from driving that mixes personal errands and paid trips in the same day, and no consumer car app produces it. This module removes the "am I actually earning anything?" fog with honest, offline per-shift and per-booking economics.

## What it does

Car and Pain adds a dedicated commercial-use mode that sits on top of the same canonical odometer, fuel, expense, and trip data the rest of the app already records — so gig and rental accounting is a lens over your real driving, not a separate silo you have to re-enter. You set up each income source (Uber, Lyft, Bolt, Turo, a delivery platform, or a fully custom one), log income per job, shift, or rental period with gross, platform fee, tips, and net, and link the fuel fill-ups, expenses, and trips that a session consumed. From there the app computes net profitability per shift, day, week, and month, derives the business-use percentage that feeds your tax and TCO split, and separates the revenue miles that earn from the dead miles that only cost.

For rental hosts, it adds handover checklists with pre/post condition photos, fuel/charge and odometer capture, and a booking record covering renter, dates, agreed mileage, deposit, and damage — so a return dispute becomes a documented reconciliation, and real damage flows straight into the insurance and claims workflow. Every number is stored canonically and converted only for display, works entirely offline, and drops into a tax-ready report pack that honors your calendar, numerals, currency, and RTL layout.

## Features

### ✅ Must-have

- **Platform / income-source setup.** Define each income source you drive for — Uber, Lyft, Bolt, Turo, a delivery platform, or a fully custom source you name yourself — with its own fee structure, so every earning is attributed to the right platform.
- **Income entry per job, shift, or rental period.** Record each earning event with gross income, the platform fee taken out, tips, and the resulting net, whether it represents a single job, a whole shift, or one rental booking.
- **Per-platform income vs cost summary.** See, for each platform separately, what it brought in against what it cost you to earn there — so you can tell which app is worth your time and which is barely covering fuel.
- **Business-use percentage from mixed trips.** Automatically derive the share of your driving that was paid work versus personal, computed from classified trips, giving you a defensible split for tax and cost allocation instead of a guess.
- **Net profitability per shift, day, week, and month.** Roll income up against fuel/energy and allocated running cost across each period, so the honest bottom line — income minus what it took to make it — is always visible.
- **Link fuel, expenses, and trips to a session or booking.** Attach the specific fill-ups, expenses, and trips that a gig session or rental period consumed, so each session's profit reflects its real, itemized costs rather than an average.

### 🔵 Should-have

- **Per-job and per-mile earnings with net margin.** Break earnings down to the individual job and to a cost-per-mile net margin, so you can see which jobs and which conditions actually pay.
- **Platform fee & commission tracking per payout.** Track the fee and commission taken on each payout, since these vary by platform and over time, and reconcile them against your gross.
- **Rental handover checklist.** Run a structured pre- and post-rental checklist capturing condition photos, fuel or charge level, odometer, and cleanliness at both handover and return — your evidence in any dispute.
- **Rental booking record.** Keep a full booking record for each rental: renter, start and end dates, agreed mileage, deposit held, and any damage noted.
- **Shift log.** Log each shift's start and end odometer and time, and split the distance driven into active (revenue) miles and dead miles.
- **Deadhead / idle-mile tracking vs revenue miles.** Measure the miles you drove empty or idling against the miles that earned, exposing the hidden cost that platform screens never show.
- **Tax-ready gig income & expense report.** Produce a report that packages gig income and expenses with the business-use split already applied, ready for a tax filing or an accountant.
- **Downtime and depreciation-per-revenue-mile allocation.** Allocate the wear and depreciation cost of high-mileage commercial use across the revenue miles that caused it, so profitability reflects the long-term hit, not just today's fuel.

### ⚪ Nice-to-have

- **Multi-platform aggregation for one vehicle.** Combine earnings from every platform a single vehicle serves into one consolidated view, since many drivers run several apps at once.
- **Break-even utilization.** Calculate how many revenue miles you need to cover your fixed plus variable cost — the point at which the car starts genuinely earning.
- **Surge, bonus & incentive line items.** Record surge pricing, bonuses, and platform incentives as distinct line items so they don't get lost inside a lumped gross figure.
- **Cleaning / detailing cost per rental turnover.** Track the cleaning or detailing cost incurred each time a rental turns over, and fold it into turnover economics.
- **Companion cost-split for shared gig vehicles.** Split costs and earnings between drivers who share one gig vehicle, so a co-driven car settles fairly.
- **Rental damage claim → Insurance/Claims handoff.** Promote rental damage into an incident and hand it off to the insurance and claims workflow with its handover photos attached as evidence.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `platform_id` | ref | Reference to the configured income-source / platform record. |
| `platform_name` | text | Display name (Uber, Lyft, Bolt, Turo, delivery, custom); stays LTR inside RTL layouts. |
| `session_id` | uuid | Stable identifier for the gig session or rental period. |
| `session_type` | enum | Job, shift, rental period, or other income event. |
| `start_time` | date | Session/shift start timestamp (stored UTC/ISO-8601, shown per calendar). |
| `end_time` | date | Session/shift end timestamp (stored UTC/ISO-8601, shown per calendar). |
| `start_odometer` | number + unit | Odometer at session start, from the shared canonical reading ledger. |
| `end_odometer` | number + unit | Odometer at session end, from the shared canonical reading ledger. |
| `revenue_miles` | number + unit | Distance driven while earning. |
| `dead_miles` | number + unit | Empty/idle distance that cost money but earned nothing. |
| `gross_income` | number + currency | Headline earnings before platform fee. |
| `platform_fee` | number + currency | Commission/fee the platform deducted. |
| `tips` | number + currency | Tips received, tracked separately from base fare. |
| `net_income` | number + currency | Derived earnings after fee and tips. |
| `currency` | enum | Recording currency; canonically normalized to base currency for aggregation. |
| `notes` | text | Free-text notes; UGC preserved and searchable across languages. |
| `cost_allocation` | number / ref | Allocated running-cost basis (per-mile rate or method) applied to this session. |
| **Rental sub-record** (`rental{…}`) | | |
| `rental.renter` | text | Renter name/identifier; UGC, preserved and searchable, kept LTR where needed. |
| `rental.start` / `rental.end` | date | Booking start and end (UTC/ISO canonical, per-calendar display). |
| `rental.agreed_mileage` | number + unit | Mileage allowance agreed for the booking. |
| `rental.deposit` | number + currency | Security deposit held. |
| `rental.fuel_level_out` / `rental.fuel_level_in` | number / enum | Fuel or charge level at handover and at return, for reconciliation. |
| `rental.condition_photos[]` | array of attachment | Pre/post condition photos captured at handover and return. |
| `rental.damage[]` | array | Damage items noted, each promotable to an incident/claim. |
| **Links** | | |
| `linked_fillup_ids[]` | array of ref | Fuel/energy fill-ups consumed by this session. |
| `linked_expense_ids[]` | array of ref | Expenses attributed to this session. |
| `linked_trip_ids[]` | array of ref | Trips belonging to this session, driving revenue/dead-mile classification. |

## Calculations & formulas

- **Net income per event** — `net_income = gross_income − platform_fee + tips`.
- **Session profit** — `session_profit = net_income − fuel/energy − allocated_running_cost`, where `allocated_running_cost = per_mile_rate × revenue_miles`.
- **Cost per revenue mile** — `cost_per_revenue_mile = allocated_cost / revenue_miles`, isolating what each earning mile truly costs.
- **Business-use percentage** — `business_use_pct = revenue_miles / total_miles`, feeding the tax and TCO split downstream.
- **Break-even revenue miles** — `break_even_revenue_miles = fixed_cost_period / (net_rate_per_mile − variable_cost_per_mile)`, the mileage at which the vehicle covers its costs.
- **Rental turnover cost** — `rental_turnover_cost = cleaning + fuel_difference + wear_allocation`, the full cost of readying a car for the next booking.

All inputs are read in canonical units and base currency and converted only for display, so switching units, currency, or locale never changes the computed profit.

## Reminders & notifications

This module consumes the shared [local notification engine](./04-reminders-notifications.md) for time-bound rental and shift events rather than generating a distinct trigger class of its own. Practical uses include a rental-return reminder as a booking's `rental.end` approaches (for example, a lead-time warning the day before return so the post-rental handover checklist and fuel/odometer reconciliation aren't forgotten), and deposit-return follow-ups after a return. As with every reminder in the app, these are date-triggered local notifications that survive reboot, Doze, and app-kill, always name the vehicle, respect quiet hours, and re-arm automatically after a backup restore.

## Offline & data

Everything in this module runs with zero connectivity and no account. Income entry, platform setup, shift logging, business-use derivation, profitability math, and rental handover checklists all execute fully on-device — the app never depends on a platform API to reconcile a payout, and it is honest that platform fees and multi-currency FX are entered or snapshotted manually (using dated offline rates) rather than fetched live. Because gig and rental economics are computed from your canonical odometer, fuel, expense, and trip records, the numbers stay correct even in airplane mode across a whole shift.

For portability, every gig session and rental booking — including its links to fill-ups, expenses, and trips, its live reminder state, and its handover/condition photos and damage attachments — is included in the single-file full backup, in per-entity CSV, and in the combined JSON export. Attachments are bundled and re-linked on restore so a Turo host's before/after photos round-trip across devices and operating systems, and merge-aware restore with trash/undo means nothing is orphaned when you migrate. See [Data, Offline, Backup & Portability](./18-data-offline-backup.md).

## Localization & RTL

Platform and renter names, and any free-text notes, are user-generated content that is preserved verbatim and remains searchable across languages; platform names and identifiers stay LTR even inside a right-to-left Persian, Arabic, or Sorani Kurdish layout via bidi isolation. All income, fees, tips, deposits, and derived profit render in the per-vehicle or display currency with localized numerals (Western, Eastern-Arabic, or Persian) and correct digit grouping. Dates — shift times and rental start/end — display in the user's chosen calendar (Gregorian, Jalali, or Hijri) while stored canonically in UTC/ISO-8601. Gig and rental terminology is fully localized, and the tax-ready report packs honor RTL layout mirroring, the selected calendar, and the display currency end to end. See [Localization, RTL & Calendars](./19-localization-rtl.md).

## Edge cases

- **Dead miles cost but don't earn.** Deadhead and idle miles are tracked separately from revenue miles so they reduce profit rather than inflating it, and cost-per-mile reflects reality.
- **Mixed personal and gig driving in one day.** A day that blends personal errands and paid work is split by trip classification, producing an honest business-use percentage instead of an all-or-nothing assumption.
- **Fee structures differ and change.** Platform commission models vary by platform and shift over time, so fees are configured per platform and can be updated without corrupting past records.
- **High-mileage wear and depreciation.** Intensive commercial use accelerates wear and depreciation, which is allocated per revenue mile so long-term cost is captured, not just the day's fuel.
- **Rental returned at a different fuel/charge level.** When a renter returns the car with more or less fuel or charge than delivered, the difference is reconciled into the turnover cost via `fuel_level_out`/`fuel_level_in`.
- **Rental damage becomes an incident and possible claim.** Damage recorded at return can be promoted to an incident and handed to the insurance/claims workflow with its handover photos as evidence.
- **Multi-currency payouts abroad.** Earnings paid in a foreign currency are handled with manual/dated FX so cross-border gig income aggregates correctly into the base currency without live rates.

## Related features

- **[Trips & Mileage Logbook](./06-trips-mileage.md)** — supplies the classified trips and canonical distances that drive revenue-vs-dead-mile splits and the business-use percentage.
- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — provides the running-cost and per-mile allocation basis, and the TCO/depreciation figures fed by the business-use split.
- **[Fuel & Energy](./02-fuel-energy.md)** — the fill-ups and charge sessions linked to a shift, giving each session its true energy cost.
- **[Fleet, Business & Company-Car](./10-fleet-business.md)** — shares per-driver P&L, cost-centre, and business-use concepts for drivers who straddle gig and fleet use.
- **[Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)** — receives rental damage handoffs, turning a handover photo set into a documented FNOL and claim.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — delivers the reliable, reboot-surviving rental-return and deposit reminders this module relies on.
