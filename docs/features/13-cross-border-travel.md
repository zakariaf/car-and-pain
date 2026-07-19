# 🛂 Cross-Border, Travel & Emission Zones

> No more €100 fines for a missing city sticker, an unbought vignette, or a warning triangle you left at home — one packing-and-compliance home for driving abroad, fully usable in airplane mode.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Documents, Glovebox & Compliance](./08-documents-compliance.md) · [Trips & Mileage Logbook](./06-trips-mileage.md) · [Offline Maps & Location](./14-maps-location.md)

## The pain

Crossing a border in a car turns a familiar routine into a minefield of unfamiliar rules. One country demands a paper vignette on the windscreen, the next runs an electronic e-toll gantry, a third bans your Euro-class engine from its city centre unless you bought the right coloured sticker weeks in advance, and every one of them has its own list of legally-required kit — warning triangle, hi-vis vest per occupant, spare bulbs, a breathalyzer, winter tires by date. Miss any of it and the "pain" is immediate: an on-the-spot fine, a turned-around car at a low-emission zone camera, or an invalidated insurance claim because the green card was never arranged. The information exists, but it is scattered across a dozen government sites you can't reach on mobile data at 2,000 km from home. This module gathers stickers, passes, documents, equipment, and per-country rules into one place — with the reference data bundled on-device so it works exactly when connectivity does not.

## What it does

Cross-Border, Travel & Emission Zones is the coherent home for everything about driving outside your home country. It tracks the compliance artefacts you must buy or register (emission-zone stickers, vignettes, toll passes, e-toll transponder accounts), stores the documents you must carry (International Driving Permit, insurance green card, temporary import/export paperwork, carnets), and holds a per-country required-equipment checklist you can tick off while packing. Alongside those records it ships a bundled offline reference for each country — which side of the road, default speed limits, headline rules, and the correct emergency number — so the essentials are on-screen even with the phone in airplane mode.

Because Car and Pain is offline-first, all of the above is stored on-device and surfaced through the shared reminder engine (so a vignette expiring mid-trip or an IDP lapsing warns you in advance) and the compliance dashboard (so a missing sticker shows red before you reach the border, not after). A country-context switch lets the app temporarily — or permanently, when relocating — apply the destination's inspection, tax, and equipment rules instead of your home defaults, and a currency/unit hint reminds you that fuel is now sold in litres priced in a different currency. Everything is honest about its limits: bundled datasets carry a visible "last updated" date, and anything genuinely live (e-toll balances, real-time gantry status) stores a manual value with a timestamp rather than pretending to be real-time.

## Features

### ✅ Must-have

- **Emission-zone / LEZ / ULEZ registration & sticker tracking.** Record each low-emission or ultra-low-emission zone you've registered for or bought a sticker for, capturing the scheme name, the zone class your vehicle qualifies as, the sticker reference, and its validity window — so you know at a glance whether you may legally enter a given city.
- **Vignette & toll-pass records.** Log each country's motorway vignette or toll pass with its validity window, the amount paid, and the transponder or account reference, covering both windscreen stickers and digital vignettes.
- **Per-country required-equipment checklist.** Keep a country-specific list of legally mandated kit — warning triangle, hi-vis vest, spare bulbs, breathalyzer, first-aid kit, and more — that you can mark as required and then tick off as packed before you leave.
- **IDP / green card / insurance-abroad document storage.** Store your International Driving Permit, insurance green card, and any abroad-cover documents in the encrypted glovebox so the paperwork travels with you and surfaces on demand at a checkpoint.
- **Bundled offline per-country reference.** Carry an on-device fact sheet per country covering the driving side, default speed limits, headline rules, and the local emergency number — available with zero connectivity.
- **Expiry reminders for vignettes, stickers, and travel documents.** Feed every dated item into the local notification engine so vignettes, emission stickers, and travel documents warn you before they lapse — never mid-trip surprise.

### 🔵 Should-have

