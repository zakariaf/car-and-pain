# 🏢 Fleet, Business & Company-Car

> Kills the shoebox-of-receipts, the guessed BIK bill, and the spreadsheet nobody trusts — turning your logged driving into audit-ready business claims without a subscription or a login.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Expenses & Cost of Ownership](./05-expenses-cost-ownership.md) · [Trips & Mileage Logbook](./06-trips-mileage.md) · [Drivers, Household & Sharing](./15-drivers-household.md)

## The pain

Anyone who drives for work lives a quiet accounting nightmare. Company-car drivers get a surprise Benefit-in-Kind (BIK) tax bill they could never sanity-check. Grey-fleet drivers — people using their own car for business — chase reimbursement with mileage numbers scribbled on the back of a fuel receipt. Small business owners and sole traders mix personal and business trips, then lose hours at year-end untangling which fuel-card fills were real, what VAT they can reclaim, and how much each project or client actually cost to drive. Every mainstream car app stops at "personal fuel log" and leaves this entire commercial layer to a spreadsheet that breaks the moment a rate changes or the phone dies.

## What it does

The Fleet, Business & Company-Car module is the commercial-use layer that sits on top of everything else you already log. It lets you flag any expense, trip, or fill-up as business and attach it to a cost-centre, department, project, or client; it turns classified trips into jurisdiction-aware, effective-dated mileage claims; it reconciles fuel-card statements against your real fills; it estimates company-car BIK tax; it runs a VAT-reclaim workflow; and it rolls everything up into per-vehicle, per-driver, and fleet-wide cost, profit-and-loss, and compliance views.

Because Car and Pain stores every value canonically (SI units, UTC/ISO dates, base currency) and converts only for display, business math stays correct even as you switch units, currency, calendar, or language. Rate tables, tax bands, and VAT rules are treated as effective-dated data, not hard-coded logic — so a claim generated for last year keeps last year's rates, and this year's driving uses this year's. Everything runs fully offline: no employer portal, no cloud account, no telephone-home. You produce a claim pack, a VAT summary, or a fleet overview from the device in your pocket, and you own every byte of it.

## Features

### ✅ Must-have

- **Business flag with cost-centre / department / project allocation.** Any expense, trip, or fuel entry can be marked as business and tagged to a cost-centre, department, and project, so every euro and every kilometre carries the accounting context it needs for later roll-up and reporting.
- **Grey-fleet support.** For a personal vehicle used for business, capture a business-use percentage and reimbursement setup, recognising that the driver — not the company — is repaid, on a different rate table and with no company depreciation.
- **Mileage-claim generation from classified trips.** Turn business-classified trips into a mileage claim automatically, using jurisdiction-aware, effective-dated rates so the correct pence/cent-per-mile or per-kilometre figure is applied for the trip's date and country.
- **Fleet overview across all vehicles.** A single screen aggregating every vehicle's cost, distance, business-use percentage, and compliance status, so a small operator sees the whole fleet at a glance instead of opening each car one by one.
- **Per-vehicle and per-driver cost roll-up.** Costs aggregate both by vehicle and by driver, so a pooled car shared across drivers and a driver who moves between cars are both accounted for correctly.
- **Business vs personal cost separation in TCO and reports.** The Total-Cost-of-Ownership engine and reports split business from personal spending, so private running costs never contaminate a business claim and business costs never inflate a personal budget.
- **Export claim packs (CSV / PDF / JSON) with receipts.** Generate a complete mileage and expense claim pack in CSV, PDF, or JSON with the underlying receipts attached, ready to hand to an employer, accountant, or tax authority.

### 🔵 Should-have

- **Benefit-in-Kind (BIK) company-car tax estimate.** Estimate the annual company-car tax charge from list price, CO2/fuel band, and the driver's tax rate — clearly labelled an estimate, since bands and rates shift by year and jurisdiction.
- **Fuel-card statement reconciliation.** Match a fuel-card statement against your logged fills line by line, flagging unmatched or discrepant transactions so phantom charges, missed logs, and card misuse surface instead of hiding.
- **VAT-reclaim workflow.** Record the reclaimable VAT amount per expense, total it by period at the correct rate, and export the result, so reclaiming input VAT becomes a report rather than an archaeology project.
- **Per-driver profit-and-loss.** For pooled or business vehicles, compare a driver's income against their allocated costs to produce a net figure — the true economics of each driver, not just their mileage.
- **Approval status on claims.** Track each claim through draft, submitted, approved, and paid, so both driver and approver always know where a claim stands and nothing falls through the cracks.
- **Project / client billing tags with billable rates.** Tag driving to a project or client and attach a billable rate, so business travel that is re-billable to a customer is captured as revenue rather than absorbed as cost.
- **Fleet compliance dashboard.** A cross-vehicle red/amber/green view of inspections, insurance, and road tax, so an expired MOT, lapsed policy, or overdue tax on any vehicle is caught before it becomes a liability.
- **Cost-per-mile by cost-centre and by driver.** Break running cost down to a cost-per-mile (or per-kilometre) figure sliced by cost-centre and by driver, exposing which parts of the operation and which drivers are expensive.

