# 👥 Drivers, Household & Sharing

> One car, two phones, no account — and yet the fuel logs, the service history, and the costs all agree, without a cloud login ever standing between you and your own data.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Data, Offline, Backup & Portability](./18-data-offline-backup.md) · [Fleet, Business & Company-Car](./10-fleet-business.md) · [Rideshare, Gig & Rental Economics](./11-rideshare-gig-rental.md)

## The pain

Most car apps assume one owner, one phone, one login. Real life doesn't work that way. A family shares a single car between a couple and a teenager; a household runs three cars where everyone drives everyone's; a gig driver hands the wheel to a partner on alternate shifts. The moment two people try to keep the same car's records, the usual apps force a cloud account and "sync" — the exact feature that has caused the most catastrophic, widely-documented data loss in this category. Meanwhile nobody can answer the simplest fair-share question: *who actually spent what on this car?* Car and Pain refuses that trade-off: it keeps a real multi-driver model and lets two phones reconcile a shared car directly, peer-to-peer, with no account and no cloud.

## What it does

This module gives Car and Pain a coherent **multi-driver / household model**. Every driver is a lightweight on-device profile you can attach to trips, fuel-ups, expenses, and services, so the app can roll up cost and distance *per person* and answer who-owes-what with a real number instead of a guess. Drivers link into the Fleet and Rideshare economics, so per-driver profit-and-loss is consistent across the whole app rather than re-invented in each screen.

It also solves the shared-car problem that the no-account promise otherwise makes hard: **household peer-to-peer local sync**. Two phones that both track the same car meet over QR, Wi-Fi Direct, or NFC and reconcile their records using stable UUIDs, tombstones for deletions, and `updated_at` timestamps — always non-destructively, always with a snapshot and a dry-run preview first, and always with deterministic conflict resolution so the two sides can never permanently diverge. No server sees the data; the two devices are the only participants.

## Features

### ✅ Must-have

- **Driver / user profiles** — Each household member is a first-class profile with a name, an optional link to their driving license record, and a default vehicle, so attribution and driver-specific reminders have something to hang on.
- **Attribute any record to a driver** — Trips, fuel-ups, expenses, and services can each be assigned to the driver who was responsible, turning a shared logbook into a per-person one without duplicating data.
- **Per-driver cost & distance roll-up** — The app sums every attributed cost and every attributed distance for each driver, so "how much has the teenager's driving cost this quarter" is a single figure, not a spreadsheet exercise.
- **Household peer-to-peer local sync/merge** — Two devices on one shared car reconcile directly over QR, Wi-Fi Direct, or NFC, using UUID + tombstone + `updated_at` as the merge keys — no account, no cloud, no server in the middle.
- **Merge without duplicates, deterministic conflict resolution** — Records are matched by UUID so the same fill-up never lands twice, and when both sides edited the same record the outcome is decided by a fixed, predictable rule rather than chance or transfer order.
- **Pre-sync snapshot and dry-run** — Before a single record changes, the app takes a restore point and shows a preview of exactly what the merge *would* do (adds, updates, deletions), so you approve the result before it's applied and can roll back if you don't like it.

### 🔵 Should-have

- **Per-driver P&L / cost share** — Beyond raw totals, each driver gets a profit-and-loss / cost-share view that links directly into [Fleet](./10-fleet-business.md) and [Rideshare](./11-rideshare-gig-rental.md), so business drivers and gig partners see consistent economics wherever they look.
- **Household garage sharing** — Each driver has a defined set of vehicles they can see and edit, so a teenager sees only the car they're allowed to touch while a parent sees the whole garage.
- **Driver-specific reminders** — A driver's own license expiry, medical certificate, or personal document deadlines raise reminders tied to that person, not to a vehicle, so nothing personal falls through the cracks.
- **Split shared expenses across drivers** — A single shared cost (a joint insurance premium, a shared tank of fuel) can be divided across several drivers by a chosen rule, so shared spending is fairly attributed instead of dumped on whoever logged it.
- **Sync history / log with reconciliation** — Every sync is recorded with what was exchanged and a record-count reconciliation afterward, so both devices can confirm they ended up holding the same number of records and nothing was silently dropped.
- **Selective sync** — You can choose which vehicles and which date range to share in a given sync, so you can hand off just one car or just the last month without exposing your whole garage or full history.

