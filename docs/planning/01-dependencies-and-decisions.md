# ⚖️ Dependencies & Engineering Decisions

> Companion to the engineering guides in [`../flutter/`](../flutter/README.md). This record captures *what* we depend on and *why*, plus the resolved architecture decisions (ADRs) that shaped the stack. It is the single source of truth for "why is this package in our `pubspec`?"

## Dependency philosophy

**Stance: built-in / first-party FIRST. Every third-party runtime dependency must earn its place.**

Car and Pain promises *offline-first, account-free, no-telemetry, buy-once* software. That promise is only as trustworthy as our dependency tree: every runtime package we ship is code we cannot fully audit, a supply-chain surface, a potential source of network calls, and a long-term maintenance liability that outlives its author's interest. So the default answer to "should we add a package?" is **no** — we reach for the Dart/Flutter SDK, `dart:*` libraries, and Google-maintained first-party packages before we reach for pub.dev.

Three rules govern the tree:

1. **Built-in / first-party first.** If `dart:convert`, `CustomPainter`, `flutter_localizations`, or a first-party package (`go_router`, `intl`) can do the job well, we do not add a third-party alternative. Charts, calendar conversion math, CSV, and state management are all things we deliberately *build* rather than *depend on*.
2. **Every runtime dependency earns its place.** A package survives review only when it wraps genuinely hard, platform-specific, or security-critical native work that we should not reimplement (encrypted SQLite, OS notification scheduling, the platform keystore, biometric APIs). "It's convenient" is not a qualifying reason; "it correctly binds a native capability we cannot safely hand-roll" is.
3. **Runtime vs dev/build-time is a hard line.** A dependency that ships in the app binary (runtime) is held to the strict bar above — it affects users, security, and app size. A dependency used only to *build, generate, lint, or test* (dev/build-time) never ships to a user, so it is judged on developer-productivity terms and can be adopted far more liberally. Code generators (`riverpod_generator`, `freezed`, `go_router_builder`, `drift_dev`), linters (`very_good_analysis`, `custom_lint`), and the `melos` monorepo tool are all dev/build-time and carry zero user-facing risk.

## The stack

Runtime = ships in the app binary. Dev = build/generate/lint/test only, never shipped.

