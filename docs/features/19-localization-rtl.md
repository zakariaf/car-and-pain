# 🌍 Localization, RTL & Calendars

> Your car history is a lifetime of numbers, dates, and money — this module makes sure it reads correctly in your language, your script, your calendar, and your currency, without ever rewriting a single record.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Accessibility & Inclusive Design](./20-accessibility.md) · [Settings & Preferences](./21-settings-preferences.md) · [Reminders & Notifications](./04-reminders-notifications.md) · [Glossary, Units, Calendars & Conventions](../reference/glossary.md)

## The pain

Most car apps are built in one language, for one calendar, with one way of writing numbers — and everyone else is treated as an afterthought. A Persian owner sees a mangled English date and Western digits on a screen that should read right-to-left; an Arabic speaker gets a phone number scrambled by bidirectional text; a Kurdish or Urdu user watches their own letters render as empty "tofu" boxes because the font never shipped. Worse, the apps that *do* offer other languages often store the localized text and break the moment you switch — turning `1.5` litres into `15`, or losing years of mileage because a date parsed one way going in and another way coming out. Car and Pain treats language, script direction, calendar, numerals, units, and currency as **data-integrity concerns**, not a translation layer bolted on at the end.

## What it does

This module is the internationalization engine that every other feature renders through. It lets you choose your app language independently of your phone's system locale, and it decouples *every* localization preference from every other: you can run an English interface with a Jalali calendar, Persian digits, kilometres, and Iranian Rial all at once, or a Hindi interface with Gregorian dates, Devanagari numerals, and Indian lakh/crore grouping — every combination is valid. Six languages ship fully translated and QA'd at launch (English, German, French, Persian/Farsi, Arabic, Sorani Kurdish), with true right-to-left layout mirroring for the RTL scripts, and an expansion tier broadens the list further.

Underneath, the app follows one strict contract: **store canonical, localize at render.** Distances live in SI units, timestamps in UTC/ISO-8601, money in a base currency, and text in stable message keys — then everything is converted, shaped, and formatted only when it is drawn on screen, spoken by a screen reader, written into a notification, or placed in an export. Because the stored truth never changes, switching language, calendar, numerals, units, or currency can never corrupt your history. All of it works 100% offline: fonts, translation catalogs, ICU/CLDR data, and calendar-conversion math are bundled in the app, with no server fetch ever required.

## Features

### ✅ Must-have