### ⚪ Nice-to-have

- **Per-driver economy / eco-score comparison** — Fuel economy and a light eco-score can be compared between drivers of the same car, turning "you drive it harder than I do" into an evidenced, friendly number.
- **Guest / temporary driver** — A gig partner, a borrowing friend, or a short-term renter can be added as a guest with deliberately scoped access that is easy to grant and easy to revoke when they hand the keys back.
- **Household shared budget** — A single budget can span the whole household and all its drivers, so the family tracks one combined spend target rather than disconnected personal ones.
- **Conflict-resolution UI with per-field override** — When a merge conflict occurs, an interface lets you resolve it field by field, manually choosing the correct value where automatic last-write-wins isn't what you want (for example, after clock skew).
- **Two-entity compare mode** — A side-by-side driver-vs-driver comparison puts two people's cost, distance, and economy next to each other for a clear head-to-head view.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `driver_id` | uuid | Stable identifier for the driver profile; the key that trips, fuel, expenses, and services attribute against, and that survives P2P merges. |
| `name` | text | Driver's display name; UGC, preserved verbatim, and searchable via digit-folding / script normalization across languages. |
| `license_ref` | ref | Optional link to the driver's license record in [Documents & Glovebox](./08-documents-compliance.md); feeds driver-specific expiry reminders. |
| `default_vehicle_id` | ref | The vehicle this driver is associated with by default, pre-selecting attribution and speeding up entry. |
| `visible_vehicle_ids[]` | array (ref) | The set of vehicles this driver may see and edit — the backbone of household garage sharing and scoped guest access. |
| `role` | enum | Driver's role/permission level (e.g. owner, household member, guest/temporary), governing scope and revocability. |
| `device_id` | text | Identifier of the device this profile primarily lives on, used to reason about which phone authored which records. |
| `sync_peer_id` | text | Identifier of a paired peer device for household P2P sync, so a known counterpart can be recognized on reconnect. |
| `last_sync_at` | date (UTC/ISO-8601) | Timestamp of the most recent successful sync with a peer; stored canonically and rendered per each device's own calendar/numerals. |
| `sync_log[]` | array | History of sync sessions — transport used, direction, and record-count reconciliation results for auditability. |
| `cost_share_rule` | enum | How shared costs are split for this driver (equal, by-distance, by-usage), driving the split-expense and P&L math. |
| `pnl{}` | object | Derived per-driver profit-and-loss / cost-share summary, shared with Fleet and Rideshare so economics stay consistent. |
| `tombstones_seen[]` | array | Record of deletion tombstones already observed from peers, so a record deleted on one device is never resurrected by a later merge. |

## Calculations & formulas

