# ⚙️ Settings & Preferences

> No more fighting an app that guesses your language, forces one unit system, or quietly ships your data to a cloud you never asked for — this is the single place where you tell Car and Pain how *you* live, and it obeys.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Localization, RTL & Calendars](./19-localization-rtl.md) · [Accessibility & Inclusive Design](./20-accessibility.md) · [Data, Offline, Backup & Portability](./18-data-offline-backup.md)

## The pain

Most car apps treat preferences as an afterthought bolted onto a US-centric, English-only, online-first core. They lock language to the phone's locale, assume miles-and-gallons (or worse, silently mix US and UK gallons), can't show a Jalali or Hijri date, print Western digits to a Persian speaker, and bury a mandatory cloud account behind an innocuous "sync" toggle. When you finally find the settings screen, changing a unit or currency risks corrupting years of history, and there is no honest statement of what the app does — or doesn't — send off your device. The result is an app that feels borrowed from someone else's country and never quite yours.

Car and Pain flips that. Settings is a first-class control surface where every cross-cutting choice — language, numerals, calendar, per-measure units, currency, accessibility, notifications, security, backup, categories, and theme — is explicit, independent, reversible, and non-destructive. Because the app stores everything canonically and converts only for display, you can toggle any of these at any time without ever rewriting a single stored value.

## What it does

Settings & Preferences is the hub that wires together every preference the rest of the app reads. It exposes the decoupled internationalization model (language, numerals, calendar, units, and currency are each set independently, or all at once via a regional preset), the accessibility layer (contrast, motion, text scale, colour-blind palette, haptics), notification behavior (defaults, channels, quiet hours, lead times), security (PIN/biometric app-lock, encryption, secure wipe), backup scheduling (local, self-hosted, SD-card, or strictly-opt-in cloud), category and tag management, theming, and default-vehicle and entry-form defaults.

Crucially, it is also the app's honesty surface: an explicit, always-visible assurance that Car and Pain is account-free, 100% offline-capable, ad-free, never force-synced, and telemetry-free by default. Every switch here follows the same rule — changing how data is *displayed* or *protected* never changes the canonical data itself, so preferences are safe to explore.

## Features

### ✅ Must-have

- **In-app language selection (independent of device locale).** Pick the app's language from the full localized set (launch tier: English, German, French, Persian/Farsi, Arabic, Sorani Kurdish) regardless of what language the phone is set to — an Arabic speaker on an English phone gets a fully Arabic, right-to-left app.
- **Global and per-vehicle unit preferences.** Set distance, volume, consumption, pressure, and temperature units globally, then override any of them per vehicle — so a US pickup logged in miles/US-gallons and a European EV logged in km/kWh coexist in one garage without conflict.
- **Currency settings.** Choose a home/base currency that all totals normalize to, set a per-vehicle default currency, and enter manual exchange rates (with dated snapshots) for offline multi-currency — no live FX feed required or implied.
- **Calendar-system and numeral-system selection, including grouping style.** Independently pick the calendar (Gregorian, Jalali/Shamsi, Hijri, Hebrew), the numeral system (Western, Eastern-Arabic, Persian, Devanagari), and the digit-grouping convention (thousands vs Indian lakh/crore).
- **Accessibility settings.** Toggle high-contrast mode, reduced motion, text scaling (dynamic type), a colour-blind-safe chart palette, and haptic feedback — treated as structural preferences, not cosmetic extras.
- **Notification permission status, per-channel management, and battery-optimization guidance.** See whether the OS has granted notification permission, manage each severity channel individually, and get platform-specific guidance for defeating OEM battery-killers so reminders actually fire.
- **App lock (PIN/passcode + biometric) with auto-lock timeout.** Protect the app behind a PIN or passcode plus optional biometric unlock, with a configurable idle timeout that re-locks automatically.
- **Backup schedule, location, and retention.** Configure automatic backups, choose where they go (on-device, self-hosted, opt-in cloud, or SD-card), and set how many generations to keep.
- **Explicit privacy assurance surface.** A plain-language, always-available statement that the app is no-account, 100% offline, no-ads, no-forced-sync, and no-telemetry — with links to the security and data controls that back each claim up.
- **Reminder default lead times and quiet hours.** Set how early reminders warn by default (e.g. "1 week before" / "1000 km before") and define quiet hours during which notifications are held.
- **Data export/import and full-backup/restore entry points.** One-tap access to the full single-file backup, per-entity CSV/JSON export, importers, and merge-aware restore — the data-ownership controls, never paywalled.
- **Trash/recycle-bin management and retention.** Review, restore, or permanently purge deleted records, and set how long the trash retains them before auto-cleanup.

