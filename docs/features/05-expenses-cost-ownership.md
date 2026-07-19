# 💰 Expenses & Cost of Ownership

> Stops the nagging question "what is this car *actually* costing me?" from ever again dying in a shoebox of receipts, a half-remembered loan APR, and a spreadsheet you never update.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Fuel & Energy](./02-fuel-energy.md) · [Service & Maintenance](./03-service-maintenance.md) · [Dashboard, Statistics & Reports](./17-dashboard-statistics-reports.md)

## The pain

Most owners have no honest number for what their car costs — fuel is only the visible tip, while depreciation, financing interest, insurance, tax, tyres, and the death-by-a-thousand-cuts of tolls and parking quietly dwarf it. The apps that try to help stop at fuel, silently add up mixed currencies, spike a whole year's insurance into one ugly month, and never tell you whether that next €900 repair is worth it on a car worth €3,000. Loan and lease terms live on paper you've lost, so nobody knows their real balance, their interest paid, or that they're underwater. Car and Pain turns all of that into one honest, on-device Total-Cost-of-Ownership picture — with no cloud, no account, and no spreadsheet.

## What it does

This module is the app's headline financial engine. It captures **every** cost — one-off or recurring, in any currency — against the right vehicle and (optionally) the right odometer reading, then rolls it into a true **Total Cost of Ownership**: fuel plus service plus everything else plus financing interest plus depreciation, all normalized to your base currency so nothing is ever silently summed across currencies. On top of the raw ledger sit the tools that turn numbers into decisions: budgets with real threshold alerts, full loan and lease amortization (including early-payoff, refinance, and negative-equity), depreciation and current-value tracking, and a repair-or-replace helper that tells you when a car has crossed the line from "worth keeping" to "worth selling."

Everything works fully offline. Fuel and service costs flow in automatically from their own modules through a shared analytic bucket, so the money you already log there is never double-entered — this module adds the *other* costs and the *analysis* layer over the top.

## Features

### ✅ Must-have

- **Quick, low-friction expense entry** — Logging a cost takes only a couple of mandatory fields, and an in-progress entry autosaves as a draft so a phone call or a dead battery never loses it.
- **One-time vs recurring flag** — Each expense is marked as a single event or the start of a repeating obligation (a monthly permit, an annual premium), which drives forecasting and reminders.
- **Odometer capture per expense** — An optional odometer reading on each cost lets the app tie spend to distance and compute an honest cost-per-kilometre; it feeds the shared odometer ledger used across the app.
- **Comprehensive built-in category set** — Ready-made categories cover insurance, road tax, registration, inspection, parking, tolls, fines, car wash, accessories, loan/lease payments, roadside assistance, tyres, repairs, service, fuel, EV charging, congestion/low-emission-zone charges, ferry, storage, memberships, warranty, depreciation, and a catch-all miscellaneous — so most costs have a home on day one.
- **Custom categories & subcategories** — Any category or subcategory the built-ins miss can be created with its own icon and colour, because every taxonomy in the app is user-definable.
- **Fuel / service / other analytic bucket mapping** — Every category maps to one of three analytic buckets so the headline "fuel vs service vs other" split stays meaningful even after you invent your own categories.
- **Recurring expense templates** — Reusable templates for the classic repeating bills (insurance, tax, lease, roadside, parking permit) generate future instances without re-typing.
- **Recurring due local reminders** — Upcoming recurring charges raise reliable on-device notifications so a renewal is never missed, delivered through the app's shared offline notification engine.
- **Overall & per-vehicle budgets** — Set a spending budget for the whole garage or for a single vehicle, whichever matches how you think about money.
- **Budget threshold alerts** — As spend climbs, the app warns at configurable thresholds (for example 80%, 100%, and over-budget) instead of only telling you after the damage is done.
- **Budget vs actual progress with projected period total** — A live bar shows spent-versus-budget and projects where the period will land based on the pace so far, turning a budget into an early-warning tool.
- **Total Cost of Ownership engine** — The on-device TCO engine combines fuel, service, other costs, financing interest, and depreciation into a single base-currency-normalized number — the true cost of the car, not just its fuel bill.
- **Cost per km / mile** — A running cost-per-distance figure in your preferred unit, the metric that makes two very different cars actually comparable.
- **Monthly & yearly running-cost breakdown** — Costs are aggregated into month and year views so trends and seasonal spikes are visible at a glance.
- **Fuel vs service vs other split** — The headline pie chart shows how the total divides across the three analytic buckets.
- **Per-expense currency handling** — Each expense stores its own currency, your base/home currency, a manual exchange rate, and a dated rate history — essential offline, where there is no live FX feed.
- **Currency-normalized totals** — Totals are always computed in the base currency using the recorded rates; the app **never** silently adds amounts in different currencies together.
- **Attach receipt/invoice photos** — Any expense can carry receipt or invoice images, stored app-private and bundled into backups through the shared attachments pipeline.
- **Draft autosave & back/exit confirmation** — Partially entered expenses persist automatically, and leaving a form warns before discarding — the app's core data-loss-prevention promise applied to money.

