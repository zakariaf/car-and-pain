# 🚗 Car and Pain

> Less pain. More car. 100% offline, in your language, accessible to everyone, on your terms.

## The pain we solve

Anyone with a car has a lot of pain about it. Not just the obvious kind — the breakdowns, the surprise repair bills, the insurance renewal you forgot until the day it lapsed — but the quiet, grinding kind: not knowing what you actually spend, losing the receipt the warranty claim needed, missing the inspection deadline, guessing whether the car is still worth keeping, and re-typing everything into an app that then lost it all when you changed phones.

Car ownership is a decade-long stream of small decisions and obligations, and the tools meant to help have a documented habit of making the pain worse — forcing accounts, hiding your own data behind a login, wiping years of history on a reinstall, doing the fuel-economy math wrong, and treating anyone who doesn't read English left-to-right as an afterthought.

Car and Pain exists to take that pain off your shoulders and put your data — all of it — firmly back in your hands.

## What is Car and Pain

Car and Pain is a 100% offline-first, account-free mobile app for Android and iOS that manages the entire pain of car ownership across an unlimited multi-vehicle garage. It is built for everyday owners, enthusiasts, households, and small commercial and gig drivers alike. Every feature works with zero connectivity and no signup: unified fuel and energy logging across petrol, diesel, LPG/CNG, ethanol, hydrogen, EV charging, and blended PHEV — with a correct partial/full/missed/first-fill economy state machine; service and maintenance with custom types, part numbers, DIY procedure logs, and bundled offline schedule templates; and dual/triple date-plus-distance-plus-engine-hour reminders delivered as reliable local notifications that survive reboot, Doze, and app-kill.

On top of that daily logging sits a genuine financial brain. Car and Pain runs a true on-device Total-Cost-of-Ownership engine — fuel plus service plus other costs plus financing interest plus depreciation — alongside full loan and lease amortization, budgets, and a repair-or-replace decision helper. Around it are a manual and optional-GPS trip logbook with effective-dated, tax-compliant mileage reporting; first-class tire management with seasonal sets, per-position tread, TPMS, and DOT-age safety; an encrypted digital glovebox with a red/amber/green compliance dashboard; a full insurance, claims, and warranty-compliance workflow; on-device analytics and reports; safety, incident, and roadside tooling; a bundled offline map layer; a components tier for the 12V battery, keys, and consumables; and dedicated Fleet/Business, Modifications, Cross-Border, Rideshare/Gig/Rental, and guided Sell/Dispose modules.

Three structural moats hold it together. First, uncompromising data ownership: a free single-file full backup with attachments, CSV/JSON export and import, merge-aware restore, competitor importers, user-facing trash and undo, self-hosted and SD-card targets, and household peer-to-peer sync — with no forced cloud, ever. Second, the deepest localization on the market: six fully translated launch languages with true RTL, expanding to a broad roster, with four calendars, multiple numeral systems, and per-preference units and currency. Third, first-class accessibility treated as a data-integrity peer of internationalization. And because all data is stored canonically — SI units, UTC/ISO dates, base currency — and converted only for display, switching units, currency, calendar, or language never corrupts your history.

## Who it's for

- **Everyday car owners** who just want to stop missing renewals, remember what they spend, and keep every receipt in one place that never asks them to log in.
- **Enthusiasts, project-car builders, and restorers** who need a structured modifications and build log, before/after specs, dyno figures, and mod cost that rolls into resale value.
- **Households and families** sharing one or more cars across multiple drivers, who need per-driver attribution and a way for two phones to stay in sync without a cloud account.
- **Gig, rideshare, and small commercial drivers** running the numbers on per-platform income versus cost, business-use percentage, per-shift profitability, and company-car or grey-fleet tax.

## Design principles

