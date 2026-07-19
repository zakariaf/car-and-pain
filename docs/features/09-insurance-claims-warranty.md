# 🛡️ Insurance, Claims & Warranty Compliance

> No more discovering — the day you crash — that your policy lapsed, your no-claims bonus reset, or a skipped oil change quietly voided the warranty that was supposed to save you.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Documents, Glovebox & Compliance](./08-documents-compliance.md) · [Service & Maintenance](./03-service-maintenance.md) · [Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)

## The pain

Insurance and warranty are the most expensive promises attached to a car, and they are also the easiest to lose on a technicality. A renewal date slips past unnoticed and you drive uninsured; a claim drags through weeks of adjuster calls with no record of who said what; the "payout" turns out to be hundreds less than expected once the deductible bites; and a single late or skipped service — logged nowhere — hands the manufacturer a reason to reject a powertrain warranty claim worth thousands. Most car apps stop at "store a photo of your insurance card." That leaves the owner to track premium installments, no-claims-bonus years, claim status, and the exact service items that keep coverage valid entirely in their own head. This module is the financial-protection stack rivals skip: it turns those promises into tracked, provable, offline records.

## What it does

Car and Pain models the full financial-protection lifecycle for every vehicle in your garage. You record one or many insurance policies per vehicle (liability, comprehensive, gap, breakdown, legal, glass and more), each with its premium, deductible, coverage limits, installment schedule, and renewal date — all reminder-backed so nothing lapses. When something happens, a structured claims workflow walks the incident from first notification of loss (FNOL) through adjuster assignment, repair authorisation, and final settlement, computing the net claim after your deductible and reconciling the payout against what you actually spent on the repair.

Alongside insurance sits a warranty-compliance dashboard: it takes the manufacturer's required service schedule and checks it against your real logged service history, then shows a red/amber/green verdict on whether your coverage is still valid — and, when it is at risk, names the exact service item and reason. Everything is stored canonically (SI units, ISO/UTC dates, base currency) and computed on-device, so it works in airplane mode, survives a phone migration, and never depends on an account or an insurer's portal.

## Features

### ✅ Must-have

- **Insurance policy record** — Capture each policy's core identity: provider, policy number, type, coverage limits, deductible, premium, and renewal/expiry date, so the whole contract lives in one editable record instead of a folder of paper.
- **Multiple policies and add-ons per vehicle** — A vehicle can carry several concurrent policies and riders — liability, comprehensive, gap/GAP, breakdown/roadside, legal cover, and glass — each tracked independently rather than flattened into one "insurance" blob.
- **Premium and installment schedule with due reminders** — Break a premium into its real payment cadence (monthly, quarterly, annual) and get a local reminder before each installment falls due, so a missed direct debit never cancels the policy.
- **Renewal reminder with auto-roll of expiry** — As a policy nears expiry, the app warns you in advance and can roll the expiry forward on renewal, re-arming the next cycle of reminders automatically.
- **Insurance claim record** — Log each claim with its number, date, description, and status as a first-class record attached to the vehicle (and, where relevant, the incident).
- **Claims lifecycle workflow** — Move a claim through explicit, status-tracked stages — FNOL → adjuster assigned → repair authorised → settled — so you always know where it stands and what the next step is.
- **Payout vs deductible / net-claim calculation** — The app computes what actually lands in your pocket by subtracting your deductible/excess from the approved payout, ending the "why is the cheque smaller than expected" surprise.
- **Attach claim documents, photos, and estimates** — Bind repair estimates, adjuster letters, damage photos, and settlement PDFs directly to the claim, all stored app-private and carried inside the backup.
- **Warranty-compliance dashboard** — See at a glance whether your logged service history satisfies the manufacturer's required schedule to keep the warranty valid, with red / amber / at-risk flags calling out trouble before it costs you a rejected claim.
- **CSV/JSON export of policies, claims, and warranty status** — Export the full insurance, claims, and warranty-compliance dataset as open CSV/JSON files you own outright — for your records, your broker, or a new app.