### 🔵 Should-have

- **Regional preset bundles.** One tap sets language, numerals, calendar, units, and currency together for a region (Iran, Germany, France, US, Saudi Arabia, Kurdistan, Turkey, India, Israel, Spain, Brazil) — a fast start that you can still override piece by piece afterward.
- **Fully independent i18n overrides.** Every internationalization axis is decoupled: language ≠ numerals ≠ calendar ≠ units ≠ currency, so (for example) a French UI can display Persian numerals on a Jalali calendar with imperial units if that is genuinely what the user wants.
- **First-run language/region onboarding wizard.** A guided first-launch flow that uses the device locale only as a *hint* and lets the user confirm or change every choice; links into the broader [Onboarding, Help & Education](./25-onboarding-help.md) flow.
- **Fiscal-year / budget-period start and first-day-of-week.** Define when the financial year and budget periods begin and which day starts the week, so reports and budgets line up with local and personal conventions.
- **Auto-backup interval, encryption passphrase, and strictly-opt-in cloud/self-hosted connection.** Choose the backup cadence, set an encryption passphrase for backups, and connect a self-hosted (WebDAV/Nextcloud/SFTP) or cloud target — always explicitly, never on by default.
- **Category & tag management.** Add, rename, reorder, re-icon, recolour, and archive service types, expense categories, trip categories, and tags — the shared taxonomy that entry, filtering, budgets, and reports depend on.
- **Dark mode / theme.** Choose light, dark, or system-following appearance, with theming that respects accessibility overrides.
- **Global notification defaults.** Set default sound, vibration, and importance for notifications, inherited by channels unless overridden.
- **Storage & attachment-compression manager.** See how much space attachments consume, tune compression/transcode quality, and clean up orphaned media.
- **Secure wipe / panic reset.** Irreversibly erase all app data (with encryption-key destruction) for device handover or emergency privacy.
- **Default vehicle and entry-form defaults.** Pick the vehicle that opens by default and preset common entry-form fields to cut repetitive typing.
- **Household peer-to-peer sync setup entry point.** Launch the QR/Wi-Fi-Direct/NFC pairing flow to reconcile a shared car between two devices — under the no-account model, with no cloud involved.

### ⚪ Nice-to-have

