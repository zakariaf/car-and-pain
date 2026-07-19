# 📋 Build Plan — Epics & Tasks

This is the build plan for **Car and Pain** — _less pain, more car, 100% offline_ — a buy-once, account-free, offline-first vehicle-ownership app with deep localization (LTR en/de/fr + RTL fa/ar/ckb), four calendars, multiple numeral systems, first-class accessibility, and no ads or telemetry. Work is organized into **epics**, grouped by **tier** (delivery milestone).

The **Foundation** and **MVP** tiers are planned in **full detail** — every epic has its own spec under [`./epics/`](./epics/) covering goals, scope, tasks, and acceptance. The **Tier 2** and **Tier 3** tiers are **outlined** as a backlog: each epic has a goal and dependencies here and a short entry in the tier backlog files, to be expanded into full epic specs when its milestone is picked up.

- 🗺️ **Roadmap & sequencing** → [`./00-roadmap.md`](./00-roadmap.md)
- 🔗 **Dependencies & resolved decisions** → [`./01-dependencies-and-decisions.md`](./01-dependencies-and-decisions.md)

> **Note:** the Tier 2 / Tier 3 backlog lives here as repo Markdown ([`./tier-2-backlog.md`](./tier-2-backlog.md), [`./tier-3-backlog.md`](./tier-3-backlog.md)) and can be synced to an external tracker (Linear, GitHub Issues, etc.) later.

---

## 🧱 Foundation — _detailed_

Ship the offline-first foundation every feature stands on: scaffold + kernel, the encrypted canonical data layer with the shared odometer ledger, the PULSE design system, the i18n/RTL/calendars/numerals engine, the local notification engine, backup/export/import + key recovery, security & app-lock, and the attachments/media pipeline.

| ID | Epic | Depends on | Goal |
| --- | --- | --- | --- |
| **F1** | [Project scaffold, tooling & app kernel](./epics/F1-project-scaffold-tooling-app-kernel.md) | — | Feature-first modular monolith on a Dart pub workspace with Melos, lints, CI/CD and flavors, plus the Riverpod DI graph, the sealed Result/Failure kernel, and async-initialized bootstrap — honoring the built-in-first/minimal-dependency policy. |
| **F2** | [Encrypted data layer, canonical model & odometer ledger](./epics/F2-encrypted-data-layer-canonical-model-odomete.md) | F1 | Drift-over-encrypted-SQLite: SQLCipher-keyed DB, canonical SI units and ISO-4217 minor-unit money, the shared odometer/engine-hour ledger, forward-only migrations, soft-delete/trash, the custom taxonomy, and data-integrity validation. |
| **F3** | [PULSE design system implementation](./epics/F3-pulse-design-system-implementation.md) | F1 | Warm-paper/ink dual-theme tokens and Persian-miniature palette, the urgency scale with always-redundant non-colour encoding, the single breathing vital and capped ambient halo, the exhale interaction, and Rooms scaffolding — theme- and RTL-aware, CustomPainter charts (no chart lib). |
| **F4** | [i18n / RTL / calendars / numerals engine](./epics/F4-i18n-rtl-calendars-numerals-engine.md) | F1, F2 | gen-l10n ARB pipeline for LTR(en/de/fr)+RTL(fa/ar/ckb), app-controlled locale persisted in the encrypted DB, own Gregorian/Jalali/Hijri/Hebrew conversion math, Western/Eastern-Arabic/Persian numeral shaping with Indian grouping, bidi-isolation, and bundled script fonts. |
| **F5** | [Local notification engine](./epics/F5-local-notification-engine.md) | F1, F2, F4 | One offline scheduler on flutter_local_notifications zonedSchedule (+timezone) with the DB as source of truth: date, distance-projection, engine-hour and whichever-first triggers, grouped digests, per-severity channels, and reboot/Doze/exact-alarm survival. |
| **F6** | [Backup, export/import & key recovery](./epics/F6-backup-export-import-key-recovery.md) | F1, F2, F7, F8 | WAL-checkpointed VACUUM INTO single-file AES-GCM backups (Argon2id key) that round-trip attachments, per-entity CSV and JSON export, a merge-aware import wizard with competitor presets, schema/format versioning + checksums, and passphrase-wrapped master-key recovery with a one-time recovery code. |
| **F7** | [Security, encryption & app-lock](./epics/F7-security-encryption-app-lock.md) | F1, F2 | Three-layer security: mandatory whole-DB AES-256 at rest, a random 256-bit master key recoverable by default via an Argon2id passphrase KEK, hardware-keystore-backed biometric/PIN daily unlock with PIN fallback, sensitive-section scoping, and redaction in handover exports. |
| **F8** | [Attachments & media pipeline](./epics/F8-attachments-media-pipeline.md) | F1, F2 | The cross-cutting media backbone: photos/receipts/scans/PDFs/dashcam clips attach polymorphically to any record, are compressed with thumbnails/transcode, stored app-private (optionally encrypted), size-accounted, orphan-cleaned, and bundled + re-linked through backup/restore. |