- **In-app language selection, decoupled from the device locale** — Pick the app's language inside the app; it does not have to match (and is never overridden by) your phone's system language, so a device set to English can run the app in Persian and vice versa.
- **Launch-tier six languages, fully translated with true RTL** — English, German, and French ship as left-to-right languages; Persian/Farsi, Arabic, and Sorani Kurdish ship as fully right-to-left languages with mirrored layouts, all professionally QA'd for launch.
- **Expansion-tier languages** — The roadmap adds Spanish, Italian, Portuguese, Turkish, Russian, and Hindi (LTR), Hebrew and Urdu/Nastaliq (RTL), and Kurmanji Kurdish (written in Latin script, LTR) — each shipped with an honest per-language completeness status.
- **Bundled offline translation catalogs** — Every translation is packaged inside the app; nothing is fetched from a server, so language works in airplane mode on first launch.
- **ICU MessageFormat with full CLDR plural and gender rules** — Strings are formatted through ICU with complete Unicode plural handling, including Arabic's six plural forms (zero/one/two/few/many/other) and the distinct Slavic and Urdu plural rules — never a hardcoded English "s".
- **Translation fallback chain with no raw keys shown** — When a string is missing in the chosen language, the app walks a sensible chain (for example `ckb→fa→ar→en`, `kmr→tr→en`, `ur→hi/ar→en`) so the user always sees real words, never a naked message key.
- **Bundled script fonts with correct shaping** — The app ships fonts that render Arabic-script contextual shaping correctly and include Nastaliq for Urdu, plus the extra letters Sorani and Kurmanji need — so no character ever falls back to an empty "tofu" box.
- **Full RTL layout mirroring via logical start/end properties** — Layouts are authored with logical (start/end) rather than physical (left/right) properties, so the entire interface mirrors cleanly for right-to-left languages.
- **Unicode bidi handling and mixed-content isolation** — Bidirectional text runs are isolated so mixed left-to-right and right-to-left content (numbers, units, IDs inside RTL sentences) never reorders or scrambles.
- **Always-LTR fields inside RTL UI** — Identifiers and values that are inherently left-to-right — VIN, licence plate, phone, price, odometer, email, URL, IBAN — stay LTR even on a fully mirrored RTL screen.
- **Numeral-system selection** — Choose how digits are drawn: Western (0-9), Eastern-Arabic (٠-٩), Persian (۰-۹), or Devanagari (०-९).
- **Numeric input accepting mixed digit systems** — When the on-screen keypad emits Western digits but the interface shows Persian or Devanagari, the app accepts either silently and normalizes internally.
- **Numbers render LTR within RTL text** — Numeric values always read left-to-right even when embedded in a right-to-left sentence, matching how these languages are actually read and written.
- **Multi-calendar system** — Display dates in Gregorian, Jalali/Shamsi, Hijri (including the Umm al-Qura variant), or Hebrew.
- **Canonical UTC/ISO timestamp storage with localized display** — Every date is stored once as a UTC/ISO-8601 timestamp and only *rendered* in the chosen calendar, so changing calendars never alters the underlying record.
- **Calendar-aware reminder and service scheduling** — Recurring reminders and service intervals are resolved in the calendar you actually use, so "every 6 months" or a Jalali-anchored due date lands on the right day.
- **Unit selection for distance, volume, and economy** — Independently choose distance (km/mi), fuel volume (litres / US gallon / UK gallon), and economy units, including EV energy units (e.g. kWh/100 km, mi/kWh).
- **Canonical base-unit storage with display-only conversion** — All measures are stored in one base unit and converted only for display and export, preventing US/UK-gallon and L/100km↔mpg corruption.
- **Per-entry currency capture** — Each record can carry its own currency, so a fuel-up abroad is recorded in the currency you actually paid.
- **Locale number formatting** — Decimal and grouping separators follow the locale, including Persian decimal `٫` and grouping `٬` and Indian lakh/crore grouping.
- **Locale date/time formatting** — Month and day names, 12- vs 24-hour clocks, and era markers all follow the chosen locale.
- **Localized notifications and reminders** — Local notifications render in the right language, numerals, and calendar with correct bidirectional layout, so an alert reads naturally on the lock screen.
- **Localized help, tutorials, insights, and category microcopy** — In-app help, tutorials, generated insights, and the small category labels are all translated across supported languages, not just the top-level UI chrome.

### 🔵 Should-have

- **Sorani Kurdish extended-letter and orthography support** — Full support for the 33-letter Sorani alphabet and its extra letters (ڕ ڵ ۆ ێ ە ڤ) with mandatory vowels rendered correctly.
- **Kurmanji Kurdish (Latin) extended letters** — Correct handling of Kurmanji's Latin-script extras (ç ê î ş û).
- **Persian/Arabic/Urdu character normalization** — Normalize the confusable variants — Persian ye/kaf (ی/ک) versus Arabic (ي/ك), heh forms, the zero-width non-joiner (ZWNJ), and Unicode NFC — so search and import behave predictably.
- **Hebrew niqqud-agnostic handling and RTL punctuation** — Treat optional Hebrew vowel points transparently and render RTL punctuation correctly.
- **Direction-aware versus direction-absolute icons** — Icons that imply direction (back/next, trend arrows) flip for RTL, while icons with a fixed real-world meaning (clock, checkmark, compass, media controls, logos) never mirror.
- **RTL-correct charts** — In right-to-left layouts the chart *chrome* mirrors and the time axis inverts, but the plotted data itself is never flipped, so a trend still means what it looks like.
- **RTL-aware gestures and controls** — Swipe actions, steppers, carousels, and gesture directions respect right-to-left reading order.
- **Locale first-day-of-week and weekend definition** — Week bucketing and business-day logic follow the locale: Saturday start for Persian/Arabic, Sunday for Hebrew, with Friday/Saturday or Friday weekends where applicable.
- **Additional unit choices** — Temperature (°C/°F) and tire-pressure (psi/bar/kPa) units are independently selectable.
- **Offline manual/historical exchange rates** — Enter and date your own exchange rates so multi-currency reporting works with no live FX feed.
- **Home-currency unified reporting** — Roll every expense up into a single home currency using dated rate snapshots for a consistent total.
- **Locale currency formatting** — Symbol position, and whether the currency shows as symbol, code, or name, follow the locale.
- **Regional preset bundles** — One-tap presets (Iran, Germany, France, US, Saudi, Kurdistan, Turkey, India, Israel, Spain, Brazil, and more) set sensible defaults for language, calendar, numerals, units, and currency together.
- **Fully independent i18n overrides** — Mix and match language, numerals, calendar, units, and currency freely; a preset is only a starting point, never a lock.
- **Language/region onboarding wizard** — Guide the choice at first run, using the device locale as a hint only, never as a mandate.
- **Text expansion and elongation resilience** — Layouts absorb German compound words, Arabic kashida elongation, and longer Russian strings without clipping or overflow.
- **UGC cross-language handling** — Custom categories, tags, notes, and vehicle nicknames get transliteration and search-folding so user-generated content stays findable across scripts.
- **Locale-aware import parsing** — Imports understand localized number, date, and separator formats so competitor data comes in cleanly.