### ⚪ Nice-to-have

- **Company mileage-policy presets.** Ship configurable policy presets such as home-to-office commute exclusion and capped reimbursement rates, so claims automatically respect the employer's rules.
- **Pool-vehicle booking / assignment log.** Log who booked or was assigned a shared pool vehicle and when, giving a clean chain of custody for a car that many drivers use.
- **Fringe-benefit / allowance tracking.** Track car allowances and other fringe benefits alongside BIK, so the full taxable picture of a company-provided vehicle is visible in one place.
- **Fleet-wide budget and variance alerts.** Set a fleet budget and get alerted when spend drifts from plan, so cost overruns are caught mid-period rather than at year-end.
- **Bulk claim export for an accounting period.** Export every claim across drivers and vehicles for a whole accounting period in one operation, built for the person who reconciles the books.
- **Depreciation / lease schedules rolled into fleet TCO.** Fold each vehicle's depreciation curve and lease schedule into the fleet-wide TCO, so the fleet number reflects the real cost of capital, not just fuel and service.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `cost_centre_id` | ref | Links an entry to a cost-centre in the shared taxonomy; UGC name preserved across languages. |
| `department` | text | Department the cost is allocated to. |
| `project_id` | ref | Links driving/spend to a project for allocation and billing. |
| `client_id` | ref | Links driving/spend to a billable client. |
| `driver_id` | ref | The driver attributed to the trip, fill, or cost; flows into per-driver roll-up and P&L. |
| `is_grey_fleet` | bool | Marks a personal vehicle used for business (driver reimbursed, no company depreciation). |
| `business_use_pct` | number+% | Share of use that is business; applied to shared costs and grey-fleet reimbursement. |
| `bik.list_price` | number+currency | Manufacturer list price (P11D-style value) used as the BIK base. |
| `bik.co2_band` | enum | CO2 emissions band driving the BIK percentage. |
| `bik.fuel_type` | enum | Fuel type (and, for EV/PHEV, electric range) affecting the band. |
| `bik.bik_percentage` | number+% | Effective-dated appropriate-percentage for the band. |
| `bik.tax_rate` | number+% | Driver's marginal tax rate. |
| `bik.annual_bik` | number+currency | Computed annual BIK charge (estimate). |
| `fuel_card.id` | uuid | Identifier of the fuel card. |
| `fuel_card.provider` | text | Card provider/network. |
| `fuel_card.statement_ref` | text | Statement reference used for reconciliation. |
| `fuel_card.reconciled` | bool | Whether the statement line matched a logged fill. |
| `vat.reclaimable_amount` | number+currency | Reclaimable VAT for the expense. |
| `vat.rate` | number+% | VAT rate applied. |
| `vat.period` | date range | Reporting period the reclaim belongs to. |
| `claim.id` | uuid | Unique claim identifier; embedded IDs render LTR even in RTL packs. |
| `claim.period` | date range | Period the claim covers. |
| `claim.driver` | ref | Driver the claim belongs to. |
| `claim.total` | number+currency | Claim total. |
| `claim.status` | enum | `draft` / `submitted` / `approved` / `paid`. |
| `claim.approver` | ref | Person who approved the claim. |
| `claim.approved_date` | date | Date of approval; approved claims lock against silent edits. |
| `billable_rate` | number+currency | Rate at which project/client driving is re-billed. |
| `fleet_scope` | enum | Scope selector: single vehicle / per-driver / all-vehicles / fleet. |
| `cost_per_mile_by_centre` | number+currency/distance | Derived cost-per-distance sliced by cost-centre. |
| `pnl.income` | number+currency | Income attributed to the driver/vehicle. |
| `pnl.allocated_cost` | number+currency | Allocated cost (fuel, service, fixed-cost share, reimbursement). |
| `pnl.net` | number+currency | Net result (`income − allocated_cost`). |

## Calculations & formulas

- **Mileage claim** — `mileage_claim = Σ(business_distance × applicable_rate)` summed per driver and period, with `applicable_rate` selected by the trip's effective date and jurisdiction.
- **BIK annual charge** — `annual_bik = list_price × bik_percentage(CO2/fuel/electric-range band) × marginal_tax_rate`, where `bik_percentage` comes from the effective-dated, country-scoped band table.
- **VAT reclaim** — `vat_reclaim = Σ reclaimable_amount` over the period, rate-aware across mixed-rate expenses.
- **Fuel-card reconciliation delta** — `delta = statement_total − matched_logged_fills`; any statement line without a matched fill (or any fill without a statement line) is flagged.
- **Per-driver P&L** — `pnl = income − (fuel + service + share_of_fixed_costs + mileage_reimbursement)`.
- **Business-use %** — `business_use_pct = business_distance / total_distance`, then applied as a multiplier to shared costs.

