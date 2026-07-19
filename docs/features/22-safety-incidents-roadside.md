# 🆘 Safety, Incidents & Roadside

> When a crash, a breakdown, or a stolen car turns your day upside down, the last thing you should be fighting is a login screen or a spinning "no connection" icon — this module is the calm, offline toolkit for the worst moments of ownership.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md) · [Offline Maps & Location](./14-maps-location.md) · [Reference, Diagnostics & Recalls](./23-reference-diagnostics.md)

## The pain

Accidents, breakdowns, and thefts happen on the hard shoulder, in an underground car park, or on a foreign motorway — exactly the places with no signal, a dead data plan, and a panicking driver who can't remember their policy number or their own blood type. Most car apps demand an account and a connection precisely when neither is available, and owners end up scrambling for photos, other-party details, and roadside numbers they should have had at their fingertips. Weeks later, a rejected or under-paid insurance claim often traces back to a missed photo, an unrecorded witness, or a damage detail no one wrote down at the scene. Car and Pain treats these stressful, high-stakes moments as first-class features that work fully offline, in the driver's own language, so the app helps instead of getting in the way.

## What it does

This module is the safety and emergency layer of the garage. It records accidents and incidents with photos, dashcam clips, and an annotated damage map; walks a shaken driver through an at-scene capture wizard step by step; and keeps a shareable roadside emergency card — emergency contacts, insurer, roadside number, VIN, and plate — reachable even from the lock screen with no signal. Around those core moments it adds the everyday safety chores that prevent emergencies: pre-trip and seasonal readiness checklists, a parking-location saver with a meter countdown, a find-my-car pointer, and bundled offline how-to guides and a warning-light dictionary.

Everything here is designed to hand off cleanly to the rest of the app. An incident can initiate an insurance claim that lives in the [Insurance module](./09-insurance-claims-warranty.md); a theft or total-loss becomes a lifecycle event that feeds [Sell, Dispose](./24-sell-dispose.md) and final cost of ownership; parking pins and find-my-car ride on the [bundled offline map](./14-maps-location.md). No screen in this module needs connectivity to do its primary job.

## Features

### ✅ Must-have

- **Accident / incident log** — A structured record of every accident and incident capturing date and time, location, the other party, their insurer, an annotated damage diagram, and the official report number, so the full picture survives long after memory fades.
- **At-scene accident capture wizard** — A guided, step-by-step flow that prompts for the right photos, the other party's details, and the location, then assembles them into an incident record. It works fully offline: GPS supplies the position and the pin renders on the bundled offline map, so a driver with zero signal is still walked through doing it right.
- **Body damage / defect map** — An annotated body diagram where each dent, scratch, or defect is pinned to a panel or zone, with photos attached over time, building a visual history of the car's condition for repairs, warranty, resale, or rental hand-back disputes.
- **Emergency / roadside info card** — A single card holding emergency contacts, blood type, insurer, the roadside-assistance number, VIN, and plate. It is fully offline, shareable in an instant, and can optionally sit on the lock screen so a first responder or bystander can reach vital details even if the phone is locked.
- **Parking-location saver** — Drops a GPS pin on the offline map with the parking level, spot number, and a photo, plus the meter expiry time and a pre-expiry reminder, so you always find the car again and never return to a ticket.
- **Pre-trip safety checklist** — A fully customizable pre-departure check covering tires, lights, fluids, wipers, and the emergency kit, turning a good habit into a quick, repeatable tap-through before a long drive.
- **Insurance-claim initiation** — One tap turns an incident into the start of an insurance claim, handing the incident's photos, party details, and damage data straight to the [Insurance / Claims workflow](./09-insurance-claims-warranty.md) with nothing re-typed.

### 🔵 Should-have

- **Insurance claim tracker view** — Surfaces the claim's live state — filed, with the adjuster, current status, payout, deductible, and attached documents — directly from the Insurance module so the driver can follow a claim without leaving the incident.
- **Dashcam clip / video attachment** — Attach dashcam clips and other video to an incident so motion evidence of who did what lives alongside the still photos and the written account.
- **Offline roadside how-to guides** — Bundled step-by-step guides for jump-starting a flat battery, changing a flat tire, handling an overheating engine, and what to do after an accident — available with zero signal, when you need them most.
- **Dashboard warning-light dictionary** — An offline, searchable dictionary of dashboard warning lights, each coded by urgency with its meaning and the recommended action. Shared with the [Reference module](./23-reference-diagnostics.md) so the same trusted content appears in both places.
- **Seasonal readiness checklist & prompts** — Season-aware checks and reminders for antifreeze, winter tires, air-conditioning, and battery health, prompting the right preparation before winter and summer instead of after a failure.
- **Find-my-car compass + distance pointer** — A compass and distance readout that points from your current position back to the saved parking pin, powered by the [Offline Maps](./14-maps-location.md) layer with a compass fallback where no map tiles are cached.
- **Theft / total-loss / write-off capture** — A dedicated capture for theft, total-loss, and write-off events recording the police report, any recovery, and the insurer payout, and feeding the vehicle's lifecycle so the garage, insurance, and cost figures all stay truthful.
- **DIY maintenance procedure log link** — Links to the DIY procedure logs in the [Service module](./03-service-maintenance.md), so a roadside fix or safety repair you performed yourself is captured in your maintenance history rather than lost.