| Area | Choice | Built-in / first-party? | Runtime or Dev | Why |
|---|---|---|---|---|
| Architecture & module structure | Feature-first modular monolith on a native Dart **pub workspace** (one runnable app package + foundational internal packages); pin verified current-stable Flutter/Dart at kickoff (workspaces need Dart 3.6+) | Built-in (SDK workspaces) | — (structure) | Feature isolation + shared core without a plugin zoo; no third-party monorepo runtime cost. See [architecture guide](../flutter/01-architecture-and-structure.md) |
| State management | **Riverpod 3.x** with codegen (`@riverpod`, `riverpod_generator`), `riverpod_lint`/`custom_lint`, paired with **Freezed**; repos/DB/services as `keepAlive` providers, scoped Drift `.watch()` wrapped in stream providers | Third-party | Runtime (riverpod) + Dev (generator/lint/freezed) | Manual `ValueNotifier` wiring got heavy across ~25 features; Riverpod unifies DI + reactive state. See [state guide](../flutter/02-state-management.md) |
| Dependency injection | **Riverpod** as the single unified mechanism for both DI and state; async infra (encrypted DB, secure store, dirs, timezone) injected via overridden root providers | Third-party (shared with state) | Runtime | One mechanism, not a second DI package. See [DI guide](../flutter/04-dependency-injection.md) |
| Local database, schema & migrations | **Drift** over **encrypted SQLite**; DEFAULT `sqlcipher_flutter_libs` (raw 64-hex PRAGMA key), `drift`'s `sqlite3mc` build-hook path only if a blocking week-1 spike proves it links + encrypts on real iOS AND Android | Third-party | Runtime (drift, sqlcipher) + Dev (`drift_dev`) | Encrypted local persistence is core to the trust moat and must not be hand-rolled. See [data guide](../flutter/03-data-persistence.md) |
| Canonical storage & aggregation | Repositories enforce the canonical contract (SI units, currency minor units, UTC instants) at the boundary; shared odometer ledger feeds pre-aggregated rollup tables | Built-in (own code over Drift) | Runtime | Correctness/recompute-at-scale is our logic, not a dependency. See [data guide](../flutter/03-data-persistence.md) |
| Navigation & routing | **`go_router`** with type-safe routes via `go_router_builder`, `StatefulShellRoute.indexedStack` for ~6 top tabs, full-screen flows above the shell via `rootNavigatorKey` | First-party (Flutter team) | Runtime (`go_router`) + Dev (`go_router_builder`) | First-party, declarative, deep-link ready — no third-party router needed. See [navigation guide](../flutter/05-navigation.md) |
| i18n / RTL / calendars / numerals | Flutter's built-in **`gen-l10n`** (`flutter_localizations` + `intl` + ARB, `generate:true`, `l10n.yaml`); Jalali/Hijri via our **own conversion math**; app-controlled locale persisted in the encrypted DB | First-party / built-in | Runtime (`flutter_localizations`, `intl`) | Deep localization is the sharpest differentiator; the platform i18n stack + our own calendar math beat any package. See [i18n guide](../flutter/06-i18n-rtl-calendars.md) |
| Local notifications & background reliability | ONE engine on **`flutter_local_notifications`** `zonedSchedule` (pin verified current-stable major at kickoff — FLN breaks channel/permission APIs across majors) + `timezone` + `flutter_timezone`, DB as source of truth | Third-party | Runtime | OS scheduling, channels, exact alarms, Doze/reboot survival are platform-native and unsafe to reimplement. See [notifications guide](../flutter/07-notifications.md) |
| Backup, export & disaster recovery | First-class v1 subsystem: `VACUUM INTO` after a WAL checkpoint, then AES-GCM encrypt with an FFI/native-Argon2id key, atomic temp-then-rename; JSON via **`dart:convert`**, CSV **hand-written** | Built-in (`dart:convert`, FFI) + small third-party file/share access | Runtime | Data ownership is a headline promise; the format is ours, only the file/share bridge is borrowed. See [backup guide](../flutter/13-backup-export-recovery.md) |
| Money, currency & FX | Integer **minor units** keyed to each ISO-4217 exponent (0/2/3) + ISO code — never floats or hardcoded 2 decimals; user-entered dated FX rates (offline), default Toman for Iran, configurable | Built-in (own model) | Runtime | Rounding correctness is our logic; FX stays offline by design. See [money guide](../flutter/14-money-currency-fx.md) |
| Error handling & functional patterns | Two tiers: sealed `Result<T,F>` over a sealed `Failure` hierarchy at every module boundary (hand-rolled with Dart 3 sealed classes) | Built-in (Dart 3 sealed classes) | Runtime | Language-level; no `dartz`/`fpdart` runtime dependency needed. See [error-handling guide](../flutter/08-error-handling.md) |
| Security & privacy architecture | Whole-DB AES-256 at rest (SQLCipher); random 256-bit master key wrapped by a passphrase-derived KEK (FFI/native **Argon2id**); **`flutter_secure_storage`** for keystore-backed secrets, **`local_auth`** for biometric/PIN unlock | Third-party (secure_storage, local_auth) + built-in FFI crypto | Runtime | Platform keystore + biometric APIs must be bound natively; the crypto scheme is ours. See [security guide](../flutter/09-security-privacy.md) |
| Accessibility & dynamic type | First-class from module #1: `Semantics` wrappers on custom charts/tiles, correct RTL + Eastern-Arabic numeral reading, mirrored traversal, accessible lock screen | Built-in (Flutter `Semantics`) | Runtime | Accessibility is a promise and a framework capability, not a package. See [accessibility guide](../flutter/15-accessibility-dynamic-type.md) |
| Permissions, onboarding & OEM survival UX | Guided onboarding/permissions flow built with **`permission_handler`**: notification + optional exact-alarm rationale, battery-optimization walkthrough | Third-party | Runtime | Cross-platform permission APIs are platform-native and messy to hand-roll. See [permissions guide](../flutter/16-permissions-onboarding-oem.md) |
| Charts & data visualization | **`CustomPainter`** — hand-drawn fuel-economy, cost, CO2 charts | Built-in (Flutter canvas) | Runtime | Full control, zero dependency, exact PULSE styling + `Semantics`; charting packages add weight and fight our design system |
| Testing strategy | Logic-heavy "diamond-topped pyramid": exhaustive table-driven unit tests at 100% on pure-Dart engines, widget + golden tests above | Built-in (`flutter_test`) + Dev tooling | Dev | Never ships. See [testing guide](../flutter/11-testing.md) |
| Build, tooling, release & CI/CD | **Melos** monorepo on native pub workspaces, `very_good_analysis` lints enforced by `flutter analyze` + `dart format --set-exit-if-changed`, pinned SDK | Third-party (dev only) | Dev | Build/CI only — never in the binary, so adopted liberally. See [build guide](../flutter/12-build-ci-release.md) |
| Store compliance & licensing | Play Data-Safety + iOS privacy nutrition label BOTH declaring no collection/no tracking; `PrivacyInfo.xcprivacy`, omitted `INTERNET` claim | — (process/config) | — | Launch-blocking deliverable, not code. See [store-compliance guide](../flutter/17-store-compliance-licensing.md) |

