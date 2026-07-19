# F4 · i18n / RTL / calendars / numerals engine

> Stand up the localization backbone — ARB pipeline, app-controlled locale in the encrypted DB, own calendar conversion math, numeral shaping, bidi-isolation, and bundled script fonts — so every surface renders correctly in LTR (en/de/fr) and RTL (fa/ar/ckb).

## Goal

Build the internationalization engine that makes localization Car and Pain's sharpest differentiator, using Flutter's built-in gen-l10n stack and first-party math rather than third-party calendar/numeral libraries.

Concretely, this epic delivers:

- A **gen-l10n ARB pipeline** (`flutter_localizations` + `intl`, `generate: true`, `l10n.yaml`) with a base `en` catalog and full `de`/`fr`/`fa`/`ar`/`ckb` catalogs carrying ICU/CLDR plural and gender categories.
- An **app-controlled locale** persisted in the encrypted Drift DB (not the OS locale), fed to `MaterialApp.locale`, with live switching and no restart.
- **Own Gregorian ⇄ Jalali/Hijri/Hebrew conversion math** derived from canonical UTC instants, with formatting and parsing — no third-party calendar dependency (built-in-first).
- **Numeral shaping** across Western, Eastern-Arabic and Persian digit sets, with Indian (South-Asian) grouping separators and robust input parsing back to canonical values.
- A **shared RTL & bidi rendering layer** that mirrors layouts via logical properties and bidi-isolates LTR-forced tokens (VIN, plate, phone, IBAN) inside RTL paragraphs.
- **Bundled, subset script fonts** for fa/ar/ckb with a resolved fallback chain and license compliance.
- A **string-externalization gate** so no user-facing string is ever hardcoded.
- **Exhaustive table-driven tests** for calendars, numerals, separators and plural categories.

This is a foundation module: every downstream feature module consumes its ARB keys, calendar/numeral formatters, and bidi helpers. It must be correct and complete before MVP feature work leans on it.

## Tier & dependencies

- **Tier:** foundation
- **Module:** `localization-rtl`
- **Depends on epics:**
  - **F1** — project scaffold & tooling (pub workspace, lints, CI, flavors); provides the package layout the `core/l10n` and formatter packages live in and the `flutter analyze` / lint infrastructure the externalization gate hooks into.
  - **F2** — data layer (Drift + SQLCipher, canonical units/money, migrations); provides the encrypted DB and settings table where the app-controlled locale, calendar, and numeral preferences are persisted, and the canonical UTC-instant storage the calendar conversions read from.

## References

- [docs/features/19-localization-rtl.md](../../features/19-localization-rtl.md) — feature spec for the localization / RTL / calendars module.
- [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md) — Flutter i18n/RTL/calendar implementation guidance (gen-l10n, ARB, locale control).
- [docs/flutter/15-accessibility-dynamic-type.md](../../flutter/15-accessibility-dynamic-type.md) — accessibility & dynamic type, incl. screen-reader reading of RTL text and Eastern-Arabic/Persian numerals.
- [docs/design/pulse/04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md) — PULSE motion, RTL and accessibility rules (mirroring, redundant encoding).
- [docs/reference/data-model.md](../../reference/data-model.md) — canonical storage contract (UTC instants, settings entities).
- [docs/reference/glossary.md](../../reference/glossary.md) — shared terminology (bidi-isolate, canonical instant, numeral systems).

## Tasks

### F4-T1 · gen-l10n ARB pipeline

**Description**
Configure Flutter's built-in gen-l10n toolchain: add `flutter_localizations` and `intl`, create `l10n.yaml` with `generate: true`, and establish the ARB catalog structure. Author a base `en` ARB (`app_en.arb`) as the template with `@` metadata (descriptions, placeholders with types/formats), and create `de`, `fr`, `fa`, `ar`, `ckb` catalogs. Encode ICU `plural`/`select` (and gender where relevant) so CLDR plural categories are honoured per locale — Arabic's `zero/one/two/few/many/other`, Persian and Sorani categories, English `one/other`. Wire the generated `AppLocalizations` delegate and `supportedLocales` into the app.

