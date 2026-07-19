# 🗂️ Documents, Glovebox & Compliance

> The pain of a fine, a failed roadside stop, or a voided warranty because the one piece of paper you needed had expired quietly in a drawer — gone.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md) · [Reminders & Notifications](./04-reminders-notifications.md) · [Cross-Border, Travel & Emission Zones](./13-cross-border-travel.md)

## The pain

Vehicle ownership buries you in paper that all expires on different clocks: registration this spring, technical inspection next autumn, road tax quarterly, the emissions test on its own cycle, the LPG tank re-certification every few years, your driver license a decade out, and a low-emission-zone sticker that must match your plate. Miss any one of them and the cost is real — a fine at a checkpoint, a car impounded at a border, a warranty claim rejected because you can't prove the service history, or simply the panic of digging through the glovebox at the roadside while an officer waits. The papers themselves are also fragile: they fade, tear, get left at home, or are lost when the car is sold.

Car and Pain replaces that pile with an encrypted, always-with-you digital glovebox and a single dashboard that tells you — at a glance, in red, amber, or green — exactly what is valid, what is about to expire, and what is already overdue. It does this entirely on-device, with no account, so your documents are never held hostage by a login or a lapsed subscription.

## What it does

This module is the vault plus the compliance brain. The **vault** stores scans, photos, and PDFs of every ownership document per vehicle, app-private and optionally encrypted, and lets you attach the same files to any other record — a service invoice, an insurance policy, an expense. The **compliance stack** turns those documents into structured, date-aware records: registration, road tax, periodic technical inspection, emissions test, driver license, warranties, LPG/CNG re-certification, emission-zone stickers, recalls, and roadside membership.

Every dated record feeds one **red/amber/green expiry dashboard** and one **offline reminder engine** that fires on date, on mileage, or on whichever comes first — with no push server, no email, and no connectivity required. When you're pulled over, a **roadside show-document mode** puts the right scan full-screen with the brightness turned up. When you sell the car, a **handover pack** exports everything the buyer needs, with sensitive numbers optionally redacted. And because everything is stored canonically (absolute ISO dates, SI units) and only converted for display, your expiry math stays correct even as you switch calendars, numerals, units, or language.

## Features

### ✅ Must-have