- **Offline-first, always** — every core feature works in airplane mode with no account, no ads, no mandatory cloud, and no forced sync. Data lives on the device, and features that inherently need connectivity ship on-device equivalents rather than blocking.
- **Data ownership is sacred** — free, first-class full backup, export, and import (single-file backup with attachments plus CSV/JSON), merge-aware non-destructive restore, competitor importers, user-facing trash and undo, and self-hosted, SD-card, and opt-in-cloud targets — never paywalled, never lock-in.
- **Correctness over cleverness** — store canonical values (SI units, UTC/ISO dates, base currency) and convert only for display, so changing units, currency, calendar, or language never corrupts history.
- **Localization is a first-class data-integrity concern, not a translation layer** — true RTL, four calendars, multiple numeral systems (including Indian grouping), per-preference units and currency, and localized help, insights, and user-content handling designed in from the first screen.
- **Accessibility is a peer of localization** — screen-reader support (including RTL), dynamic type, high-contrast, colour-blind-safe charts, reduced-motion, and minimum touch targets are structural requirements, not add-ons.
- **Never block an entry** — optional odometer, optional cost, autosaved drafts, back/exit warnings, and fast capture (VIN/plate scan, OCR). Your data is more important than a complete form.
- **Reliability beats features** — dependable local reminders that survive reboot, Doze, OEM battery-killers, and app-kill, and that re-arm on restore.
- **Buy-once, not subscribe** — any premium tier is a one-time unlock; core logging, export, reminders, and backup are always free.
- **Everything editable and fully custom** — every record can be edited or deleted with history intact, and every category, service type, and tag is user-definable.
- **Adaptive to vehicle type and use-case** — ICE, diesel, LPG/CNG, EV, PHEV, motorcycle, project/modified, fleet, gig, and rental each get the right fields, units, metrics, and workflows.
- **Honest about offline limits** — no live fuel prices, live FX, real-time recall/VIN databases, live charging tariffs, or shop marketplace. Bundle datasets (maps, emission zones, schedules, dictionaries), cache with timestamps, offer manual equivalents, and set clear expectations.
- **Multi-vehicle and multi-driver everywhere** — scoped per-vehicle, per-driver, and aggregate/fleet views for every module, with household peer-to-peer sync for shared cars under the no-account model.
- **Privacy and security by design** — local at-rest encryption, PIN/biometric app lock, redaction in handover exports, secure wipe, and an explicit no-telemetry assurance surface.
- **End-to-end lifecycle coverage** — from purchase and onboarding through daily logging, compliance, incidents, and financing to a guided sell/dispose close-out with final TCO.

## The promises

### Offline-first & account-free

There is no signup, no login, and no server that owns your account. Open the app and start logging — in airplane mode, in a parking garage with no signal, on a road trip through a dead zone. Every core feature runs entirely on the device: fuel entry, service history, reminders, expenses, trips, backup, and export all work with zero connectivity. There are no ads and no telemetry, and nothing is gated behind a network call. Where a feature genuinely depends on the outside world — recall lookups, live fuel prices, charging tariffs, reverse geocoding, currency rates — Car and Pain ships an on-device equivalent (bundled datasets, manual entry, cached results with a visible "last checked" timestamp) rather than blocking you or pretending the data is real-time. Offline is not a fallback mode here; it is the default and the design center.

### Your data, your rules (export/import)

Your history belongs to you, completely and portably. Car and Pain produces a free single-file full backup that bundles every module's records, settings, live reminder state, and all attachments — photos, receipts, PDFs, dashcam clips — and re-links them on restore so they round-trip cleanly across devices and operating systems. On top of that you get per-entity CSV and combined JSON export, a real import wizard with competitor presets (Fuelio, Drivvo, aCar, Fuelly) including column mapping and unit/locale/full-tank detection, merge-aware non-destructive restore, a user-facing trash with undo, and schema-versioned files with checksums. Choose where it goes: on-device, an SD card, a self-hosted target (WebDAV, Nextcloud, SFTP), or — strictly if you opt in — a cloud file. None of this is paywalled, and none of it is ever forced to a cloud you didn't choose.

### Truly multilingual & accessible (LTR + RTL)

Localization here is a data-integrity discipline, not a bolt-on translation. Car and Pain launches with six fully QA'd languages spanning both writing directions — English, German, and French (LTR) plus Persian/Farsi, Arabic, and Sorani Kurdish (RTL) — with complete layout mirroring, bidi isolation that keeps VINs, plates, phone numbers, and IBANs correctly LTR, and covering fonts bundled offline. It supports four calendars (Gregorian, Jalali/Shamsi, Hijri, Hebrew), multiple numeral systems (Western, Eastern-Arabic, Persian, Devanagari) with correct grouping including Indian lakh/crore, and per-preference units and currency that are settable independently of the device locale. Accessibility rides alongside as an equal peer: screen-reader labels with correct RTL reading order, dynamic type resilient to Arabic elongation and German compounds, high-contrast and colour-blind-safe charts with non-colour encodings, reduced-motion, and minimum touch targets — all validated by a QA harness. The same rendering and accessibility layers apply uniformly to screens, charts, notifications, help, and exports.