- **e-toll transponder account tracking.** Keep records for electronic toll accounts across the common schemes (Austria, Switzerland, Czechia, Italy, France, and others), storing the provider, account reference, transponder ID, and a manually-entered balance.
- **Bundled offline emission-zone dataset.** Ship an on-device dataset of which cities operate emission zones and which vehicle classes each allows, so you can check eligibility before arriving — clearly dated so you know how fresh it is.
- **Temporary import/export document tracking.** Track the paperwork for temporarily bringing a vehicle into or out of a country, including start/end dates and reference numbers.
- **Country-context switching.** Switch the app's active country context so that relocating (or a long trip) changes the default inspection, tax, and equipment rules the app applies and reminds you about.
- **Localized road-rule cheatsheet per country.** Provide a translated, at-a-glance summary of the key driving rules for each country in the user's chosen language.
- **Cross-border road-trip integration.** Link travel-compliance records to the trip logbook so a multi-day road trip carries its tolls, parking, and country context alongside the route.
- **Currency & unit auto-hint when entering a country.** When you switch context to a new country, hint at its local currency and measurement units (with manual offline FX and display-unit conversion) so fuel and toll costs read correctly.

### ⚪ Nice-to-have

- **Border-crossing checklist.** A quick pre-crossing checklist to confirm documents, stickers, equipment, and passes are all in order before you reach the frontier.
- **Fuel-type availability / naming per country.** A reference to how fuels are labelled and named across countries (for example the E10 petrol label and the local names for diesel), so you fuel the right grade abroad.
- **Toll-cost estimator for a planned route.** Estimate the toll cost of a planned route offline by summing segment rates from the bundled rate table — clearly an estimate, not a live quote.
- **Environmental-zone violation risk warning by vehicle class.** Warn when your vehicle's Euro/emission class risks being barred from a zone on your route, flagging the exposure before you drive into a fine.
- **Customs/carnet document support.** Store and track ATA carnet and customs documents for journeys that require formal temporary-admission paperwork.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `record_id` | uuid | Stable identifier for the travel-compliance record. |
| `vehicle_id` | ref | Links the record to a vehicle in the garage; scopes it to the correct car. |
| `country` | enum/text | Country the record applies to (ISO country reference). |
| `scheme` | text | Name of the emission-zone or toll scheme, kept in its canonical local form with a translated gloss. |
| `zone_class` | enum | The vehicle's qualifying class within the scheme (e.g. sticker colour / Euro band). |
| `sticker_ref` | text | Registration or sticker reference number. |
| `valid_from` | date | Start of validity, stored canonically as UTC/ISO-8601. |
| `valid_to` | date | End of validity; drives RAG status and expiry reminders. |
| `cost` | number+currency | Amount paid, stored in base currency with the entry currency retained. |
| `currency` | enum | Currency the cost was paid in. |
| `vignette` | object | `{country, type, valid_from, valid_to, cost}` — one vignette / toll-pass record. |
| `etoll` | object | `{provider, account_ref, transponder_id, balance}` — electronic toll account; `balance` is a manual, timestamped value, never live. |
| `required_equipment[]` | array | List of `{item, required, packed}` entries powering the packing checklist. |
| `idp_ref` | ref | Link to the stored International Driving Permit document. |
| `green_card_ref` | ref | Link to the stored insurance green card / abroad-cover document. |
| `country_ref` | object | `{driving_side, emergency_number, speed_defaults, key_rules}` — bundled offline per-country reference. |
| `temp_import` | object | `{start, end, ref}` — temporary import/export paperwork. |
| `reminders[]` | array | References to reminders generated for this record's dated items. |

## Calculations & formulas

- **Sticker / vignette RAG status** — derived from validity: `status = RAG(valid_to − today)`, so a record shows green when comfortably valid, amber as expiry approaches, and red once expired or overdue.
- **Required-equipment completeness** — a simple readiness ratio: `completeness = packed_count / required_count`, shown as a progress indicator on the packing checklist.
- **Country-context resolution** — while abroad or relocated, `active_rules = country_context ?? home_defaults`, so the destination's compliance rules override your home defaults for inspection, tax, and equipment.
- **Toll estimate** — an offline sum over route segments: `toll_estimate = Σ segment_rate` drawn from the bundled offline rate table, always presented as an estimate.

## Reminders & notifications

This module is a producer for the shared [local notification engine](./04-reminders-notifications.md). It emits date-based reminders for every dated artefact it holds:

- **Vignette and toll-pass expiry** — warns before a validity window closes, with configurable lead time (e.g. "1 week before") so you can renew before a trip rather than discover it lapsed mid-motorway.
- **Emission-zone sticker expiry** — reminds you to re-register or re-buy before a sticker's validity ends.
- **Travel-document expiry** — IDP, green card, and temporary import/export references warn ahead of their end dates.

