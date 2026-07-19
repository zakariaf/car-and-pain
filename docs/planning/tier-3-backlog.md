# Tier 3 Backlog

These entries are **outlines**, not full specifications. Each epic is captured here at outline detail-level so the tier's scope, dependencies, and reference material are pinned down. Each is intended to be **expanded into a detailed, task-by-task backlog when the tier is reached** — after the MVP and Tier 2 modules have landed and their foundations are proven. Sizes and task breakdowns are provisional and should be re-estimated at expansion time.

---

## T3-1 · Fleet, Business & Company-Car

**Goal:** The commercial-use and company-car layer: Benefit-in-Kind tax, cost-centre/department/project allocation, grey-fleet, fuel-card reconciliation, VAT-reclaim workflow, and mileage claims — over expenses, trips and drivers.

**Dependencies:** F2, F3, F4, F6, M6, M7, T2-7

**References:**
- [../features/10-fleet-business.md](../features/10-fleet-business.md)
- [../flutter/14-money-currency-fx.md](../flutter/14-money-currency-fx.md)
- [../flutter/03-data-persistence.md](../flutter/03-data-persistence.md)
- [../design/pulse/02-components.md](../design/pulse/02-components.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks (outline):**
- **Cost-centre/BiK schema & allocation** — Cost-centre/project taxonomy plus a Benefit-in-Kind tax model. — _M_
- **Fuel-card & VAT-reclaim workflow** — Reconciliation plus VAT-reclaim and mileage claims. — _M_
- **Grey-fleet & reporting** — Personal-car-for-business tracking and fleet reports. — _M_
- **PULSE UI + i18n + export/backup + tests** — Screens, localized copy, backup mapping and tests. — _M_

---

## T3-2 · Rideshare, Gig & Rental Economics

**Goal:** A dedicated mode for the underserved commercial-use segment: per-platform income vs cost, business-use percentage from mixed trips, per-job/per-shift profitability, platform-fee tracking, and rental (Turo/peer-to-peer) hosting economics.

**Dependencies:** F2, F3, F4, F6, M6, M7

**References:**
- [../features/11-rideshare-gig-rental.md](../features/11-rideshare-gig-rental.md)
- [../flutter/14-money-currency-fx.md](../flutter/14-money-currency-fx.md)
- [../design/pulse/02-components.md](../design/pulse/02-components.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks (outline):**
- **Platform income/cost schema** — Per-platform income vs cost and fees. — _M_
- **Profitability engine** — Per-job/per-shift P&L and business-use % from mixed trips. — _M_
- **Rental economics** — Turo/peer-to-peer hosting economics. — _M_
- **PULSE UI + i18n + export/backup + tests** — Screens, localized copy, backup mapping and tests. — _M_

---

## T3-3 · Modifications & Build Log

**Goal:** Structured tracking for enthusiasts, project cars and restoration builds: aftermarket/OEM+ parts with install date/odometer, before/after specs, dyno/power figures, reversibility notes, and build media galleries.

**Dependencies:** F2, F3, F4, F6, F8, M2

**References:**
- [../features/12-modifications-build-log.md](../features/12-modifications-build-log.md)
- [../flutter/03-data-persistence.md](../flutter/03-data-persistence.md)
- [../flutter/10-performance-rendering.md](../flutter/10-performance-rendering.md)
- [../design/pulse/02-components.md](../design/pulse/02-components.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks (outline):**
- **Modification schema & repository** — Parts with install date/odometer, before/after specs and reversibility. — _M_
- **Dyno/power figures & build timeline** — Power figures and a build-log timeline. — _M_
- **Media gallery** — Before/after galleries via attachments. — _S_
- **PULSE UI + i18n + export/backup + tests** — Screens, localized copy, backup mapping and tests. — _M_

---

## T3-4 · Cross-Border, Travel & Emission Zones

**Goal:** The coherent home for driving abroad: emission-zone stickers, vignettes and e-toll transponder accounts, per-country required-equipment and driving-rules reference, IDP/green-card documents, and temporary import/export — with reminders and the offline map.

**Dependencies:** F2, F3, F4, F5, F6, T2-2, T2-6

**References:**
- [../features/13-cross-border-travel.md](../features/13-cross-border-travel.md)
- [../flutter/07-notifications.md](../flutter/07-notifications.md)
- [../flutter/06-i18n-rtl-calendars.md](../flutter/06-i18n-rtl-calendars.md)
- [../design/pulse/02-components.md](../design/pulse/02-components.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks (outline):**
- **Travel-item schema & repository** — Stickers/vignettes/e-toll/import-export items with expiry. — _M_
- **Country reference content** — Bundled required-equipment and driving-rules with offline-honesty caching. — _M_
- **Reminders & map integration** — Vignette-expiry reminders plus an emission-zone map. — _M_
- **PULSE UI + i18n + export/backup + tests** — Screens, localized copy, backup mapping and tests. — _M_

---

## T3-5 · Reference, Diagnostics & Recalls

**Goal:** Offline automotive knowledge plus optional local diagnostics: bundled generic maintenance-schedule templates, warning-light and DTC dictionaries as guaranteed offline content, a check-engine event log, and offline VIN decode — with honest online-degradation for recall/full-VIN lookups.

**Dependencies:** F2, F3, F4, F6, M2

**References:**
- [../features/23-reference-diagnostics.md](../features/23-reference-diagnostics.md)
- [../flutter/03-data-persistence.md](../flutter/03-data-persistence.md)
- [../design/pulse/02-components.md](../design/pulse/02-components.md)
- [../reference/data-model.md](../reference/data-model.md)
- [../reference/glossary.md](../reference/glossary.md)

**Tasks (outline):**
- **Bundled reference content** — DTC and warning-light dictionaries plus schedule templates as offline assets. — _M_
- **Check-engine event log** — DTC event-log schema and repository. — _M_
- **Offline-honesty for recall/VIN** — Cache last results with a last-checked stamp and honest degradation. — _M_
- **PULSE UI + i18n + tests** — Reference screens, localized strings and tests. — _M_

---

## T3-6 · Sell, Dispose & Ownership Transfer

**Goal:** A guided end-of-ownership workflow: de-registration and insurance/tax cancellation checklists, bill-of-sale and odometer-disclosure generation, a redacted handover pack, and final TCO close-out — leaning on backup redaction and the TCO engine.

**Dependencies:** F2, F3, F4, F6, M2, M6

**References:**
- [../features/24-sell-dispose.md](../features/24-sell-dispose.md)
- [../flutter/13-backup-export-recovery.md](../flutter/13-backup-export-recovery.md)
- [../flutter/09-security-privacy.md](../flutter/09-security-privacy.md)
- [../design/pulse/03-screens.md](../design/pulse/03-screens.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks (outline):**
- **Disposal workflow & checklists** — De-registration and insurance/tax cancellation checklists with the lifecycle-state transition. — _M_
- **Document generation** — Bill-of-sale and odometer-disclosure generation. — _M_
- **Redacted handover pack** — Redacted export via the backup/redaction infra. — _M_
- **Final TCO close-out + i18n + tests** — Final TCO close-out, localized copy and tests. — _M_