### ⚪ Nice-to-have

- **Emergency kit inventory & expiry** — Track what's actually in the emergency kit and when items expire (flares, first-aid supplies, extinguisher), linked to the [Components](./16-components-consumables.md) tier so a checklist item like "kit" reflects reality.
- **Emergency info / medical card** — A dedicated medical card — blood type, allergies, medical notes, contacts — kept behind the app lock for privacy yet reachable in a genuine emergency view so responders aren't blocked.
- **Parking cost log & meter timer** — Log what parking cost and run a live meter timer with a countdown alarm, so paid parking is both budgeted and never overrun.
- **Trip expense splitter for companions** — Split the cost of a shared drive among passengers, shared with the [Trips module](./06-trips-mileage.md) so companion contributions feed the same expense math.
- **Cross-border cheatsheet** — A quick reference of each country's legally required emergency equipment and its local emergency numbers, linked to the [Cross-Border module](./13-cross-border-travel.md) for drivers crossing frontiers.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `incident_id` | uuid | Stable primary key for the incident record. |
| `vehicle_id` | ref | Links the incident to a vehicle in the garage. |
| `datetime` | date | Stored canonically as UTC / ISO-8601; displayed in the user's calendar and timezone. |
| `location` | text | Human-readable place; free text preserved as entered (UGC). |
| `map_pin` | number+unit | Latitude/longitude pin rendered on the offline map. |
| `description` | text | Free-text account of what happened; UGC preserved verbatim. |
| `incident_type` | enum | One of `accident` / `theft` / `total_loss` / `vandalism`. |
| `other_party` | object | `{ name, plate, insurer, contact }` for the other party involved. |
| `police_report_no` | text | Official report / crime reference number; kept LTR. |
| `injury` | text | Notes on any injuries at the scene. |
| `photos[]` | attachment | Scene and damage photos; compressed with thumbnails, stored app-private. |
| `dashcam_clips[]` | attachment | Video evidence; optional transcode/compression and size guard. |
| `damage_diagram_ref` | ref | Reference to the annotated body damage diagram. |
| `claim_ref` | ref | Link to the associated insurance claim in the Insurance module. |
| `cost` | number+unit | Total incident cost in canonical base currency. |
| `deductible` | number+unit | Policy deductible/excess applied to the claim. |
| `witnesses[]` | array | List of witnesses and their contact details. |
| `damage_map[]` | array | Per-entry `{ panel_zone, type, severity, date_noticed, repaired, repair_cost }`. |
| `emergency_contacts[]` | array | Per-contact `{ name, phone, relation }` for the roadside/medical card. |
| `blood_type` | enum | Held behind the app lock; shown in the emergency view. |
| `allergies` | text | Medical detail behind the app lock. |
| `medical_notes` | text | Free-text medical notes behind the app lock (UGC). |
| `roadside_provider` | text | Roadside-assistance provider name. |
| `roadside_phone` | text | Roadside-assistance number; kept LTR for dialing. |
| `parking` | object | `{ lat, lon, level, spot, photo_ref, meter_expiry, cost }` for the parking saver. |
| `checklist` | object | `{ template, items[], completed_at }` for pre-trip/seasonal checks. |
| `warning_light` | object | `{ symbol, urgency, meaning, action }` from the warning-light dictionary. |

## Calculations & formulas

- **Net claim** — `net_claim = actual_payout − deductible`, reconciled in the Insurance module so the incident and the policy agree on what was actually recovered.
- **Find-my-car pointer** — `bearing + distance` derived from the saved GPS pin and the device's current heading, giving a compass arrow and a live distance back to the car.
- **Parking meter countdown** — Countdown from now to `meter_expiry`, with the pre-expiry reminder fired at `meter_expiry − lead_offset`.
- **Damage cost aggregation** — Sum of `repair_cost` across `damage_map[]` entries over time, producing a running damage total for resale and rental records.

## Reminders & notifications

This module both produces and consumes reminders through the shared offline notification engine:

- **Parking-meter pre-expiry** — A time-based alarm fires a configurable lead time before `meter_expiry` (for example "10 minutes before"), and the optional meter timer runs a live countdown with an alarm at zero. Alarms respect the device timezone and DST so they fire at the intended local wall-clock time even after crossing a border.
- **Pre-trip and seasonal checklists** — Seasonal readiness prompts are scheduled ahead of the relevant season (antifreeze and winter tires before winter, AC and battery before summer), nudging preparation before the weather turns.
- **Emergency-kit expiry** — When kit inventory is tracked, approaching expiry dates raise a reminder so flares, first-aid items, and the extinguisher are replaced before they lapse.

All of these use the app's standard trigger model (date / distance / whichever-comes-first with early-warning lead times) and are delivered as reliable local notifications that survive reboot, Doze, and app-kill, and re-arm after a backup restore.

## Offline & data

Every primary action here works in airplane mode. The at-scene wizard pulls position from GPS and renders the pin on the bundled offline map with no reverse geocoding required; the roadside and medical cards, how-to guides, and warning-light dictionary are all bundled on-device content; and the parking saver, find-my-car pointer, and meter timer need only the device's own sensors. There is no signup and no cloud dependency at any step.

In backup and export, incident records — including live claim links, the damage map, checklist state, and the roadside/medical card fields — are covered by the single-file full backup, the per-entity CSV, and the combined JSON. Photos, dashcam clips, and scene attachments travel inside the backup and are re-linked on restore so evidence round-trips across devices and operating systems. Because photos and especially video inflate backup size, the media pipeline compresses attachments, generates thumbnails, and can transcode clips, warning the user about large captures before they bloat storage. Medical/ICE fields sit behind the app lock and are redaction-eligible in handover exports.

## Localization & RTL

- **Emergency & roadside numbers** — Localized to the user's context (112 across the EU, 911 in the US, and other numbers surfaced per the Cross-Border cheatsheet), so the card shows the right number to dial wherever the car is.
- **Translated safety content** — How-to guides and warning-light names are translated for all supported languages, so a driver reads jump-start steps and light meanings in their own language.
- **RTL layout** — Guides and cards mirror fully for right-to-left languages (Persian, Arabic, Sorani Kurdish), while plate, VIN, and phone numbers stay LTR and bidi-isolated so they remain readable and dialable.
- **Calendars & numerals** — Incident and claim dates render in the user's chosen calendar (Gregorian, Jalali, Hijri, or Hebrew) from the canonical UTC value, and all numerals — distances, costs, countdowns — display in the preferred numeral system (Western, Eastern-Arabic, Persian, Devanagari).
- **Currency** — Costs, deductibles, and payouts display in the vehicle or display currency, converted only for display from the canonical base currency.
- **User content** — Incident free-text notes, descriptions, and medical notes are preserved verbatim as user-generated content in whatever language they were written.

## Edge cases

- The accident capture wizard works with zero signal: it auto-fills location from GPS and renders the scene on the offline map with no connectivity.
- Many scene photos and dashcam clips can inflate storage and backups, so the app compresses media and warns the user about large captures.
- Medical/ICE data sits behind the app lock for privacy yet remains reachable in a genuine emergency view so responders are never blocked.
- The warning-light dictionary is purely offline bundled content with no live lookup.
- The meter timer respects timezone and DST so countdown alarms fire at the intended local time, including after crossing time zones.
- A theft or total-loss becomes a disposal event that feeds Sell/Dispose, Insurance, and final TCO, keeping the vehicle's lifecycle consistent.
- Video attachments are large, so optional compression/transcode and a size guard keep backups manageable.
- The parking pin works offline via the bundled map even without reverse geocoding, so you still find the car with no data.

## Related features

- **[Insurance, Claims & Warranty Compliance](./09-insurance-claims-warranty.md)** — Receives claims initiated from an incident and reconciles payout, deductible, and net recovery back into the record.
- **[Offline Maps & Location](./14-maps-location.md)** — Renders incident pins, parking saves, and the find-my-car pointer on the bundled offline map layer.
- **[Reference, Diagnostics & Recalls](./23-reference-diagnostics.md)** — Shares the offline, urgency-coded dashboard warning-light dictionary.
- **[Sell, Dispose & Ownership Transfer](./24-sell-dispose.md)** — Consumes theft/total-loss/write-off events as lifecycle disposal, closing out the vehicle with a final cost picture.
- **[Components, Batteries, Keys & Consumables](./16-components-consumables.md)** — Backs the emergency-kit inventory and expiry tracking behind the readiness checklists.
- **[Cross-Border, Travel & Emission Zones](./13-cross-border-travel.md)** — Provides the required-equipment and local-emergency-number cheatsheet for drivers crossing borders.