### ⚪ Nice-to-have

- **Offline holiday awareness for scheduling** — A bundled table of Nowruz, Eid, and Jewish holidays lets reminders shift around observances without any network access.
- **Currency redenomination handling** — Handle Iranian Rial versus Toman (×10) and Turkish lira history so amounts aren't misread across a redenomination.
- **Locale-aware collation and digit-folding search** — Sorting and search fold digits and collate correctly across all supported scripts.
- **RTL and translation QA harness** — A developer/QA tool offers pseudolocale, force-RTL and force-numeral previews, and untranslated-string highlighting to catch issues before release.
- **Accessibility × i18n test matrix** — A paired test matrix validates screen-reader behaviour in RTL and dynamic-type overflow in Arabic, German, and Russian together.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `app_language` | enum | Chosen interface language (e.g. `en`, `de`, `fa`, `ar`, `ckb`). |
| `follow_system_locale` | bool | Whether to track the device locale or stay pinned to the in-app choice. |
| `text_direction` | enum | `ltr` or `rtl`, derived from the language but overridable. |
| `translation_bundle_version` | text | Version of the bundled translation catalog in use. |
| `icu_pattern` | text | ICU MessageFormat pattern used to render a string. |
| `plural_categories` | array | CLDR plural categories active for the language (zero/one/two/few/many/other). |
| `fallback_order` | array | Ordered fallback chain for missing strings (e.g. `ckb→fa→ar→en`). |
| `font_family_per_script` | ref | Which bundled font renders each script (Latin, Arabic, Nastaliq, Devanagari, Hebrew). |
| `numeral_system` | enum | Western / Eastern-Arabic / Persian / Devanagari. |
| `decimal_separator` | text | Locale decimal mark (e.g. `.`, `,`, Persian `٫`). |
| `grouping_separator` | text | Locale grouping mark (e.g. `,`, `.`, Persian `٬`). |
| `grouping_style(western/indian)` | enum | Western 3-3-3 grouping vs Indian 2-2-3 (lakh/crore). |
| `calendar_system` | enum | Gregorian / Jalali-Shamsi / Hijri / Hebrew for display. |
| `hijri_variant` | enum | Umm al-Qura or civil arithmetic variant. |
| `jalali_leap_rule` | enum | Astronomical vs arithmetic Jalali leap-year rule. |
| `hebrew_leap_rule` | enum | Metonic-cycle leap-month rule for the Hebrew calendar. |
| `stored_utc_timestamp` | date | Canonical UTC/ISO-8601 instant — the single source of truth. |
| `display_calendar` | enum | Calendar used only for rendering the stored timestamp. |
| `first_day_of_week` | enum | Locale week start (Sat for fa/ar, Sun for he, Mon elsewhere). |
| `weekend_days` | array | Locale weekend definition (e.g. Fri/Sat, Fri, Sat/Sun). |
| `distance_unit` | enum | km or mi. |
| `volume_unit` | enum | Litres / US gallon / UK gallon. |
| `consumption_unit` | enum | Economy unit, including EV energy units. |
| `temperature_unit` | enum | °C or °F. |
| `pressure_unit` | enum | psi / bar / kPa. |
| `currency_code` | text | ISO currency code for a captured amount. |
| `symbol_position` | enum | Currency symbol before or after the number. |
| `home_currency` | text | Base currency for unified reporting. |
| `exchange_rate` | number | Manual/historical rate to the home currency. |
| `rate_effective_date` | date | Date the exchange rate applies from. |
| `preset_id` | ref | Regional preset that seeded the current preferences. |