- **Home-screen / lock-screen / Watch widget configuration.** Choose which quick stats and shortcuts appear on home-screen, lock-screen, and wearable widgets.
- **CarPlay / Android Auto preferences and voice quick-log.** Configure the in-car interface and enable hands-free quick logging of fuel and trips.
- **Assistant/voice-shortcut configuration.** Set up OS voice shortcuts (Siri/Google Assistant) for common actions like logging a fill-up.
- **Developer / pseudolocale QA mode.** A hidden mode that swaps in pseudolocalized strings to stress-test layout expansion, RTL mirroring, and truncation.
- **Per-vehicle unit/currency override management screen.** A consolidated view of every per-vehicle unit and currency override, so you can audit and adjust them in one place.
- **Crash-reporting opt-in toggle (default off).** A clearly-labelled, off-by-default switch to voluntarily share anonymized crash reports — consistent with the no-telemetry promise.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `app_language` | enum | Chosen UI language, independent of device locale. |
| `follow_system_locale` | bool | If true, language tracks the OS; overridden by an explicit `app_language`. |
| `numeral_system` | enum | Western / Eastern-Arabic / Persian / Devanagari digit shaping. |
| `calendar_system` | enum | Gregorian / Jalali (Shamsi) / Hijri / Hebrew. |
| `grouping_style` | enum | Thousands vs Indian lakh/crore digit grouping. |
| `distance_unit` | enum | Display unit for distance (km / mi); global default. |
| `volume_unit` | enum | Display unit for volume (L / US-gal / UK-gal). |
| `consumption_unit` | enum | Economy unit (L/100km, mpg-US, mpg-UK, km/L, kWh/100km, mi/kWh). |
| `pressure_unit` | enum | Tire pressure unit (bar / psi / kPa). |
| `temperature_unit` | enum | °C / °F. |
| `home_currency` | enum | Base currency all totals normalize to. |
| `per_vehicle_currency_overrides` | ref → map | Per-vehicle default currency, keyed by vehicle. |
| `manual_exchange_rates[]` | array | Dated offline FX snapshots (from/to/rate/date). |
| `first_day_of_week` | enum | Week-start day for calendars and reports. |
| `fiscal_year_start` | date | Month/day the fiscal & budget year begins. |
| `theme` | enum | Light / dark / system. |
| `a11y_prefs{}` | object | High-contrast, reduced-motion, text scale, colour-blind palette, haptics. |
| `reminder_default_lead_times` | object | Default early-warning offsets by trigger type (date/distance/engine-hour). |
| `quiet_hours{start,end}` | object | Local time window during which notifications are held. |
| `notification_channels[]` | array | Per-severity channels with sound/vibration/importance. |
| `app_lock_enabled` | bool | Whether the app requires unlock. |
| `lock_scope` | enum | Whole-app vs sensitive-section-only locking. |
| `pin_hash` | text | Salted hash of the PIN/passcode (never stored in clear). |
| `biometric_enabled` | bool | Whether biometric unlock is allowed alongside the PIN. |
| `auto_lock_timeout` | number+unit | Idle duration before auto-relock (seconds/minutes). |
| `auto_backup{enabled,interval,location,keep_last_n,encrypt}` | object | Scheduled-backup configuration. |
| `backup_targets{}` | object | Configured destinations (local / self-hosted / cloud / SD-card). |
| `cloud_features_enabled` | bool | Strictly-opt-in cloud switch; default off. |
| `selfhosted_enabled` | bool | Whether a WebDAV/Nextcloud/SFTP target is configured; default off. |
| `analytics_enabled(false)` | bool | Telemetry/crash-reporting opt-in; defaults to false. |
| `category_taxonomy[]` | array | Custom service types, expense/trip categories, and tags with icons/colours. |
| `default_vehicle_id` | ref | Vehicle opened by default across the app. |

## Calculations & formulas

- **Preference precedence resolution.** For any display value the app resolves the effective preference as `per-record override > per-vehicle setting > global default` — the most specific setting wins, and an unset level transparently falls through to the next.
- **Conversion-factor management for display units.** Canonical SI values are converted for display via `display_value = canonical_value × factor(unit)` (e.g. `mi = km × 0.621371`, `mpg_US = 235.215 / (L/100km)`); the stored canonical value is never touched.
- **Budget-period and fiscal-year boundary derivation.** Period boundaries derive from `fiscal_year_start` and `first_day_of_week`, e.g. the current fiscal year is `[fiscal_year_start(currentYear), fiscal_year_start(currentYear)+1yr)`, computed in the active calendar system from canonical UTC dates.
- **Auto-lock timeout evaluation.** The app relocks when `now − last_interaction ≥ auto_lock_timeout`, evaluated on foreground/resume so a backgrounded app locks per policy.

## Reminders & notifications

Settings does not itself emit reminders, but it is the control panel that governs the shared [Reminders & Notifications](./04-reminders-notifications.md) engine for every module. Here the user sets the global defaults that the engine consumes:

- **Default lead times** — how early each trigger type warns, expressed as date offsets (e.g. "1 week before"), distance offsets (e.g. "1000 km before"), or engine-hour offsets, applied to date / distance / engine-hour / whichever-comes-first reminders across the app.
- **Quiet hours** — a local-time window during which due notifications are queued and delivered afterward, so nothing wakes you at 3 a.m.
- **Per-channel behavior** — sound, vibration, and importance per severity channel, plus grouped-digest preferences.
- **Permission & reliability** — the current OS notification-permission state and battery-optimization guidance; if permission is denied, the app degrades gracefully to an in-app due list rather than losing the reminder.

## Offline & data

Everything in Settings works with zero connectivity — there is no account to authenticate, no server to reach, and no network call required to change any preference. Preferences are stored on-device and applied instantly. The only settings that *can* touch a network are the strictly-opt-in cloud/self-hosted backup targets, and those never activate or transmit anything until the user explicitly enables and configures them.