## Feature map

### Core logging

| Module | What it does | Doc |
| --- | --- | --- |
| Vehicles, Garage & Odometer | The unlimited, account-free multi-vehicle garage: rich per-vehicle profiles and specs, powertrain-adaptive fields, lifecycle states (active/archived/sold/scrapped/stolen/written-off), and the shared, auditable odometer/engine-hour ledger that feeds every other module. | [Vehicles, Garage & Odometer](./features/01-vehicles-garage.md) |
| Fuel & Energy | One unified entry-and-economy engine for every energy type — petrol/diesel/LPG/CNG/ethanol/hydrogen fills and EV/PHEV charge sessions — with correct full/partial/missed/first-fill economy math, EV break-even vs ICE, and fast pump-side entry. | [Fuel & Energy](./features/02-fuel-energy.md) |
| Service & Maintenance | A complete, editable service history: multi-line-item visits mapped to one receipt, fully custom service types, parts with part numbers and warranties, DIY procedure logs, bundled offline schedule templates, appointment scheduling, and powertrain-adaptive workflows including motorcycle-specific behaviour. | [Service & Maintenance](./features/03-service-maintenance.md) |
| Reminders & Notifications | The offline local-notification engine: date, distance, engine-hour, and whichever-first triggers, odometer-freshness prediction that turns distance rules into schedulable dates, grouped digests, per-severity channels, and reliable delivery that survives reboot, Doze, and app-kill. | [Reminders & Notifications](./features/04-reminders-notifications.md) |
| Trips & Mileage Logbook | Manual and optional on-device-GPS trip logging with business/personal tax classification, effective-dated IRS/HMRC/custom rate engines, odometer gap reconciliation, an offline-map road-trip mode linking fuel and expenses, and hooks into rideshare/gig and fleet mileage-claim workflows. | [Trips & Mileage Logbook](./features/06-trips-mileage.md) |
| Tires, Wheels & Seasonal | First-class native tire management: multiple named sets, seasonal changeover with automatic per-set mileage accrual, rotation, per-position multi-point tread and pressure, TPMS, DOT-age safety, alignment/balancing, storage location, damage log, and cost-per-km per set. | [Tires, Wheels & Seasonal](./features/07-tires-wheels.md) |
| Components, Batteries, Keys & Consumables | Track the discrete parts and consumables that outlive a single service visit: the 12V starter battery, keys/fobs, wear items with lifecycle, fluids, and spare-parts inventory — each with its own reminders and warranty, distinct from the EV traction battery. | [Components, Batteries, Keys & Consumables](./features/16-components-consumables.md) |

### Ownership & compliance

| Module | What it does | Doc |
| --- | --- | --- |
| Documents, Glovebox & Compliance | The encrypted digital glovebox plus the compliance stack — registration, road tax, localized technical inspection, emissions, driver license, and recurring legal/safety items (LPG/CNG re-cert, emission-zone stickers) — unified under a red/amber/green expiry dashboard with offline reminders. | [Documents, Glovebox & Compliance](./features/08-documents-compliance.md) |
| Insurance, Claims & Warranty Compliance | The deep financial-protection stack most rivals skip: multi-policy insurance with premium history and no-claims bonus, a full claims lifecycle (FNOL→adjuster→authorisation→payout vs deductible), and a warranty-compliance dashboard proving the required service schedule was met to keep coverage valid. | [Insurance, Claims & Warranty Compliance](./features/09-insurance-claims-warranty.md) |
| Cross-Border, Travel & Emission Zones | The coherent home for driving abroad: emission-zone stickers, vignettes and e-toll transponder accounts, per-country required-equipment and driving-rules reference, IDP/green-card documents, temporary import/export, and country-context switching when relocating — all with bundled offline datasets. | [Cross-Border, Travel & Emission Zones](./features/13-cross-border-travel.md) |
| Safety, Incidents & Roadside | First-class tooling for the worst moments of ownership, usable with zero signal: accident/damage records with photos and dashcam clips, an at-scene guided capture wizard, a shareable roadside emergency card, claim initiation, safety/seasonal checklists, parking-location saver, find-my-car, and bundled offline how-to guides. | [Safety, Incidents & Roadside](./features/22-safety-incidents-roadside.md) |
| Sell, Dispose & Ownership Transfer | A guided end-of-ownership workflow: de-registration and insurance/tax cancellation checklists, bill-of-sale and odometer-disclosure generation, redacted handover pack, and final TCO close-out — plus scrap, total-loss, and stolen dispositions. | [Sell, Dispose & Ownership Transfer](./features/24-sell-dispose.md) |