- **Digital glovebox document vault** — Store photos, PDFs, and scans of every document on a per-vehicle basis, kept app-private and encrypted at rest so nothing leaks if the phone is lost or shared.
- **Attach documents to any record** — The same scan can be linked to a service entry, an insurance policy, a warranty, or an expense, so proof lives next to the event it supports rather than in a separate silo.
- **Vehicle registration record** — Capture registration number, plate, VIN, issuing authority, and expiry so the core ownership document is always structured and searchable, not just a photo.
- **Road tax / vehicle excise duty record** — Track the locally-named road tax or excise duty with its period (annual, semi-annual, quarterly) and amount, feeding both the expiry dashboard and cost tracking.
- **Periodic technical inspection record** — Log the roadworthiness inspection under its local name with interval logic that knows how often it recurs for this vehicle.
- **Emissions / smog / pollution test record** — Record the emissions test as a separate certificate or bundled into the main inspection, depending on how the country handles it.
- **Driver license record** — Store the license with its holder, categories, and expiry, so the driver's own compliance is tracked alongside the vehicle's.
- **Vehicle warranty record with dual expiry** — Track manufacturer warranty against both a date and a mileage limit, with the effective expiry being whichever comes first.
- **LPG/CNG tank re-certification record** — Keep the gas-system periodic re-certification/inspection date and its statutory interval, with a reminder — a safety-critical deadline that owners of converted vehicles routinely forget.
- **Environmental / emission-zone sticker record** — Log low-emission-zone stickers (Umweltplakette, Crit'Air, ULEZ/LEZ and equivalents) with validity dates, the assigned zone class, and the plate they belong to.
- **Unified expiry & compliance dashboard** — One red/amber/green/none view across every dated record, so a single screen answers "is my car legal to drive today?"
- **Local expiry reminder engine** — Reminders driven by date and by mileage, scheduled entirely on-device with no account and no server.
- **Per-document reminder lead time and staged alerts** — Each document can carry its own lead time and multiple staged early warnings, so a big renewal warns you weeks ahead while a minor one warns you days ahead.
- **App lock for sensitive documents** — A PIN, passcode, or biometric gate protects the vault and the sensitive sections behind it.
- **Local encrypted storage** — Documents and their metadata are encrypted at rest on the device, consistent with the privacy-first, no-account promise.
- **CSV/JSON export of compliance records** — Every structured record can be exported as CSV per entity or combined JSON, so the data is yours to move, audit, or archive.
- **Full backup including the document files** — The single-file backup carries not just the records but the actual scans and PDFs, re-linked on restore, so a device migration never orphans your paperwork.

### 🔵 Should-have

- **In-app document scanner** — An on-device scanner with edge detection, deskew, and multi-page PDF capture turns a stack of paper into clean digital documents without leaving the app or uploading anything.
- **Roadside show-document mode** — A full-screen, brightness-boosted quick-access view (optionally reachable from the lock screen) presents the exact document an officer asked for, fast, without hunting through folders.
- **Owner's manual & reference library** — Store the handbook plus fuse-box, bulb, and wiper reference per vehicle, so the answers you need at the roadside are already on the phone.
- **Storage & image-compression manager** — Tools to see what documents consume and to compress images keep the vault lean on space-constrained devices.
- **Localized inspection interval auto-suggest** — Based on country, first-registration date, vehicle category, and age, the app proposes the correct inspection cadence instead of making you look up the rules.
- **Inspection defects / advisories log** — Record defects and advisories from an inspection and bridge them into maintenance to-dos so nothing flagged gets forgotten before the retest.
- **Individual part / component warranty** — Track separate warranties on parts like the battery, tires, exhaust, or DPF, each with their own terms and expiry.
- **Extended warranty / service contract** — Record aftermarket extended warranties and service contracts alongside the factory warranty.
- **Manual recall / safety-campaign record** — Log recalls and safety campaigns with a status of open, scheduled, or completed, so an outstanding remedy stays visible.
- **Roadside assistance membership record** — Store the provider, membership number, a tappable assistance phone number, and expiry, so help is one tap away and the membership itself never lapses unnoticed.
- **Auto-reschedule on renewal** — When you renew a document, its expiry and all its reminders roll forward automatically to the next cycle, so you set the cadence once.
- **Per-vehicle handover pack** — Export a complete document pack for the buyer at sale time, with optional redaction of sensitive numbers.
- **Warranty-expiry reminder as odometer approaches** — Beyond the date warning, an alert fires as your projected mileage nears the warranty limit, catching the "whichever comes first" cliff before you fall off it.

### ⚪ Nice-to-have

- **Offline OCR text extraction & search** — On-device OCR reads document text across Latin, Arabic, Persian, Hebrew, and Devanagari scripts, making the vault searchable without sending images anywhere.
- **License plate history view** — A timeline of the plates a vehicle has carried, useful across re-registration and cross-border moves.
- **Cross-border & supplementary driver documents** — Store an International Driving Permit, insurance green card, and customs papers, linking into the Cross-Border module for travel compliance.
- **Recall check reminder & online-lookup deep links** — Periodic nudges to check for recalls, with cached, timestamped deep links to official lookup sites — honestly labelled as not real-time.
- **Emergency info / medical card** — A medical/ICE card kept behind the lock but reachable in an emergency, so first responders can find critical information.
- **Calendar (.ics) export of compliance dates** — Export all compliance deadlines as an `.ics` file to drop them into any calendar app the user already relies on.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `document_id` | uuid | Stable primary key; survives export/import and sync. |
| `vehicle_id` | ref | Links the document to a vehicle in the garage. |
| `doc_type` | enum | Registration, road tax, inspection, emissions, license, warranty, LPG re-cert, sticker, recall, roadside, manual, other. |
| `title` | text | User-facing label; free text, localized. |
| `file_attachments[]` | array<attachment> | Scans, photos, PDFs stored app-private; thumbnails generated. |
| `file_size` | number+unit | Bytes; drives the storage manager and warnings. |
| `issue_date` | date | Canonical ISO/UTC; displayed in the user's calendar. |
| `expiry_date` | date | Canonical ISO; drives RAG status and reminders. Empty = no expiry, no reminder. |
| `issuing_authority` | text | Authority, agency, or provider that issued the document. |
| `reference_number` | text | Certificate/policy/registration number; bidi-isolated LTR in RTL layouts. |
| `country` | enum | Drives localized terminology and interval rule tables. |
| `region_state` | text | Sub-national region where rules or names differ. |
| `tags[]` | array<text> | User taxonomy for filtering and search. |
| `status_color` | enum | Derived RAG value: red / amber / green / none. |
| `reminder_offsets[]` | array<number> | Per-document staged lead times (e.g. 60/30/7/1 days). |
| `encrypted_blob_refs[]` | array<ref> | Pointers to encrypted attachment blobs. |
| **`inspection{}`** | object | Technical inspection detail. |
| `inspection.type_label` | text | Localized name (TÜV/HU, MOT, CT, ITV…) or generic fallback. |
| `inspection.test_date` | date | Date the inspection was performed. |
| `inspection.result` | enum | Pass / pass-with-advisories / fail. |
| `inspection.certificate_number` | text | Certificate reference. |
| `inspection.next_due_date` | date | Computed or entered next-due date. |
| `inspection.odometer` | number+unit | Reading at inspection; canonical km. |
| `inspection.defects[]` | array<text> | Defects/advisories, bridgeable to maintenance to-dos. |
| **`emission_test{}`** | object | Emissions/smog test detail. |
| `emission_test.type_label` | text | Localized test name. |
| `emission_test.date` | date | Test date. |
| `emission_test.result` | enum | Pass / fail. |
| `emission_test.readings` | text | Measured values. |
| `emission_test.next_due` | date | Next-due date. |
| **`lpg_recert{}`** | object | LPG/CNG re-certification detail. |
| `lpg_recert.last_date` | date | Last certification date. |
| `lpg_recert.interval` | number+unit | Statutory interval (country-specific). |
| `lpg_recert.next_due` | date | Computed next-due date. |
| `lpg_recert.certificate_no` | text | Certificate reference. |
| **`emission_sticker{}`** | object | Emission-zone sticker detail. |
| `emission_sticker.scheme` | enum | Umweltplakette, Crit'Air, ULEZ/LEZ, etc. |
| `emission_sticker.zone_class` | text | Assigned class/colour. |
| `emission_sticker.valid_from` | date | Start of validity. |
| `emission_sticker.valid_to` | date | End of validity. |
| `emission_sticker.plate` | text | Plate the sticker is bound to. |
| **`license{}`** | object | Driver license detail. |
| `license.holder` | ref | Driver the license belongs to. |
| `license.number` | text | License number; bidi-isolated. |
| `license.categories[]` | array<enum> | Entitlement categories (A, B, C…). |
| `license.expiry` | date | Expiry date. |
| `license.points` | number | Penalty-point balance where applicable. |
| **`warranty{}`** | object | Warranty detail. |
| `warranty.type` | enum | Manufacturer / extended / component / service contract. |
| `warranty.provider` | text | Warranty provider. |
| `warranty.start_date` | date | Coverage start. |
| `warranty.expiry_date` | date | Date limit. |
| `warranty.mileage_limit` | number+unit | Distance limit. |
| `warranty.mileage_unit` | enum | km/mi for the limit; converted against canonical odometer. |
| `warranty.part_ref` | ref | Linked part/component for component warranties. |
| **`recall{}`** | object | Recall / safety-campaign detail. |
| `recall.campaign_code` | text | Manufacturer/authority campaign code. |
| `recall.issuing_body` | text | Body that issued the campaign. |
| `recall.status` | enum | Open / scheduled / completed. |
| `recall.remedy_date` | date | Date the remedy was or will be applied. |
| **`roadside{}`** | object | Roadside membership detail. |
| `roadside.provider` | text | Assistance provider. |
| `roadside.membership_number` | text | Membership number. |
| `roadside.assistance_phone` | text | Tappable phone number. |
| `roadside.coverage` | text | Coverage description. |
| `roadside.expiry` | date | Membership expiry. |

## Calculations & formulas

- **RAG status** — `red` when `expiry_date < today`; `amber` when `today <= expiry_date <= today + lead_window`; `green` when the expiry is further out; `none` when there is no expiry date at all. Rendered as `status = expiry_date < today ? red : (expiry_date <= today + lead ? amber : green)`.
- **Warranty whichever-first** — Effective expiry is `min(expiry_date, projected_date(odometer reaches mileage_limit))`, where the projected date comes from average-daily-distance on the shared odometer ledger. An alert fires as the odometer approaches `mileage_limit`.
- **Inspection interval auto-suggest** — Country rule tables map first-registration date, category, and age to a cadence, e.g. `DE HU: 3y then 2y`, `UK MOT: 3y then annual`, `FR CT: 4y then 2y`, `ES ITV: 4y then 2y then annual`.
- **LPG/CNG re-cert next due** — `next_due = last_cert_date + statutory_interval` where the interval is country-specific.
- **Days remaining & staged alerts** — `days_remaining = expiry_date - today`, with staged lead alerts at `60 / 30 / 7 / 1` days by default (per-document overridable).

## Reminders & notifications

This module is one of the heaviest producers for the shared [local notification engine](./04-reminders-notifications.md). It emits reminders for registration, road tax, inspection, emissions, license, warranty, LPG/CNG re-cert, emission-zone stickers, and roadside membership.

- **Trigger types** — Reminders fire on a **date**, on a **mileage** threshold (via projected odometer), or on **whichever comes first** for dual-limit items like warranties.
- **Lead-time early warnings** — Staged alerts warn ahead of the deadline, defaulting to 60, 30, 7, and 1 days before; distance-based warnings can warn a set number of kilometres before a mileage limit (e.g. "1000 km before the warranty cap").
- **Per-document customization** — Each record carries its own lead times, so a costly renewal can warn a month out while a routine one warns a few days out.
- **Auto-reschedule on renewal** — Renewing a document rolls its expiry and all of its reminders forward to the next cycle automatically.
- **Stale-odometer safety net** — When the odometer hasn't been updated, mileage reminders degrade to a projection and the app nudges the user, labelling the estimate as "based on last reading" rather than silently failing.
- **Offline-only delivery** — There is no email or push (no account); reminders are reliable local notifications that survive reboot, Doze, and app-kill, backed by an in-app catch-up list for anything missed.

## Offline & data

Everything here works with zero connectivity. Scanning, OCR, encryption, RAG computation, interval auto-suggest, and reminder scheduling all run on-device against bundled country rule tables and reference data — nothing calls a server. The only inherently-online touchpoints (recall lookups, official document portals) are honestly degraded: they cache last results with a "last checked" timestamp and provide manual records and deep links rather than claiming real-time detection.

In **export and backup**, structured compliance records export as per-entity CSV and combined JSON, while the **full single-file backup includes the actual document files** (scans, PDFs, photos) with checksums and versioning. On **import/restore**, attachments are re-linked to their records and reminders re-arm with their live state, so a device migration reproduces the exact glovebox and dashboard you left. The **handover pack** is a scoped export for a buyer, with optional redaction of license and medical numbers — and it never carries the app-lock credentials.

## Localization & RTL

- **Localized inspection terminology** — The app speaks the local name for the roadworthiness inspection: TÜV/HU, MOT, Contrôle technique, ITV, revisione, APK, NCT, ITP, besiktning, EU-kontroll, §57a/Pickerl, technická kontrola, muayene, and more, with a generic "roadworthiness inspection" fallback for countries without a standard term.
- **Calendars** — Expiry and renewal dates display in Gregorian, Jalali/Shamsi, Hijri, or Hebrew per the user's preference, while stored canonically as absolute ISO dates so reminder math stays correct across calendars and leap years.
- **Numerals** — Dates and reference numbers render in Western, Eastern-Arabic, Persian, or Devanagari numerals as preferred, with correct grouping.
- **Units** — Warranty mileage limits and inspection odometers are stored in canonical km and converted for display, so a km limit reads correctly against a mi odometer and the threshold alert still fires at the right point.
- **Currency** — Road-tax and renewal amounts carry the base currency canonically and display in the user's preference.
- **RTL layout** — Full right-to-left mirroring via logical properties, with embedded LTR identifiers — VIN, plate, policy/certificate numbers, provider names, IBAN, phone — held in bidi isolation so they don't scramble inside Arabic, Persian, or Kurdish text.
- **Encoding** — Exports are UTF-8 with correct RTL and BOM handling; bundled emission-zone and LPG re-cert reference content is translated across all supported languages.

## Edge cases

- **Cross-calendar dates** — Expiry/renewal dates entered and displayed in Jalali/Hijri/Hebrew are stored as absolute ISO, so reminder math stays correct across calendars and leap years.
- **Bidi identifiers in RTL** — Full RTL layout with embedded LTR VIN, policy, plate, and provider names handled via bidi isolation.
- **Mixed distance units** — A warranty mileage limit in km against an odometer in mi is converted consistently, and the threshold warning fires at the correct point.
- **Dual-trigger firing** — The whichever-first expiry fires on the earliest of the date or mileage trigger, including handling a mileage limit already exceeded.
- **Stale odometer** — A mileage reminder that can't see a fresh reading nudges the user and shows an "estimate based on last reading" label rather than silently missing.
- **Back-dated expired documents** — A document entered with an already-past expiry is accepted and shown red/overdue immediately.
- **No standard inspection name** — A country without a recognized term falls back to a generic "roadworthiness inspection" with a user-set interval.
- **Bundled vs separate emissions** — Emissions may be part of the main inspection in some countries and a separate certificate in others; both are supported.
- **Offline recall limits** — Recalls are manual records plus optional online deep-links, never real-time detection.
- **No account, no push** — Delivery is local notifications only, backed by an in-app catch-up list.
- **Large attachments** — Compression, size warnings, and graceful handling when storage fills mid-scan.
- **Timezone & travel** — A stable local-date definition ensures "expires today" doesn't fire a day early or late when travelling across timezones.
- **Country-varying rules** — Emission-zone sticker classes and LPG re-cert intervals differ per country; bundled offline reference tables cover them and are honestly labelled.
- **Redaction & lock safety** — Handover/export redaction hides license and medical numbers, and the shared pack never leaks the app-lock credentials.
- **No-expiry documents** — Documents without an expiry generate no reminder and show no status.

## Related features

- **[Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)** — The deep insurance and claims workflows and the full warranty-compliance dashboard live here; this module supplies the underlying warranty and document records.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — The shared offline scheduler that delivers every expiry, mileage, and whichever-first alert this module produces.
- **[Cross-Border, Travel & Emission Zones](./13-cross-border-travel.md)** — Consumes the emission-zone stickers, IDP, green card, and customs documents stored here for travel-compliance checks.
- **[Service & Maintenance](./03-service-maintenance.md)** — Inspection defects and advisories bridge into maintenance to-dos, and service history feeds warranty-validity proof.
- **[Sell, Dispose & Ownership Transfer](./24-sell-dispose.md)** — Uses the per-vehicle handover pack with redaction to transfer a clean document set to the buyer.
- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md)** — Provides the single-file backup, CSV/JSON export, and merge-aware restore that carry the vault and its attachments across devices.
