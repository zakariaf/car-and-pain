# 🔧 Reference, Diagnostics & Recalls

> When a warning light blinks on a mountain road with no signal, you shouldn't need Google to know whether it's "pull over now" or "book a garage next week."

📍 Part of **[Car and Pain](../overview.md)** · Related: [Service & Maintenance](./03-service-maintenance.md) · [Vehicles, Garage & Odometer](./01-vehicles-garage.md) · [Components, Batteries, Keys & Consumables](./16-components-consumables.md)

## The pain

A dashboard symbol lights up and most owners are left guessing: is it a loose fuel cap or a failing catalytic converter? The information exists, but it lives behind an internet search, a manufacturer app that demands an account, or a paid VIN service — none of which help in a parking garage, a border crossing, or a rural road with no bars. Meanwhile safety recalls quietly pile up because nobody remembers to check, generic maintenance schedules are buried in a glovebox manual nobody reads, and a scary check-engine code turns a five-minute diagnosis into an anxious tow-truck decision. Car and Pain answers the "what is this and how bad is it?" question instantly, offline, in the owner's own language — and only reaches for the internet when it genuinely has to, always saying so plainly.

## What it does

This module is the app's built-in automotive knowledge base plus an optional local diagnostics bench. It ships **guaranteed-offline** dictionaries — dashboard warning lights and generic OBD-II fault codes with plain-language meaning and urgency — alongside bundled generic maintenance-schedule templates that expand into real per-vehicle reminders. It keeps a check-engine event log, decodes VINs on-device, and tracks recalls through manual entry and cached lookups with honest "last checked" timestamps.

For owners who want to go deeper, an optional Bluetooth/Wi-Fi ELM327 dongle turns the app into a fully local scan tool: read and clear DTCs, watch live sensor data, and check emissions readiness monitors — all processed on the phone, never sent to a server. Throughout, the module is scrupulously honest about the line between bundled offline content (which always works) and connectivity-dependent lookups (VIN full decode, fresh recall data), and it never blocks core offline logging to fetch anything.

## Features

### ✅ Must-have

- **Maintenance schedule templates** — Bundled generic service schedules that are fully editable and auto-generate reminders based on the vehicle's powertrain (ICE, diesel, LPG/CNG, EV, PHEV), so a new vehicle arrives with a sensible maintenance plan even with zero connectivity.
- **Dashboard warning-light dictionary** — A guaranteed-offline, searchable catalog of dashboard symbols, each urgency-coded (red = stop now, amber = service soon, green/blue = informational) with what it means and what to do, so a lit symbol is understood in seconds.
- **DTC / fault-code dictionary** — A bundled offline library of generic OBD-II fault codes translated into plain-language meaning, the affected system, and common causes — no dongle required to look up a code someone read out to you.

### 🔵 Should-have

- **Warning / check-engine event log** — Record every warning-light or check-engine event with date, odometer, symptom, and (if known) the DTC — with or without a dongle — and link it to the service that resolved it, building a fault history for the vehicle.
- **Offline VIN decoder** — Decode a VIN's structural parts entirely on-device (World Manufacturer Identifier, region, manufacturer, model-year character, check-digit validation), shared with the Vehicles module so setup can prefill fields without the internet.
- **Recall lookup & recall log** — Look up open safety campaigns with an occasional online refresh, then cache and timestamp the results so the last-known status is always visible offline, honestly labeled with when it was last checked.
- **Manual recall / safety-campaign record** — Enter a recall notice by hand (from a letter or dealer call) with campaign number, component, remedy, and fixed-date — shared with the Documents module so the paperwork and compliance proof live together.
- **Bulb / fuse / wiper reference per vehicle** — A quick per-vehicle reference for bulb types, fuse ratings, and wiper-blade sizes, linked to Components and Vehicles so a roadside bulb swap or fuse check doesn't require digging out the manual.

### ⚪ Nice-to-have