## Built-in wins

Places where we deliberately chose a built-in / first-party path over a readily available third-party package:

- **Charts → `CustomPainter`.** We hand-draw every chart on the Flutter canvas instead of pulling a charting library. We get exact PULSE styling, `Semantics` integration, no extra binary weight, and no library churn.
- **Jalali / Hijri calendars → our own conversion math.** Calendar conversion is deterministic, testable, and central to our differentiation — we own the math (100% unit-tested) rather than trust a package's edge cases.
- **JSON / CSV → `dart:convert` + hand-written CSV.** Export/import is a headline data-ownership promise; the format must be stable and fully understood, so JSON goes through the SDK and CSV is hand-written (quoting/escaping under our control).
- **State management → Riverpod's reactive providers + Drift `.watch()` streams.** *(Historically `ValueNotifier`/`ChangeNotifier` + DB streams with no framework; adopted Riverpod once manual wiring grew heavy — see ADR below.)* Still no BLoC/Redux/MobX; reactivity is provider + DB stream.
- **i18n → `flutter_localizations` / `intl` (`gen-l10n`).** The platform i18n stack, not a third-party localization framework.
- **Routing → `go_router`.** First-party rather than a community router (`auto_route`, etc.).
- **Error handling → Dart 3 sealed classes.** Hand-rolled `Result`/`Failure` instead of `dartz`/`fpdart`.

## Kept third-party

Runtime packages that earned their place — each binds genuinely hard, platform-specific, or security-critical native work:

- **Drift + SQLCipher (`sqlcipher_flutter_libs`)** — encrypted SQLite; reactive queries, migrations, and whole-DB AES-256 at rest that we must not reimplement.
- **`flutter_local_notifications` (+ `timezone` / `flutter_timezone`)** — OS-native scheduling, notification channels, exact alarms, and timezone-correct `zonedSchedule` firing; impossible to hand-roll safely across iOS/Android.
- **`flutter_secure_storage`** — hardware-keystore / Keychain-backed storage for the wrapped master key and secrets.
- **`local_auth`** — platform biometric (Face/Touch/fingerprint) + device-credential unlock APIs.
- **Small file / share access packages** — path resolution and the OS share sheet for backup export/import; a thin, well-scoped bridge to platform file APIs.

*(Riverpod + Freezed are also runtime/dev third-party — see The stack — adopted as the unified DI+state mechanism once manual wiring proved unscalable across ~25 features.)*

## Resolved decisions (ADR)

Architecture Decision Records for the choices that were open questions during planning. Each is a decision we can revisit at the noted trigger.

