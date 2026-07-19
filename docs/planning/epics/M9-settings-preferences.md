# M9 · Settings & Preferences

> The central control surface that ties every cross-cutting preference together — language, units, currency, calendar and numerals, accessibility, notifications, security and app-lock, and backup scheduling — all resolving through the one canonical precedence model.

## Goal

Ship the single place where the user tells Car and Pain how *they* live, and every other module obeys. Settings is a first-class, offline, account-free control surface — not a menu bolted onto a US-centric core — where each cross-cutting choice is **explicit, independent, reversible, and non-destructive**. Because the app stores everything canonically (SI units, currency minor units, UTC/wall-clock dates) and converts only at display and export, the user can toggle any preference at any time without ever rewriting a single stored value.

Concretely this epic delivers: the global/per-vehicle **Setting store** and the canonical `per-record override → per-vehicle setting → global default` **precedence resolver** every module reads through; **decoupled i18n controls** (language, numerals, calendar, digit-grouping, per-measure units, home + per-vehicle currency, manual dated FX) wired to the F4 engine for **live-apply** without restart; **accessibility + theme** controls (high-contrast, reduced-motion, text scale, colour-blind palette, haptics) over the F3/accessibility layer; **security & app-lock** (encryption, biometric/PIN, sensitive-section scoping, recovery-code UI) over F7; **notification behavior** (channels, digests, quiet hours, default lead times, permission status + battery-optimization guidance) over F5; **backup scheduling** (auto cadence, retention, self-hosted/local/SD/opt-in-cloud targets, encryption passphrase, and manual export/import entry points) over F6; the shared **category & tag taxonomy** manager; and the app's **privacy-honesty surface** (no-account, 100% offline, no-ads, no-forced-sync, no-telemetry) with secure-wipe/panic-reset. Every screen is fully localized PULSE, RTL-verified, and the entire `Setting` entity round-trips through export/backup so a restore reproduces the exact setup. The governing contract, made visible and testable here: **changing how data is displayed or protected never changes the canonical data itself.**

## Tier & dependencies

- **Tier:** MVP (`mvp`) — the cross-cutting control panel the other MVP modules configure through.
- **Depends on:**
  - **F2** — Encrypted data layer (Drift + SQLCipher, canonical units/money, migrations, soft-delete/trash) that stores the `Setting` entity and enforces the canonical contract.
  - **F3** — PULSE design system implementation (tokens + components) for every settings screen and control.
  - **F4** — i18n / RTL / calendars / numerals engine that the locale/units/currency/calendar/numeral controls drive live.
  - **F5** — Local notification engine that notification-behavior settings configure (channels, quiet hours, digests, lead times).
  - **F6** — Backup / export / import + key-recovery subsystem that backup-scheduling settings drive and that the `Setting` entity round-trips through.
  - **F7** — Security & app-lock (whole-DB encryption, biometric/PIN, recoverable master key, sensitive-section scoping) that the security settings expose.
  - **M1** — Shared canonical-contract repository + precedence foundation this module extends into a user-editable settings surface.

## References

- [docs/features/21-settings-preferences.md](../../features/21-settings-preferences.md) — feature spec, field list, precedence/conversion formulas, edge cases, honesty surface.
- [docs/flutter/06-i18n-rtl-calendars.md](../../flutter/06-i18n-rtl-calendars.md) — gen-l10n/ARB, app-controlled locale, RTL mirroring, bidi isolation, calendars, numerals.
- [docs/flutter/09-security-privacy.md](../../flutter/09-security-privacy.md) — encryption layers, recoverable master key, biometric/PIN, sensitive-section scoping, secure wipe.
- [docs/flutter/13-backup-export-recovery.md](../../flutter/13-backup-export-recovery.md) — VACUUM-INTO backups, scheduling, self-hosted/local targets, encryption, restore.
- [docs/design/pulse/02-components.md](../../design/pulse/02-components.md) — list rows, toggles/segmented controls, pickers, status chips, Rooms nav.
- [docs/reference/data-model.md](../../reference/data-model.md) — `Setting` entity contract, precedence conventions, export/backup mapping.

## Tasks

### M9-T1 · Settings schema & precedence