- **OBD-II live diagnostics** — Connect an optional Bluetooth/Wi-Fi ELM327 adapter for fully local diagnostics: read and clear DTCs and watch live PIDs (sensor readings), with all processing on-device and nothing sent to any server.
- **Readiness-monitor status** — When connected, show the emissions readiness monitors (e.g., catalyst, EVAP, oxygen sensor) so you know whether the car will pass an inspection before you drive to the testing station.
- **Recall-check reminder & official-lookup deep links** — Schedule a periodic reminder to check for recalls and deep-link straight to the official manufacturer or government lookup page, so the manual step is prompted and one tap away.
- **Manufacturer-specific code hints** — Where licensable, bundle hints for manufacturer-specific (non-generic) codes to supplement the generic OBD-II dictionary with brand-aware explanations.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `schedule_template_id` | uuid | Identifier for a bundled or user-cloned maintenance-schedule template. |
| `service_type` | ref | The service the template line drives (oil change, brake fluid, timing belt…), linked to the shared service-type taxonomy. |
| `interval_distance` | number+unit | Distance interval, stored canonically (km) and shown in the vehicle's preferred distance unit. |
| `interval_time` | number+unit | Time interval (e.g., months) used for whichever-comes-first scheduling. |
| `applies_powertrain` | enum | Powertrain(s) the line applies to (ICE, diesel, LPG/CNG, EV, PHEV). |
| `severity_schedule` | enum | Whether the interval belongs to a normal or severe-duty service schedule. |
| `source` | enum | Origin of the template (bundled-generic vs user-edited/custom). |
| `symbol_id` | uuid | Identifier for a dashboard warning-light entry. |
| `warning_name` | text | Localized name of the warning light. |
| `urgency_color` | enum | Urgency coding (red / amber / green-blue) for the symbol. |
| `meaning` | text | Localized plain-language explanation of the symbol. |
| `recommended_action` | text | What the owner should do (stop, service soon, informational). |
| `dtc_code` | text | OBD-II fault code (e.g., `P0420`) — always rendered LTR. |
| `dtc_description` | text | Localized plain-language description of the fault code. |
| `system` | enum | Vehicle system the code belongs to (powertrain, chassis, body, network). |
| `severity` | enum | Relative seriousness of the fault. |
| `common_causes` | array | Typical root causes for the code. |
| `warning_event` | object | Logged event: `{date, odometer, type, dtc_if_known, resolved, linked_service}`. |
| `recall` | object | Recall record: `{campaign_no, component, description, remedy, status, fixed_date, last_checked_online}`. |
| `vin` | text | 17-character VIN — always rendered LTR, even in RTL layouts. |
| `wmi` | text | World Manufacturer Identifier (first three VIN chars). |
| `decoded_region` | text | Region decoded from the WMI. |
| `decoded_manufacturer` | text | Manufacturer decoded from the WMI. |
| `model_year_char` | text | Model-year character from the VIN. |
| `check_digit_valid` | bool | Result of ISO 3779 check-digit validation. |
| `dongle` | object | Connected adapter: `{id, protocol, connection_type}` (Bluetooth/Wi-Fi ELM327). |
| `live_pids[]` | array | Live parameter IDs / sensor readings streamed while connected. |
| `readiness_monitors` | array | Emissions readiness-monitor statuses read from the OBD interface. |

## Calculations & formulas

- **VIN check-digit validation** — Validates the VIN's 9th-position check digit per ISO 3779: `check_digit = (Σ(transliterate(charᵢ) × weightᵢ)) mod 11`, where `10` maps to `X`. A mismatch flags a likely typo before it corrupts vehicle setup.
- **DTC lookup** — Resolves a raw code against the bundled dictionary: `lookup(dtc_code) → {dtc_description, system, severity, common_causes}`, working fully offline.
- **Schedule-template expansion** — Turns a template into per-vehicle recurring reminders anchored to today's readings: `next_due_distance = current_odometer + interval_distance` and `next_due_date = current_date + interval_time`, fired on whichever comes first.
- **Readiness-monitor status** — Derives inspection-readiness from live OBD PIDs when a dongle is connected: `readiness(monitorᵢ) = complete | incomplete | not_supported`, so pass/fail likelihood is known before an emissions test.

## Reminders & notifications

This module both **produces** and **consumes** reminders through the shared [local notification engine](./04-reminders-notifications.md):

- **Schedule-driven maintenance reminders** — Expanded template lines fire on a **date OR distance** basis, whichever comes first, using projection-based scheduling (average daily distance) so a distance target can be forecast even offline. Early warnings lead the due point — for example "1 week before" or "1,000 km before" — so parts can be ordered in time.
- **Recall-check reminders** — An optional recurring prompt (e.g., every 6 or 12 months) reminds the owner to run a manual/online recall check, with a deep link to the official lookup, since recall detection is never claimed real-time.
- **Powertrain-aware defaults** — Because templates are keyed to powertrain, EV vehicles won't nag about oil changes and ICE vehicles get the intervals that actually apply.