### 🔵 Should-have

- **No-claims-bonus tracking with projected claim impact** — Track your accumulated NCB/discount years and preview how a new claim would step them back, so you can make an informed "claim it or pay it myself" decision.
- **Premium-history trend across renewals** — Chart how your premium has moved renewal over renewal, per vehicle and across the fleet, exposing creeping increases you would otherwise never notice.
- **At-fault vs no-fault classification** — Mark each claim's fault status, because it is fault — not the mere existence of a claim — that determines whether your no-claims bonus takes a hit.
- **Multi-vehicle / multi-driver policy handling** — One policy can cover several vehicles or drivers and still produce a single, correctly-scoped set of reminders instead of duplicate nags for every car on the contract.
- **Insurer and broker contact directory** — Keep the provider, broker, claims line, and adjuster contacts on file next to the policy, so at the worst moment you are not searching for a phone number.
- **Excess-protection / add-on tracking** — Record excess-protection and other add-on products so you know what is covered — and can actually reclaim your deductible when the add-on entitles you to.
- **Warranty coverage catalogue** — Model distinct warranty layers — powertrain, corrosion/anti-perforation, part-level, and extended service contracts — each with its own dual date + mileage limits, rather than one vague "in warranty / out of warranty" flag.
- **Warranty-at-risk alerts** — Get warned as a service due-date or a mileage threshold approaches a schedule limit, giving you time to book the work before the warranty condition is breached.
- **Claim cost recovery reconciled against expenses** — A claim payout nets against the repair spend it reimburses, so your Total-Cost-of-Ownership reflects the real out-of-pocket cost, not the gross bill.

### ⚪ Nice-to-have

- **Claim timeline / audit view** — A chronological, document-linked history of every status change, payment, and attachment on a claim — an audit trail you can hand to an insurer or ombudsman.
- **Total-loss / write-off handoff to Sell/Dispose** — When a claim ends in a write-off, hand the vehicle cleanly to the Sell & Dispose workflow so the total-loss settlement flows into a final TCO close-out.
- **Premium comparison notes at renewal** — Jot manual quotes from competing insurers at renewal time to compare against your current premium — offline, with no live-quote dependency.
- **Diminished-value note post-repair** — Record the diminished market value a repaired vehicle carries after an at-fault-of-another incident, feeding both any diminished-value claim and your resale expectations.
- **Reusable claim templates** — Save templates for common incident types (windscreen chip, parking dink, hail) to pre-fill a new claim's structure and speed up the next FNOL.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `policy_id` | uuid | Stable identifier for the insurance policy. |
| `vehicle_ids[]` | array of ref | One policy may cover several vehicles; scopes reminders and views. |
| `provider` | text | Insurer/underwriter name; kept LTR inside RTL layouts. |
| `broker` | text | Intermediary/broker, if the policy was arranged through one. |
| `policy_number` | text | Contract number; bidi-isolated so it never reverses in RTL. |
| `policy_type` | enum | Liability, comprehensive, gap, breakdown, legal, glass, other. |
| `coverage_limits` | text / number+currency | Per-cover limits and sums insured. |
| `deductible` | number+currency | Excess the owner bears before payout; base-currency canonical. |
| `premium` | number+currency | Total premium for the term. |
| `currency` | enum | Display currency for this policy; stored against base currency. |
| `payment_frequency` | enum | Annual, semi-annual, quarterly, monthly, one-off. |
| `installments[]` | array | Scheduled payments (amount, due date, paid flag) driving reminders. |
| `start_date` | date | Policy inception; ISO/UTC canonical, shown in chosen calendar. |
| `renewal_date` | date | Expiry/renewal; drives renewal reminders and auto-roll. |
| `auto_renew` | bool | Whether expiry rolls forward automatically on renewal. |
| `ncb_years` | number | Accumulated no-claims-bonus years. |
| `ncb_protected` | bool | Whether NCB is protected against step-back. |
| `claim_id` | uuid | Identifier for a claim record. |
| `claim_date` | date | Date of loss / claim opened. |
| `claim_status` | enum | FNOL, adjuster assigned, repair authorised, settled, rejected, withdrawn. |
| `fault_status` | enum | At-fault, no-fault, split/shared, undetermined. |
| `incident_ref` | ref | Link to the originating Safety/Incident record, if any. |
| `estimate_amount` | number+currency | Repairer/adjuster estimate. |
| `approved_amount` | number+currency | Amount the insurer approved. |
| `payout_amount` | number+currency | Actual settlement paid. |
| `excess_applied` | number+currency | Deductible/excess deducted from the payout. |
| `documents[]` | array of attachment | Estimates, photos, letters, settlement PDFs. |
| `adjuster` | object `{name, contact}` | Assigned loss adjuster and how to reach them. |
| `warranty_id` | uuid | Identifier for a warranty coverage record. |
| `warranty_type` | enum | Powertrain, corrosion, part-level, extended contract, other. |
| `warranty_start` | date | Coverage start. |
| `warranty_expiry` | date | Date limit of coverage. |
| `warranty_mileage_limit` | number+unit | Distance limit (canonical SI, shown in preferred unit). |
| `required_schedule_ref` | ref | Link to the manufacturer service schedule that keeps warranty valid. |
| `compliance_status` | enum | Compliant, at-risk, void-risk. |
| `at_risk_flags[]` | array | Specific items/reasons the warranty is at risk. |
| `notes` | text | Free-form notes, localized and searchable across languages. |