## Reminders & notifications

This module consumes the shared [local notification engine](./04-reminders-notifications.md) rather than defining new trigger types, and surfaces business-critical alerts through it:

- **Fleet compliance reminders** for inspections, insurance renewal, and road tax across every vehicle, firing on date and/or distance (whichever comes first) with configurable early warnings such as "1 month before" or "1,000 km before".
- **Claim-status nudges** when a claim sits in draft or submitted for too long, so nothing stalls before payment.
- **Fleet budget / variance alerts** when period spend crosses a configured threshold.

Every notification names the specific vehicle and driver, respects per-severity channels and quiet hours, and — like all Car and Pain reminders — survives reboot, Doze, and app-kill, and re-arms automatically after a backup restore.

## Offline & data

Everything in this module is computed on-device with zero connectivity. Mileage claims, BIK estimates, VAT summaries, fuel-card reconciliation, per-driver P&L, and the fleet overview all run against local data and bundled, effective-dated rate/band tables — no employer portal, payroll system, or tax-authority connection is ever required. Where a value is inherently external (a live tax band change, an FX rate for a foreign fuel-card statement), the app uses bundled or manually entered figures with "last checked" transparency and never blocks logging.

In [backup and export](./18-data-offline-backup.md), all fleet records — allocations, BIK inputs, fuel-card links and reconciliation state, VAT amounts, claims with their live approval status, billable rates, and P&L inputs — are included in the single-file backup, the per-entity CSV, and the combined JSON, with attachments (receipts) bundled and re-linked so claim packs round-trip intact across devices and operating systems. Claim packs themselves export as CSV, PDF, or JSON with receipts attached, and bulk export can emit an entire accounting period at once. Cost-centre, department, project, and client references are preserved by UUID, so nothing is orphaned on migration.

## Localization & RTL

- **Jurisdiction tax terminology** is localized — BIK/P11D, HMRC, IRS standard mileage, and VAT/USt/TVA appear with the correct term for the user's language and region, so the vocabulary matches the paperwork.
- **Rate and band tables are data, not code** — effective-dated and country-scoped, so switching language never changes which rates apply; the jurisdiction does.
- **Currency and numerals follow user preference**, including Eastern-Arabic/Persian/Devanagari numerals and Indian lakh/crore grouping, so a claim total reads naturally in the driver's locale while staying canonically stored in the base currency.
- **Claim-pack PDFs honor language, RTL layout mirroring, calendar (Gregorian/Jalali/Hijri), and currency**, while embedded identifiers — claim IDs, VINs, plates, IBANs, statement references — stay LTR and bidi-isolated so they remain scannable and unambiguous inside an otherwise right-to-left document.
- **Cost-centre, department, project, and client names are user-generated content**, preserved verbatim and searchable across languages rather than translated.

## Edge cases

- **Grey-fleet reimburses the driver, not the company** — a distinct rate table applies and no company depreciation is counted, so the reimbursement math and TCO treatment differ from a company-owned vehicle.
- **BIK bands and rates change yearly and per jurisdiction** — effective-dated, country-scoped tables are used and the result is always labelled an estimate, never presented as an official figure.
- **A fuel-card statement in a different currency or period than the logged fills** — amounts are normalized to the base currency and dates aligned before matching, so cross-currency and cross-period statements still reconcile.
- **A single trip mixing business and personal legs** — the split follows per-leg classification, not a whole-trip assumption, so partial-business journeys are apportioned correctly.
- **VAT reclaimable on fuel may require business-mileage evidence** — the reclaim links back to the trip log, so the supporting mileage proof travels with the claim.
- **One driver across multiple vehicles, and one vehicle across multiple drivers** — attribution is tracked on each entry so both roll-ups (by driver and by vehicle) stay correct in pooled scenarios.
- **An already-approved claim must lock against silent edits** — approved claims are protected, and any amendment creates a new revision rather than mutating the approved record, preserving an auditable trail.

## Related features

- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — supplies the underlying cost and TCO engine that this module splits into business vs personal and rolls up per vehicle and driver.
- **[Trips & Mileage Logbook](./06-trips-mileage.md)** — the classified, effective-dated trip data that mileage claims and business-use percentages are generated from.
- **[Drivers, Household & Sharing](./15-drivers-household.md)** — defines the drivers whose attribution powers per-driver roll-up, P&L, and pool-vehicle assignment.
- **[Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)** — feeds the insurance side of the fleet compliance dashboard's red/amber/green status.
- **[Documents, Glovebox & Compliance](./08-documents-compliance.md)** — holds the inspection, tax, and policy documents that fleet compliance reminders track across all vehicles.
- **[Dashboard, Statistics & Reports](./17-dashboard-statistics-reports.md)** — renders the fleet overview, cost-per-mile breakdowns, and exportable business reports.
