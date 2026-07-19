# 🏁 Sell, Dispose & Ownership Transfer

> The pain of ending ownership cleanly: cancelling the right insurance, tax and roadside contracts, proving the odometer, handing over full history without leaking your private IDs, and finally knowing what the car truly cost you.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Expenses & Cost of Ownership](./05-expenses-cost-ownership.md) · [Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md) · [Data, Offline, Backup & Portability](./18-data-offline-backup.md)

## The pain

Selling or scrapping a car is the moment owners are most likely to get burned, and the moment their careful records finally have to pay off. People forget to cancel insurance and road tax and keep paying for a car they no longer own; they hand the buyer a shoebox of receipts with their policy number, licence number and home address exposed; they sign an odometer disclosure they cannot back up; and months later they still have no honest answer to "did I lose money on that car?" A total-loss or theft is worse still — the vehicle is gone, but the loan, the paperwork and the accounting are not. This module turns the messy end of ownership into a guided, offline checklist that closes the books instead of leaving them open.

## What it does

Sell, Dispose & Ownership Transfer is the guided close-out that runs when a vehicle leaves your garage. You pick a disposition type — sold, scrapped, total-loss, stolen, or exported — and the workflow adapts: it captures the right facts, walks you through de-registration and insurance/tax cancellation, generates a localized bill of sale and odometer-disclosure statement where the law requires one, and assembles a redacted handover pack the buyer can trust while your private numbers stay private.

At the same time it finalizes the money. Every fuel fill, service, expense, financing charge and depreciation estimate you logged over the life of the car is snapshotted into a **final Total Cost of Ownership** and a **realized-depreciation summary**, so the car exits with a truthful lifetime number instead of a guess. The vehicle is then archived — its full history is retained and exportable forever, but it drops out of your active dashboards, reminders and stats so it stops nagging you and stops distorting your fleet averages. All of it works with zero connectivity: the checklists, templates and calculations are bundled on-device.

## Features

### ✅ Must-have

- **Guided disposition workflow** — A single step-by-step flow that starts by asking *how* the vehicle is leaving: **sold**, **scrapped**, **total-loss**, **stolen**, or **exported**. The choice tailors every following step — which fields appear, which checklist loads, and which documents are offered — so you never fill in a sale price for a scrapped car or hunt for a de-registration step that does not apply.
- **Sale record** — Captures the core disposal facts (sale price, sale date, buyer, final odometer reading, and reason for selling) as a first-class record that feeds the vehicle lifecycle and the final TCO. The final odometer is written to the shared per-vehicle odometer ledger so the disclosure statement, the handover pack and the closing statistics all agree.
- **Per-vehicle full-history handover pack** — One export of the complete record for this vehicle in the buyer's choice of formats: CSV for spreadsheets, JSON for a faithful data copy, a human-readable PDF dossier, and a QR code for quick device-to-device handoff. The next owner inherits the full service, fuel and document history instead of starting blind.
- **Final TCO close-out & realized-depreciation summary** — Snapshots the lifetime Total Cost of Ownership at the moment of disposal — fuel, service, other expenses, financing interest and depreciation — and reports the realized depreciation (what the car actually lost in value), so ownership ends with a real, defensible number.
- **De-registration / insurance-and-tax cancellation checklist** — A bundled, country-scoped checklist of the steps to formally end ownership: notify the registration authority, cancel or transfer road tax, cancel insurance, return or surrender plates where required. Each item is tickable and its completion is stored on the disposal record, so nothing is silently skipped.

### 🔵 Should-have

