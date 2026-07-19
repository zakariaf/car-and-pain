# M1 · App shell, Rooms navigation & PULSE vitals Home

> Assemble the runnable app skeleton: a three-Room `StatefulShellRoute.indexedStack`, the persistent active-vehicle selector, and the single breathing-vital Home — wiring PULSE, i18n and DB streams into one coherent shell.

## Goal

Turn the foundation packages (design system, data layer, i18n, notifications) into the first **runnable, navigable app**. This epic delivers the load-bearing chrome every downstream feature plugs into:

- A **`go_router` shell** with type-safe routes (`go_router_builder`), one `StatefulShellRoute.indexedStack` whose branches are the three PULSE **Rooms** — **Cockpit** (Now/home), **Garage** (the cars & their care) and **Pit-lane** (what's due) — each carrying its own master-detail navigation stack and preserved scroll position, plus full-screen flows (onboarding, add/edit, backup) pushed above the shell via `rootNavigatorKey`.
- The **persistent active-vehicle selector** and a **scoping provider** (per-vehicle / all-vehicles / fleet) that every downstream dashboard, list, stat and reminder reads from — and that guarantees notifications always name their vehicle.
- The **PULSE single-vital Home** (Cockpit "Now", screen A2): the breathing ECG pulse-line hero, one count-up readiness numeral, the redundantly-encoded aggregate `StatusBadge`, the **capped ambient halo** (`clamp(worst, 0, 2)`), **no visible list**, and a persistent quick-add entry point — reading live Drift streams.
- The **Home aggregation logic** that computes the one readiness vital and the single acute-ache card from the odometer ledger and reminder rollups, respecting the current scope.
- The supporting seams that make it production-real: **deep-link/notification restoration**, back/exit confirmation and draft autosave, **empty/first-run** states wired to onboarding, complete **i18n/RTL** for all shell chrome, accessibility + reduced-motion, backup/export coverage of the shell's own persisted UI state, and **golden tests** across light/dark/RTL.

The shell reconciles the two vocabularies in the reference docs: the engineering guide's "~6 branches" is the general routing shape; **for Car and Pain the top-level shell is exactly the three PULSE Rooms**, with the remaining feature modules living as master-detail routes inside those Rooms or as full-screen flows above the shell.

## Tier & dependencies

- **Tier:** MVP (foundation slice — everything else mounts on this shell).
- **Depends on:**
  - **F1** — project scaffold, pub workspace, tooling, app bootstrap/composition root.
  - **F2** — data layer (Drift + SQLCipher, canonical units/money, odometer ledger, `SETTING` store, migrations, streams).
  - **F3** — PULSE design system in Flutter (tokens, `PulseScaffold`, `RoomsNav`, `PulseLineHero`, `StatusBadge`, `AmbientHalo`, `QuickAddPill`).
  - **F4** — i18n / RTL / calendars / numerals engine (gen-l10n, app-controlled locale, `Directionality`).

## References

- [Dashboard, Statistics & Reports (product)](../../features/17-dashboard-statistics-reports.md)
- [PULSE — Screen blueprints & module patterns](../../design/pulse/03-screens.md)
- [PULSE — Design system overview](../../design/pulse/00-design-system.md)
- [PULSE — Motion, RTL & accessibility](../../design/pulse/04-motion-rtl-accessibility.md)
- [Flutter — Navigation & routing](../../flutter/05-navigation.md)
- [Flutter — State management](../../flutter/02-state-management.md)
- [Data model reference](../../reference/data-model.md)

## Tasks

### M1-T1 · go_router shell

**Description.** Stand up the single `GoRouter` as the app's only routing layer. Type-safe routes via `go_router_builder` (`@TypedGoRoute` + `GoRouteData`, generated `routes.g.dart` git-ignored and CI-regenerated), one `StatefulShellRoute.indexedStack` with an explicit `navigatorKey` per Room branch, and a `rootNavigatorKey` for full-screen flows. Wire `restorationScopeId`, a Riverpod-backed `refreshListenable`, and a pure, idempotent `redirect` (onboarding-complete, has-vehicle) into `MaterialApp.router`. Keep the router in a small stable module (`routing/`).

**Acceptance criteria**
- [ ] `buildAppRouter` exposes one `GoRouter` with `rootNavigatorKey`, per-branch `navigatorKey`s, `restorationScopeId`, and `refreshListenable`.
- [ ] Routes are declared type-safely; `flutter analyze` + `build_verify` pass and `.g.dart` regenerates cleanly in CI.
- [ ] Master-detail detail routes carry stable DB IDs in **path params** (never `extra`), e.g. `/garage/:vehicleId`, so any screen is reconstructable from its URL alone.
- [ ] Full-screen flows (onboarding, add/edit, backup/restore) set `parentNavigatorKey: rootNavigatorKey` and render **above** the Rooms nav.
- [ ] Navigation uses `.go()` (typed) for shell moves; `push()` is not used for shell navigation.
- [ ] `redirect` is pure/idempotent, always excludes its target location (no infinite loop), and re-runs when onboarding/vehicle-count state changes.

**Size:** M · **Depends on:** F1, F2 · **Governing docs:** [flutter/05-navigation.md](../../flutter/05-navigation.md), [flutter/02-state-management.md](../../flutter/02-state-management.md)

### M1-T2 · Rooms navigation chrome

**Description.** Build the three-Room bottom nav — **Cockpit / Garage / Pit-lane** — using PULSE `RoomsNav` with plain-language sublabels. Implement PULSE room-to-room transitions, re-tap-to-root behaviour (`goBranch(index, initialLocation: index == currentIndex)`), and correct **RTL traversal/order** (mirrored nav order and focus order, directionality-aware custom transitions). `indexedStack` keeps each Room's stack and scroll alive across switches.

**Acceptance criteria**
- [ ] Three Rooms render with icon + label + plain-language sublabel; the active Room is redundantly indicated (not colour-only).
- [ ] Switching Rooms preserves each Room's navigation stack and scroll position; re-tapping the active Room pops to its root.
- [ ] Room transitions follow the PULSE motion spec and are disabled/static under reduced-motion.
- [ ] In `fa`/`ar`/`ckb` the Rooms order and focus traversal mirror; custom transitions read `Directionality.of(context)` (no hard-coded `Offset(1,0)`).
- [ ] Nav items meet the 48px minimum target; `QuickAddPill` stays thumb-reachable in every Room.

**Size:** M · **Depends on:** M1-T1, F3, F4 · **Governing docs:** [design/pulse/03-screens.md](../../design/pulse/03-screens.md) (§0.1, A2), [design/pulse/04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md)

### M1-T3 · Active-vehicle selector

**Description.** Implement the persistent active-vehicle selector (backed by `SETTING.default_vehicle_id`) plus a **scoping provider** exposing `per-vehicle` / `all-vehicles` / `fleet` scope to downstream screens. The selector states which car is in view and switches vehicles in one tap; scope is a single source of truth read by Home, dashboards, lists, stats and reminders. The contract also guarantees every scheduled notification names its vehicle.

**Acceptance criteria**
- [ ] A persistent selector shows the active vehicle (name, and current odometer where shown) and switches vehicle in one tap; the choice persists in the encrypted DB and survives restart.
- [ ] A scoping provider exposes the current scope (`per-vehicle` | `all-vehicles` | `fleet`) as reactive state that downstream screens consume.
- [ ] Archived/sold/scrapped/stolen/written-off vehicles are handled per lifecycle rules (excluded or clearly flagged, never silently mixed into active scope).
- [ ] Changing the active vehicle or scope re-drives the Home vital and any subscribed streams without a manual refresh.
- [ ] The notification-payload contract carries the vehicle so every reminder can name it (verified against the deep-link mapper).
- [ ] Empty/edge cases handled: zero vehicles, exactly one vehicle (selector still coherent), and a deleted active vehicle (falls back gracefully).

**Size:** M · **Depends on:** M1-T1, F2 · **Governing docs:** [reference/data-model.md](../../reference/data-model.md), [flutter/02-state-management.md](../../flutter/02-state-management.md), [features/17-dashboard-statistics-reports.md](../../features/17-dashboard-statistics-reports.md)

### M1-T4 · Breathing-vital Home

**Description.** Build the Cockpit "Now" home (PULSE screen A2): the **single breathing vital, no visible list**. Full-bleed `PulseLineHero` (symmetric ECG seismograph via `CustomPainter`, ~4s breath, `RepaintBoundary`-isolated), one count-up readiness numeral, the redundantly-encoded aggregate `StatusBadge`, the **capped ambient halo** (`clamp(worst, 0, 2)`, eases at most one stop), the drag-reveal "Needs you now" preview (does not change the halo), the Nastaliq/Ruqaa masthead in RTL, and the persistent quick-add entry point. Reads live Drift streams via stream providers.

**Acceptance criteria**
- [ ] Home shows exactly one hero vital and **no visible list**; the prioritised list is one pull/swipe-up away and revealing it does not change the halo.
- [ ] The pulse-line breathes at ~4s and is `RepaintBoundary`-isolated so the breath never repaints the whole tree.
- [ ] The count-up numeral animates **only on real readiness change**, not on every visit.
- [ ] The ambient halo is `clamp(worst, 0, 2)` (Home can warm to saffron at most, never ember/pomegranate) and eases at most one stop per change.
- [ ] Aggregate status is redundantly encoded (icon + label + shape/position), never colour-only; the icon/label use a WCAG-AA on-surface ink colour.
- [ ] The masthead renders true Nastaliq (`fa`) / Aref Ruqaa (`ar`) in RTL; the pulse-line, checkmarks and logo do **not** mirror.
- [ ] Under reduced motion the breath renders static and the controller stops; haptics remain the feedback channel.
- [ ] The screen reads live from DB streams — no manual refresh, instant paint (no skeleton loaders).

**Size:** L · **Depends on:** M1-T5, F2, F3, F4 · **Governing docs:** [design/pulse/03-screens.md](../../design/pulse/03-screens.md) (A2, §0.2, §0.3), [design/pulse/00-design-system.md](../../design/pulse/00-design-system.md), [design/pulse/04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md)

### M1-T5 · Home vitals aggregation

**Description.** Pure-Dart logic that computes the **one readiness vital** (0..100 count-up score) and the aggregate urgency (0..4, halo-capped at 2) plus the **single acute-ache card** from the shared odometer/engine-hour ledger and reminder rollups, honouring the active scope from M1-T3. Table-driven, deterministic (injected `Clock`), with an insufficient-data fallback so a brand-new car reads calm (urgency 0), never a false ache.

**Acceptance criteria**
- [ ] A pure function maps `(reminder rollups, ledger state, scope, clock)` → `(readiness score, aggregate urgency 0..4, single acute-ache card | none)`.
- [ ] Aggregate urgency drives the halo via `clamp(worst, 0, 2)`; the acute-ache card may carry its own urgency up to 4.
- [ ] Insufficient/empty history yields urgency 0 (calm), never a fabricated ache.
- [ ] Results recompute reactively when the scope, active vehicle, or underlying streams change.
- [ ] Aggregation reads pre-aggregated summary/rollup tables (not full table scans) for scale.
- [ ] Exhaustive table-driven unit tests cover: no data, one healthy reminder, one overdue reminder, mixed urgencies, scope = fleet vs per-vehicle, and worst-of selection.

**Size:** M · **Depends on:** M1-T3, F2 · **Governing docs:** [features/17-dashboard-statistics-reports.md](../../features/17-dashboard-statistics-reports.md), [reference/data-model.md](../../reference/data-model.md), [flutter/02-state-management.md](../../flutter/02-state-management.md)

### M1-T6 · Deep-link & state restoration

**Description.** Wire the notification-payload → location bridge (pure `mapNotificationPayload`), `getNotificationAppLaunchDetails()` → `initialLocation` for cold start, and `router.go()` for warm taps — all reconstructing the target screen from path-param IDs and the DB (`extra` is null after reboot/Doze/restore). Wire `restorationScopeId` end-to-end and add back/exit confirmation (`PopScope` / go_router `onExit`) plus draft-autosave hooks for in-progress edits.

**Acceptance criteria**
- [ ] A pure `mapNotificationPayload(payload) → location` maps reminder payloads to `/garage/:vehicleId/reminders/:reminderId` and falls back to Home (`/`) on null/malformed/legacy input.
- [ ] Cold start via `getNotificationAppLaunchDetails()` lands on the mapped location; warm taps route via `router.go()` — both rebuild data from the DB with `extra == null`.
- [ ] `restorationScopeId` is set on `MaterialApp`, the router, and restorable form fields; last route and in-progress form state survive an OS kill (`restartAndRestore`).
- [ ] Back/exit on an unsaved form prompts confirm-discard via `PopScope`/`onExit` (never `WillPopScope`).
- [ ] Draft-autosave hooks persist in-progress edits transactionally so a kill mid-edit does not lose data.
- [ ] No `FlutterDeepLinkingEnabled`/App-Links native config is added (routing is Dart-driven from payloads).

**Size:** M · **Depends on:** M1-T1, F2 · **Governing docs:** [flutter/05-navigation.md](../../flutter/05-navigation.md)

### M1-T7 · Empty/first-run states

**Description.** Build the pre-onboarding empty Home (PULSE Empty pattern B6): a calm, urgency-0 state with the demoted nozzle/dipstick or car-body illustration, one authored sentence, and a single primary CTA that routes into the onboarding/add-first-vehicle flow. The has-vehicle redirect (M1-T1) sends brand-new users here.

**Acceptance criteria**
- [ ] With no vehicles, Home shows the Empty pattern (illustration + one sentence + one CTA), forced to urgency 0 — never warm, never a skeleton.
- [ ] The CTA routes into onboarding / add-first-vehicle as a full-screen flow above the shell.
- [ ] Copy is authored per language (calm physician / good race engineer voice — no mascot, no streaks); illustration does not mirror, copy and CTA do.
- [ ] After the first vehicle is added, Home transitions to the live single-vital state with no dead-end.

**Size:** S · **Depends on:** M1-T4, F3, F4 · **Governing docs:** [design/pulse/03-screens.md](../../design/pulse/03-screens.md) (B6, A1), [features/17-dashboard-statistics-reports.md](../../features/17-dashboard-statistics-reports.md)

### M1-T8 · Shell & Home golden tests

**Description.** Golden and widget tests for the shell and Home across **light/dark × LTR/RTL** and both platforms (`debugDefaultTargetPlatformOverride`). Cover Room switching/stack-preservation, the deep-link cold-start path, restoration, reduced-motion static hero, and the empty/first-run state. Use the shared harness (deterministic `Clock`, in-memory Drift DB, `ProviderContainer` overrides, forced locale).

**Acceptance criteria**
- [ ] Goldens for the shell and Home exist for day/night × en(LTR)/fa(RTL) and pass on CI.
- [ ] Widget test: tapping across Rooms preserves each branch's stack and scroll; re-tap pops to root.
- [ ] Widget test: cold-start with an `initialLocation` from a mapped payload renders the target with data rebuilt via the `extra == null` path (seeded in-memory DB).
- [ ] Restoration test (`restartAndRestore`) confirms last route + form fields return.
- [ ] Reduced-motion test asserts the hero renders static and the controller is stopped.
- [ ] Empty/first-run golden verified for both directions.

**Size:** M · **Depends on:** M1-T1, M1-T2, M1-T4, M1-T6, M1-T7 · **Governing docs:** [flutter/05-navigation.md](../../flutter/05-navigation.md), [design/pulse/04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md)

### M1-T9 · App bootstrap & provider composition root *(added — vertical-slice glue)*

**Description.** Compose the runnable entrypoint: async-initialize infra (opened encrypted DB, secure key store, app dirs, timezone, launch details) and inject it via overridden root providers, then build the router, wire the `refreshListenable`, and hand off to `MaterialApp.router`. This is the seam that turns F1–F4 into one running app and feeds the Home its DB streams and the router its guard state.

**Acceptance criteria**
- [ ] `bootstrap()` resolves async infra before `runApp`, overriding placeholder root providers with the live DB/key-store/dirs/timezone.
- [ ] The router's `refreshListenable` is driven by onboarding/vehicle-count providers; guards re-run on change.
- [ ] Startup failures surface a typed `Failure` (sealed `Result`) and a recoverable error surface, not an uncaught crash.
- [ ] The active locale from `SETTING` drives `MaterialApp.locale` / `Directionality` at launch.

**Size:** M · **Depends on:** F1, F2, F3, F4, M1-T1 · **Governing docs:** [flutter/02-state-management.md](../../flutter/02-state-management.md), [flutter/05-navigation.md](../../flutter/05-navigation.md)

### M1-T10 · Shell UI-state persistence & backup/export coverage *(added — schema→repo→backup)*

**Description.** Persist the shell's own durable UI state — active vehicle (`SETTING.default_vehicle_id`), current scope, and last-visited Room — through a repository at the canonical boundary, and ensure this state is included in the single-file backup and JSON export (so a restore returns the user to a coherent shell). No new colour-only or non-canonical storage.

**Acceptance criteria**
- [ ] Active vehicle, scope, and last Room are written/read via the settings repository (returning sealed `Result`/`Failure`), not scattered ad-hoc keys.
- [ ] These fields round-trip through the single-file backup and JSON export/import with schema/format versioning.
- [ ] A restore with a now-missing active vehicle falls back gracefully (first active vehicle or empty state), never a broken shell.
- [ ] Unit tests cover persist → reload → restore for each field.

**Size:** S · **Depends on:** M1-T3, F2 · **Governing docs:** [reference/data-model.md](../../reference/data-model.md), [features/17-dashboard-statistics-reports.md](../../features/17-dashboard-statistics-reports.md)

### M1-T11 · i18n & RTL wiring for shell chrome *(added — i18n completeness)*

**Description.** Externalize every shell string to ARB (gen-l10n): Room names and sublabels, the "Readiness" label, all `StatusBadge` labels (Healthy/Watch/Due soon/Overdue/Aching), quick-add, empty-state copy, and confirm-discard prompts — with ICU plurals where counts appear ("1 item" / "N items"). Verify locale-driven numerals (Persian/Eastern-Arabic), calendar framing, and full RTL mirroring of directional chrome across `en/de/fr/fa/ar/ckb`, including the 60/64 hero-numeral fallback for long-Arabic/German.

**Acceptance criteria**
- [ ] Zero hard-coded user-facing strings in the shell/Home; all keys exist in every supported ARB with no missing-translation warnings.
- [ ] Count-bearing labels use ICU plurals and render correctly in each language.
- [ ] Numerals render per `SETTING.numeral_system` (Latin / Persian `۰۱۲۳` / Eastern-Arabic `٠١٢٣`) with correct grouping separators.
- [ ] Directional chrome (nav order, chevrons, focus order) mirrors in `fa/ar/ckb`; the pulse-line, checkmarks and logo do not mirror.
- [ ] The hero numeral uses the reduced type scale where the locale needs it, without overflow.

**Size:** M · **Depends on:** M1-T2, M1-T4, F4 · **Governing docs:** [design/pulse/04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md), [design/pulse/03-screens.md](../../design/pulse/03-screens.md) (A12)

### M1-T12 · Accessibility & reduced-motion for shell & Home *(added — accessibility completeness)*

**Description.** Make the shell first-class accessible: `Semantics` on the pulse-line hero and readiness numeral (screen readers hear the **word** status and the number, not colour), correct TalkBack/VoiceOver reading of RTL text and Persian/Eastern-Arabic numerals, mirrored focus/traversal order in RTL, reduced-motion honoured (static hero, no room-transition animation), minimum 48px targets, and the redundant-encoding contract enforced everywhere status appears.

**Acceptance criteria**
- [ ] The hero, readiness numeral and `StatusBadge` expose semantic labels; screen readers announce the status word + number, never a colour.
- [ ] RTL focus/traversal order is mirrored and verified; Persian/Eastern-Arabic numerals read correctly under TalkBack/VoiceOver.
- [ ] `MediaQuery.disableAnimations`/app reduced-motion setting stops the breath controller and disables room transitions; haptics remain.
- [ ] All interactive shell targets meet the minimum touch size; status is never encoded by colour alone anywhere in the shell.
- [ ] Accessibility assertions are part of the M1-T8 widget/golden suite.

**Size:** S · **Depends on:** M1-T2, M1-T4 · **Governing docs:** [design/pulse/04-motion-rtl-accessibility.md](../../design/pulse/04-motion-rtl-accessibility.md), [design/pulse/03-screens.md](../../design/pulse/03-screens.md) (§0.2)

## Definition of Done

- **Runnable & navigable:** the app launches to the Cockpit Home, moves between all three Rooms with per-Room stack/scroll preserved, and pushes full-screen flows above the shell — all wired to live DB streams.
- **PULSE fidelity:** single breathing vital with **no visible list**, capped ambient halo (`clamp(worst,0,2)`), scoped acute-ache card, and the redundant-encoding contract (icon + label + shape/position) honoured everywhere status appears — verified in day/night.
- **Tests green:** pure aggregation and payload-mapper unit tests are exhaustive/table-driven; shell + Home golden and widget tests pass for **light/dark × LTR/RTL** on both platforms; restoration and reduced-motion paths covered; CI runs `build_runner` + `build_verify` with no codegen drift.
- **i18n complete:** no hard-coded strings; every shell/Home key translated across `en/de/fr/fa/ar/ckb` with ICU plurals and locale-driven numerals/calendars.
- **RTL verified:** Rooms order, focus traversal and directional chrome mirror in `fa/ar/ckb`; the Nastaliq/Ruqaa masthead renders; pulse-line, checkmarks and logo do not mirror.
- **Backup/export:** the shell's persisted UI state (active vehicle, scope, last Room) round-trips through the single-file backup and JSON export, with graceful fallback on a missing active vehicle.
- **Accessible:** screen readers announce status by word + numeral (never colour); RTL reading order correct; reduced-motion honoured; all targets ≥ minimum size — per the redundant-encoding rule.
- **Offline & clean:** no network, no telemetry, no OS deep-link config; `flutter analyze` and `dart format --set-exit-if-changed` pass; module-boundary calls return sealed `Result`/`Failure`.
