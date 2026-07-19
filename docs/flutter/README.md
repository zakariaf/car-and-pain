# 🛠️ Flutter Engineering Guide — Index

> The source-of-truth engineering guide for **Car and Pain** — a 100% offline-first, account-free, no-telemetry Flutter app. Written to be built from by both human engineers and AI coding agents: every decision here is concrete, opinionated, and load-bearing.

Car and Pain is a **data-custody product wearing a car app's clothes**: the user's years of hand-entered maintenance history exist nowhere else, there is no server to re-sync from, and no telemetry to tell us when something broke. Every decision in these docs optimizes for **correctness, durability, and reboot/Doze survival** over feature velocity. Two durability laws are never softened to "nice to have": the master key is **recoverable by default** (encryption is worthless if the key is lost), and the encrypted DB is **not** the backup — a proactive, verified, local backup subsystem is the real disaster-recovery guarantee.

## Start here

Read **[Engineering Philosophy & Principles](./00-overview.md)** first. It is the contract every other doc elaborates: the data-custody-first philosophy, why offline/no-network inverts the classic Flutter layering, the recoverable-key + proactive-backup doctrine, the instant-vs-wall-clock storage distinction, the reactive-graph mental model, and the ~14 concrete engineering principles.

## The stack in one line

**Flutter + a feature-first modular monolith** on a native Dart Pub Workspace (Melos for scripts/CI), **Riverpod 3.x with codegen** as unified DI + state, **Drift over encrypted SQLite** (SQLCipher default; sqlite3mc build-hook only if the week-one spike passes), **go_router** with typed routes, **flutter_local_notifications** `zonedSchedule` as the single reminder engine, **built-in gen-l10n** for i18n/RTL/calendars/numerals, pure Flutter-free Dart engines injected with a `Clock`, and a **buy-once / no-ads / no-telemetry** posture enforced by CI, not just promised.

## Documents