---

## 🚀 MVP — _detailed_

A daily-usable, buy-once app: the PULSE breathing-vital Home + Cockpit/Garage/Pit-lane Rooms shell over the multi-vehicle garage, fuel/energy, service, reminders, expenses/TCO, trips, dashboard/reports, settings, and first-run onboarding.

| ID | Epic | Depends on | Goal |
| --- | --- | --- | --- |
| **M1** | [App shell, Rooms navigation & PULSE vitals Home](./epics/M1-app-shell-rooms-navigation-pulse-vitals-home.md) | F1, F2, F3, F4 | A go_router StatefulShellRoute.indexedStack Rooms shell (Cockpit/Garage/Pit-lane) with per-tab master-detail stacks and full-screen flows above it, the persistent active-vehicle selector, and the PULSE single breathing-vital Home with no visible list. |
| **M2** | [Vehicles, Garage & Odometer](./epics/M2-vehicles-garage-odometer.md) | F2, F3, F4, F6, F8, M1 | The account-free unlimited multi-vehicle garage: powertrain-adaptive profiles, full lifecycle states, VIN capture with offline decode, per-vehicle unit/currency overrides, audited cluster-swap/rollover events, and the odometer/engine-hour ledger UI. |
| **M3** | [Fuel & Energy](./epics/M3-fuel-energy.md) | F2, F3, F4, F6, M2 | The unified energy entry-and-economy engine: petrol/diesel/LPG/CNG/ethanol/hydrogen fills and EV/PHEV charge sessions with correct full/partial/missed/first-fill economy math, EV break-even vs ICE, canonical storage, and PULSE entry + economy visualizations. |
| **M4** | [Service & Maintenance](./epics/M4-service-maintenance.md) | F2, F3, F4, F6, F8, M2 | A complete, editable service history: multi-line-item visits mapped to one receipt, fully custom service types, parts with part numbers and warranties, DIY procedure logs, bundled offline schedule templates, and appointment/next-due reminders. |
| **M5** | [Reminders & Notifications](./epics/M5-reminders-notifications.md) | F2, F3, F4, F5, F6, M2 | The user-facing reminders layer on the foundation engine: date/distance/engine-hour/whichever-first rules, odometer-freshness projection into schedulable dates, grouped digests, per-severity channels, and PULSE reminder surfaces with the exhale on completion. |
| **M6** | [Expenses & Cost of Ownership](./epics/M6-expenses-cost-of-ownership.md) | F2, F3, F4, F6, F8, M2 | Capture every car cost: rich + custom categories, recurring and amortized bills, budgets with real alerts, full loan/lease amortization (early-payoff/refinance/negative-equity), depreciation, and a true on-device TCO engine. |
| **M7** | [Trips & Mileage Logbook](./epics/M7-trips-mileage-logbook.md) | F2, F3, F4, F6, M2 | Manual and optional on-device-GPS trip logging: business/personal tax classification, effective-dated IRS/HMRC/custom rate engines, odometer-gap reconciliation, and a road-trip mode linking fuel and expenses — degrading honestly without the Tier-2 offline map. |
| **M8** | [Dashboard, Statistics & Reports](./epics/M8-dashboard-statistics-reports.md) | F2, F3, F4, F6, M1, M3, M6, M7 | The on-device analytics layer populating the Rooms: glanceable customizable KPIs + quick-add, fuel-economy/cost/distance/CO2 CustomPainter charts, insights and anomaly detection, forecasting with a min-samples fallback, gamification, and a localized report export. |
| **M9** | [Settings & Preferences](./epics/M9-settings-preferences.md) | F2, F3, F4, F5, F6, F7, M1 | The central control surface tying every cross-cutting preference together: language, units, currency, calendar and numerals, accessibility, notification behavior, security and app-lock, and backup scheduling (incl. self-hosted) — resolving through the canonical precedence model. |
| **M10** | [Onboarding, Help & Education](./epics/M10-onboarding-help-education.md) | F2, F3, F4, F5, M1, M2 | A strong first-run and ongoing-help layer beyond the language wizard: guided permission/OEM-survival onboarding, a demo/sample vehicle, a guided tour, contextual education for complex features (TCO, full-to-full economy, calendars), and searchable in-app help/FAQ — all offline. |

---

## 🧩 Tier 2 — _outlined_

Round out the ownership stack rivals leave open: tires/seasonal, documents/compliance glovebox, insurance/claims/warranty, components/consumables, safety/incidents/roadside, the shared offline map layer, drivers/household, and hardened cross-cutting accessibility.

