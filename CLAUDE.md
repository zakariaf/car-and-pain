# Car and Pain

A 100% offline-first, account-free Flutter app (iOS + Android) that manages the entire pain of car ownership — fuel/energy, service, reminders, expenses/TCO, trips, and ~25 feature modules — across an unlimited multi-vehicle garage. It is a data-custody product wearing a car app's clothes: no server, no account, no telemetry. Engineer for correctness, durability, and reboot/Doze survival before feature velocity.

## NON-NEGOTIABLE INVARIANTS

Violating any of these is a bug, not a style choice. CI enforces several of them.

1. **100% offline & account-free.** Every core feature works in airplane mode with no signup and no server of record. Features that seem to need the network ship an on-device equivalent (bundled dataset, manual entry, cached-with-timestamp) — never block on connectivity.
2. **No telemetry, analytics, crash SDK, or network calls.** There is no HTTP tier. A CI lockfile scan fails the build if any analytics/crash SDK appears; the prod flavor omits the `INTERNET` permission so the OS enforces it. Never add one.
3. **Drift over encrypted SQLite (SQLCipher) only — never raw SQLite.** All DB access goes through the `data` package: per-feature `@DriftAccessor` DAOs, `.watch()` repositories, forward-only transactional migrations guarded by a pre-migration snapshot. Whole-DB AES-256 at rest.
4. **go_router only.** One `GoRouter` (typed routes via `go_router_builder`, `StatefulShellRoute.indexedStack` for the ~6 tabs, full-screen flows above the shell via `rootNavigatorKey`). Never a second router or raw `Navigator` for top-level flows.
5. **Riverpod 3.x for state AND DI — the single unified mechanism.** `@riverpod` codegen + `riverpod_lint`; repos/DB/services as `keepAlive` providers; Drift `.watch()` wrapped in stream providers. No BLoC/Redux/MobX; no second DI package. Ephemeral widget-only state may use `ValueNotifier`.
6. **Store canonical, convert at the edge.** Distance in metres, volume in millilitres, engine time in whole minutes. True instants = UTC epoch millis; recurring schedules = local wall-clock + recurrence rule + calendar, resolved to a `TZDateTime` only at (re)schedule time (so DST/timezone changes never shift a reminder). Conversion/formatting live only in `core` and `l10n`; widgets receive value objects.
7. **Money is integer minor units keyed to the real ISO-4217 exponent (0/2/3) + ISO code — never a float, never a hardcoded 2 decimals.** FX rates are user-entered, dated, and offline.
8. **ALL user-facing text via gen-l10n (ARB) — never hardcode a string.** Six launch locales (en/de/fr/fa/ar/ckb), true RTL, four calendars, Eastern-Arabic/Persian numerals. Normalize numeric input to ASCII (including `٫`/`٬`) before math.
9. **Directional geometry only — never `EdgeInsets.left/right`.** Use `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`, `Icons.adaptive.*`. A CI grep / custom_lint rejects `EdgeInsets.only(left/right)`, `Alignment.centerLeft`, `Positioned(left:)`, `TextAlign.left/right` in feature code.
10. **Status is ALWAYS encoded redundantly beyond colour.** Every status carries icon + text label + shape/position; the PULSE urgency stripe changes *pattern*, not just hue. Nothing is knowable by colour alone. Colour is mood/decoration painted behind content that always passes WCAG-AA on its own, in both themes.
11. **Built-in / first-party dependencies FIRST.** Default answer to "add a package?" is no. Reach for `dart:*`, `CustomPainter`, `flutter_localizations`/`intl`, `go_router`, Dart 3 sealed classes before pub.dev. A runtime dependency survives review only when it binds genuinely hard, platform-specific, or security-critical native work (encrypted SQLite, OS notifications, keystore, biometrics). Charts, calendar math, CSV, JSON, `Result`/`Failure` are ours. Dev/build-time tooling is judged liberally.
12. **PULSE design system.** Warm Persian-paper day / ink night; the scoped emotional-temperature model (capped ambient halo ≤ saffron stop-2; concentrated ache card up to pomegranate); the vitals pulse-line hero; the exhale on every completed action. Use `PulseTokens` + the light/dark `ColorScheme`; charts are `CustomPainter` (no chart library), `Semantics`-annotated. See `docs/design/pulse/`.
13. **Never lose data.** Transactional multi-table writes (WAL); debounced draft autosave; soft-delete + Trash + Undo (a shared query layer filters `is_deleted` from *every* read, including analytics); forward-only migrations with a mandatory pre-migration snapshot; backups via `VACUUM INTO` after a WAL checkpoint, verified by re-opening before success is reported. The encrypted DB is NOT the backup. The master key is recoverable by default (passphrase-wrapped + one-time recovery code) — "key only in secure storage" is the risky mode, not the default.

Business logic is pure, Flutter-free Dart injected with a `Clock`, exhaustively table-tested. Errors are typed values — a sealed `Result<T,F>` over a sealed `Failure` hierarchy (codes, not user-facing strings) — at every boundary; exceptions are reserved for bugs and routed to a local rotating log. Heavy compute never runs on the UI thread (rollup tables + `Isolate.run`). Background isolates get no `ProviderScope` — build infra via plain top-level factory functions.

## Where things live

- **`docs/overview.md`** — product source of truth: what the app is, promises, the ~25-module feature map, roadmap tiers.
- **`docs/features/`** — one doc per feature module (`01-vehicles-garage.md` … `25-onboarding-help.md`); the product-level spec for each.
- **`docs/flutter/`** — the engineering guide. `00-overview.md` is the binding contract (14 core principles + stack table + folder map); topic docs `01`…`17` elaborate architecture, state, data, DI, navigation, i18n, notifications, error handling, security, performance, testing, build, backup, money, accessibility, permissions, store compliance.
- **`docs/design/pulse/`** — the PULSE design system: `00-design-system.md` (principles), `01-tokens.md` (`PulseTokens`, colour/type/space/motion), `02-components.md`, `03-screens.md`, `04-motion-rtl-accessibility.md`.
- **`docs/planning/`** — dependency philosophy, the kept/rejected dependency table, and the resolved ADRs (`01-dependencies-and-decisions.md`); the single source of truth for "why is this package in our pubspec?".
- **`docs/reference/`** — the canonical data model/schema and the glossary/conventions.
- **`.claude/skills/`** — project skills (`<kebab-name>/SKILL.md`), invoked as `/command`. Consult before doing the task a skill covers.

## Code layout

Feature-first modular monolith on a native Dart pub workspace. One runnable shell `apps/car_and_pain/` (two entrypoints → shared `bootstrap.dart` composition root, the single router, `features/` folders that never import each other — they share via `core`/`data` or navigate by ID). Foundational packages: `core` (pure Dart value objects + engines + `Result`/`Failure` + `Clock`), `data` (encrypted Drift DB, DAOs, ledger + rollup tables, backup engine), `notifications` (the one `flutter_local_notifications` scheduler), `l10n` (gen-l10n ARB + calendar/numeral math + fonts), `design_system` (PULSE theme + Directional-only widgets). Melos runs scripts/CI only. Packages expose narrow barrel APIs; the app shell is thin.