### 🔵 Should-have

- **Payment method, account, vendor & location** — Optionally record how you paid (card, cash, account label), and the merchant/vendor and location, for richer filtering and reporting.
- **Split one expense into multiple line items** — A single receipt (parts + labour + a coffee) can be broken into several category line items while remaining one transaction.
- **Reorder / hide / archive categories** — Categories can be reordered, hidden, or archived without deleting the history that used them, so old records stay intact.
- **Auto-generated upcoming recurring instances & forecast** — Recurring templates project their future instances onto a forward-looking cost forecast.
- **Mark instance paid / skipped / amount-changed** — Each generated instance can be confirmed paid, skipped, or edited to its real amount — capturing renewal drift without overwriting the template's estimate.
- **Prepaid / annual cost amortization** — A yearly premium or prepaid lump can be spread evenly across its coverage months so running-cost and budget views aren't distorted by one giant spike.
- **Per-category budgets** — Budgets can be set at the category level (e.g. a tyres budget or a parking budget), not just overall.
- **Fixed vs variable cost split** — Categories are classified as fixed or variable so the app can show which of your costs are unavoidable and which respond to how you drive.
- **Annualized cost projection** — A year-to-date figure is scaled by the elapsed fraction of the period to project a full-year cost.
- **Multi-vehicle cost comparison** — Side-by-side comparison of what each vehicle in the garage costs to run.
- **Cost per day owned** — When distance is zero or unknown, cost-per-day-owned is a robust fallback that still lets you compare vehicles or periods.
- **Loan / finance tracking with full amortization** — Full loan modelling with principal, APR, term, payment, and a running balance, producing a complete amortization schedule of interest and principal per payment.
- **Early payoff / refinance modelling** — Model paying off early or refinancing and see the interest saved, so a financial decision is backed by numbers.
- **Lease tracking** — Lease-specific terms — mileage allowance, excess-mileage rate, residual value, and balloon — are tracked so you can see excess-mileage risk before the return date.
- **Negative-equity / underwater-loan flag** — When the outstanding loan balance exceeds the car's current value, the app flags that you're underwater.
- **Down payment / deposit / balloon capture** — Up-front and end-of-term amounts (down payment, deposit, balloon) are captured as part of the financing picture.
- **Current value & depreciation estimate** — Track the car's current value and estimate depreciation by straight-line, fixed percentage, or a curve.
- **Depreciation-in-TCO toggle** — Because depreciation is a non-cash cost, a single toggle includes it in the true TCO while keeping it out of cash-flow budgets that only track money actually spent.
- **Repair-or-replace decision helper** — Combines a rising cost-per-km trend, cumulative repairs versus residual value, and a keep-versus-sell break-even to answer "is this car still worth fixing?"
- **Spend forecast / projection** — On-device linear or moving-average projection of future spend, with no server involved.
- **Configurable fiscal / period start** — The reporting period can start on any month or day to match a personal or business fiscal year.
- **Report export to PDF/CSV** — Cost reports export to PDF and CSV for taxes, expenses, or your own records.
- **Tax / VAT amount & reclaimable tracking** — Capture the tax/VAT portion of a cost and whether it's reclaimable, feeding the Fleet module's VAT-reclaim workflow.
- **Refunds / discounts / cashback** — Money coming back (a refund, a discount, a cashback, a warranty payout) is entered as a negative/credit that nets against costs rather than inflating spend.

