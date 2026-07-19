# 🧭 Onboarding, Help & Education

> Removes the "I opened a powerful car app and had no idea where to start — and when I got stuck, there was no answer without an internet connection or my own language."

📍 Part of **[Car and Pain](../overview.md)** · Related: [Localization, RTL & Calendars](./19-localization-rtl.md) · [Accessibility & Inclusive Design](./20-accessibility.md) · [Data, Offline, Backup & Portability](./18-data-offline-backup.md)

## The pain

Car apps are deep, and depth is intimidating. A new owner installs the app, faces a wall of empty screens and unfamiliar concepts — full-to-full economy, Total Cost of Ownership, partial fills, seasonal tire sets, Jalali dates — and quietly gives up before logging a single fill. Worse, the ones who *would* switch are already using a competitor and dread re-typing years of history by hand, so they stay unhappy where they are. And when help is needed most — on the roadside, in a parking garage, on a plane — the "help" is a web page that will not load and is only written in English. Car and Pain treats teaching the app as a first-class, fully offline, fully localized feature: nobody should need connectivity or fluent English to understand their own car data.

## What it does

This module is the app's welcome mat and its always-on tutor. On first run it configures language, region, units, currency, and calendar (using the device locale only as a hint, never a lock-in), then offers three honest doorways: start fresh with an optional clearly-marked demo vehicle, import from a competitor app, or restore from a backup file. A short guided tour walks the core loop — add a vehicle, log fuel, set a reminder, make a backup — and from then on the app teaches *in place*: empty screens explain what they are for, complex features carry contextual tips, hard terms get glossary popovers, and a searchable offline FAQ answers the rest in the user's own language.

Every word of this — tour steps, tips, FAQ articles, spotlights, glossary, and the demo vehicle's example data — is part of the translation scope, mirrors correctly in RTL, and shows numbers, dates, and money in the user's chosen numerals, calendar, and currency. Nothing here fetches from the network; if a help article has not been translated yet, the app falls back gracefully with a visible note rather than failing silently.

## Features

### ✅ Must-have

- **First-run onboarding flow** — A guided setup that captures language/region, units, currency, and calendar up front, treating the device locale as a *suggestion the user can override*, not a decision made for them. These choices feed the canonical-display layer so everything downstream renders correctly from the very first screen.
- **Optional demo/sample vehicle** — A one-tap sample car pre-loaded with realistic example fills, services, and expenses so a newcomer can *see* the app working before committing their own data — clearly labeled as demo and removable in a single tap, never blended into real statistics.
- **Guided tour of core actions** — A short, skippable walkthrough of the essential loop: add a vehicle, log a fuel-up, set a reminder, and run a backup — the four actions that turn an empty install into a working ownership record.
- **In-app help / FAQ** — A complete, searchable help center that lives *on the device*: no page loads, no connectivity, fully localized, so it works on a plane, in a basement garage, or at an accident scene.
- **Contextual help tips on complex features** — Inline, just-in-time explanations attached to the genuinely tricky concepts — Total Cost of Ownership, full-to-full economy, partial/missed fills, calendar systems, and RTL behavior — surfaced where the user meets them rather than buried in a manual.
- **Importer-first path** — During onboarding the app actively offers to import from Fuelio, Drivvo, aCar, and Fuelly, turning "I'd have to re-enter everything" from a reason to quit into a reason to switch — with unit, locale, and full-tank detection handled inline (see Edge cases).

### 🔵 Should-have