Reminders are delivered as reliable local notifications that survive reboot, Doze, OEM battery-killers, and app-kill, always name the vehicle, and re-arm automatically after a backup restore. Vignette validity is frequently a fixed window (a 10-day, 2-month, or annual pass) rather than a rolling period, so reminders are anchored to the concrete `valid_to` date rather than an interval.

## Offline & data

Everything in this module works with zero connectivity. The compliance records, documents, equipment checklists, and per-country reference sheets live entirely on-device; the emission-zone and country datasets are bundled with the app, each carrying a visible "last updated" timestamp so you always know how fresh the data is. Nothing here requires an account, a login, or a network round-trip to view or edit.

Data that is inherently live is handled honestly: e-toll account balances and real-time gantry status are online-only, so the app stores an account reference plus a manually-entered balance with a "last checked" timestamp and never claims to be showing a live figure. Bundled datasets are labelled clearly as periodically-updated snapshots, never real-time.

In export and backup, every travel-compliance record, its settings, its live reminder state, and its attached documents (IDP, green card, carnet, import papers) are included in the single-file full backup, per-entity CSV, and combined JSON — with schema versioning, checksums, and merge-aware restore. Attachments are bundled and re-linked so the paperwork round-trips intact across devices and operating systems, and self-hosted (WebDAV/Nextcloud/SFTP/SD-card) and strictly-opt-in cloud targets are all supported. See [Data, Offline, Backup & Portability](./18-data-offline-backup.md).

## Localization & RTL

Per-country reference sheets and road-rule cheatsheets are localized across every supported language, and equipment names and emergency numbers are translated so a packing list reads naturally in the user's language. Zone and scheme names are deliberately kept in their canonical local form (the name you'll actually see on signs and stickers) with a translated gloss alongside, so nothing gets lost in translation at the border.

Costs are shown in both local and home currency using manual, dated offline FX snapshots — no live rates — with localized numerals throughout, so figures render in Western, Eastern-Arabic, Persian, or Devanagari digits per the user's preference. All dates are stored canonically as ISO-8601/UTC and displayed in the user's chosen calendar (Gregorian, Jalali/Shamsi, Hijri, or Hebrew), so switching calendar or language never rewrites a validity window. Under RTL layouts (Persian, Arabic, Sorani Kurdish), the interface mirrors via logical properties while VIN, plate, IBAN, phone, transponder ID, and reference numbers stay bidi-isolated and LTR so they remain readable and correct. See [Localization, RTL & Calendars](./19-localization-rtl.md).

## Edge cases

- **Emission-zone classes and eligibility differ per city and per vehicle Euro class.** The bundled offline dataset is honestly scoped and dated rather than pretending to universal coverage — you always see how current it is.
- **Vignette validity is often fixed windows, not rolling.** Windows such as 10-day, 2-month, or annual passes are modelled as concrete date ranges, and reminders anchor to the real end date.
- **e-toll balances and live gantry status are online-only.** The app stores an account reference and a manual balance with a timestamp and never claims a live figure.
- **Required equipment varies by country and season.** Checklists account for seasonal mandates such as winter-tire requirements that apply only in certain months.
- **Relocating permanently vs travelling temporarily changes which rules apply.** An explicit mode distinguishes a temporary trip context from a permanent relocation, so the right set of inspection/tax/equipment rules is applied.
- **Offline datasets go stale.** Every bundled dataset carries a clearly-labelled "last updated" date so staleness is visible, not hidden.
- **Emergency numbers differ.** The correct number (112 across the EU, 911 in the US, or a local number) is bundled per country so it is right wherever you are.

## Related features

- **[Documents, Glovebox & Compliance](./08-documents-compliance.md)** — stores the IDP, green card, carnet, and import papers this module references, and drives the shared red/amber/green compliance dashboard.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — the offline scheduler that delivers vignette, sticker, and travel-document expiry warnings that survive reboot and re-arm on restore.
- **[Trips & Mileage Logbook](./06-trips-mileage.md)** — cross-border road-trip mode links a journey to its tolls, parking, and active country context.
- **[Offline Maps & Location](./14-maps-location.md)** — the bundled map layer that renders routes for the toll estimator and locates parking and stations abroad.
- **[Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)** — green-card and abroad-cover records tie into insurance compliance so a claim abroad isn't invalidated by missing paperwork.
- **[Settings & Preferences](./21-settings-preferences.md)** — where country context, preferred units, currency, and calendar are chosen and applied across the app.