**Description.** Model the `Setting` entity from the data model as a Drift-backed store with a **global** singleton row plus **per-vehicle** override rows (keyed by `vehicle_id`), covering the full field set: language/`follow_system_locale`, numeral system, calendar system, grouping style, the five display units (distance/volume/consumption/pressure/temperature), home currency + per-vehicle currency overrides + `manual_exchange_rates[]`, `first_day_of_week`/`fiscal_year_start`, theme, `a11y_prefs{}`, reminder default lead times, quiet hours, notification channels, app-lock/security fields, auto-backup + targets, opt-in cloud/self-hosted flags, analytics-opt-in (default false), category taxonomy, and `default_vehicle_id`. Build a `SettingsRepository` over the M1 canonical boundary exposing a **pure `PreferenceResolver`** that returns the effective value for any convertible preference via `per-record override → per-vehicle setting → global default`, with an unset level transparently falling through. Expose reactive Drift `.watch()` streams so changing a preference re-renders dependent surfaces app-wide with no restart, and return sealed `Result<T, Failure>` at every boundary. Secrets are never stored in clear (PIN as salted hash; keys via F7 secure storage).

**Acceptance criteria**
- [ ] Drift schema persists a global settings singleton plus per-vehicle override rows; every field in the `Setting` contract has a column (or normalized child table for `manual_exchange_rates[]` / `notification_channels[]` / `category_taxonomy[]`).
- [ ] `PreferenceResolver.resolve(key, {vehicleId, recordOverride})` returns the effective value via `per-record → per-vehicle → global`, falling through unset levels deterministically.
- [ ] Repository exposes reactive `watchGlobal()` / `watchForVehicle(id)` streams and returns `Result` over a sealed `Failure` hierarchy (stable codes, no user strings).
- [ ] Canonical storage is never mutated by a preference change — only display/protection changes (contract-level invariant asserted in code).
- [ ] `pin_hash` stored salted; no secret (PIN, passphrase, keys) is ever persisted in clear; forward-only migration bumps `schema_version` behind a pre-migration snapshot.

**Size:** M · **Depends on:** F2, M1 · **Governing docs:** data-model.md (Setting, precedence), 21-settings-preferences.md (data captured, formulas), 03-data-persistence.

### M9-T2 · Locale / units / currency / calendar / numerals controls

**Description.** Wire the F4 i18n engine to **live-apply** controls. In-app language selection independent of device locale (`follow_system_locale` uses the OS only as a hint) across en/de/fr (LTR) + fa/ar/ckb (RTL), feeding `MaterialApp.locale`. Independent pickers for numeral system (Western / Eastern-Arabic / Persian / Devanagari), calendar (Gregorian / Jalali / Hijri / Hebrew), and digit-grouping (thousands vs Indian lakh/crore). Global unit pickers for distance/volume/consumption/pressure/temperature, plus a home-currency picker, per-vehicle currency defaults, and a manual dated FX-rate editor (no live feed implied). `first_day_of_week` and `fiscal_year_start` entered/displayed in the active calendar. **Regional preset bundles** (Iran, Germany, France, US, Saudi Arabia, Kurdistan, Turkey, India, Israel, Spain, Brazil) set every axis at once as a starting point, after which any single axis can still be overridden. Every control shows a **live numeric/date preview** rendered through the chosen axes; each axis is fully decoupled from the others.

**Acceptance criteria**
- [ ] Language, numerals, calendar, grouping, each unit, and currency are independently settable; picking a language never implies a calendar or numeral system.
- [ ] Changing any axis applies **live** (no restart) and re-renders dependent surfaces via the reactive streams; the change never rewrites stored canonical values.
- [ ] Regional preset bundles set all axes at once; a subsequent single-axis override wins and persists.
- [ ] Home currency + per-vehicle currency overrides persist and resolve via precedence; manual dated FX snapshots (from/to/rate/date) are editable and used offline only.
- [ ] `first_day_of_week` / `fiscal_year_start` accept and display in the active calendar while storing canonical ISO; a live preview shows values in the chosen numeral system + grouping.

**Size:** M · **Depends on:** F4, M9-T1 · **Governing docs:** 06-i18n-rtl-calendars.md, 14-money-currency-fx, 21-settings-preferences.md (i18n, presets, formulas).

### M9-T8 · Accessibility, theme & display-behavior settings