- **Per-driver cost** — `per_driver_cost = Σ costs attributed to driver_id`. Every fuel, service, and expense record tagged to a driver is summed to a single figure, in the app's base currency, converted only for display.
- **Cost-share split** — A shared cost is divided across drivers by the chosen `cost_share_rule`: `equal` (even split across participants), `by-distance` (proportional to each driver's attributed distance), or `by-usage` (proportional to a usage measure such as number of trips or engine-hours).
- **Merge conflict resolution** — `last-write-wins by updated_at`, i.e. the record edit with the newer `updated_at` timestamp wins, with a **field-level manual override** available when device clocks have skewed and the automatic winner is wrong.
- **Deduplication & reconciliation** — Records dedupe on `UUID + tombstone` (same UUID = same record; a tombstone marks it deleted rather than re-adding it), followed by a **record-count reconciliation** after every merge so both devices confirm they hold the same set.

## Reminders & notifications

This module *produces* driver-scoped reminders and hands them to the shared [local notification engine](./04-reminders-notifications.md). The key difference from vehicle reminders is that these are tied to a *person*, not a car:

- **Driver document expiry** — A driver's own license, medical certificate, or personal permit raises a date-triggered reminder (with configurable lead-time early warnings, e.g. "1 month before" and "1 week before" expiry), so the person — not just the vehicle — stays compliant.
- **Delivery follows the same reliability rules** — These notifications survive reboot, Doze, and app-kill, name the driver they concern, and re-arm on backup/restore, exactly like every other reminder in the app.

## Offline & data

Everything here works with zero connectivity by design — it is, in fact, the module that *proves* the offline promise for shared cars. Driver profiles, attribution, and per-driver roll-ups are pure on-device computation. The household sync is deliberately **serverless**: QR, Wi-Fi Direct, and NFC are all local, direct device-to-device transports, so two phones reconcile a shared car in airplane mode with no account and no internet.

In **export / backup / import**, driver profiles, their visibility scopes, cost-share rules, derived P&L, and the full sync log (with live state) are included in the single-file backup, the per-entity CSV, and the combined JSON — with schema versioning, checksums, and merge-aware restore — so drivers and their attributions round-trip across devices and OSes without orphaning any attributed record. The pre-sync snapshot is itself a restore point, and every merge is transactional and non-destructive, matching the app-wide autosave and trash/undo guarantees. See [Data, Offline, Backup & Portability](./18-data-offline-backup.md) for the full portability contract.

## Localization & RTL

Two household members may run the app in entirely different UI languages, numeral systems, and calendars against the *same shared data* — one on Persian with the Jalali calendar and Persian numerals, another on German with the Gregorian calendar and Western digits. Because all data is stored canonically (SI units, UTC/ISO-8601 dates, base currency), this is safe: each device simply renders the shared records in its own preference, and a sync between them never rewrites anyone's history.

Driver **names are user-generated content**, preserved exactly as entered and made searchable via digit-folding and script normalization, so a name typed in one script is still findable from a device set to another. All **sync status messages** — pairing prompts, dry-run previews, conflict notices, and reconciliation results — are fully localized, including correct **RTL layout mirroring** for Persian, Arabic, and Sorani Kurdish, with numbers, record counts, and device identifiers bidi-isolated so they read correctly inside right-to-left sentences. See [Localization, RTL & Calendars](./19-localization-rtl.md) for the shared rendering layer.

## Edge cases

- **Two phones edit the same car offline** — P2P merge reconciles both sides without a cloud account, and the deterministic rules guarantee no silent, permanent divergence between the devices.
- **Deleted-on-one-device records must not resurrect** — Deletions are represented as tombstones, so a record removed on one phone stays removed after merging rather than being re-created from the other phone's older copy.
- **Clock skew between devices** — When device clocks disagree, `updated_at` still drives the automatic decision, but a per-field manual override lets the user correct any case where the "newer" timestamp is actually wrong.
- **Transport abstraction** — QR (small payloads), Wi-Fi Direct, and NFC (larger transfers) sit behind a single transport layer, so the merge logic is identical regardless of how the two devices actually exchange bytes.
- **Driver removed but history retained** — Deleting a driver profile does not erase their past attributions; historical records keep their attribution intact so cost history and P&L stay accurate.
- **Guest driver access scoped and revocable** — A temporary/guest driver's access is limited to a defined set of vehicles and can be revoked cleanly when they're done, without disturbing the records they created.
- **Merge is always non-destructive** — Every sync begins with a snapshot and a dry-run preview, so a bad merge is always previewable beforehand and recoverable afterward.

## Related features

- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md)** — Shares the UUID + tombstone + `updated_at` merge model, snapshots, and record-count reconciliation; household sync is the peer-to-peer sibling of backup/restore.
- **[Fleet, Business & Company-Car](./10-fleet-business.md)** — Consumes per-driver attribution and P&L for cost-centre, grey-fleet, and per-driver business reporting.
- **[Rideshare, Gig & Rental Economics](./11-rideshare-gig-rental.md)** — Uses driver attribution and cost-share to compute gig/rental per-driver earnings and costs, including scoped guest drivers.
- **[Documents, Glovebox & Compliance](./08-documents-compliance.md)** — Holds the license records that driver profiles link to and that drive driver-specific expiry reminders.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — Delivers the driver-scoped document-expiry reminders this module produces, with the same reboot/Doze/app-kill reliability.
- **[Vehicles, Garage & Odometer](./01-vehicles-garage.md)** — Provides the unlimited multi-vehicle garage that household sharing scopes visibility and editing against.
