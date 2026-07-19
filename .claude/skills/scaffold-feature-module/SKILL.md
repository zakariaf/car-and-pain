---
name: scaffold-feature-module
description: Stand up one of Car and Pain's ~25 numbered feature FOLDERS end-to-end, consistent with the feature-first modular monolith. Creates apps/car_and_pain/lib/src/features/NN-feature-name/ with the presentation (view plus a Riverpod @riverpod Notifier as ViewModel) / application / domain skeleton, wires the Notifier to shared repository providers and their scoped .watch streams, registers the screen in the single go_router (TypedGoRoute, navigate-by-ID), and adds user-facing strings across all six gen-l10n ARB files (en/de/fr/fa/ar/ckb) with parity. Enforces core value objects (Distance, Volume, Money, EngineHours), Result/Failure boundaries, PulseScaffold patterns, and Directional-only geometry. Use when creating a feature folder, scaffolding a fuel/service/reminders/expenses/TCO/trips module, adding a feature Notifier or stream provider, registering a route, wiring a repository, or adding ARB keys. Pairs with flutter-architecture and i18n-rtl-localization. Runs new_feature.sh then verify_feature.sh.
argument-hint: "[feature-number] [feature-name]"
metadata:
  project: car-and-pain
  pairs-with: flutter-architecture, i18n-rtl-localization, pulse-design-system
  sources: docs/flutter/01-architecture-and-structure.md, docs/flutter/02-state-management.md, docs/flutter/05-navigation.md, docs/design/pulse/03-screens.md
---

# Scaffold a feature module (Car and Pain)

Stand up one feature the SAME way every time: a numbered **folder** under
`apps/car_and_pain/lib/src/features/`, never a package. A feature is
`presentation/` (a dumb View + a Riverpod `Notifier` = the ViewModel) plus a thin
`application/` and a `domain/` of Freezed models. `data/` is **usually ABSENT** — the
feature reads shared repositories from `packages/data`, not its own DB code.

Run the generator, then wire the two things it can't do for you (route + ARB strings),
then verify:

```bash
scripts/new_feature.sh 07 trips-roadtrip     # $1 = number, $2 = kebab-name
scripts/verify_feature.sh 07 trips-roadtrip  # grep parity/violation checks + analyze
```

Read the reference the task touches:
- `references/checklist.md` — the copyable end-to-end checklist (folder → notifier → route → ARB → verify).
- `references/routing-and-l10n.md` — go_router registration table + the six-ARB-file workflow with parity rules.

Templates live in `assets/templates/` (`notifier.dart.tmpl`, `view.dart.tmpl`,
`domain_model.dart.tmpl`, `feature_readme.md.tmpl`); the generator substitutes `$1`/`$2`.

## Non-negotiable rules

- **New feature = new numbered FOLDER, never a new package.** Path is
  `apps/car_and_pain/lib/src/features/NN-feature-name/` (two-digit `NN`, kebab-case name,
  matching the numbering already claimed in `docs/features/`). The five packages
  (`core`, `data`, `notifications`, `l10n`, `design_system`) are frozen — do not add a sixth.
- **A feature folder NEVER imports another feature folder.** Share via `core`/`data`, or
  navigate by route **ID** (`const TripDetailRoute(vehicleId: id).go(context)`).
  `custom_lint` enforces this; a cross-feature import fails the analyze lane.
- **Most features are `presentation/` + `application/` only.** Add `domain/` for Freezed
  models the feature owns; add `application/` use-cases **only when logic spans multiple
  repositories** (TCO, projection, analytics, scheduler). No use-case on trivial CRUD.
  Never create a per-feature `data/` folder — repositories live in `packages/data`.
- **The Notifier is the ViewModel; the View is dumb.** `presentation/NN_notifier.dart`
  holds a `@riverpod` Notifier (state + commands); the View is a small `ConsumerWidget`
  that watches a provider and renders. Widgets hold **no** business, conversion, or
  formatting logic.
- **Read the DB only through repository providers; wrap `.watch()` in a stream provider.**
  Never touch Drift, `flutter_secure_storage`, or a platform channel from a widget or a
  feature Notifier. Scope the stream **by vehicle + time window** so one write never
  re-emits app-wide.
- **`ref.watch` in `build`, `ref.read` in callbacks, `ref.listen` for one-shot effects**
  (SnackBar, navigate). Make expensive derived providers survive navigation with
  `ref.keepAlive()`; keep cheap ones `autoDispose`. Offload heavy analytics/TCO to
  `Isolate.run`/`compute` — never compute synchronously in `build`.