### ⚪ Nice-to-have

- **Allocate a shared expense across vehicles** — One cost that benefits several vehicles (a shared insurance policy, a bulk tyre order) can be split across them by share.
- **Clone / duplicate last entry** — Repeating micro-costs like weekly parking can be logged by duplicating the previous entry.
- **Spending spike / anomaly notice** — The app can flag an unusual jump in spending so a surprise cost gets noticed early.
- **Cost-per-km trend over time** — A trend line of cost-per-distance reveals whether a car is getting cheaper or more expensive to run.
- **Historical exchange-rate snapshots** — Dated FX snapshots preserve the rate that was true when each foreign cost occurred.
- **Offline OCR receipt prefill** — On-device OCR can pre-fill amount, date, and vendor from a photographed receipt, with manual fallback and no data leaving the phone.
- **Business mileage reimbursement calc** — Computes reimbursable business mileage, linking the Trips logbook and the Fleet module.
- **Depreciation & resale-value tracker with snapshots** — Periodic snapshots of estimated resale value build a depreciation history over the life of the car.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `expense_id` | uuid | Stable primary key; survives export/import and sync. |
| `vehicle_id` | ref | The vehicle this cost belongs to (or the shared/allocated target). |
| `category_id` | ref | Built-in or custom category; maps to a fuel/service/other analytic bucket. |
| `subcategory` | text | Optional finer classification under the category. |
| `amount_signed` | number+currency | Signed amount — negative for refunds/credits. |
| `currency` | enum | ISO currency of the original transaction. |
| `exchange_rate` | number | Manual rate to the home currency (offline; no live FX). |
| `rate_date` | date | Date the exchange rate applies to; anchors the rate history. |
| `home_currency` | enum | The base/home currency totals are normalized to. |
| `converted_amount` | number+currency | Amount in home currency = `amount × exchange_rate`. |
| `date` | date | Transaction date, stored canonically (UTC/ISO), displayed per calendar. |
| `odometer` | number+unit | Optional reading; feeds cost-per-distance and the shared ledger. |
| `payment_method` | enum | Card, cash, transfer, fuel-card, etc. |
| `account_label` | text | Free-text account/wallet label. |
| `vendor` | text | Merchant/vendor name (UGC, preserved across languages). |
| `location` | text/ref | Where the cost occurred; optional map pin. |
| `is_recurring` | bool | Marks a repeating obligation vs a one-off. |
| `recurrence_rule` | text | Interval/rule for generating future instances. |
| `next_date` | date | Next due date for the recurring series. |
| `end_date` | date | Optional end of the recurring series. |
| `amortize_flag` | bool | Whether a lump sum is spread across coverage months. |
| `amortization_period` | number+unit | Number of months to spread the cost over. |
| `is_credit` | bool | Marks the entry as a refund/credit rather than a cost. |
| `is_reimbursable` | bool | Whether the cost can be reimbursed (business/mileage). |
| `reimbursed_amount` | number+currency | Amount already reimbursed. |
| `is_business` | bool | Business vs personal, for Fleet P&L and tax. |
| `cost_centre` | ref | Cost-centre/project allocation for business use. |
| `tax_amount` | number+currency | Tax/VAT portion of the cost. |
| `tax_rate` | number | Tax/VAT rate applied. |
| `reclaimable_vat` | number+currency | Reclaimable VAT, feeding Fleet VAT reclaim. |
| `line_items[]` | array | Split line items, each with its own category and amount. |
| `attachment_ids[]` | array of attachment | Linked receipts/invoices/PDFs. |
| `tags[]` | array | User-defined tags for filtering and reporting. |
| `budget_id` | ref | Budget this expense counts against. |
| `loan{…}` | object | Financing: `principal`, `apr`, `term_months`, `monthly_payment`, `remaining_balance`, `amortization_schedule[]`, `early_payoff`, `refinance_history[]`. |
| `lease{…}` | object | Lease: `start`, `end`, `mileage_allowance`, `excess_rate`, `residual`, `balloon`. |
| `purchase_price` | number+currency | Original purchase price; anchors depreciation and TCO. |
| `current_value` | number+currency | Estimated current value; drives depreciation and negative-equity. |
| `depreciation_method` | enum | Straight-line, fixed-percent, or curve. |
| `include_depreciation_flag` | bool | Whether depreciation counts toward TCO (non-cash toggle). |
| `notes` | text | Free-form notes (UGC, preserved across languages). |