**Description.** Expose the accessibility layer as **structural** preferences (not cosmetic extras) over the F3 / accessibility infrastructure: high-contrast mode, reduced motion, text scale / dynamic type, a colour-blind-safe chart palette, and haptic feedback, persisted in `a11y_prefs{}`. Add the theme control (light / dark / system) with warm-paper/ink dual theme, respecting the rule that **accessibility overrides win over theme** (high-contrast can override chosen theme colours without breaking layout). All changes apply live through the reactive streams. Because status is always redundantly encoded, toggling the colour-blind palette must never be the sole thing that conveys state.

**Acceptance criteria**
- [ ] High-contrast, reduced-motion, text-scale, colour-blind-palette, and haptics toggles persist in `a11y_prefs{}` and apply live app-wide.
- [ ] Theme control offers light / dark / system; accessibility overrides (e.g. high-contrast) take precedence over theme colours without breaking layout.
- [ ] Reduced-motion disables non-essential PULSE motion (halo/exhale) while preserving state legibility; text-scale reflows settings screens without truncation or overlap.
- [ ] Colour-blind palette changes chart/stat colours only; state remains conveyed by icon + label + shape/position regardless of palette.

**Size:** S · **Depends on:** F3, M9-T1 · **Governing docs:** 15-accessibility-dynamic-type, 04-motion-rtl-accessibility, 21-settings-preferences.md (accessibility settings, edge cases).

### M9-T3 · Security & app-lock settings

**Description.** Surface F7's security stack as user controls: enable/verify whole-DB **encryption** at rest, enable **app-lock** with PIN/passcode + optional **biometric** unlock and a configurable **auto-lock timeout** (relock when `now − last_interaction ≥ timeout`, evaluated on foreground/resume), a `lock_scope` toggle for **whole-app vs sensitive-section-only** scoping (documents / medical-ICE), and the **recovery-code UI** for the recoverable master key (passphrase-wrapped KEK + one-time recovery code with an un-skippable loss warning). Enabling encryption/app-lock **re-secures existing data in place** (no wipe, no loss). Handle the biometric-invalidation edge: if enrolled biometrics change or are removed, the biometric-bound key is invalidated and the app falls back to the always-required PIN/passphrase backstop.

**Acceptance criteria**
- [ ] Enabling at-rest encryption re-secures existing data in place without loss; state is verifiable in-app.
- [ ] App-lock enable sets PIN/passcode (stored only as salted hash) with optional biometric; auto-lock timeout relocks on foreground/resume per policy.
- [ ] `lock_scope` toggles whole-app vs sensitive-section-only locking; scoped sections require unlock while the rest stays accessible.
- [ ] Recovery-code UI generates/records the one-time recovery code with an un-skippable loss warning; passphrase-wrapped key recovery is exercised end-to-end.
- [ ] Changed/removed device biometrics invalidate the biometric key and fall back to PIN/passphrase; PIN/passphrase is always a mandatory backstop.

**Size:** M · **Depends on:** F7, M9-T1 · **Governing docs:** 09-security-privacy.md, 21-settings-preferences.md (app lock, edge cases), security/app-lock cross-cut.

### M9-T4 · Notification behavior settings

**Description.** The control panel over the F5 engine (Settings itself emits no reminders). Manage **per-severity channels** (sound / vibration / importance) and grouped-**digest** preferences, define **quiet hours** (`{start,end}` local window during which due notifications are queued and delivered afterward), and set **default lead times** per trigger type — date offsets (e.g. "1 week before"), distance offsets (e.g. "1000 km before"), and engine-hour offsets — consumed by date / distance / engine-hour / whichever-first reminders across the app. Show current OS **notification-permission status** and platform-specific **battery-optimization guidance**; if permission is denied, surface the graceful degrade (in-app due list, keep re-arming) rather than presenting reminders as lost.

**Acceptance criteria**
- [ ] Per-severity channels expose sound/vibration/importance and grouped-digest preferences; changes persist and reach the F5 engine.
- [ ] Quiet-hours window persists and holds due notifications until after the window, in local time.
- [ ] Default lead times settable per trigger type (date / distance / engine-hour) and applied to whichever-first reminders app-wide.
- [ ] OS permission status is displayed; denied state shows battery-optimization guidance and the honest in-app-due-list degrade, never silent loss.