## Calculations & formulas

- **Net claim** — `net_claim = approved_payout − deductible/excess`. What the owner actually receives after the excess is applied.
- **No-claims-bonus impact projection** — `post_claim_discount = ncb_table[max(0, ncb_years − step_back)]`. Models how many bonus years a claim removes, respecting protection where set.
- **Premium trend** — `premium_trend = period-over-period % change across renewals`. Surfaces year-on-year premium creep per vehicle and across the fleet.
- **Warranty compliance** — `all required schedule items logged within (date & mileage) tolerance → compliant; any missed/overdue → at-risk / void-risk`. The verdict powering the dashboard's red/amber/green.
- **Projected warranty-at-risk date** — `at_risk_date = min(next required service due, warranty mileage projection)`. The earliest date coverage could be jeopardised, projecting mileage from average daily distance.
- **Installment projection** — Derived from `payment_frequency` and `premium` to lay out the due-date schedule that feeds reminders.

## Reminders & notifications

This module is a heavy producer of reminders, all served by the shared offline [Reminders & Notifications](./04-reminders-notifications.md) engine and always naming the vehicle:

- **Premium installments** — Date-triggered, one per scheduled installment, with configurable lead time (for example "1 week before") so a missed payment never lapses the cover.
- **Policy renewal / expiry** — Date-triggered early warnings ahead of the renewal date, re-arming for the next term after auto-roll.
- **Warranty-at-risk** — Whichever-comes-first triggers combining the next required service due-date and a projected mileage threshold (for example "1,000 km before" the warranty distance limit), warning while there is still time to book the work.
- **Claim follow-ups** — Optional date reminders to chase an adjuster or supplement while a claim sits in an open status.

Reminders for a single policy covering multiple vehicles are de-duplicated (see Edge cases), grouped into digests, respect quiet hours, survive reboot/Doze/app-kill, and re-arm on backup restore.

## Offline & data

Everything here runs with zero connectivity. Policies, claims, and warranty compliance are computed entirely on-device — no insurer portal, no account, no live FX. Premiums and payouts are stored in the base currency using dated, manual/historical exchange snapshots, so a multi-currency, multi-country garage never depends on a live rate and history never silently re-values. The app is honest about its offline limits: it will not fetch live quotes or an insurer's real-time claim status; instead it tracks what you record and reminds you to update it.

