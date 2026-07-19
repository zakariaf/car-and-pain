# Feature-module scaffold checklist (copyable)

End-to-end steps to stand up one feature folder consistently. Tick every box.

## 0. Claim the number & name
- [ ] Pick the two-digit `NN` and kebab `feature-name` matching `docs/features/NN-*.md`
      (the ~25 features are already numbered there — reuse that number, do not invent).
- [ ] Confirm it is a **feature**, not a cross-cutting concern (those are the five frozen
      packages `core`/`data`/`notifications`/`l10n`/`design_system`, never a new one).

## 1. Generate the skeleton
- [ ] `scripts/new_feature.sh NN feature-name` — creates
      `apps/car_and_pain/lib/src/features/NN-feature-name/` with:
  - [ ] `presentation/NN_notifier.dart` — `@riverpod` Notifier (ViewModel) + scoped stream provider
  - [ ] `presentation/view/NN_view.dart` — dumb `ConsumerWidget` in a `PulseScaffold`
  - [ ] `domain/NN.dart` — Freezed model using `core` value objects
  - [ ] `application/` — empty until logic spans >1 repository
  - [ ] `README.md` — folder contract
- [ ] Delete any `data/` if the generator (or you) created one — features read `packages/data`.

## 2. Domain model
- [ ] Replace the placeholder fields with the real ones.
- [ ] Every measured quantity is a **value object** (`Distance` SI-metres, `Volume` SI-litres,
      `Money` integer-minor-units + ISO-4217 currency, `EngineHours`) — never a bare `int`/`double`.
- [ ] Timestamps stored UTC (`occurredAtUtc`); IDs are UUIDv7 strings.

## 3. Repository wiring
- [ ] Confirm `packages/data` exposes `<feature>RepositoryProvider` (keepAlive) and a scoped
      `watch<Feature>s(vehicleId)` returning **domain models**, not Drift rows. Add it there if missing.
- [ ] Stream provider `<feature>ListProvider(vehicleId)` wraps that `.watch()` — scoped by
      vehicle (+ time window), so one write is not app-wide.
- [ ] Write commands go through the repository and return `Result<T, Failure>`; the Notifier
      maps them to `AsyncValue`.

## 4. Notifier (ViewModel)
- [ ] `ref.watch` only in `build`; `ref.read` in command methods.
- [ ] Heavy analytics/TCO offloaded to `Isolate.run`/`compute`, guarded with `ref.keepAlive()`
      where expensive; cheap derived providers stay `autoDispose`.
- [ ] No Drift/secure-storage/platform-channel access; no unit math or formatting here.

## 5. View (presentation)
- [ ] Small `ConsumerWidget`; `.when(data/loading/error)` on the AsyncValue.
- [ ] `ref.listen` for one-shot effects (SnackBar, the PULSE "exhale", navigation).
- [ ] Pick ONE PULSE Part-B pattern (List B1 / Detail B2 / Form B3 / Report B4 / Settings B5 / Empty B6).
- [ ] Status uses `StatusBadge` (icon + label + position), never colour alone; halo capped at 2.
- [ ] `EdgeInsetsDirectional` / `AlignmentDirectional` only — no `.left/.right`, no `TextAlign.left`.
- [ ] Charts are `CustomPainter` — no chart library.

## 6. Route (single go_router)
- [ ] Add `@TypedGoRoute`/`GoRouteData` in `apps/car_and_pain/lib/src/routing/routes.dart`.
- [ ] Deep-linkable identity in **path params** (`:vehicleId`, `:<feature>Id`), never `state.extra`.
- [ ] Attach to the right shell branch; full-screen add/edit sets
      `parentNavigatorKey: _rootNavigatorKey`.
- [ ] Navigate by ID: `const <Feature>DetailRoute(vehicleId: id).go(context)`.
- [ ] Prefer `.go()` over `.push()`. Regenerate typed routes (`build_runner`).

## 7. Strings — all six ARB files
- [ ] Add key + `@`metadata to **template `app_en.arb` FIRST**
      (`packages/l10n/lib/l10n/`).
- [ ] Mirror the message into `app_de/fr/fa/ar/ckb.arb` — identical placeholder names + ICU
      structure; Arabic uses the six CLDR plural forms; plurals via ICU, never concatenation.
- [ ] Money/units rendered as separate isolated runs, formatted at the edge via `l10n`.

## 8. Verify
- [ ] `scripts/verify_feature.sh NN feature-name` (folder shape, no cross-feature import,
      Directional-only geometry, no Drift/float leak, no hardcoded strings, ARB parity).
- [ ] `dart run build_runner build --delete-conflicting-outputs` (riverpod/freezed/go_router/gen-l10n).
- [ ] `flutter analyze` clean (custom_lint + riverpod_lint enforce the boundaries).
- [ ] `dart format` clean.

## 9. Tests (headless-first)
- [ ] Notifier test via `ProviderContainer` with `NativeDatabase.memory()` / fake repository
      overrides; `addTearDown(container.dispose)`.
- [ ] Pure engine logic (if any) tested in `core` with injected `Clock`.
- [ ] Golden for one representative locale × direction (fa/ar/ckb RTL + en LTR), Jalali calendar,
      Eastern-Arabic/Persian numerals, `textScaler` 1.5–2×.
