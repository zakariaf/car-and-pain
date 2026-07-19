# 📚 Car and Pain — Documentation

Everything about **Car and Pain**, the offline-first car-ownership app. Start with the overview, then dive into any feature.

> **New here?** Read the **[Product Overview & Architecture](overview.md)** first — it explains the whole app, its promises, and how the pieces fit together.

---

## 🧭 Start here

- **[Product Overview & Architecture](overview.md)** — the high-level picture: what the app is, who it's for, the design principles, and the technical shape.

## ⭐ Core features (the everyday five)

These are the reasons the app exists — the pain every owner feels.

| # | Feature | In one line |
|---|---------|-------------|
| 02 | **[Fuel & Energy](features/02-fuel-energy.md)** | Log every fill/charge and get correct consumption for petrol, diesel, LPG/CNG, EV & PHEV. |
| 03 | **[Service & Maintenance](features/03-service-maintenance.md)** | A complete, searchable history of every service, part and repair. |
| 04 | **[Reminders & Notifications](features/04-reminders-notifications.md)** | Be warned **1 week** or **1,000 km** before anything is due. |
| 05 | **[Expenses & Cost of Ownership](features/05-expenses-cost-ownership.md)** | Track every cost and see what the car *really* costs you. |
| 06 | **[Trips & Mileage Logbook](features/06-trips-mileage.md)** | Record each trip's distance, fuel and expenses — road-trip ready. |

## 🚙 Garage & assets

| # | Feature | In one line |
|---|---------|-------------|
| 01 | **[Vehicles, Garage & Odometer](features/01-vehicles-garage.md)** | Unlimited multi-vehicle garage and the shared odometer ledger. |
| 07 | **[Tires, Wheels & Seasonal](features/07-tires-wheels.md)** | Seasonal sets, rotation, tread, pressure, TPMS and per-set mileage. |
| 16 | **[Components, Batteries, Keys & Consumables](features/16-components-consumables.md)** | 12V battery health, keys/fobs, wear items and spare-parts inventory. |

## 💸 Money & business

| # | Feature | In one line |
|---|---------|-------------|
| 10 | **[Fleet, Business & Company-Car](features/10-fleet-business.md)** | BIK, cost-centres, grey-fleet, fuel-card and VAT for work vehicles. |
| 11 | **[Rideshare, Gig & Rental Economics](features/11-rideshare-gig-rental.md)** | Per-shift/per-trip profit for gig and rental drivers. |

## 🛡️ Documents & compliance

| # | Feature | In one line |
|---|---------|-------------|
| 08 | **[Documents, Glovebox & Compliance](features/08-documents-compliance.md)** | Encrypted glovebox with a red/amber/green expiry dashboard. |
| 09 | **[Insurance, Claims & Warranty](features/09-insurance-claims-warranty.md)** | Policies, claims (FNOL→payout) and keeping warranties valid. |
| 13 | **[Cross-Border, Travel & Emission Zones](features/13-cross-border-travel.md)** | Travel-ready compliance and bundled emission-zone data. |
| 22 | **[Safety, Incidents & Roadside](features/22-safety-incidents-roadside.md)** | At-scene accident wizard, dashcam clips and roadside info. |
| 23 | **[Reference, Diagnostics & Recalls](features/23-reference-diagnostics.md)** | Spec reference, warning-light guide and recall records. |

## 🔧 Specialized modules

| # | Feature | In one line |
|---|---------|-------------|
| 12 | **[Modifications & Build Log](features/12-modifications-build-log.md)** | Track mods, upgrades and the build story of a project car. |
| 15 | **[Drivers, Household & Sharing](features/15-drivers-household.md)** | Multiple drivers, household roles and peer-to-peer sharing. |
| 24 | **[Sell, Dispose & Ownership Transfer](features/24-sell-dispose.md)** | Guided sale with bill-of-sale and odometer disclosure. |

## 📊 Insight

| # | Feature | In one line |
|---|---------|-------------|
| 17 | **[Dashboard, Statistics & Reports](features/17-dashboard-statistics-reports.md)** | KPIs, trend charts, insights and printable PDF/CSV reports. |

## 🌍 Platform & experience

| # | Feature | In one line |
|---|---------|-------------|
| 14 | **[Offline Maps & Location](features/14-maps-location.md)** | Bundled offline map for trips, parking and find-my-car. |
| 18 | **[Data, Offline, Backup & Portability](features/18-data-offline-backup.md)** | The offline engine, full backup, and export/import. |
| 19 | **[Localization, RTL & Calendars](features/19-localization-rtl.md)** | 6 launch languages, full RTL, and 3+ calendars. |
| 20 | **[Accessibility & Inclusive Design](features/20-accessibility.md)** | Screen-reader, dynamic type, high-contrast, colour-blind-safe. |
| 21 | **[Settings & Preferences](features/21-settings-preferences.md)** | Units, currency, language, calendar, security and backup options. |
| 25 | **[Onboarding, Help & Education](features/25-onboarding-help.md)** | Guided setup, importers, demo vehicle and in-app help. |

---

## 📖 Reference

- **[Canonical Data Model & Schema](reference/data-model.md)** — entities, fields, relationships and export/import mapping.
- **[Glossary, Units, Calendars & Conventions](reference/glossary.md)** — terms, unit conversions, calendars, numerals and formulas.

---

### How these docs are organized

Each feature document follows the same shape: **the pain → what it does → features (must / should / nice-to-have) → data captured → calculations → offline & data → localization & RTL → edge cases → related features.** So you can jump into any one and know where to look.