| ID | Epic | Depends on | Goal |
| --- | --- | --- | --- |
| **T2-1** | [Tires, Wheels & Seasonal](./tier-2-backlog.md#t2-1) | F2, F3, F4, F5, F6, F8, M2 | First-class native tire management: multiple named sets, seasonal changeover with automatic per-set mileage accrual, rotation, per-position multi-point tread and pressure, TPMS, and DOT-age safety alerts. |
| **T2-2** | [Documents, Glovebox & Compliance](./tier-2-backlog.md#t2-2) | F2, F3, F4, F5, F6, F7, F8, M2 | The encrypted digital glovebox plus the compliance stack — registration, road tax, localized technical inspection, emissions, driver license, recurring legal/safety items — unified with reminders and sensitive-section scoping. |
| **T2-3** | [Insurance, Claims & Warranty Compliance](./tier-2-backlog.md#t2-3) | F2, F3, F4, F5, F6, F8, M2, M6 | The financial-protection stack: multi-policy insurance with premium history and no-claims bonus, a full claims lifecycle (FNOL → adjuster → authorisation → payout vs deductible), and a warranty-compliance dashboard. |
| **T2-4** | [Components, Batteries, Keys & Consumables](./tier-2-backlog.md#t2-4) | F2, F3, F4, F5, F6, F8, M2 | Track the discrete parts and consumables that outlive a service visit — the 12V starter battery, keys/fobs, wear items with lifecycle, fluids and spare-parts inventory — each with its own reminders and warranty. |
| **T2-5** | [Safety, Incidents & Roadside](./tier-2-backlog.md#t2-5) | F2, F3, F4, F6, F7, F8, M2 | First-class tooling for the worst moments: accident/damage records with photos and dashcam clips, an at-scene guided capture wizard, a shareable roadside emergency card and ICE info — usable with zero signal and sensitive-section scoped. |
| **T2-6** | [Offline Maps & Location](./tier-2-backlog.md#t2-6) | F2, F3, F4, F6, M7 | A shared bundled/vector offline map layer rendering pins and route polylines for trips, parking saver, find-my-car, stations and incidents — with region caching and compass/distance fallback where uncached. |
| **T2-7** | [Drivers, Household & Sharing](./tier-2-backlog.md#t2-7) | F2, F3, F4, F6, M2, M6, M7 | A coherent multi-driver/household model — per-driver profiles, assignment, and P&L — plus the schema groundwork for later household peer-to-peer sync (UUID + tombstone + updated_at) under the no-account design. |
| **T2-8** | [Accessibility & Inclusive Design](./tier-2-backlog.md#t2-8) | F3, F4, M1 | Harden accessibility as a first-class cross-cutting concern: screen-reader support (incl. RTL reading order), dynamic type/font-scaling reflow, high-contrast and colour-blind-safe palettes with non-colour encodings, reduced-motion, and minimum touch targets. |

---

## 🛠️ Tier 3 — _outlined_

Serve specialist and end-of-life needs: fleet/business/company-car, rideshare/gig/rental economics, the modifications build log, cross-border travel & emission zones, offline reference/diagnostics/recalls, and the guided sell/dispose transfer.

| ID | Epic | Depends on | Goal |
| --- | --- | --- | --- |
| **T3-1** | [Fleet, Business & Company-Car](./tier-3-backlog.md#t3-1) | F2, F3, F4, F6, M6, M7, T2-7 | The commercial-use and company-car layer: Benefit-in-Kind tax, cost-centre/department/project allocation, grey-fleet, fuel-card reconciliation, VAT-reclaim workflow, and mileage claims. |
| **T3-2** | [Rideshare, Gig & Rental Economics](./tier-3-backlog.md#t3-2) | F2, F3, F4, F6, M6, M7 | A dedicated mode for the underserved commercial-use segment: per-platform income vs cost, business-use percentage from mixed trips, per-job/per-shift profitability, platform-fee tracking, and rental (Turo/peer-to-peer) hosting economics. |
| **T3-3** | [Modifications & Build Log](./tier-3-backlog.md#t3-3) | F2, F3, F4, F6, F8, M2 | Structured tracking for enthusiasts, project cars and restoration builds: aftermarket/OEM+ parts with install date/odometer, before/after specs, dyno/power figures, reversibility notes, and build media galleries. |
| **T3-4** | [Cross-Border, Travel & Emission Zones](./tier-3-backlog.md#t3-4) | F2, F3, F4, F5, F6, T2-2, T2-6 | The coherent home for driving abroad: emission-zone stickers, vignettes and e-toll transponder accounts, per-country required-equipment and driving-rules reference, IDP/green-card documents, and temporary import/export. |
| **T3-5** | [Reference, Diagnostics & Recalls](./tier-3-backlog.md#t3-5) | F2, F3, F4, F6, M2 | Offline automotive knowledge plus optional local diagnostics: bundled generic maintenance-schedule templates, warning-light and DTC dictionaries as guaranteed offline content, a check-engine event log, and offline VIN decode. |
| **T3-6** | [Sell, Dispose & Ownership Transfer](./tier-3-backlog.md#t3-6) | F2, F3, F4, F6, M2, M6 | A guided end-of-ownership workflow: de-registration and insurance/tax cancellation checklists, bill-of-sale and odometer-disclosure generation, a redacted handover pack, and final TCO close-out. |
