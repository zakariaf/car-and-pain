# Tier 2 Backlog

These are **outlines**, not final specs. Each epic below is captured at `detail_level: outline`
and is intended to be expanded into full task detail (acceptance criteria, schema, edge cases,
test matrices) **when the Tier 2 phase is actually reached**. Until then, treat the tasks as
scope markers layered over the shared Foundation and MVP backbone (ledger, reminder engine,
money model, backup/export, PULSE, i18n). Sizes (S/M/L) are rough estimates for sequencing only.

Tier 2 modules: `tires-wheels`, `documents-compliance`, `insurance-claims-warranty`,
`components-wear-consumables`, `safety-incidents-roadside`, `maps-location`,
`drivers-household`, `accessibility-inclusive-design`.

---

## T2-1 · Tires, Wheels & Seasonal

**Goal:** First-class native tire management: multiple named sets, seasonal changeover with
automatic per-set mileage accrual, rotation, per-position multi-point tread and pressure, TPMS,
and DOT-age safety alerts — over the shared ledger and reminder engine.

**Depends on:** F2, F3, F4, F5, F6, F8, M2

**References:**
- [../features/07-tires-wheels.md](../features/07-tires-wheels.md)
- [../flutter/07-notifications.md](../flutter/07-notifications.md)
- [../flutter/03-data-persistence.md](../flutter/03-data-persistence.md)
- [../design/pulse/02-components.md](../design/pulse/02-components.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks:**
- **T2-1-T1 — Tire-set & tire schema + repository** — Named sets with per-position tread/pressure/DOT and mileage accrual on the active set. — *M*
- **T2-1-T2 — Seasonal changeover & rotation logic** — Swap events, per-set accrual, and rotation scheduling. — *M*
- **T2-1-T3 — DOT-age & wear alerts** — Feed reminders (date plus tread/distance) and record TPMS entries. — *M*
- **T2-1-T4 — PULSE tire UI + i18n** — Per-position visual and set management with localized strings. — *M*
- **T2-1-T5 — Export/backup mapping + tests** — Tire entities plus accrual tests. — *S*

---

## T2-2 · Documents, Glovebox & Compliance

**Goal:** The encrypted digital glovebox plus the compliance stack — registration, road tax,
localized technical inspection, emissions, driver license, and recurring legal/safety items —
unified with reminders and sensitive-section scoping.

**Depends on:** F2, F3, F4, F5, F6, F7, F8, M2

**References:**
- [../features/08-documents-compliance.md](../features/08-documents-compliance.md)
- [../flutter/09-security-privacy.md](../flutter/09-security-privacy.md)
- [../flutter/07-notifications.md](../flutter/07-notifications.md)
- [../design/pulse/02-components.md](../design/pulse/02-components.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks:**
- **T2-2-T1 — Document schema & repository** — Typed compliance items with expiry dates, attachments and scoping. — *M*
- **T2-2-T2 — Compliance reminders** — Feed expiries to the notification engine with localized inspection/emissions variants. — *M*
- **T2-2-T3 — Encrypted glovebox UI** — Scanned docs behind re-auth with a PDF viewer and i18n. — *M*
- **T2-2-T4 — Export/backup mapping + redaction + tests** — Handover redaction flags and round-trip tests. — *S*

---

## T2-3 · Insurance, Claims & Warranty Compliance

**Goal:** The financial-protection stack: multi-policy insurance with premium history and
no-claims bonus, a full claims lifecycle (FNOL → adjuster → authorisation → payout vs deductible),
and a warranty-compliance dashboard on the shared financing/warranty backbone.

**Depends on:** F2, F3, F4, F5, F6, F8, M2, M6

**References:**
- [../features/09-insurance-claims-warranty.md](../features/09-insurance-claims-warranty.md)
- [../flutter/14-money-currency-fx.md](../flutter/14-money-currency-fx.md)
- [../flutter/07-notifications.md](../flutter/07-notifications.md)
- [../design/pulse/02-components.md](../design/pulse/02-components.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks:**
- **T2-3-T1 — Policy & premium schema + repository** — Multi-policy, premium history and no-claims bonus over the money model. — *M*
- **T2-3-T2 — Claims lifecycle** — FNOL → adjuster → authorisation → payout vs deductible state machine. — *M*
- **T2-3-T3 — Warranty compliance dashboard** — Date+mileage limits from the ledger with renewal reminders. — *M*
- **T2-3-T4 — PULSE UI + i18n** — Screens with localized strings. — *M*
- **T2-3-T5 — Export/backup mapping + tests** — Policy/claim/warranty entities plus tests. — *S*

---

## T2-4 · Components, Batteries, Keys & Consumables

**Goal:** Track the discrete parts and consumables that outlive a service visit — the 12V starter
battery, keys/fobs, wear items with lifecycle, fluids and spare-parts inventory — each with its
own reminders and warranty.

**Depends on:** F2, F3, F4, F5, F6, F8, M2

**References:**
- [../features/16-components-consumables.md](../features/16-components-consumables.md)
- [../flutter/07-notifications.md](../flutter/07-notifications.md)
- [../flutter/03-data-persistence.md](../flutter/03-data-persistence.md)
- [../design/pulse/02-components.md](../design/pulse/02-components.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks:**
- **T2-4-T1 — Component/consumable schema & repository** — Lifecycle, warranty and inventory counts. — *M*
- **T2-4-T2 — Per-component reminders** — 12V-battery and wear-item date+distance triggers. — *M*
- **T2-4-T3 — PULSE inventory UI + i18n** — Inventory screens with localized strings. — *M*
- **T2-4-T4 — Export/backup mapping + tests** — Component entities plus tests. — *S*

---

## T2-5 · Safety, Incidents & Roadside

**Goal:** First-class tooling for the worst moments: accident/damage records with photos and
dashcam clips, an at-scene guided capture wizard, a shareable roadside emergency card and ICE
info — usable with zero signal and sensitive-section scoped.

**Depends on:** F2, F3, F4, F6, F7, F8, M2

**References:**
- [../features/22-safety-incidents-roadside.md](../features/22-safety-incidents-roadside.md)
- [../flutter/09-security-privacy.md](../flutter/09-security-privacy.md)
- [../flutter/15-accessibility-dynamic-type.md](../flutter/15-accessibility-dynamic-type.md)
- [../design/pulse/03-screens.md](../design/pulse/03-screens.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks:**
- **T2-5-T1 — Incident schema & repository** — Damage records with photo/dashcam attachments and location (map-optional). — *M*
- **T2-5-T2 — At-scene capture wizard** — Guided offline capture flow with autosave and high-stress accessibility. — *M*
- **T2-5-T3 — Roadside/ICE card** — Shareable emergency card with sensitive-section scoping and redaction. — *M*
- **T2-5-T4 — PULSE UI + i18n + export/backup + tests** — Screens, localized copy, backup mapping and tests. — *M*

---

## T2-6 · Offline Maps & Location

**Goal:** A shared bundled/vector offline map layer rendering pins and route polylines for trips,
parking saver, find-my-car, stations and incidents — with region caching and compass/distance
fallback where uncached — closing the biggest '100% offline' hole.

**Depends on:** F2, F3, F4, F6, M7

**References:**
- [../features/14-maps-location.md](../features/14-maps-location.md)
- [../flutter/10-performance-rendering.md](../flutter/10-performance-rendering.md)
- [../flutter/16-permissions-onboarding-oem.md](../flutter/16-permissions-onboarding-oem.md)
- [../design/pulse/02-components.md](../design/pulse/02-components.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks:**
- **T2-6-T1 — Offline map rendering layer** — Bundled/vector tiles with pins and route polylines (subject to the size-budget decision). — *L*
- **T2-6-T2 — Location features** — Parking saver, find-my-car, station pins and compass/distance fallback. — *M*
- **T2-6-T3 — Trip/incident integration** — Upgrade trips and incidents from raw coordinates to the map. — *M*
- **T2-6-T4 — PULSE map UI + i18n + tests** — Map screens, localized strings and tests. — *M*

---

## T2-7 · Drivers, Household & Sharing

**Goal:** A coherent multi-driver/household model — per-driver profiles, assignment, and P&L —
plus the schema groundwork for later household peer-to-peer sync (UUID + tombstone + updated_at)
under the no-account design.

**Depends on:** F2, F3, F4, F6, M2, M6, M7

**References:**
- [../features/15-drivers-household.md](../features/15-drivers-household.md)
- [../flutter/03-data-persistence.md](../flutter/03-data-persistence.md)
- [../flutter/14-money-currency-fx.md](../flutter/14-money-currency-fx.md)
- [../design/pulse/02-components.md](../design/pulse/02-components.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks:**
- **T2-7-T1 — Driver schema & assignment** — Per-driver profiles with vehicle/trip attribution. — *M*
- **T2-7-T2 — Per-driver P&L** — Aggregate expenses and trips per driver. — *M*
- **T2-7-T3 — Sync-enabling schema** — device_origin_id/row_revision groundwork (P2P sync out of scope). — *M*
- **T2-7-T4 — PULSE UI + i18n + export/backup + tests** — Screens, localized copy, backup mapping and tests. — *M*

---

## T2-8 · Accessibility & Inclusive Design

**Goal:** Harden accessibility as a first-class cross-cutting concern: screen-reader support
(incl. RTL reading order), dynamic type/font-scaling reflow, high-contrast and colour-blind-safe
palettes with non-colour encodings, reduced-motion, and minimum touch targets — audited across
shipped screens.

**Depends on:** F3, F4, M1

**References:**
- [../features/20-accessibility.md](../features/20-accessibility.md)
- [../flutter/15-accessibility-dynamic-type.md](../flutter/15-accessibility-dynamic-type.md)
- [../design/pulse/04-motion-rtl-accessibility.md](../design/pulse/04-motion-rtl-accessibility.md)
- [../design/pulse/02-components.md](../design/pulse/02-components.md)
- [../reference/data-model.md](../reference/data-model.md)

**Tasks:**
- **T2-8-T1 — Screen-reader audit & fixes** — Semantics labels and RTL reading order across screens and charts. — *M*
- **T2-8-T2 — Dynamic type & reflow** — Font-scaling reflow and minimum touch targets. — *M*
- **T2-8-T3 — High-contrast & colour-blind modes** — Verify redundant encoding and reduced-motion. — *M*
- **T2-8-T4 — Accessibility test suite** — Automated a11y checks wired into CI. — *S*