### Money

| Module | What it does | Doc |
| --- | --- | --- |
| Expenses & Cost of Ownership | Capture every car cost with rich and custom categories, recurring and amortized bills, budgets with real alerts, full loan/lease amortization with early-payoff/refinance/negative-equity, depreciation, a true on-device Total-Cost-of-Ownership engine, and a repair-or-replace decision helper — the headline financial differentiator. | [Expenses & Cost of Ownership](./features/05-expenses-cost-ownership.md) |
| Fleet, Business & Company-Car | The commercial-use and company-car layer competitors ignore: Benefit-in-Kind tax, cost-centre/department/project allocation, grey-fleet, fuel-card reconciliation, VAT-reclaim workflow, mileage-claim approval/export packs, and per-driver profit-and-loss. | [Fleet, Business & Company-Car](./features/10-fleet-business.md) |
| Rideshare, Gig & Rental Economics | A dedicated mode for the underserved commercial-use segment: per-platform income vs cost, business-use percentage from mixed trips, per-job/per-shift profitability, platform-fee tracking, and rental (Turo/peer-to-peer) handover checklists and economics. | [Rideshare, Gig & Rental Economics](./features/11-rideshare-gig-rental.md) |

### Specialized modules

| Module | What it does | Doc |
| --- | --- | --- |
| Modifications & Build Log | Structured tracking for enthusiasts, project cars, and kit/restoration builds: aftermarket/OEM+ parts with install date/odometer, before/after specs, dyno/power figures, reversibility notes, and mod cost rolled into TCO and resale value. | [Modifications & Build Log](./features/12-modifications-build-log.md) |
| Drivers, Household & Sharing | A coherent multi-driver/household model — per-driver profiles, assignment, and P&L — plus the answer to the shared-car problem under a no-account design: household peer-to-peer local sync so two phones on one car reconcile without a cloud account. | [Drivers, Household & Sharing](./features/15-drivers-household.md) |
| Reference, Diagnostics & Recalls | Offline automotive knowledge plus optional local diagnostics: bundled generic maintenance-schedule templates, warning-light and DTC dictionaries as guaranteed offline content, a check-engine event log, offline VIN decode, manual/cached recall tracking, and optional ELM327 OBD-II. | [Reference, Diagnostics & Recalls](./features/23-reference-diagnostics.md) |

### Platform & experience

| Module | What it does | Doc |
| --- | --- | --- |
| Offline Maps & Location | A shared bundled/vector offline map layer so trips, parking saver, find-my-car, incident location, and stations work fully offline instead of degrading to raw coordinates — closing the single biggest hole in the "100% offline" claim. | [Offline Maps & Location](./features/14-maps-location.md) |
| Dashboard, Statistics & Reports | The daily home screen and on-device analytics layer: glanceable customizable KPIs and quick-add, fuel-economy and cost/distance/CO2 charts, insights and anomaly detection, forecasting, gamification, and a complete localized, accessible report suite (PDF/CSV/JSON) — all computed locally. | [Dashboard, Statistics & Reports](./features/17-dashboard-statistics-reports.md) |
| Data, Offline, Backup & Portability | The offline-first data foundation and biggest trust moat: a local encrypted SQLite database, single-file full backups that round-trip attachments, CSV/JSON export, a real import wizard with competitor presets, merge-aware restore, trash/undo, self-hosted and SD-card targets, and safe schema migration — free and never forced to the cloud. | [Data, Offline, Backup & Portability](./features/18-data-offline-backup.md) |
| Localization, RTL & Calendars | The internationalization engine: fully translated languages with true RTL, ICU/CLDR plurals, bundled script fonts, four calendars, multiple numeral systems (incl. Indian grouping), and multi-unit/multi-currency — every preference independently settable, decoupled from device locale, all 100% offline, extending to help, insights, and user-content handling. | [Localization, RTL & Calendars](./features/19-localization-rtl.md) |
| Accessibility & Inclusive Design | Accessibility as a first-class cross-cutting concern beside i18n: screen-reader support (including RTL), dynamic type/font scaling, high-contrast and colour-blind-safe design, reduced-motion, minimum touch targets, and an a11y QA harness — so the "most complete" app is usable by everyone. | [Accessibility & Inclusive Design](./features/20-accessibility.md) |
| Settings & Preferences | The central control surface tying every cross-cutting preference together — language, units, currency, calendar and numerals, accessibility, notification behavior, security and app-lock, backup scheduling (incl. self-hosted), category management, theme, and the explicit offline/no-account privacy assurances. | [Settings & Preferences](./features/21-settings-preferences.md) |
| Onboarding, Help & Education | A strong first-run and ongoing-help layer beyond the language wizard: a demo/sample vehicle, guided tour, contextual education for complex features (TCO, full-to-full economy, calendars), in-app searchable help/FAQ, and importer-first onboarding to convert competitor users — all localized and accessible. | [Onboarding, Help & Education](./features/25-onboarding-help.md) |