**Size:** S · **Depends on:** F5, M9-T1 · **Governing docs:** 07-notifications, 21-settings-preferences.md (reminders & notifications), 04-reminders-notifications.

### M9-T5 · Backup scheduling settings

**Description.** The control surface over the F6 subsystem: configure **auto-backup** (`{enabled, interval, location, keep_last_n, encrypt}`), choose destinations in `backup_targets{}` — on-device file, SD-card, **self-hosted** (WebDAV / Nextcloud / SFTP), or strictly-opt-in cloud — set an optional **encryption passphrase**, and set **retention** (generations to keep). `cloud_features_enabled` / `selfhosted_enabled` default **off** and transmit nothing until explicitly enabled and configured. Provide **manual export / import / full-backup / restore** entry points (single-file backup, per-entity CSV/JSON, importers with competitor presets, merge-aware restore) — the data-ownership controls, never paywalled. Backups follow F6's contract (WAL-checkpoint + VACUUM INTO, AES-256-GCM with Argon2id-derived key, atomic temp-then-rename).

**Acceptance criteria**
- [ ] Auto-backup config (enabled / interval / location / keep_last_n / encrypt) persists and drives F6 scheduling; retention prunes to `keep_last_n`.
- [ ] `backup_targets{}` supports local / SD-card / self-hosted (WebDAV/Nextcloud/SFTP) / opt-in cloud; self-hosted + cloud default off and transmit nothing until user-configured.
- [ ] Optional backup encryption passphrase is set and used (AES-256-GCM, Argon2id KDF) per the F6 contract; passphrase never stored in clear.
- [ ] Manual export (single-file backup, per-entity CSV/JSON), import wizard, and merge-aware restore are reachable one-tap and never paywalled.

**Size:** M · **Depends on:** F6, M9-T1 · **Governing docs:** 13-backup-export-recovery.md, 21-settings-preferences.md (backup schedule), 18-data-offline-backup.

### M9-T9 · Category & tag taxonomy management

**Description.** Expose the shared taxonomy manager over the cross-cutting category/tag system: add, rename, reorder, re-icon, recolour, and archive service types, expense categories, trip categories, and tags — the taxonomy that entry, filtering, budgets, and reports depend on. Each entry carries icon/colour and (where relevant) default intervals and analytic-bucket mapping. Editing never breaks existing records: rename/re-icon updates in place; archive hides from pickers while preserving historical references; reorder sets a stable custom order. Taxonomy round-trips through export/backup (see M9-T11) so custom types and tags survive migration.

**Acceptance criteria**
- [ ] Users can add / rename / reorder / re-icon / recolour / archive service types, expense categories, trip categories, and tags.
- [ ] Renaming or re-iconing updates in place without orphaning existing records; archiving hides from pickers while preserving historical references.
- [ ] Custom order is stable and persisted; analytic-bucket mapping (where applicable) is retained.
- [ ] Taxonomy entries are localized/bidi-safe and render in the active numeral system where they carry numeric defaults (e.g. default intervals).

**Size:** M · **Depends on:** M9-T1, F3 · **Governing docs:** 21-settings-preferences.md (category & tag management), category/tag/taxonomy cross-cut.

### M9-T10 · Privacy-honesty surface, secure wipe & data controls

**Description.** Build the app's **honesty surface**: an always-available, plain-language assurance that Car and Pain is **no-account, 100% offline, no-ads, no-forced-sync, and telemetry-free by default**, with links to the security (M9-T3) and data (M9-T5) controls that back each claim. Include the **crash-reporting opt-in** (`analytics_enabled`, default **false**, clearly labelled). Implement **secure wipe / panic reset**: irreversibly erase all app data with encryption-key destruction, behind an explicit multi-step confirmation, for device handover or emergency privacy. Surface **trash / recycle-bin management**: review, restore, or permanently purge soft-deleted records and set the trash retention window before auto-cleanup.

**Acceptance criteria**
- [ ] Privacy-assurance panel states no-account / offline / no-ads / no-forced-sync / no-telemetry in plain language, always reachable, with links to the controls backing each claim.
- [ ] Crash-reporting/analytics opt-in defaults to false and is clearly labelled; nothing is transmitted while off.
- [ ] Secure wipe irreversibly erases all data and destroys the encryption key behind an explicit multi-step confirmation; post-wipe the DB is unrecoverable.
- [ ] Trash view lists soft-deleted records with restore + permanent-purge; retention window is configurable and drives auto-cleanup.