- **Never leak Drift row/companion classes into a Notifier or widget.** Repositories map
  rows → domain models at the boundary. The Notifier passes **value objects** — `Distance`,
  `Volume`, `Money` (integer minor units keyed to the ISO-4217 exponent — never a float),
  `EngineHours` — from `core`. No unit math or numeral/calendar formatting in the widget:
  conversions live in `core`, formatting/parsing in `l10n`.
- **Errors are typed values.** Repositories/use-cases return sealed `Result<T, F>` over a
  sealed `Failure`; the Notifier surfaces `AsyncValue`, and the View `switch`es exhaustively
  and localizes the `Failure` at the presentation edge — never shows a raw exception string.
- **Every user-facing string goes through gen-l10n across ALL SIX ARB files** — never
  hardcode a literal. Add the key + `@`metadata to the template `app_en.arb` FIRST, then
  mirror the message into `app_de/fr/fa/ar/ckb.arb` with identical placeholder names and ICU
  structure. Build plurals with ICU (`{count, plural, ...}`), never string concatenation;
  Arabic needs the six CLDR forms. Run the parity check.
- **Register the screen in the ONE go_router**, not a per-feature router. Add a
  `@TypedGoRoute`/`GoRouteData` in `routing/routes.dart`; carry deep-linkable identity in
  **path params** (`:vehicleId`), never `state.extra` (null on cold start). Full-screen
  add/edit flows set `parentNavigatorKey: _rootNavigatorKey`.
- **Compose the screen from PULSE patterns, not ad-hoc layout.** Wrap in `PulseScaffold`;
  pick a Part-B pattern (List / Detail-Timeline / Form / Report / Settings / Empty). Encode
  status with **icon + label + position**, never colour alone (`StatusBadge`). Use
  **`EdgeInsetsDirectional`** and directional geometry only — never `EdgeInsets.left/right`,
  `Alignment.centerLeft`, or `TextAlign.left`. Charts are `CustomPainter`, no chart library.

## The canonical Notifier + scoped stream (colocated in `presentation/`)

`presentation/NN_notifier.dart` owns the scoped stream provider and the command Notifier.
The View watches these; nothing else touches the repository.

```dart
// features/07-trips-roadtrip/presentation/trips_notifier.dart
import 'package:core/core.dart';          // Result, Failure, Distance, Money — value objects
import 'package:data/data.dart';           // tripRepositoryProvider (keepAlive, in packages/data)
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/trip.dart';              // feature-local Freezed model

part 'trips_notifier.g.dart';

/// Reactive backbone: wrap the repository's scoped .watch() in a stream provider.
/// Scoped by vehicleId so one trip write never re-emits app-wide.
@riverpod
Stream<List<Trip>> trips(Ref ref, String vehicleId) =>
    ref.watch(tripRepositoryProvider).watchTrips(vehicleId); // returns domain models, not Drift rows

/// The ViewModel: form/command state + write commands. autoDispose (per-screen).
@riverpod
class TripsController extends _$TripsController {
  @override
  FutureOr<void> build() {} // no synchronous heavy work here

  Future<void> logTrip(Trip draft) async {
    state = const AsyncLoading();
    // Repository returns Result<T, Failure>; guard maps it to AsyncValue for the View.
    final result = await ref.read(tripRepositoryProvider).addTrip(draft);
    state = switch (result) {
      Ok() => const AsyncData(null),
      Err(:final failure) => AsyncError(failure, StackTrace.current),
    };
  }
}
```

The View watches `tripsProvider(vehicleId)` with `.when`, renders inside `PulseScaffold`
with the List pattern, and calls `ref.read(tripsControllerProvider.notifier).logTrip(...)`
from the button callback. See `assets/templates/view.dart.tmpl` for the full widget.

## Do the two manual steps the generator prints

1. **Register the route** in `apps/car_and_pain/lib/src/routing/routes.dart`
   (`@TypedGoRoute`, path-param ID, `parentNavigatorKey` for full-screen flows), and add the
   branch/entry per `references/routing-and-l10n.md`. Regenerate typed routes with
   `build_runner`.
2. **Add the strings** to all six ARB files in `packages/l10n/lib/l10n/` — template
   `app_en.arb` first, then mirror. Run `scripts/verify_feature.sh` (calls the ARB parity
   check), then `dart run build_runner build --delete-conflicting-outputs`, then
   `flutter analyze`.