### ADR-1 — State management

- **Decision:** Built-in reactive state + DB streams as the baseline; adopt Riverpod only if manual wiring gets heavy.
- **Rationale:** Fits the "built-in first" stance — no state framework for a mostly form-and-list app driven by DB streams. Keeps the tree lean and the mental model simple.
- **Status / Revisit:** **Superseded → Riverpod 3.x adopted.** Across ~25 features, manual `ValueNotifier`/`ChangeNotifier` wiring plus DI grew heavy, tripping the pre-agreed "only if it gets heavy" trigger. Riverpod now serves as the single unified DI + state mechanism. Revisit only if codegen/build-time cost becomes a problem.

### ADR-2 — Household P2P sync

- **Decision:** OUT of MVP; the schema still enables it later.
- **Rationale:** Peer-to-peer reconciliation (UUID + tombstone + `updated_at`, conflict resolution) is significant surface area that the MVP does not need. But designing it *out of the data model* would be a one-way door, so every entity carries the columns a future sync needs.
- **Status / Revisit:** Accepted. Revisit as a Tier-2/3 feature once MVP ships; no schema migration should be required to turn it on.

### ADR-3 — Key recovery

- **Decision:** Passphrase-wrapped master key + a one-time recovery code; biometric/PIN for daily unlock; an un-skippable data-loss warning at setup.
- **Rationale:** A random 256-bit master key must be *recoverable by default* or users lose everything on device loss — unacceptable for a buy-once, no-cloud app. Wrapping the key with a passphrase-derived KEK plus a printable recovery code gives account-free recovery; biometric/PIN keeps daily use frictionless; the un-skippable warning makes the loss model honest.
- **Status / Revisit:** Accepted. Revisit only if a stronger account-free recovery UX emerges. See [security guide](../flutter/09-security-privacy.md).

### ADR-4 — KDF params

- **Decision:** Decide the Argon2id parameters (memory/iterations/parallelism) at the week-1 encryption spike, device-calibrated.
- **Rationale:** KDF cost must balance brute-force resistance against unlock latency on low-end target devices (notably older Android). That trade-off can only be measured, not guessed, so it is deferred to a calibrated spike on real hardware.
- **Status / Revisit:** Open — **resolve at week-1 spike.** Record the chosen params and calibration method in the security guide once measured.

### ADR-5 — Encryption library

- **Decision:** Default to `sqlcipher_flutter_libs`; adopt Drift's `sqlite3mc` build-hook path only if a week-1 spike proves it links and encrypts on real iOS **and** Android.
- **Rationale:** SQLCipher is the proven, well-trodden path (raw 64-hex PRAGMA key). `sqlite3mc` via native-assets/build-hooks is attractive but unproven for us on both platforms; we default to the safe option and only switch if the spike removes all doubt.
- **Status / Revisit:** Open — **resolve at week-1 spike.** Ship SQLCipher unless the spike passes cleanly on both platforms. See [data guide](../flutter/03-data-persistence.md).

### ADR-6 — Currency / FX

- **Decision:** User-entered, dated FX rates (fully offline); default currency Toman for Iran, configurable.
- **Rationale:** Live FX would break the "100% offline, no telemetry" promise. Users enter rates with an effective date so historical conversions stay accurate; the Iran-first default (Toman display over the Rial minor unit) matches the primary audience while remaining configurable.
- **Status / Revisit:** Accepted. Revisit only if an *optional*, explicitly-consented online rate fetch is ever added. See [money guide](../flutter/14-money-currency-fx.md).

### ADR-7 — Offline map / dataset size

- **Decision:** Treat the offline map/dataset size as a separate Tier-2/3 size-budget decision.
- **Rationale:** Bundled/vector offline maps could balloon app size and conflict with store limits and download friction. It is not an MVP concern, so the size/format trade-off is deferred to a dedicated budget decision when the maps module (Tier-2) is scheduled.
- **Status / Revisit:** Deferred to Tier-2/3. Decide the size budget and bundling strategy when `maps-location` is planned.