- **Empty-state education across modules** — Every module's blank screen does double duty as a lesson: it says what the screen is for and how to add the first record, so an empty garage, an empty tire history, or an empty expense list is an invitation instead of a dead end.
- **Feature spotlights for differentiators** — Lightweight, dismissible highlights that introduce the things that make Car and Pain different — genuine offline/no-account operation, free full backup, first-class tire sets, and the red/amber/green compliance dashboard — so users discover the moats instead of missing them.
- **Restore-from-backup path prominent in onboarding** — A device-migration doorway placed alongside "start fresh," so someone reinstalling or moving to a new phone lands on *restore my data*, not an empty setup they have to rebuild by hand.
- **Progressive disclosure** — Advanced fields stay hidden until they are needed, keeping first entries fast and unintimidating while power remains one tap away — matching the "never block an entry" principle.
- **Accessibility onboarding** — A localized introduction to screen-reader support and high-contrast/large-type options offered early, so users who rely on assistive technology are set up correctly from the start rather than discovering the settings by accident.
- **"What's new" / changelog surface** — An offline, in-app record of what changed in each version, so updates are transparent and new capabilities are actually noticed — no web release-notes page required.

### ⚪ Nice-to-have

- **Interactive tutorials with sample tasks** — Hands-on mini-lessons that ask the user to *do* the thing (log a practice fill, set a practice reminder) rather than just read about it, reinforcing the core loop through practice.
- **Localized short how-to videos or animated tips** — Bundled (not streamed) short clips or animated hints that demonstrate a workflow at a glance, available offline and captioned/localized for each language.
- **Contextual glossary popovers** — Tap-to-define popovers on domain terms — full-to-full, whichever-first, RAG (red/amber/green), TCO — so a user never has to leave the screen or guess at jargon.
- **Re-runnable tour from settings** — The guided tour can be replayed any time from Settings, so users who skipped it, forgot it, or handed the phone to a family member can revisit it on demand.
- **Tip-of-the-day / insights education feed** — An optional, gentle drip of tips and data-driven insights that keeps teaching over time and surfaces features a user has not yet discovered.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `onboarding_state` | enum | Overall status of first-run: `not_started` / `in_progress` / `completed` / `skipped`; used to route returning users and avoid re-prompting. |
| `completed_steps[]` | array | List of finished onboarding step IDs (locale, units, currency, calendar, starting-path choice), enabling resume mid-flow. |
| `demo_vehicle_present` | bool | Whether the sample vehicle currently exists; gates the "remove demo data" action and excludes it from real stats. |
| `tour_progress` | number | Index/percentage of guided-tour steps completed; supports pause and resume of the walkthrough. |
| `help_article_id` | ref | Identifier of a help/FAQ article, used for deep-linking from contextual tips and for search results. |
| `help_category` | enum | Grouping for help articles (e.g. Getting Started, Fuel, Reminders, Backup, Localization), used for browsing and search facets. |
| `faq_entries[]` | array | The bundled, localized FAQ corpus (question, answer, category, language) indexed for offline search. |
| `spotlight_seen[]` | array | Which differentiator spotlights the user has already viewed, so they are shown once and not repeated. |
| `whats_new_version_seen` | text | The last app version whose changelog the user has acknowledged; drives the "what's new" badge. |
| `glossary_terms[]` | array | The localized glossary corpus (term, definition, language) backing popovers and search. |

## Calculations & formulas

- **Onboarding completion tracking and resume** — Progress is derived from step state so an interrupted setup resumes exactly where it left off: `progress = count(completed_steps) / count(required_steps)`, and the entry router uses `onboarding_state` to decide between resume, restore, or normal launch.
- **Contextual-tip targeting by feature-first-use** — Tips fire the *first time* a user reaches a complex feature, tracked per feature: a tip for feature `f` shows only while `first_use(f) == true AND tip_dismissed(f) == false`, then is suppressed thereafter.
- **Help search ranking with locale-aware collation** — Search results are ranked with locale-correct string collation and folding (so, e.g., Persian/Arabic and German queries match their content), combining term-match score with category weighting: `rank = match_score(query, article) × category_weight`, compared under the active locale's collation rules rather than raw byte order.

## Offline & data

Everything in this module is bundled with the app and runs with zero connectivity. The onboarding flow, guided tour, empty-state copy, contextual tips, FAQ, glossary, spotlights, and "what's new" changelog are all shipped inside the install — there is no fetched content, no remote config, and no analytics call required to complete setup. Help search runs against an on-device index, and any bundled how-to media plays locally. This satisfies the edge-case requirement that onboarding work fully offline, and it means the app is fully usable and learnable in airplane mode on the very first launch.