## Cross-cutting systems

- **Shared odometer / engine-hour ledger** — a single monotonic per-vehicle reading timeline written by fuel, service, expense, trip, and tire entries and read by reminders, stats, tires, warranties, and financing, with source tracking, cluster-swap offsets, rollover handling, regression validation, and average-daily-distance projection.
- **Canonical units & currency model** — all measures stored in one base unit (SI distance/volume, ISO/UTC dates, base currency) with per-vehicle and per-record overrides, converting only at display and export to prevent rounding drift and gallon/L-per-100km↔mpg corruption; multi-currency uses dated offline rate snapshots.
- **Attachments & media pipeline** — photos, receipts, scans, PDFs, and dashcam clips attach to any record, compressed with thumbnails/transcode, stored app-private and optionally encrypted, size-accounted, orphan-cleaned, and bundled and re-linked inside the full backup.
- **Local notification engine** — one offline scheduler serving maintenance, document/legal, tire, warranty, budget, trip, parking-meter, LPG re-cert, 12V-battery, and emission-sticker reminders with multi-trigger logic, projection-based scheduling, grouped digests, per-severity channels, quiet hours, iOS 64-pending rotation, and Android boot/exact-alarm handling.
- **Multi-vehicle & multi-driver scoping** — a persistent active-vehicle selector plus per-vehicle / per-driver / all-vehicles / fleet toggles across dashboards, stats, reminders, expenses, and reports, with vehicle-named notifications and retained-but-excluded archived/sold/stolen/written-off vehicles.
- **Household peer-to-peer sync** — under the no-account model, two devices on one shared car reconcile via QR/Wi-Fi Direct/NFC using UUID + tombstone + updated_at, with pre-sync snapshot, dry-run, deterministic conflict resolution, and record-count reconciliation — no cloud required.
- **Backup / export coverage of every entity** — every module's records, settings, live-state reminders, and attachments included in the single-file backup, per-entity CSV, and combined JSON, with schema/format versioning, checksums, merge-aware restore, trash/undo, and self-hosted/SD-card/opt-in-cloud targets.
- **RTL, bidi, calendar & numeral rendering** — a shared layer mirrors layouts via logical properties, bidi-isolates numbers/units/IDs, keeps VIN/plate/phone/IBAN LTR, converts four calendars from canonical dates, shapes four numeral systems with correct grouping (incl. lakh/crore), and bundles covering fonts including Nastaliq — applied to screens, charts, notifications, help, and exports.
- **Accessibility layer** — shared infrastructure for screen-reader labels and correct RTL reading order, dynamic-type reflow, high-contrast and colour-blind-safe palettes with non-colour encodings, reduced-motion, minimum touch targets, and focus management, validated by a QA harness paired with the i18n/pseudolocale harness.
- **Offline maps & location** — a bundled/vector map layer renders pins and route polylines for trips, parking, find-my-car, stations, and incidents, with region caching and compass/distance fallback where uncached, and no dependency on online routing or reverse geocoding.
- **Data integrity & validation** — shared guardrails detect odometer regression/rollover/duplicates, over-capacity fuel volumes, outlier economy, out-of-order/backdated entries, and import duplicates, warning with override while preserving the partial/missed/full-tank flags that downstream statistics depend on.
- **Offline-honesty degradation** — features that inherently need connectivity (recall/VIN decode, live fuel prices, charging tariffs, reverse geocoding, FX, zone/schedule updates) cache last results with "last checked" timestamps, offer bundled/manual equivalents, and never block offline logging or claim real-time data.
- **Security, app-lock & encryption** — optional at-rest database and attachment encryption, PIN/passcode plus biometric unlock with hardware-keystore keys and PIN fallback, sensitive-section scoping, redaction in handover exports, and secure wipe.
- **Autosave & data-loss prevention** — transactional writes, in-progress draft autosave, back/exit confirmation, user-facing trash/undo, pre-restore/pre-migration/pre-sync snapshots, and scheduled local backups that directly counter the field's most damaging failure: losing years of data on reinstall, update, sync, or a bad restore.
- **Category, tag & taxonomy system** — a shared, fully custom taxonomy (service types, expense/trip categories, tags, cost-centres/projects) with icons/colors/default intervals and analytic bucket mapping underpinning entry, filtering, budgets, fleet allocation, and reporting, with user content preserved and searchable across languages.
- **Financing, warranty & TCO backbone** — a shared financial layer (loan/lease amortization, depreciation curves, warranty date+mileage limits, insurance/claims netting) feeding the TCO engine, repair-or-replace helper, warranty-compliance dashboard, and final close-out, so financial truth is consistent across expenses, insurance, fleet, and disposal.
- **Fast capture & OCR/scan pipeline** — VIN barcode/QR scanning, license-plate OCR, and receipt/document OCR prefill feed vehicle setup, expenses, and documents, reducing entry friction with graceful manual fallback and fully on-device processing.