| # | Document | Covers |
|---|----------|--------|
| 00 | [Engineering Philosophy & Principles](./00-overview.md) | Data-custody-first philosophy, the inverted offline layering, recoverable-key + proactive-backup doctrine, instant-vs-wall-clock storage, the reactive-graph mental model, and the ~14 core principles. |
| 01 | [Architecture & Module Structure](./01-architecture-and-structure.md) | Feature-first modular monolith on a Pub Workspace: ~25 feature folders vs foundational packages, MVVM + when to add a domain layer, barrels, the DAG rule, and boundary enforcement (custom_lint + geometry grep + DB-header assertion). |
| 02 | [State Management with Riverpod](./02-state-management.md) | Riverpod 3.x + codegen as DI + state: keepAlive repo/DB providers, scoped Drift `.watch()` stream providers, memoized analytics/TCO, stable AsyncNotifier for backup/import, settings notifiers, startup gating, and rebuild-storm avoidance. |
| 03 | [Local Database, Schema, Indexing & Migrations](./03-data-persistence.md) | Drift over encrypted SQLite, PRAGMA-key-first + asserted cipher + not-plaintext header test, shared DAOs, UUIDv7 + soft-delete, the shared ledger with revision-keyed rollups, index/query-plan strategy, content-addressed attachments, and forward-only snapshot-guarded migrations. |
| 04 | [Dependency Injection & Composition Root](./04-dependency-injection.md) | Riverpod as the single DI mechanism: placeholder root providers overridden at `main()`, repository/service/engine layering, keepAlive vs autoDispose, framework-free engines, and the isolate-safe factory-function pattern. |
| 05 | [Navigation & Routing](./05-navigation.md) | go_router with typed routes + StatefulShellRoute.indexedStack tab shell, master-detail with stable path-param IDs, full-screen flows via rootNavigatorKey, redirect guards, the notification-payload→location mapper + cold-start wiring, and state restoration. |
| 06 | [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md) | gen-l10n ARB workflow, app-controlled DB-persisted locale, Directional-only geometry + icon mirroring, bidi isolation, calendar-neutral epoch storage projected to Gregorian/Jalali/Hijri, numeral + separator normalization, the ckb fallback delegate, and bundled fonts. |
| 07 | [Local Notifications & Background Reliability](./07-notifications.md) | The single `zonedSchedule` engine with DB as source of truth, wall-clock + recurrence storage resolved to TZDateTime, the pure UsageProjector with fallback, rolling-window reconcile (iOS 64-cap), clock-tamper guard, Android inexact-vs-exact, and per-platform reboot re-arm. |
| 08 | [Error Handling & Never-Lose-Data](./08-error-handling.md) | The two-tier model: sealed `Result<T,F>` + sealed `Failure` taxonomies with codes not strings, exhaustive UI switches, global handlers to a local rotating log, the never-lose-data subsystem (WAL, autosave, soft-delete/Trash/Undo), and accumulative form validation. |
| 09 | [Security, Privacy & At-Rest Encryption](./09-security-privacy.md) | The three-layer model: whole-DB AES-256, recoverable-by-default master key (Argon2id KEK + recovery code, secure-storage fast path), app-lock via local_auth + PIN, per-file attachment encryption, redacted handover export, secure wipe, and enforced no-telemetry. |
| 10 | [Performance & Rendering](./10-performance-rendering.md) | Impeller with week-one low-end OEM validation, const/RepaintBoundary discipline, lazy lists, offloading compute via `Isolate.run` keyed off a revision counter, rollups + scoped watches, memoized RTL/calendar strings, local image handling, and profile-mode gating. |
| 11 | [Testing Strategy](./11-testing.md) | The diamond-topped pyramid: 100%-covered pure-Dart engine tests, canonical-storage invariance, in-memory Drift + forced-mid-migration-failure, the keyed encryption suite, the flagship WAL-active backup round-trip, CSV round-trip, a trimmed golden matrix, and the manual OEM device matrix. |
| 12 | [Build, Tooling, Release & CI/CD](./12-build-ci-release.md) | Melos on native pub workspaces, very_good_analysis + format/analyze gates, FVM pinning + committed lockfiles, two flavors (dev/prod), gitignore-and-regenerate codegen, semantic versioning + CI build numbers, obfuscation + archived symbols, and the GitHub Actions topology. |
| 13 | [Backup, Export & Disaster Recovery](./13-backup-export-recovery.md) | The proactive durability subsystem: `VACUUM INTO` after WAL checkpoint, AES-GCM + Argon2id, atomic rename, verify-by-reopen, pre-import snapshot, auto-backup + nagging + passphrase-loss warning, the single-file archive + competitor importers, and CSV export safety. |
| 14 | [Money, Currency, Units & FX](./14-money-currency-fx.md) | Canonical value objects, money as integer minor units keyed to real ISO-4217 exponents (never floats or hardcoded 2 decimals), the Iranian Rial/Toman storage-vs-display convention, and offline user-entered dated staleness-flagged FX. |
| 15 | [Accessibility & Dynamic Type](./15-accessibility-dynamic-type.md) | First-class a11y: Semantics on charts/tiles, TalkBack/VoiceOver with RTL text + Eastern numerals, mirrored focus order, accessible biometric/PIN lock, WCAG-AA contrast in both themes, and dynamic-type overflow rules for tall glyphs at textScaler 1.5–2x. |
| 16 | [Permissions, Onboarding & OEM Survival](./16-permissions-onboarding-oem.md) | The guided permission_handler onboarding flow: notification + exact-alarm requests, battery-optimization exemption and OEM autostart deep links, local_auth setup realities, the honest "foreground reconcile is the one guaranteed path" framing, and its pairing with the QA matrix. |
| 17 | [Store Compliance, Privacy Declarations & Licensing](./17-store-compliance-licensing.md) | Launch-blocking compliance: the Play Data-Safety form + iOS privacy label both declaring no collection, RTL store screenshots + six-language listings, the in-app OSS + font-license attributions screen, and the pre-submission checklist. |

## Related product docs

These describe **what** the app does (the guide above describes **how** it is built). Read them for the product surface behind each engineering decision.

- [Product Overview](../overview.md) — what Car and Pain is and who it is for.
- [Canonical Data Model](../reference/data-model.md) — the entities, the shared ledger, and the canonical storage contract.
- [Glossary & Conventions](../reference/glossary.md) — shared vocabulary and naming conventions.
- [Reminders & Notifications (product)](../features/04-reminders-notifications.md) — the date + odometer-projection + engine-hour reminder feature behind [doc 07](./07-notifications.md).
- [Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md) — the offline/backup/export feature behind docs [09](./09-security-privacy.md) and [13](./13-backup-export-recovery.md).
- [Localization, RTL & Calendars (product)](../features/19-localization-rtl.md) — the multi-language/RTL/calendar feature behind [doc 06](./06-i18n-rtl-calendars.md).

## Conventions

These are **living decisions**, not immutable law — but changing one means changing a load-bearing part of the app, so revisions are deliberate and documented, never incidental.

- **Open questions** (Riverpod-vs-Bloc, household P2P sync scope, key-recovery UX, Argon2id params, the encryption spike, FX/Toman UX, asset-size budget) are tracked in **[00-overview](./00-overview.md)** — resolve the ones that shape all 25 modules **before kickoff**.
- **Cross-linking:** every doc links to its siblings and back to the product docs above. Follow the links rather than duplicating rationale.
- **Tie back to the constraints:** when in doubt, re-derive from the four invariants — *offline*, *RTL/i18n*, *reliable local notifications*, and *no telemetry*. If a proposed change weakens any of them, it is wrong for this app regardless of how idiomatic it looks elsewhere.