All notifications name the specific vehicle, respect quiet hours and per-severity channels, survive reboot/Doze/app-kill, and re-arm after a backup restore.

## Offline & data

Everything owners reach for in a panic is **bundled and works in airplane mode**: the warning-light dictionary, the DTC dictionary, the generic schedule templates, the bulb/fuse/wiper reference, VIN structural decode, and the entire ELM327 diagnostics path (which is inherently local — the dongle talks directly to the phone, never to a server). The check-engine event log and manual recall records are ordinary on-device entries.

Only two things genuinely need connectivity — **full VIN decode** (trim/options beyond the structural fields) and **fresh recall data**. Both follow the app's offline-honesty rule: they cache the last result with a visible "last checked" timestamp, degrade gracefully, offer manual equivalents, and never block offline logging.

In **export / backup / import**, schedule templates (including user edits), warning-event logs, recall records, VIN decode results, and dongle/session metadata are all included in the single-file backup, the per-entity CSV, and the combined JSON. Cached recall lookups round-trip with their timestamps intact, and generated maintenance reminders carry their live state, so migrating to a new phone loses nothing.

## Localization & RTL

Per `i18n_notes`, all human-readable reference content — warning-light names, DTC descriptions, schedule-template names, recommended actions, and common causes — is translated for every supported language (English, German, French, Persian/Farsi, Arabic, Sorani Kurdish, and the expanding tier) and rendered with correct RTL mirroring. See [Localization, RTL & Calendars](./19-localization-rtl.md).

- **Numerals** — Reference numbers (intervals, odometer values, code counts) shape to the user's numeral system (Western / Eastern-Arabic / Persian / Devanagari) with correct grouping.
- **Codes stay LTR** — VINs and DTC codes are bidi-isolated and always render left-to-right even inside RTL text, so `P0420` and a 17-character VIN never scramble.
- **Calendars** — Schedule interval time units and event/recall dates respect the vehicle's chosen calendar (Gregorian / Jalali / Hijri / Hebrew), converted from the canonical UTC/ISO storage.
- **Units** — Schedule distance intervals follow the vehicle's distance preference (km/mi), converted for display only from canonical SI storage.

## Edge cases

- **OBD-II needs real hardware** — Live diagnostics require a physical ELM327 adapter; supported PIDs vary by vehicle and manufacturer-specific codes differ. The feature stays purely local with no server dependency, and gracefully reports unsupported PIDs.
- **VIN decode and recall data need connectivity** — Full VIN decode and fresh recall lookups cache their last result with a "last checked" timestamp and degrade gracefully rather than failing loudly.
- **Offline logging is never blocked** — No reference or diagnostics feature ever prevents core offline logging; connectivity-dependent extras are additive only.
- **Dictionaries are guaranteed bundled content** — Warning-light and DTC dictionaries ship in the app as offline must-have content, always available regardless of network.
- **Templates never overwrite custom intervals** — Generic schedule templates remain user-overridable per vehicle and never silently overwrite a service interval the owner has customized.
- **Recall detection is never real-time** — The app is explicit that recall tracking is manual plus cached, never a live safety feed.

## Related features

- **[Service & Maintenance](./03-service-maintenance.md)** — Schedule templates expand into the maintenance reminders and service records tracked here; resolved warning events link back to the service that fixed them.
- **[Vehicles, Garage & Odometer](./01-vehicles-garage.md)** — The offline VIN decoder is shared with vehicle setup, and the shared odometer ledger stamps every warning event and reminder projection.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — Consumes the whichever-comes-first triggers this module produces and delivers the recall-check and maintenance reminders reliably offline.
- **[Documents, Glovebox & Compliance](./08-documents-compliance.md)** — Manual recall and safety-campaign records are shared here as compliance proof alongside the vehicle's paperwork.
- **[Components, Batteries, Keys & Consumables](./16-components-consumables.md)** — The bulb/fuse/wiper reference links to component inventory so replacements are one tap from the part spec.
- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md)** — Ensures templates, event logs, cached recalls, and VIN results are fully captured in backup and export and round-trip on restore.