## What makes it the most complete

- **Offline-first and account-free, with real data ownership** — free first-class full backup/export/import, trash/undo, self-hosted (WebDAV/Nextcloud/SFTP/SD-card) targets, and household peer-to-peer sync — directly answering the #1 documented failure across Fuelly, aCar, CARFAX, Simply Auto, and AUTOsist: catastrophic data loss on forced accounts, sync, and reinstall.
- **The deepest localization on the market** — six fully-QA'd launch languages with true RTL, expanding to a broad roster, with four calendars, four numeral systems including Indian lakh/crore grouping, and per-preference multi-unit/multi-currency — a combination no mainstream competitor approaches.
- **Accessibility as a genuine differentiator** — screen-reader support in RTL, dynamic type resilient to Arabic/German/Russian expansion, colour-blind-safe charts, high-contrast, and reduced-motion — inclusive design most car apps ignore entirely.
- **One unified energy engine** — an EV charge session treated as the analogue of a fill-up, giving first-class ICE + diesel + LPG/CNG + EV + PHEV support with blended cost-per-distance, home vs public tariffs, charging losses, battery State-of-Health, and EV-vs-ICE break-even that legacy trackers do poorly or not at all.
- **A true on-device Total-Cost-of-Ownership engine** — fuel + service + other + financing interest + depreciation, normalized to a base currency, extended with full loan/lease amortization, early-payoff/refinance/negative-equity, and a repair-or-replace helper — where most rivals stop at fuel and ignore depreciation.
- **Correct fuel-economy math** — a precise partial/full/missed/first-fill state machine that eliminates the "wrong MPG" complaints plaguing Drivvo and Fuelly.
- **Reminders done right** — dual/triple-trigger (date + distance + engine-hours) with projection-based offline scheduling, grouped digests, and reliability engineering for iOS 64-pending, Android Doze, and OEM battery-killers, surviving backup/restore and re-arming.
- **Native, first-class tire management** — per-position multi-point tread, pressure, TPMS, DOT-age, rotation, alignment/balancing, and seasonal sets with automatic per-set mileage accrual, storage, and cost-per-km — a guaranteed core, not a thin seasonal tracker.
- **An encrypted digital glovebox with red/amber/green compliance** — plus a full insurance/claims/warranty workflow (FNOL→adjuster→payout vs deductible, no-claims bonus, and proof the required schedule keeps warranty valid), including LPG/CNG re-cert and emission-zone stickers.
- **Breadth no competitor combines** — Fleet/Business (BIK, cost-centre, grey-fleet, fuel-card, VAT, per-driver P&L), Rideshare/Gig/Rental economics, a Modifications/build log, Cross-Border/travel-compliance with bundled emission-zone data, a bundled offline map layer, an at-scene accident wizard with dashcam clips, and a guided Sell/Dispose workflow with bill-of-sale and odometer disclosure.
- **A components tier competitors omit** — 12V starter-battery health, keys/fobs and fob-battery tracking, wear-item lifecycle, and consumables/spare-parts inventory, distinct from EV traction-battery health.
- **Frictionless capture and switching** — VIN barcode/QR scan, plate/receipt OCR, and importer-first onboarding with column mapping and unit/locale/full-tank detection for Fuelio, Drivvo, aCar, and Fuelly, plus a demo vehicle and guided tour — turning disgruntled competitor users into an acquisition channel.
- **Everything editable and fully custom** — no ads ever, buy-once instead of subscription, and low-friction entry (optional mileage/cost, autosave, back-warnings) — fixing the exact editability, paywall, ad, and data-loss complaints that fill competitor reviews.