## Calculations & formulas

- **Total Cost of Ownership** — `TCO = purchase_price + Σfuel + Σservice + Σother + Σfinancing_interest + depreciation`, all normalized to the base currency.
- **Cost per distance & per day** — `cost_per_km = total_cost / distance` and, as a fallback when distance is zero, `cost_per_day = total_cost / days_owned`.
- **Amortized lump sums** — `amortized_monthly = annual_or_prepaid_cost / coverage_months`.
- **Budget pace** — `percent_used` plus `projected_period_total = actual_spend / elapsed_fraction`.
- **Annualized projection** — `annualized = ytd_spend / elapsed_fraction`.
- **Depreciation** — straight-line and fixed-percent annual curve methods.
- **Loan amortization** — per payment: `interest_part = balance × apr / 12` and `principal_part = payment − interest_part`; early payoff: `interest_saved = Σremaining_interest − recomputed_interest`.
- **Negative equity** — `negative_equity = loan_balance − current_value`, flagged when greater than 0.
- **Repair-or-replace** — compares `keep_cost / period` against `(replacement_cost financing + expected new running cost)` and computes a break-even in months.
- **Currency normalization** — `converted = amount × exchange_rate(rate_date)`; refunds net in as signed negatives.
- **Fixed vs variable** — `fixed_total` and `variable_total` derived from each category's fixed/variable classification.

## Reminders & notifications

This module both **produces** and **consumes** reminders through the app's shared offline notification engine:

- **Recurring bill due** — Each recurring expense (insurance, tax, lease, permit, roadside) schedules a local notification ahead of its `next_date`, with configurable lead time (e.g. "1 week before") so a renewal is never missed.
- **Budget thresholds** — Crossing a configured threshold (80% / 100% / over) fires an alert while there is still time to react, not after the period closes.
- **Loan/lease milestones** — Payment-due dates and lease end/return dates can raise reminders, including early warning of approaching excess-mileage on a lease.
- **Spending anomalies** — An optional notice when spend spikes unusually against the recent trend.

All of these are date-triggered (some also distance-aware via projected mileage for lease excess), fire fully offline, survive reboot/Doze/app-kill, and re-arm automatically after a backup restore.

## Offline & data

Everything in this module runs with zero connectivity: categories, budgets, the TCO engine, amortization, depreciation, and forecasting are all computed on-device. Because there is no live FX feed offline, cross-currency costs use **manual, dated exchange rates** you enter, and totals are normalized from those recorded rates — the app never fetches a rate or silently sums mixed currencies. Values are stored canonically (SI units, UTC/ISO dates, base currency) and converted only for display, so switching units, currency, calendar, or language never rewrites your financial history.

In **export and backup**, every expense — with its line items, recurrence state, financing/lease objects, budgets, dated rate history, and linked receipt attachments — is included in the single-file full backup, in per-entity CSV, and in the combined JSON, with schema versioning and checksums. Restore is merge-aware and non-destructive, recurring series and reminders re-arm on restore, and attachments are re-linked so receipts round-trip across devices and operating systems. The user fully owns this data.