For export and backup, this module's footprint is small but real: onboarding and education state (`onboarding_state`, `completed_steps[]`, `tour_progress`, `spotlight_seen[]`, `whats_new_version_seen`, and the `demo_vehicle_present` flag) travels as user-preferences/app-state inside the single-file backup and combined JSON, so a restored device does not force a returning user back through setup. The demo vehicle itself, if still present, is an ordinary (clearly-flagged) vehicle record and is included or excluded per the user's choice; the bundled FAQ and glossary corpora are app assets, refreshed with updates rather than carried in user backups. See [Data, Offline, Backup & Portability](./18-data-offline-backup.md) for the backup format and merge-aware restore.

## Localization & RTL

Localization here is not a translation layer bolted on at the end — the entire educational surface is part of the translation scope. Every tour step, tip, FAQ article, spotlight, glossary term, and changelog entry is authored for translation across all supported languages, and lays out correctly in RTL (Persian/Farsi, Arabic, Sorani Kurdish) with mirrored layouts and correct bidi handling of embedded numbers, units, and IDs. Worked examples inside tips and the demo vehicle render in the user's chosen numeral system (Western, Eastern-Arabic, Persian), calendar (Gregorian/Jalali/Hijri), units, and currency — so a Persian user's economy example shows Persian numerals, a Jalali date, litres/100 km (or their choice), and their currency, while a US user sees MPG and dollars. Accessibility onboarding is itself localized. When a help article or glossary term has not yet been translated for the active language, the app falls back to an available language with a visible note rather than showing a blank or an untranslated string with no explanation. See [Localization, RTL & Calendars](./19-localization-rtl.md) and [Accessibility & Inclusive Design](./20-accessibility.md).

## Edge cases

- **Demo data stays quarantined** — The sample vehicle must be visually distinct and removable in one tap, and its example fills/services/expenses must never leak into real statistics, averages, or TCO.
- **Fully offline onboarding** — Setup and all education must complete with no network at all; no step may depend on fetched content or remote configuration.
- **Returning/reinstalling users go to restore** — Someone who reinstalls or migrates devices must be routed toward restore-from-backup, not dropped into an empty first-run setup that discards their history.
- **Per-language help with visible fallback** — Help content must exist per language or fall back to an available language with a clearly visible note, never a silent blank or an unexplained foreign-language article.
- **Skipping is safe** — Skipping onboarding must still leave the app in a valid, fully configured state (sensible default locale/units/currency/calendar), never broken or half-set-up.
- **Importer detection during first run** — The importer path must detect and confirm units, locale, and full-tank conventions from the incoming Fuelio/Drivvo/aCar/Fuelly data *during* onboarding, so imported history is interpreted correctly instead of silently mis-scaled.

## Related features

- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md)** — Supplies the restore-from-backup path offered in onboarding and the competitor importers the importer-first flow drives.
- **[Localization, RTL & Calendars](./19-localization-rtl.md)** — Provides the RTL, calendar, and numeral rendering that the entire educational surface depends on, including the first-run locale wizard.
- **[Accessibility & Inclusive Design](./20-accessibility.md)** — The source of the screen-reader and high-contrast infrastructure that accessibility onboarding introduces.
- **[Vehicles, Garage & Odometer](./01-vehicles-garage.md)** — The demo vehicle and the "add a vehicle" tour step live here; onboarding hands off into real garage setup.
- **[Fuel & Energy](./02-fuel-energy.md)** — The full-to-full and partial/missed-fill concepts that contextual tips and glossary popovers explain in depth.
- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — The TCO engine whose meaning contextual education and glossary popovers unpack for newcomers.
- **[Settings & Preferences](./21-settings-preferences.md)** — Where the tour can be re-run and where locale/unit/currency/calendar choices made during onboarding can be changed later.
- **[Glossary, Units, Calendars & Conventions](../reference/glossary.md)** — The canonical reference behind the in-app glossary popovers (full-to-full, whichever-first, RAG, TCO).