## Architecture at a glance

Car and Pain is built around a device-resident core, so the network is never on the critical path.

- **On-device database** — a single local (encrypted SQLite) database holds every record; there is no server of record and no account. The app is fully functional the moment it is installed.
- **Canonical storage** — every measurement is persisted once, canonically: SI units for distance and volume, UTC/ISO-8601 for dates, and a single base currency for money. Display units, calendar, numerals, and currency are conversions applied at render and export time only, which is why switching any of them never rewrites or corrupts history.
- **Attachments pipeline** — photos, receipts, PDFs, and dashcam clips attach to any record, are compressed with generated thumbnails and transcoded where needed, stored app-private and optionally encrypted, size-accounted and orphan-cleaned, and bundled with stable references so they re-link inside a full backup and round-trip across devices and OSes.
- **Local notification engine** — one offline scheduler drives all reminders using date, distance, engine-hour, and whichever-first triggers with projection-based distance scheduling. It is engineered to survive reboot, Doze, OEM battery-killers, and app-kill, to rotate within the iOS 64-pending limit, to re-arm after a restore, and to offer battery-optimization guidance where the OS interferes.
- **Backup & export formats** — a versioned, checksummed single-file full backup (records + settings + live reminder state + attachments), plus per-entity CSV and combined JSON, with merge-aware non-destructive restore, trash/undo, and a competitor-import wizard.
- **Sync options — all strictly optional** — the app needs none of these to work, and none is a cloud account:
  - **Self-hosted / non-cloud targets** — WebDAV, Nextcloud, SFTP, or an Android SD card, for privacy-first users who reject third-party clouds.
  - **Manual cloud file** — if you choose, drop the backup file into your own Drive/iCloud/Dropbox/OneDrive; the app never mandates or manages an account.
  - **Household peer-to-peer** — two phones on one shared car reconcile directly over QR/Wi-Fi Direct/NFC using UUID + tombstone + updated_at, with a pre-sync snapshot, dry-run, and deterministic conflict resolution — no cloud in the loop.

## Languages & directions

The launch tier ships fully translated and QA'd across both writing directions; the planned expansion broadens the roster after launch.

| Tier | Language | Script direction |
| --- | --- | --- |
| Launch | English | LTR |
| Launch | German | LTR |
| Launch | French | LTR |
| Launch | Persian / Farsi | RTL |
| Launch | Arabic | RTL |
| Launch | Sorani Kurdish | RTL |
| Planned | Spanish, Italian, Portuguese, Turkish, Russian, Hindi, Kurmanji Kurdish | LTR |
| Planned | Hebrew, Urdu / Nastaliq | RTL |

**Calendars:** Gregorian, Jalali/Shamsi, Hijri, and Hebrew — all converted from the same canonical UTC/ISO dates.

**Numeral systems:** Western, Eastern-Arabic, Persian, and Devanagari digits, with correct grouping including Indian lakh/crore.

Every preference — language, calendar, numerals, units, and currency — is set independently and is decoupled from the device locale, and all of it works 100% offline.

## Documentation index

### Features