In export and backup, all preferences travel with your data. The full single-file backup includes the complete settings object (language, units, currency, calendar, numerals, accessibility, theme, notification defaults, category taxonomy, and non-secret configuration) alongside every module's records and attachments, so a restore on a new device reproduces your exact setup. Secrets are handled safely: the PIN is stored only as a salted hash, and backup encryption uses your passphrase. Merge-aware restore re-applies settings without clobbering unrelated on-device state, and the category taxonomy round-trips so custom types and tags survive migration.

## Localization & RTL

Settings is where the app's decoupled internationalization model is exposed and controlled, and it must itself be fully localized in every supported language with correct right-to-left layout mirroring. Key concerns:

- **Independent axes.** Language, numerals, calendar, per-measure units, and currency are each chosen separately — the screen never assumes that picking Arabic implies the Hijri calendar or Eastern-Arabic numerals, though a regional preset can set them together as a convenience.
- **Regional presets.** Preset bundles (Iran, Germany, France, US, Saudi Arabia, Kurdistan, Turkey, India, Israel, Spain, Brazil) set every axis at once as a starting point, after which any individual override still applies.
- **Numerals & grouping.** Numeric previews in Settings render in the chosen numeral system with the chosen grouping (thousands vs lakh/crore), while identifiers like VIN, plate, IBAN, and phone stay LTR via bidi isolation even in an RTL layout.
- **Calendars.** Date-related settings (fiscal-year start, first-day-of-week) display and accept input in the active calendar, converted from canonical ISO/UTC — the stored date is never mutated by a calendar switch.
- **Units & currency.** Unit and currency pickers change display and export only; the onboarding wizard uses the device locale purely as a hint and lets the user confirm each choice.
- **Non-destructive by contract.** Switching language, numerals, calendar, units, or currency is guaranteed never to rewrite stored data — a core promise this screen makes visible and testable.

## Edge cases

- **Per-vehicle vs global precedence is documented and consistent.** The `per-record > per-vehicle > global` order is applied uniformly, so a per-vehicle unit or currency override always predictably wins over the global default.
- **Changing units never rewrites stored canonical values.** Unit changes are display-only; the underlying SI value is untouched, eliminating US/UK-gallon and L/100km↔mpg corruption.
- **Changing calendar or numeral system never mutates stored dates or numbers.** Canonical ISO/UTC dates and numeric values stay fixed; only their rendering changes.
- **Biometric change/removal invalidates the key.** If the device's enrolled biometrics change or are removed, the biometric-bound key is invalidated and the app falls back to the PIN/passphrase, which is therefore always required as a backstop.
- **Notification permission denied degrades gracefully.** If the OS denies notifications, reminders are not lost — the app surfaces an in-app due list and keeps re-arming, with guidance to re-enable permission.
- **Cloud/self-hosted connection is strictly optional and user-initiated.** Nothing syncs or uploads without an explicit opt-in; the default state is fully local and offline.
- **Enabling encryption/app-lock migrates existing data safely.** Turning on at-rest encryption or app-lock re-secures existing data in place without loss or a wipe.
- **Accessibility settings can override theme.** High-contrast can override the chosen theme colours without breaking layout, so accessibility always wins the conflict.

## Related features

- **[Localization, RTL & Calendars](./19-localization-rtl.md)** — Settings is the user-facing control panel for the decoupled language / numeral / calendar / unit / currency model that this module implements end-to-end.
- **[Accessibility & Inclusive Design](./20-accessibility.md)** — the high-contrast, reduced-motion, text-scale, colour-blind-palette, and haptics toggles here drive the shared accessibility layer.
- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md)** — backup scheduling, targets, retention, export/import, and trash management configured in Settings feed the full data-ownership pipeline.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — default lead times, quiet hours, and channel behavior set here govern every reminder the app emits.
- **[Onboarding, Help & Education](./25-onboarding-help.md)** — the first-run language/region wizard is the entry point that seeds these preferences from a device-locale hint.
- **[Drivers, Household & Sharing](./15-drivers-household.md)** — the household peer-to-peer sync setup entry point launches account-free device pairing for a shared car.