## Calculations & formulas

- **Jalali ↔ Gregorian conversion** — Convert between calendars using the astronomical Nowruz leap rule: `jalali_to_gregorian(y, m, d)` and its inverse, anchored on the vernal-equinox Nowruz.
- **Hijri conversion** — `hijri_convert(date, variant)` supports both the `umm_al_qura` tabular variant and civil arithmetic variants.
- **Hebrew calendar conversion** — `hebrew_convert(date)` applies the Metonic cycle and leap-month (Adar I/II) rules.
- **Calendar-aware recurrence** — Recurrence is resolved in the chosen calendar with short-month clamping: `clamp_to_month_end(target)` handles Esfand 30, `Jan-31 → Feb-28/29`, and Adar I/II.
- **Digit normalization** — `normalize_digits(input)` maps Eastern-Arabic, Persian, and Devanagari digits to canonical Western digits for parsing and search.
- **Separator parsing and formatting** — Parse and format decimals and groups per locale, including Persian decimal `٫`, grouping `٬`, and Indian `2-2-3` grouping.
- **ICU plural selection** — `select_plural(count, language)` returns the correct CLDR category (`zero`/`one`/`two`/`few`/`many`/`other`) for the language.
- **Unit conversion** — `convert(value, from_unit, to_unit)` applies per-measure conversion factors with defined rounding, always from the canonical stored value.

## Reminders & notifications

This module does not create reminders of its own, but it renders and schedules every reminder the rest of the app produces — so it is a first-class consumer of the [notification engine](./04-reminders-notifications.md).

- **Calendar-correct scheduling** — Date-based recurrences ("every 6 months", an annual inspection) are resolved in the user's chosen calendar, so the same rule can land on different absolute Gregorian dates for a Jalali versus a Hijri user, with short-month clamping applied.
- **Localized delivery** — Each notification renders in the chosen language, numeral system, and calendar, with correct bidirectional layout, and always names the vehicle in a way that reads naturally in RTL.
- **Holiday-aware shifts (nice-to-have)** — Where enabled, a bundled offline table of Nowruz, Eid, and Jewish holidays can nudge a reminder off an observance day — with no network dependency.
- **Distance and engine-hour triggers unaffected** — Triggers that are date-independent (distance-to-go, engine-hours) are unit-formatted for display but computed from canonical values, so unit and numeral choices never change *when* they fire, only how they read.

## Offline & data

Everything in this module runs with zero connectivity by design. Fonts (including Nastaliq and Kurdish-covering faces), translation catalogs, ICU/CLDR plural and formatting data, and all four calendar-conversion algorithms are bundled into the app, so language, script, calendar, and numerals work in airplane mode from the very first launch — there is never a server fetch for a string, a glyph, or a date. Multi-currency reporting uses manual/historical exchange rates you enter and date yourself; when a rate is missing, the amount is kept in its original currency and flagged as unconverted rather than guessed.

Because the app stores canonical values (SI units, UTC/ISO timestamps, base currency, stable message keys) and localizes only at render, none of these preferences touch the stored data. In export and backup, records are written in their canonical form for lossless round-tripping, with your display preferences recorded as settings alongside them — so a full backup restores identically on another device regardless of its locale. CSV exports include a UTF-8 BOM so localized text and non-Latin scripts open correctly in Excel without mojibake. See [Data, Offline, Backup & Portability](./18-data-offline-backup.md) for the full portability contract.

## Localization & RTL

This module *is* the localization and RTL contract for the whole product; every other feature inherits its behaviour. The core rule is separation: language, numeral system, calendar, per-measure units, and currency are each independently settable and none is derived from another, so any combination — English UI with a Jalali calendar, Persian digits, kilometres, and Iranian Rial; or a Hindi UI with Gregorian dates, Devanagari numerals, and lakh grouping — is fully valid.