**Size:** M · **Depends on:** M9-T1, F7, F2 · **Governing docs:** 09-security-privacy.md, 21-settings-preferences.md (privacy surface, secure wipe, trash), 17-store-compliance-licensing.

### M9-T6 · Settings UI & i18n

**Description.** Compose the fully localized PULSE settings screens: a grouped settings home (accessible via the app's nav) routing into per-section screens for i18n, accessibility & theme, security & app-lock, notifications, backup & data, taxonomy, privacy, and per-vehicle overrides. Use PULSE list rows, toggles, segmented controls, and pickers with tokens from F3; status is **always redundantly encoded** (icon + label + shape + position), never colour alone. Externalize **every** user-facing string to ARB via gen-l10n for en/de/fr/fa/ar/ckb, with full **RTL layout mirroring** and mirrored focus/traversal order, while keeping identifiers (VIN / plate / IBAN / phone) LTR via bidi isolation. Numeric/date previews render in the active numeral system + calendar. Screens carry `Semantics` labels, reflow under dynamic type, and meet minimum touch targets. Include a first-run entry point that seeds preferences from a device-locale hint (links into onboarding).

**Acceptance criteria**
- [ ] Grouped PULSE settings home + per-section screens render with F3 tokens/components; every status indicator uses icon + label + shape/position, not colour alone.
- [ ] No hardcoded user-facing strings; all resolve through ARB for all six locales.
- [ ] RTL screens mirror layout and traversal/focus order; VIN/plate/IBAN/phone stay LTR via bidi isolation; numeric/date previews use the active numeral system + calendar.
- [ ] Screens carry `Semantics` labels, reflow under dynamic type without truncation, and meet minimum touch-target sizes.
- [ ] A first-run/onboarding entry point seeds axes from the device-locale hint and lets the user confirm or change each.

**Size:** M · **Depends on:** F3, F4, M9-T2, M9-T3, M9-T4, M9-T5, M9-T8, M9-T9, M9-T10 · **Governing docs:** 02-components.md, 03-screens.md, 06-i18n-rtl-calendars.md, 21-settings-preferences.md (localization & RTL), 25-onboarding-help.

### M9-T11 · Setting entity export/backup mapping

**Description.** Map the `Setting` entity (global + per-vehicle overrides, plus child collections: `manual_exchange_rates[]`, `notification_channels[]`, `category_taxonomy[]`) into the F6 export/backup subsystem so a restore reproduces the exact setup. The full single-file backup includes the complete non-secret settings object (language, units, currency, calendar, numerals, accessibility, theme, notification defaults, category taxonomy, backup config sans secrets) alongside every module's records. **Secrets are handled safely**: the PIN travels only as its salted hash (or is excluded), backup passphrase/keys are never serialized in clear, and opt-in cloud/self-hosted credentials are excluded or secure-store-referenced. Restore is **merge-aware by UUID** and re-applies settings without clobbering unrelated on-device state; the category taxonomy round-trips so custom types and tags survive migration. Per-entity CSV/JSON export honors the same non-secret contract.

**Acceptance criteria**
- [ ] Full JSON/ZIP backup includes global + per-vehicle settings and child collections; a restore on a new device reproduces the exact non-secret setup.
- [ ] No secret is serialized in clear: PIN only as salted hash (or omitted), backup passphrase/keys never exported, cloud/self-hosted credentials excluded or secure-store-referenced.
- [ ] Merge-aware restore reconciles settings by UUID and does not clobber unrelated on-device state; tombstones honored.
- [ ] Category taxonomy round-trips losslessly (icons/colours/order/mappings); per-entity CSV/JSON export honors the same non-secret contract.

**Size:** S · **Depends on:** F6, M9-T1, M9-T9 · **Governing docs:** data-model.md (export/backup mapping), 13-backup-export-recovery.md, 21-settings-preferences.md (offline & data).

### M9-T7 · Tests

**Description.** Layered tests per the diamond-topped pyramid, weighted to the pure logic. Exhaustive table-driven pure-Dart unit tests for the **`PreferenceResolver`** (`per-record → per-vehicle → global` fall-through across every convertible axis, including unset-level fall-through and per-vehicle-wins), conversion-factor management (`display = canonical × factor`, e.g. `mi = km × 0.621371`, `mpg_US = 235.215 / (L/100km)`) asserting canonical values are never mutated, budget/fiscal-boundary derivation from `fiscal_year_start` + `first_day_of_week` in each calendar, and auto-lock-timeout evaluation. Repository integration tests over an in-memory encrypted Drift DB (global + per-vehicle CRUD, precedence, migration, taxonomy round-trip). Widget tests for **live-apply** (changing language/numerals/calendar/units/theme re-renders dependent surfaces without restart), the security flows (app-lock, sensitive-section scoping, recovery-code, biometric-fallback), and secure-wipe confirmation. RTL/pseudolocale + `Semantics`/a11y checks and golden coverage of the redundant status encoding on settings screens. Export/backup round-trip test asserting non-secret settings restore and no secret leaks into the archive.

**Acceptance criteria**
- [ ] Exhaustive table-driven cases cover `PreferenceResolver` precedence + fall-through, unit conversion factors, fiscal/budget-boundary derivation, and auto-lock evaluation; conversion tests assert canonical values are never rewritten.
- [ ] Repository tests cover global + per-vehicle CRUD, precedence, encrypted in-memory migration, and taxonomy round-trip.
- [ ] Widget tests assert live-apply of language/numerals/calendar/units/theme without restart, and the security flows (app-lock, scoping, recovery-code, biometric fallback to PIN) plus secure-wipe confirmation.
- [ ] RTL/pseudolocale render check + `Semantics`/a11y assertions pass; golden covers redundant status encoding.
- [ ] Export/backup round-trip restores non-secret settings and taxonomy losslessly and proves no PIN/passphrase/key/credential is serialized in clear.

**Size:** S · **Depends on:** M9-T1..T6, M9-T8..T11 · **Governing docs:** 11-testing, 21-settings-preferences.md (formulas/edge cases), 15-accessibility-dynamic-type.

## Definition of Done

- **Functionality:** A first-class offline settings surface where language, numerals, calendar, grouping, per-measure units, home + per-vehicle currency (with dated manual FX), accessibility, theme, notification behavior, security & app-lock (encryption, biometric/PIN, sensitive-section scoping, recovery code), backup scheduling (auto cadence, retention, local/SD/self-hosted/opt-in-cloud, encryption passphrase, manual export/import/restore), category taxonomy, privacy honesty surface, secure wipe, and trash management are all editable, all resolving through the canonical `per-record → per-vehicle → global` precedence — with changes applied live and no restart.
- **Non-destructive contract:** Changing display or protection preferences (units/currency/calendar/numerals/theme/encryption) provably never rewrites stored canonical values; asserted in tests.
- **Built-in-first:** No new runtime third-party dependency beyond the sanctioned set; the precedence resolver and conversion/boundary math are pure Dart; state via DB streams + `ValueNotifier`/Riverpod providers; i18n via flutter_localizations/intl.
- **Tests:** Pure-Dart resolver/conversion/boundary/auto-lock engines at exhaustive table-driven coverage; repository, live-apply, security, and export-round-trip integration/widget tests green; `flutter analyze` + `dart format --set-exit-if-changed` clean.
- **i18n complete:** All user-facing strings externalized to ARB for en/de/fr/fa/ar/ckb; numerals/calendars/grouping honored in previews; no hardcoded strings.
- **RTL verified:** All settings screens mirror layout and traversal/focus order; VIN/plate/IBAN/phone stay LTR via bidi isolation; RTL/pseudolocale check passes.
- **Backup/export:** The full `Setting` entity (global + per-vehicle + taxonomy + child collections) round-trips losslessly through the combined JSON/ZIP backup and per-entity export; merge-aware restore is UUID-based and non-clobbering; no secret (PIN/passphrase/key/credential) is ever serialized in clear.
- **Accessible:** Every status indicator is redundantly encoded (icon + label + shape + position), never colour alone; accessibility overrides win over theme; screens carry `Semantics` labels, reflow under dynamic type, and meet minimum touch targets.