**Acceptance criteria**
- [ ] `l10n.yaml` present with `generate: true`, template `app_en.arb`, output class `AppLocalizations`, and configured ARB/output dirs.
- [ ] Base `en` ARB defines every string with `@`-metadata (description + typed placeholders) and no untyped placeholders.
- [ ] `de`, `fr`, `fa`, `ar`, `ckb` catalogs exist and cover all base keys (missing-key policy explicit: fail build or fall back to `en`, documented).
- [ ] ICU plural/select expressions cover the full CLDR category set required per locale, verified for `ar` (`zero/one/two/few/many/other`), `fa` and `ckb`.
- [ ] `supportedLocales` and `localizationsDelegates` (incl. `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, `GlobalCupertinoLocalizations`) registered in `MaterialApp`.
- [ ] `flutter gen-l10n` runs clean in CI; generated sources are reproducible and either committed or generated pre-build consistently.

**Size:** M
**Depends on:** F1
**Governing docs:** [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md), [docs/features/19-localization-rtl.md](../../features/19-localization-rtl.md)

---

### F4-T2 · Locale controller & persistence

**Description**
Implement an app-controlled locale that overrides the OS locale. Persist the user's chosen locale (and, jointly, calendar system and numeral system preferences — see F4-T3/F4-T4) in the encrypted Drift settings table. Expose a reactive controller (Riverpod provider backed by a Drift `.watch()` stream) that feeds `MaterialApp.locale`, supports first-run resolution (best-match against OS locale, else default `en`), and applies live switching without an app restart. Ensure locale changes propagate to directionality, formatters, and font resolution atomically.

**Acceptance criteria**
- [ ] Locale, calendar, and numeral preferences persist in the encrypted DB and survive restart, backup/restore, and migration.
- [ ] `MaterialApp.locale` is driven by the controller, ignoring OS locale changes once the user has chosen.
- [ ] First-run resolution picks the best supported match for the device locale, falling back to `en` when unsupported.
- [ ] Switching locale at runtime updates strings, text direction, numerals, calendar, and active font with no restart and no flash of wrong-direction layout.
- [ ] Preference reads/writes go through the repository boundary and return a sealed `Result`/`Failure`, never throw to the UI.
- [ ] Changing to an RTL locale flips `Directionality` app-wide; changing back restores LTR cleanly.

**Size:** M
**Depends on:** F1, F2, F4-T1
**Governing docs:** [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md), [docs/reference/data-model.md](../../reference/data-model.md)

---

### F4-T3 · Calendar conversion math

**Description**
Implement first-party bidirectional conversions between the proleptic Gregorian calendar and the Jalali (Solar Hijri), Hijri (Islamic — tabular/civil variant, documented), and Hebrew calendars, all derived from canonical UTC instants stored in the DB. Provide a clean model (`{calendarSystem, year, month, day}` plus wall-clock helpers), formatting (localized month/weekday names via ARB/intl symbols per locale), and parsing of user-entered dates back to canonical instants. Cover leap-year rules (Jalali 33-year cycle / astronomical-vs-arithmetic decision documented, Hebrew embolismic years and molad, Hijri tabular leap pattern) and boundary handling. Keep the math pure Dart (no third-party calendar package) for exhaustive testability.

**Acceptance criteria**
- [ ] Gregorian ⇄ Jalali, ⇄ Hijri, ⇄ Hebrew round-trip is lossless across a wide date range (verified against reference anchor dates per calendar).
- [ ] All conversions take a canonical UTC instant plus the display time zone and yield the correct local wall-clock date (no off-by-one across midnight/DST).
- [ ] Leap-year and month-length rules are correct and documented for each calendar; the chosen Hijri variant (tabular vs sighting) and Jalali algorithm are explicitly stated.
- [ ] Localized month and weekday names render per locale (fa/ar/ckb/en/de/fr) and read correctly under RTL.
- [ ] Parsing rejects invalid dates (e.g. Esfand 30 in a common year) with a typed validation failure, not an exception or silent wraparound.
- [ ] Formatters emit through the numeral layer (F4-T4) so dates show locale-correct digits.
- [ ] Pure-Dart, no third-party calendar dependency; 100% branch coverage on the conversion engine.

**Size:** L
**Depends on:** F2, F4-T4
**Governing docs:** [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md), [docs/features/19-localization-rtl.md](../../features/19-localization-rtl.md), [docs/reference/data-model.md](../../reference/data-model.md)

---

### F4-T4 · Numeral systems

**Description**
Implement digit shaping and de-shaping across Western Arabic (0-9), Eastern-Arabic (٠-٩), and Persian (۰-۹) numeral sets, plus locale-correct grouping — including South-Asian/Indian grouping (e.g. `12,34,567`) where the numeral/locale calls for it — and the correct decimal and grouping separators per locale. Provide a canonical formatting path (int/decimal minor-unit money, distances, counts) that routes through the active numeral system, and a robust input parser that accepts any of the numeral sets and separators and normalizes back to canonical machine values. Ensure the numeral system is user-selectable independent of locale where the feature spec allows.

**Acceptance criteria**
- [ ] Formatting produces Western, Eastern-Arabic, and Persian digits per the active numeral system.
- [ ] Grouping honours the locale/numeral rule, including Indian 2-2-3 grouping, with correct grouping and decimal separators.
- [ ] Input parsing accepts mixed/foreign digit sets and separators and normalizes to canonical values (minor-unit ints for money, SI base for measures).
- [ ] Round-trip format→parse→format is stable and lossless for representative money, distance, and count values.
- [ ] Numeral shaping integrates with money (ISO-4217 exponent) and unit formatting without double-rounding.
- [ ] Numerals inside RTL text are bidi-isolated correctly (coordinates with F4-T5) and read correctly by TalkBack/VoiceOver.
- [ ] Pure-Dart engine with exhaustive table-driven tests; no third-party numeral dependency.

**Size:** M
**Depends on:** F2
**Governing docs:** [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md), [docs/features/19-localization-rtl.md](../../features/19-localization-rtl.md), [docs/flutter/15-accessibility-dynamic-type.md](../../flutter/15-accessibility-dynamic-type.md)

---

### F4-T5 · RTL & bidi rendering layer

**Description**
Build the shared rendering layer that makes every screen mirror correctly under RTL and keeps embedded LTR tokens readable. Enforce logical (start/end) properties over left/right in the shared PULSE widgets and lints, mirror icons/chevrons/progress and traversal order where semantically appropriate (never mirror inherently-LTR glyphs like the play triangle without cause), and provide a bidi-isolation helper that wraps VIN, plate, phone, and IBAN strings so they render LTR intact inside RTL paragraphs (Unicode isolates / `Directionality` + `Bidi` utilities). Provide reusable widgets/extensions so feature modules get correct bidi behaviour by default.

**Acceptance criteria**
- [ ] Shared PULSE components use logical `EdgeInsetsDirectional`/`AlignmentDirectional`/start-end constraints; a lint or review check flags raw left/right in UI code.
- [ ] Under an RTL locale, layouts mirror, focus/traversal order is right-to-left, and directional icons mirror correctly while non-mirrorable glyphs do not.
- [ ] A bidi-isolate helper renders VIN, license plate, phone, and IBAN as intact LTR runs within RTL sentences (no digit/character reordering, no bracket flipping).
- [ ] Numbers + units (from F4-T4) embed in RTL text without visual reordering.
- [ ] Mixed-direction strings (RTL label + LTR ID) copy/paste and screen-read in the correct visual and logical order.
- [ ] Widget/golden tests cover key screens in both an LTR and an RTL locale.

**Size:** M
**Depends on:** F4-T1, F4-T4, (PULSE component epic)
**Governing docs:** [docs/design/pulse/04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md), [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md), [docs/flutter/15-accessibility-dynamic-type.md](../../flutter/15-accessibility-dynamic-type.md)

---

### F4-T6 · Bundled script fonts

**Description**
Select, subset, and bundle fonts covering the Arabic script (ar), Persian (fa) and Sorani Kurdish (ckb — needs the extended Arabic-script glyph set) plus Latin (en/de/fr), define a resolved fallback chain in `TextTheme`/`fontFamilyFallback`, and ensure all licenses (SIL OFL or equivalent) permit bundling and redistribution. Subset to needed glyph ranges to keep the app binary lean (built-in-first, minimal weight), and verify shaping (contextual joining, Persian/Sorani-specific letterforms like ک/گ/ی and ڕ/ڵ/ۆ) renders correctly.

**Acceptance criteria**
- [ ] Fonts registered in `pubspec.yaml` and applied via the theme with an explicit `fontFamilyFallback` chain per script.
- [ ] Arabic, Persian, and Sorani Kurdish glyphs (including contextual joining and Sorani-specific letters) render correctly on iOS and Android.
- [ ] Fonts are subset to required ranges with the binary-size impact measured and recorded.
- [ ] Every bundled font's license is OFL-compatible (or otherwise redistribution-permitting) and recorded in the third-party/licensing manifest for store compliance.
- [ ] Missing-glyph fallback degrades gracefully (no tofu boxes) across supported locales.

**Size:** S
**Depends on:** F1
**Governing docs:** [docs/features/19-localization-rtl.md](../../features/19-localization-rtl.md), [docs/design/pulse/04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md)

---

### F4-T7 · String externalization gate

**Description**
Establish an automated lint/review gate ensuring no user-facing string is hardcoded anywhere in the app. Enable/author an analyzer rule (e.g. custom_lint / `flutter_lints` string-literal-in-widget check) that flags literal strings in UI, wire it into `flutter analyze` and CI so violations fail the build, and add a PR review checklist item. Allow a documented, narrow escape-hatch annotation for genuinely non-localizable literals (debug logs, keys, canonical codes).

**Acceptance criteria**
- [ ] An analyzer/custom-lint rule flags hardcoded user-facing string literals in widget/UI code.
- [ ] The gate runs in CI and fails the build on violations (`flutter analyze` non-zero exit).
- [ ] A documented, greppable escape-hatch exists for non-localizable literals and is used sparingly.
- [ ] The existing codebase passes the gate at merge time (baseline clean).
- [ ] Contributor docs describe how to add a new string via ARB and why the gate exists.

**Size:** S
**Depends on:** F1, F4-T1
**Governing docs:** [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md), [docs/features/19-localization-rtl.md](../../features/19-localization-rtl.md)

---

### F4-T8 · i18n / calendar / numeral tests

**Description**
Author exhaustive, table-driven tests across the engine: calendar round-trips and anchor dates for all four calendars, numeral shaping/parsing across all three digit sets, grouping/decimal separators (incl. Indian grouping), and ICU plural category selection per locale. Include RTL widget/golden tests and screen-reader-semantics assertions where feasible. Enforce 100% coverage on the pure-Dart calendar and numeral engines per the testing strategy.

**Acceptance criteria**
- [ ] Table-driven calendar tests cover Gregorian ⇄ Jalali/Hijri/Hebrew with reference anchors, leap years, and month boundaries; round-trips lossless.
- [ ] Numeral tests cover Western/Eastern-Arabic/Persian shaping, parsing of mixed input, and all separator/grouping rules incl. Indian grouping.
- [ ] Plural-category tests assert correct ICU selection for `en/de/fr/fa/ar/ckb` across boundary counts (0,1,2,3,11,100,…).
- [ ] RTL widget/golden tests verify mirroring and bidi-isolation on representative screens.
- [ ] Semantics tests assert numerals and RTL text read in correct order for screen readers where testable.
- [ ] Pure-Dart calendar and numeral engines at 100% coverage; suite runs in CI.

**Size:** M
**Depends on:** F4-T3, F4-T4, F4-T5, F4-T1
**Governing docs:** [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md), [docs/features/19-localization-rtl.md](../../features/19-localization-rtl.md), [docs/flutter/15-accessibility-dynamic-type.md](../../flutter/15-accessibility-dynamic-type.md)

---

### F4-T9 · Locale/calendar/numeral settings UI (PULSE) · added

**Description**
_Added for a complete vertical slice (PULSE UI surface for the engine)._ Build the language / calendar / numeral selection surfaces in the PULSE design system, consumed by the Settings module and the first-run language wizard. Present supported languages in their own script/endonym, calendar and numeral pickers, and a live preview (a sample date + number rendering in the chosen combination). All controls follow PULSE tokens/components, mirror under RTL, and encode selection state redundantly (icon + label + checkmark position, not colour alone).

**Acceptance criteria**
- [ ] Language picker lists each language by endonym in its own script and applies instantly (live switching via F4-T2).
- [ ] Calendar and numeral pickers exist with a live sample-date + sample-number preview reflecting the current combination.
- [ ] All controls built from PULSE components and tokens; layout mirrors correctly under RTL.
- [ ] Selection state is redundantly encoded (not colour-only) per the PULSE redundant-encoding rule.
- [ ] Screen is fully localized (no hardcoded strings) and passes the F4-T7 gate.

**Size:** M
**Depends on:** F4-T2, F4-T3, F4-T4, F4-T5, (PULSE component epic)
**Governing docs:** [docs/design/pulse/04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md), [docs/features/19-localization-rtl.md](../../features/19-localization-rtl.md)

---

### F4-T10 · Backup/export coverage of localization preferences · added

**Description**
_Added for a complete vertical slice (export/backup coverage)._ Ensure the locale, calendar system, and numeral system preferences are included in the single-file encrypted backup and the JSON/CSV export, with schema/format versioning, and are restored correctly on import/merge — so a user's language and formatting choices round-trip across devices and restores. Exported dates/numbers document their canonical (UTC/machine) representation so exports are locale-independent for data integrity while display honours the restored preference.

**Acceptance criteria**
- [ ] Locale/calendar/numeral preferences are written to the full backup and the JSON export with a schema version.
- [ ] Restore/import applies the preferences and the app renders in the restored language/calendar/numeral without restart.
- [ ] Exported data values remain canonical (UTC instants, machine numerals) regardless of display preference; a round-trip export→import preserves both data and preferences.
- [ ] Backward/forward compatibility handled for a preference key absent in an older backup (falls back to first-run resolution).

**Size:** S
**Depends on:** F2, F4-T2
**Governing docs:** [docs/reference/data-model.md](../../reference/data-model.md), [docs/features/19-localization-rtl.md](../../features/19-localization-rtl.md)

---

## Definition of Done

- **Tasks complete:** F4-T1 through F4-T10 meet all their acceptance criteria.
- **i18n complete:** every user-facing string flows through the ARB pipeline; the externalization gate (F4-T7) is green in CI; `de/fr/fa/ar/ckb` catalogs fully cover the `en` base with correct ICU/CLDR plural categories; the missing-key policy is enforced.
- **RTL verified:** the app mirrors correctly under fa/ar/ckb via logical properties; icons/traversal mirror appropriately; VIN/plate/phone/IBAN and numbers+units are bidi-isolated and read correctly; RTL golden tests pass.
- **Calendars & numerals correct:** own Gregorian ⇄ Jalali/Hijri/Hebrew math and Western/Eastern-Arabic/Persian numeral shaping (incl. Indian grouping and input parsing) pass exhaustive table-driven tests; pure-Dart engines at 100% coverage; no third-party calendar/numeral runtime dependency added.
- **Persistence & live switch:** locale/calendar/numeral preferences live in the encrypted DB, drive `MaterialApp.locale`, and switch live with no restart and no wrong-direction flash.
- **Fonts & licensing:** subset fa/ar/ckb fonts bundle with a resolved fallback chain, render all required glyphs on iOS + Android, and every license is recorded in the store-compliance/licensing manifest.
- **In backup/export:** localization preferences are covered by the single-file backup and JSON/CSV export with schema versioning and round-trip correctly on restore/import.
- **Accessible per the redundant-encoding rule:** the settings/wizard UI and any status shown by this engine encode state beyond colour (icon + label + shape/position); numerals and RTL text read correctly under TalkBack/VoiceOver; the surfaces respect dynamic type.
- **CI green:** `flutter analyze`, `dart format --set-exit-if-changed`, gen-l10n, and the full test suite pass.