## Localization & RTL

Money and dates are treated as core data, not cosmetics. The app renders **locale-correct decimal and grouping separators** (including Indian lakh/crore grouping), places the **currency symbol** on the correct side, and shapes **Western, Eastern-Arabic, Persian, and Devanagari numerals** correctly inside right-to-left bidirectional text — while keeping identifiers like IBANs and account numbers left-to-right via bidi isolation. Non-Gregorian calendars (**Jalali/Shamsi, Hijri, Hebrew**) change how monthly and yearly totals and budgets aggregate, and both the **fiscal-period start** and **first day of week** are configurable to match those boundaries. Per-expense currency uses manual offline FX, and high-inflation or redenominated currencies (e.g. IRR, TRY) are handled at large magnitudes without overflow or rounding drift. Vendor names, category names, notes, and tags are user-generated content preserved verbatim across every language, and the whole module mirrors cleanly in RTL layouts.

## Edge cases

- **Odometer gaps from partial/missed fills** — Estimated odometer or interpolation fills the gap for cost-per-km; the app never divides by zero.
- **Zero-distance periods** — A stored car with no distance falls back to cost-per-day-owned, clearly labelled as such.
- **Odometer rollover / cluster swap / km↔mi switch** — Distance math stays correct across meter rollover, cluster replacement offsets, and unit switches.
- **Multi-currency with no live FX** — Manual rate plus dated history, showing both original and converted amounts, correctly handling 0-decimal and 3-decimal currencies.
- **Prepaid / annual lump sums** — Amortized across coverage months so running-cost and budget views aren't dominated by a single spike.
- **Depreciation is non-cash** — The toggle inflates true TCO but is kept out of cash-flow budgets.
- **Refunds / cashback / warranty payouts** — Net against costs as credits rather than being logged as new spend.
- **Recurring amount drift at renewal** — Confirming an instance's real amount does not overwrite the template's estimate.
- **Fines have a lifecycle** — Issue, due, late-fee, dispute, and void states, not just a flat amount.
- **Micro-transactions** — Tolls and street parking support fast batch entry so they don't clutter reports.
- **Non-Gregorian aggregation boundaries** — Alternative calendars shift where months and years start for totals and budgets.
- **Vehicle sold / written-off mid-period** — Recurring charges stop, the TCO is finalized, and history is retained.
- **Shared vehicles / drivers** — One expense can be split across vehicles or attributed to a specific driver.
- **Tax-inclusive vs exclusive & reclaimable VAT** — Change the "real" cost depending on business context.
- **Import mapping** — Foreign category names, varied date formats, and comma-vs-dot decimals are mapped on import.
- **Very large multi-year datasets** — TCO rollups and charts stay performant at scale.
- **Iranian Rial vs Toman** — The 10× Rial/Toman distinction is captured explicitly to avoid order-of-magnitude errors.

## Related features

- **[Fuel & Energy](./02-fuel-energy.md)** — Feeds the fuel bucket of TCO automatically, so energy costs count without double entry.
- **[Service & Maintenance](./03-service-maintenance.md)** — Feeds the service bucket and supplies the repair history behind the repair-or-replace helper.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — Delivers recurring-bill, budget-threshold, and loan/lease reminders reliably offline.
- **[Dashboard, Statistics & Reports](./17-dashboard-statistics-reports.md)** — Renders the cost splits, trends, and TCO charts and exports the reports.
- **[Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)** — Warranty payouts and claims net into costs, and premiums appear as recurring expenses.
- **[Fleet, Business & Company-Car](./10-fleet-business.md)** — Consumes reclaimable-VAT, cost-centre, and business flags for per-driver P&L and VAT reclaim.
- **[Sell, Dispose & Ownership Transfer](./24-sell-dispose.md)** — Uses current value, depreciation, and the finalized TCO for the guided close-out.