- **Bill-of-sale generation** — Produces a localized bill-of-sale document from the sale record using a per-jurisdiction template with the correct legal wording, currency and calendar, ready to print or share.
- **Odometer-disclosure-statement generation** — Generates the odometer-disclosure statement that is legally required in several US states (and useful elsewhere), pre-filled from the final odometer reading and the vehicle identity, with the reading shown in the buyer's expected units.
- **Redacted handover pack** — A privacy-safe variant of the handover export that strips sensitive identifiers — licence numbers, insurance policy numbers, medical/ICE details — while keeping the maintenance and cost history the buyer legitimately wants. The app lock/PIN is never included in any export.
- **Cancel-recurring-costs reminder** — On disposal, prompts you to cancel the money that keeps flowing after a car is gone: recurring expense templates, roadside-assistance memberships, and insurance. This closes the classic "still paying for a car I sold" leak.
- **Scrap / export / total-loss field sets** — Disposition-specific fields for the non-sale endings: a scrap certificate or destruction reference, an export/customs reference and destination country, or an insurer claim reference and payout for a write-off — so each ending records what actually matters to it.
- **Buyer contact & payment record** — Stores the buyer's name and contact details and how payment was made, giving you a paper trail if a dispute arises after the sale.
- **Post-sale archive** — Moves the disposed vehicle into an archived state that retains its complete history and keeps it fully exportable, while excluding it from active dashboards, reminders, and aggregate/fleet statistics so it no longer skews your live numbers.

### ⚪ Nice-to-have

- **Selling-price suggestion** — Proposes a plausible asking price derived from your own logged valuation history and the vehicle's depreciation curve — a personal, offline estimate with no live market lookup, honestly labelled as guidance.
- **Pre-sale checklist** — A preparation list before you advertise: detailing, gathering documents, locating spare keys and fobs, and rounding up stored stock/OEM parts you removed during modifications so they can go with the car.
- **Household P2P transfer notes** — A guided hand-off that transfers the vehicle record to another device over local peer-to-peer sync (no cloud), with room for notes to the new keeper — useful when a car moves between family members.
- **Insurance total-loss handoff** — When a claim is settled as a write-off, pulls the insurer's payout across from Insurance/Claims and treats it as the disposal proceeds, so a total-loss closes the TCO correctly instead of showing zero recovery.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `disposal_id` | uuid | Primary key for the disposal record. |
| `vehicle_id` | ref | The vehicle being disposed; links to the garage record. |
| `disposition_type` | enum | One of `sold` / `scrapped` / `total-loss` / `stolen` / `exported`; drives which fields and checklist apply. |
| `sale_date` | date | Disposal/handover date (canonical UTC/ISO-8601); the recurring-cost stop date. |
| `sale_price` | number+currency | Agreed sale price; absent for scrap/stolen; replaced by payout for total-loss. |
| `currency` | enum | Currency of the sale price; stored so display can convert without corrupting the figure. |
| `buyer` | object `{name, contact}` | Buyer's name and contact details; empty for scrap/export/stolen dispositions. |
| `final_odometer` | number+unit | Closing odometer reading; written to the shared odometer ledger and used in the disclosure statement. |
| `reason` | text | Free-text reason for disposal (upgrade, running costs, write-off, etc.). |
| `bill_of_sale_ref` | attachment | Reference to the generated/attached bill-of-sale document. |
| `odometer_disclosure_ref` | attachment | Reference to the generated odometer-disclosure statement. |
| `handover_pack_ref` | attachment | Reference to the exported handover pack (redacted or full). |
| `redaction_profile` | enum | Which redaction profile was applied to the handover pack. |
| `cancellation_checklist` | object `{items[], done}` | De-registration / insurance / tax steps with per-item completion state. |
| `realized_depreciation` | number+currency | Purchase price minus sale price (computed). |
| `final_tco` | number+currency | Lifetime TCO snapshot at disposal (computed). |
| `notes` | text | Any additional free-text notes on the disposal. |

## Calculations & formulas

- **Realized depreciation** — `realized_depreciation = purchase_price − sale_price`. The actual value lost over the ownership period; for a total-loss, `sale_price` is the insurer payout.
- **Final TCO** — `final_TCO = lifetime TCO snapshot at disposal (incl. financing and depreciation)`. A frozen snapshot of the running Total Cost of Ownership at the disposal date, combining fuel, service, other expenses, financing interest and depreciation.
- **Net proceeds / equity** — `net_proceeds = sale_price − outstanding_loan_balance`. What you actually walk away with after clearing any finance; a negative result surfaces negative equity explicitly.
- **Recurring-cost stop date** — `recurring-cost stop date = disposal date`. Halts recurring expense templates from the disposal date so no post-sale charges accrue.

## Reminders & notifications