- [Vehicles, Garage & Odometer](./features/01-vehicles-garage.md)
- [Fuel & Energy](./features/02-fuel-energy.md)
- [Service & Maintenance](./features/03-service-maintenance.md)
- [Reminders & Notifications](./features/04-reminders-notifications.md)
- [Expenses & Cost of Ownership](./features/05-expenses-cost-ownership.md)
- [Trips & Mileage Logbook](./features/06-trips-mileage.md)
- [Tires, Wheels & Seasonal](./features/07-tires-wheels.md)
- [Documents, Glovebox & Compliance](./features/08-documents-compliance.md)
- [Insurance, Claims & Warranty Compliance](./features/09-insurance-claims-warranty.md)
- [Fleet, Business & Company-Car](./features/10-fleet-business.md)
- [Rideshare, Gig & Rental Economics](./features/11-rideshare-gig-rental.md)
- [Modifications & Build Log](./features/12-modifications-build-log.md)
- [Cross-Border, Travel & Emission Zones](./features/13-cross-border-travel.md)
- [Offline Maps & Location](./features/14-maps-location.md)
- [Drivers, Household & Sharing](./features/15-drivers-household.md)
- [Components, Batteries, Keys & Consumables](./features/16-components-consumables.md)
- [Dashboard, Statistics & Reports](./features/17-dashboard-statistics-reports.md)
- [Data, Offline, Backup & Portability](./features/18-data-offline-backup.md)
- [Localization, RTL & Calendars](./features/19-localization-rtl.md)
- [Accessibility & Inclusive Design](./features/20-accessibility.md)
- [Settings & Preferences](./features/21-settings-preferences.md)
- [Safety, Incidents & Roadside](./features/22-safety-incidents-roadside.md)
- [Reference, Diagnostics & Recalls](./features/23-reference-diagnostics.md)
- [Sell, Dispose & Ownership Transfer](./features/24-sell-dispose.md)
- [Onboarding, Help & Education](./features/25-onboarding-help.md)

### Reference

- [Canonical Data Model & Schema](./reference/data-model.md)
- [Glossary, Units, Calendars & Conventions](./reference/glossary.md)

## Build tiers / roadmap

The roadmap is layered so the owner's core asks and the enablers that make them trustworthy ship first, with the specialized and commercial depth following.

### MVP — the owner's core asks + enablers

The essentials every owner needs on day one, plus the foundations that keep the data correct and portable:

- **Owner's core asks:** [Fuel & Energy](./features/02-fuel-energy.md), [Service & Maintenance](./features/03-service-maintenance.md), [Reminders & Notifications](./features/04-reminders-notifications.md), [Expenses & Cost of Ownership](./features/05-expenses-cost-ownership.md), and [Trips & Mileage Logbook](./features/06-trips-mileage.md).
- **Enablers:** [Vehicles, Garage & Odometer](./features/01-vehicles-garage.md), [Data, Offline, Backup & Portability](./features/18-data-offline-backup.md), and [Localization, RTL & Calendars](./features/19-localization-rtl.md) — the multi-vehicle garage, the data-ownership foundation, and the localization engine that the promises rest on.

### Tier 2 — completeness & compliance

The features that turn a solid logger into the "most complete" ownership app:

- [Tires, Wheels & Seasonal](./features/07-tires-wheels.md)
- [Documents, Glovebox & Compliance](./features/08-documents-compliance.md)
- [Insurance, Claims & Warranty Compliance](./features/09-insurance-claims-warranty.md)
- [Components, Batteries, Keys & Consumables](./features/16-components-consumables.md)
- [Dashboard, Statistics & Reports](./features/17-dashboard-statistics-reports.md)
- [Accessibility & Inclusive Design](./features/20-accessibility.md)
- [Settings & Preferences](./features/21-settings-preferences.md)
- [Safety, Incidents & Roadside](./features/22-safety-incidents-roadside.md)
- [Offline Maps & Location](./features/14-maps-location.md)
- [Drivers, Household & Sharing](./features/15-drivers-household.md)
- [Onboarding, Help & Education](./features/25-onboarding-help.md)

### Tier 3 — specialized segments & lifecycle depth

The modules serving specific audiences and the ends of the ownership lifecycle:

- [Fleet, Business & Company-Car](./features/10-fleet-business.md)
- [Rideshare, Gig & Rental Economics](./features/11-rideshare-gig-rental.md)
- [Modifications & Build Log](./features/12-modifications-build-log.md)
- [Cross-Border, Travel & Emission Zones](./features/13-cross-border-travel.md)
- [Reference, Diagnostics & Recalls](./features/23-reference-diagnostics.md)
- [Sell, Dispose & Ownership Transfer](./features/24-sell-dispose.md)

---

**Reference:** [Canonical Data Model & Schema](./reference/data-model.md) · [Glossary, Units, Calendars & Conventions](./reference/glossary.md)