- **Numerals** — Western, Eastern-Arabic, Persian, and Devanagari digit systems are supported for both display and input, with mixed input normalized silently and numbers always rendered left-to-right even inside RTL text.
- **Calendars** — Gregorian, Jalali/Shamsi, Hijri (incl. Umm al-Qura), and Hebrew are all converted from the single canonical UTC timestamp, with leap-rule and short-month edge cases handled.
- **Units** — Distance, volume, economy (incl. EV energy), temperature, and pressure units are per-preference and convert only at display from canonical SI storage.
- **Currency** — Per-entry currency capture, home-currency roll-up, locale-aware symbol position and formatting, and manual/historical offline rates.
- **RTL layout** — Full mirroring via logical start/end properties, bidi isolation of mixed content, always-LTR identifier fields (VIN, plate, phone, price, IBAN, email, URL), direction-aware icon flipping (but never for clocks, checkmarks, compasses, media, or logos), and RTL-correct charts whose plotted data is preserved while the chrome and time axis mirror.
- **Script coverage** — Bundled fonts guarantee correct Arabic contextual shaping, Nastaliq for Urdu, and the extended Sorani/Kurmanji letters, with character normalization (ye/kaf variants, heh, ZWNJ, NFC) keeping search and import reliable.

## Edge cases

- **Persian decimal versus grouping** — `1٫5` means 1.5, not 15; the decimal `٫` and grouping `٬` marks must never be confused.
- **Indian grouping** — `1,00,000` is one lakh, not one hundred thousand — it must both format and parse correctly under the 2-2-3 style.
- **Mixed digit input** — When the system keypad emits Western digits while the UI shows Persian or Devanagari, the input is accepted silently and normalized.
- **Bidi-isolated numbers and units** — Values like `50 km/h`, prices, VINs, and parentheses inside RTL text are isolated so they don't scramble.
- **LTR-forced identifiers** — Phone, plate, VIN, and IBAN stay left-to-right even on RTL screens.
- **Jalali leap edge** — The astronomical versus arithmetic leap rule can shift a Jalali date by a day.
- **Hijri variance** — A calculated Hijri date can differ from a sighting-based one by a day.
- **Hebrew leap month** — Adar I/II must be handled correctly for recurrences.
- **Cross-calendar recurrence** — "Every 6 months" resolves to different absolute dates depending on the calendar in use.
- **Short-month clamping** — Recurrences landing on a nonexistent day (e.g. the 31st, or Esfand 30) clamp to the month's end.
- **Week and weekend differences** — First day of week and weekend days differ (Saturday for fa/ar, Sunday for he), affecting bucketing and business-day scheduling.
- **Holiday shifts** — Nowruz, Eid, and Jewish holidays may shift reminders, resolved from an offline bundled table.
- **Icon and chart mirroring** — Directional icons mirror; clock/checkmark/compass/media/logos do not; charts never mirror plotted data.
- **Missing glyphs** — Sorani and Urdu letters absent from generic Arabic fonts render as tofu unless covering fonts (incl. Nastaliq) are bundled.
- **Character confusables** — Persian ی/ک versus Arabic ي/ك, Urdu forms, and ZWNJ break search and import unless normalized.
- **Text overflow** — German and Russian expansion and Arabic elongation demand flexible layouts with no fixed widths.
- **CSV mojibake** — Excel garbles non-Latin CSV without a UTF-8 BOM; exports stay canonical for lossless re-import.
- **Offline hard limits** — No live FX, font, or CLDR fetch; everything is bundled, and a missing rate keeps the original amount and flags it unconverted.
- **Every combination valid** — Any mix of preferences must work (English UI + Jalali + Persian digits + km + IRR; Hindi UI + Gregorian + Devanagari + lakh grouping).
- **Rare device locales** — An unsupported or rare device locale resolves via the fallback chain, never crashing or showing raw keys.
- **Correct plurals** — Pluralized strings resolve to the correct language forms — never a hardcoded English "s".
- **Localized help fallback** — Help and insight content must exist for every supported language or fall back gracefully with a visible note.

## Related features

- **[Settings & Preferences](./21-settings-preferences.md)** — Where the user actually chooses language, numerals, calendar, units, currency, and regional presets that this engine applies everywhere.
- **[Accessibility & Inclusive Design](./20-accessibility.md)** — The peer discipline; screen-reader reading order in RTL and dynamic-type overflow in Arabic/German/Russian are validated jointly with i18n.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — Consumes calendar-aware scheduling and localized rendering so alerts fire on the right day and read naturally.
- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md)** — Enforces the canonical-store/localized-display contract in export/import, with UTF-8 BOM and settings preserved across devices.
- **[Glossary, Units, Calendars & Conventions](../reference/glossary.md)** — The reference for unit definitions, calendar conventions, and numeral systems this module implements.
- **[Canonical Data Model & Schema](../reference/data-model.md)** — Defines how canonical values (SI units, UTC dates, base currency) are stored so localization stays a display-only concern.