This module *produces* one-off cancellation reminders rather than recurring triggers. On disposal it schedules prompts through the shared [local notification engine](./04-reminders-notifications.md) to **cancel recurring expenses, roadside assistance, and insurance**, so those obligations are not forgotten in the days after the car leaves. Disposal also *stops* consuming reminders: archiving the vehicle cancels its outstanding maintenance, document, tire and warranty reminders and excludes it from future digests, and the recurring-cost stop date halts recurring expense templates as of the disposal date. Notifications continue to name the vehicle explicitly so a pending "cancel insurance" prompt is unambiguous in a multi-vehicle garage.

## Offline & data

The entire workflow runs with no connectivity. De-registration and cancellation checklists, bill-of-sale and odometer-disclosure templates, and every calculation are bundled on-device — nothing here calls a server. The selling-price suggestion is derived purely from your own logged history and depreciation curve, never a live market feed, and is labelled as an offline estimate.

The disposal record, its checklist state, and its attached documents are first-class entities in the single-file full backup, per-entity CSV, and combined JSON export, so a disposed vehicle's close-out round-trips across devices and OSes intact. The handover pack is itself an export product: full or redacted, in CSV/JSON/PDF/QR, owned entirely by the user. Archived vehicles remain in backups and exports forever — disposal removes a car from *active* views, never from *your* data.

## Localization & RTL

Bill-of-sale and odometer-disclosure templates are localized per jurisdiction with the correct legal terminology, calendar and currency, and de-registration checklists are country-scoped bundled content translated across all supported languages. Handover-pack PDFs honor the reader's language, text direction, calendar (Gregorian/Jalali/Hijri/Hebrew), numeral system (Western/Eastern-Arabic/Persian/Devanagari), and currency. Inside right-to-left layouts, embedded identifiers — VIN, licence plate, policy and reference numbers — stay left-to-right via bidi isolation so they remain correct and legible. Prices, odometer readings and depreciation figures convert only at display time from their canonical stored values, so viewing the same disposal in a different language, currency or calendar never alters the underlying record. De-registration steps that differ per country are honestly labelled as bundled guidance rather than a live authority integration.

## Edge cases

- **Sold mid-period** — Selling partway through a month stops recurring charges at the disposal date, finalizes the TCO snapshot, and retains full history in the archive.
- **Total-loss proceeds** — A write-off uses the insurer's payout as the sale proceeds, pulled from and linked to [Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md), so realized depreciation and net proceeds compute correctly.
- **No buyer or price** — Scrapped, exported and stolen vehicles have no buyer or sale price; the workflow hides those fields and shows disposition-specific ones (scrap/destruction reference, export/customs reference, or theft/claim details) instead.
- **Sensitive-ID redaction** — The handover pack redacts licence, policy and medical numbers, and the app lock/PIN is never included in any export under any profile.
- **Jurisdiction-scoped disclosure** — The odometer-disclosure statement is only surfaced where it is legally relevant, so users in other regions are not shown irrelevant paperwork.
- **Negative equity** — When the outstanding loan exceeds the sale price, net proceeds go negative and the shortfall is shown plainly rather than hidden.
- **Household P2P transfer** — Handing the record to another device removes the vehicle from the seller's *active* garage but leaves the seller's historical export intact, so both parties keep what they need.
- **Country-specific de-registration** — Required steps and documents vary by country; the bundled offline checklist reflects this and is honestly labelled as guidance, not an official filing.

## Related features

- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — Supplies the lifetime TCO engine that this module snapshots and freezes at disposal.
- **[Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)** — Feeds the insurer payout for total-loss dispositions and is where the claim that triggers a write-off lives.
- **[Vehicles, Garage & Odometer](./01-vehicles-garage.md)** — Owns the vehicle record that gets archived and the shared odometer ledger the final reading writes to.
- **[Documents, Glovebox & Compliance](./08-documents-compliance.md)** — Source of the documents gathered for the pre-sale checklist and the redacted handover pack.
- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md)** — Provides the export/redaction pipeline behind the handover pack and keeps archived vehicles in every backup.
- **[Drivers, Household & Sharing](./15-drivers-household.md)** — Powers the peer-to-peer transfer of a vehicle record to another device with no cloud account.
