# Routing registration & the six-ARB-file workflow

Detailed tables for the two manual steps the generator prints. Everything else is scaffolded.

---

## A. Register the screen in the ONE go_router

There is a single `GoRouter` in `apps/car_and_pain/lib/src/routing/`. A feature does NOT get
its own router. Add typed routes to `routes.dart`; codegen writes `routes.g.dart`.

### Where each screen kind attaches

| Screen kind | Attaches to | Navigator key | Path shape |
| --- | --- | --- | --- |
| List (a shell tab) | one of the ~6 `StatefulShellBranch`es | branch key (`_vehiclesKey`, …) | `/<feature>` or nested under a branch |
| Master → detail | inside the same branch | branch key | `/vehicles/:vehicleId/<feature>/:<feature>Id` |
| Full-screen add/edit | ABOVE the shell | `_rootNavigatorKey` | child `path: 'new'` / `'edit'` with `parentNavigatorKey` |
| Wizard / import-export | above the shell | `_rootNavigatorKey` | dedicated top-level route |

~25 feature folders map to ~6 shell branches (Dashboard, Vehicles, Reminders, Costs/TCO,
Reports/Charts, Settings). A feature is usually reached via a branch it belongs to, not a new tab.

### Canonical typed route

```dart
// routing/routes.dart
@TypedGoRoute<TripDetailRoute>(
  path: '/vehicles/:vehicleId/trips/:tripId',
)
class TripDetailRoute extends GoRouteData with _$TripDetailRoute {
  const TripDetailRoute({required this.vehicleId, required this.tripId});
  final String vehicleId;   // path param — reconstructable on cold start
  final String tripId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      TripDetailView(vehicleId: vehicleId, tripId: tripId);
}

// Full-screen add flow renders ABOVE the bottom nav:
@TypedGoRoute<AddTripRoute>(path: '/vehicles/:vehicleId/trips/new')
class AddTripRoute extends GoRouteData with _$AddTripRoute {
  const AddTripRoute({required this.vehicleId});
  final String vehicleId;
  @override
  Object? get parentNavigatorKey => rootNavigatorKey; // covers the tab bar
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AddTripSheet(vehicleId: vehicleId);
}
```

### Rules
- **Path params carry deep-linkable identity; never `state.extra`** (null on cold start, reboot,
  OS restore). The screen rebuilds its data from the encrypted DB using the IDs.
- **Prefer `.go()` / typed `Route(...).go()`** over `.push()` (since go_router 8.0 `push()` no
  longer updates the location redirects/URL observe).
- **Assign explicit branch `navigatorKey`s**; full-screen flows set `parentNavigatorKey:`
  `rootNavigatorKey`.
- **Keep `redirect` pure and idempotent** and always exclude the target location (no loops).
- Regenerate typed routes: `dart run build_runner build --delete-conflicting-outputs`;
  CI `build_verify` fails on stale route codegen.
- Notification taps map to a location through the **pure** `mapNotificationPayload` — if this
  feature is a notification target, add its case there (`/vehicles/$id/<feature>/$itemId`).

---

## B. Add strings across all six ARB files

Inputs live in `packages/l10n/lib/l10n/`. `app_en.arb` is the **template**
(`template-arb-file: app_en.arb`). Every key exists in all six files.

| File | Locale | Direction | Notes |
| --- | --- | --- | --- |
| `app_en.arb` | English | LTR | **Template** — source of truth for keys + `@`metadata |
| `app_de.arb` | German | LTR | compound words expand — leave room, never fixed widths |
| `app_fr.arb` | French | LTR | |
| `app_fa.arb` | Persian | RTL | |
| `app_ar.arb` | Arabic | RTL | six CLDR plural forms: zero/one/two/few/many/other |
| `app_ckb.arb` | Sorani Kurdish | RTL | Material strings borrow `ar` via `CkbMaterialLocalizations` |

### Steps
1. **Template first.** Add the message + a `@key` object declaring every placeholder and its
   `type` to `app_en.arb` only.
2. **Mirror into the other five** with real translations — identical placeholder names, identical
   ICU structure (same plural/select branches; bodies differ per language).
3. **Parity:** `.claude/skills/i18n-rtl-localization/scripts/check_arb_parity.sh`
   (also invoked by `scripts/verify_feature.sh`).
4. **Regenerate + analyze:** `dart run build_runner build --delete-conflicting-outputs`
   then `flutter analyze`. A missing key is a compile error via gen-l10n — the safety net.

### ICU, never concatenation

```json
{
  "tripsTitle": "Trips",
  "@tripsTitle": { "description": "Title of the trips list screen" },

  "tripDistanceCount": "{count, plural, =0{No trips} =1{1 trip} other{{count} trips}}",
  "@tripDistanceCount": {
    "description": "Count of trips this period",
    "placeholders": { "count": { "type": "int" } }
  }
}
```

### Placeholder typing

| ICU intent | `type` | Notes |
| --- | --- | --- |
| plural / cardinal | `int` / `num` | `int` for whole counts, `num` for measured |
| interpolated UGC text | `String` | vehicle nickname — preserved verbatim |
| formatted date | `DateTime` + `format` | prefer projecting via the `l10n` calendar formatter so Jalali/Hijri preference is honored |
| formatted number/currency | `num` + `format` | compose with the numeral formatter + ISO-4217 minor-unit model; number and unit are **separate isolated runs**, never hand-glued |

### Pitfalls
- Adding a key to `app_en.arb` only — the other five silently ship English. Parity catches it.
- Renaming a placeholder in one locale — breaks that translation at runtime. Keep names identical.
- Hand-building "1 day"/"2 days" — use ICU `plural`.
- Forgetting iOS `CFBundleLocalizations` for all six — the locale is not offered on iOS.