For export and backup, every policy, installment, claim (with full status history), warranty record, and compliance verdict is included in the single-file full backup alongside its attachments (estimates, adjuster letters, settlement PDFs), and is also available as per-entity CSV and combined JSON. Attachments are re-linked on restore so the whole claim file round-trips across devices and operating systems. See [Data, Offline, Backup & Portability](./18-data-offline-backup.md) for the guarantees.

## Localization & RTL

Per `module.i18n_notes`, this module is built for the app's deep-localization promise:

- **Bidi-isolated identifiers** — Policy numbers, claim numbers, VIN, and provider names stay left-to-right inside right-to-left (Persian, Arabic, Sorani Kurdish) layouts, so an insurer reference never visually reverses or scrambles.
- **Money in the reader's terms** — Premiums, deductibles, and payouts render in the per-vehicle/display currency with localized numerals (Western, Eastern-Arabic, Persian) and correct digit grouping, including Indian lakh/crore.
- **Calendars** — All dates (start, renewal, claim, warranty limits) are stored canonically as ISO/UTC and displayed in the user's chosen calendar — Gregorian, Jalali/Shamsi, or Hijri — so switching calendars never shifts a real renewal date.
- **Fully translated meaning, not just labels** — Insurance and warranty terminology is localized across all supported languages, and critically the at-risk explanations ("which service, why it matters") are translated too — not left as English strings inside a localized shell.
- **Full RTL layout mirroring** — Dashboards, claim timelines, and forms mirror correctly, with the compliance status colours paired with non-colour cues per the [Accessibility & Inclusive Design](./20-accessibility.md) layer.

## Edge cases

- **One policy, many vehicles/drivers — no duplicate reminders** — A single contract covering several cars produces one correctly-scoped reminder set, never one nag per vehicle.
- **Multi-currency premiums, no live FX** — Premiums across vehicles and countries are held in their own currency and normalised via dated offline rate snapshots, never a live feed.
- **Claims that span periods** — A claim opened in one term and settled in another is supported, including partial payments and supplements paid after the initial settlement.
- **NCB step-back vs protected NCB** — An at-fault claim steps the no-claims bonus back; a protected NCB shields it — both outcomes are modelled and projected.
- **Warranty voided by a skipped or late service** — When compliance breaks, the app names the exact service item at risk and the reason (missed, or done outside date/mileage tolerance), not a vague "at risk".
- **Mileage-limited warranty with a stale odometer** — If the latest reading is old, the app flags the uncertainty and projects current mileage from average daily distance rather than guessing silently.
- **Total-loss claim as a disposal event** — A write-off flows into the Sell & Dispose workflow and final TCO, closing the vehicle out with its settlement recorded.
- **Back-dated / already-settled claims** — Historical claims can be entered after the fact, fully settled, so your record is complete even for events before you started using the app.
- **Payout logged as a credit, not new spend** — A settlement nets against the repair cost it reimburses so it reduces net cost rather than inflating total expenditure.

## Related features

- **[Documents, Glovebox & Compliance](./08-documents-compliance.md)** — The encrypted glovebox stores the policy and warranty documents this module reasons over, and shares the red/amber/green compliance dashboard.
- **[Service & Maintenance](./03-service-maintenance.md)** — Supplies the logged service history that the warranty-compliance engine checks against the manufacturer's required schedule.
- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — Receives claim payouts as credits netted against repair spend, keeping the on-device TCO honest.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — Delivers the installment, renewal, and warranty-at-risk reminders this module generates, reliably and offline.
- **[Safety, Incidents & Roadside](./22-safety-incidents-roadside.md)** — The at-scene incident record that a claim links to via `incident_ref`, carrying photos and dashcam clips into the FNOL.
- **[Sell, Dispose & Ownership Transfer](./24-sell-dispose.md)** — Takes the handoff when a total-loss claim writes a vehicle off, folding the settlement into the final close-out.
- **[Fleet, Business & Company-Car](./10-fleet-business.md)** — Aggregates premium history and claims across the fleet for per-vehicle and per-driver financial reporting.
