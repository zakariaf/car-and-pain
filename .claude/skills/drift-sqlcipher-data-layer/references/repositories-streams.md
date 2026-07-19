# Repositories, domain mapping & scoped .watch streams

Detail for the repository boundary: mapping Drift rows to `core` domain models,
exposing reactive vehicle-scoped `.watch` streams, and feeding Riverpod
providers. Repositories are the **single source of truth**; feature code never
touches DAOs or Drift row classes directly.

## The repository boundary

- **DAOs return Drift row/data classes; repositories return `core` domain
  models.** Map at the boundary — a feature widget or Notifier receives a
  `FuelEntry` domain object (with `Money`, `Distance`, `Volume` value objects),
  never a generated `FuelEntriesData` row or a raw `int`.
- Value objects live in `packages/core` (Flutter-free): `Money` (integer minor
  units + `Currency`), `Distance` (whole metres), `Volume` (millilitres),
  `EngineHours` (whole minutes). The mapper converts canonical `int` columns into
  these — e.g. `Distance.metres(row.readingMetres)`,
  `Money(row.amountMinor, Currency.tryParse(row.currencyCode)!)`. Formatting
  never happens here; that is the `l10n` presentation edge.
- Cross-table transactions (parent + ledger + rollup) live in the repository, not
  the DAO — DAOs hold single-table queries.
- Repositories return a typed `Result<T, Failure>` for fallible operations (see
  the `error-handling-never-lose-data` skill).

## Scoped reactive streams

Every reactive read is a Drift `.watch()` **scoped by vehicle + time window** —
never an unscoped app-wide stream.

```dart
Stream<List<FuelEntry>> watchFuelForVehicle(String vehicleId, DateTimeRange window) {
  final q = (select(db.fuelEntries)
        ..where((t) => t.vehicleId.equals(vehicleId) &
            t.isDeleted.equals(false) &
            t.filledAt.isBetweenValues(window.start.ms, window.end.ms))
        ..orderBy([(t) => OrderingTerm.desc(t.filledAt)]));
  return q.watch().map((rows) => rows.map(_toDomain).toList());
}
```

- **Always filter `is_deleted = 0`** in the base query helper — even analytics
  streams.
- **Read rollups, not raw ledger scans**, for TCO/economy/statistics streams.
- Map rows to domain models inside `.map(...)` so subscribers get value objects.

## Riverpod wiring

Scoped Drift `.watch()` streams map onto **stream providers**; derived
TCO/analytics are computed providers over the rollup streams. Riverpod is the
project's state + DI mechanism. Keep the recompute off the UI thread — heavy work
runs via `Isolate.run` keyed off the rollup revision counter, only over the
affected slice.

## Pagination

History screens use **keyset (seek) pagination**, never `OFFSET`:

```dart
// next page: pass the last row's cursor
..where((t) => t.takenAt.isSmallerThanValue(cursor))
..orderBy([(t) => OrderingTerm.desc(t.takenAt)])
..limit(pageSize);
```

## Historical-edit reconcile

Correcting a past odometer/fuel row triggers a **bounded, explicitly-modeled
recompute-and-reconcile cascade** over the affected window only — economy between
fills, projections, pending reminders. Never a full-history recompute, and never
on the UI thread. The cascade runs in the same transaction discipline as the
original write and re-bumps the affected rollup revision.

## Pitfalls

- **Leaking Drift row types past the repository** — feature code then depends on
  generated classes and canonical `int`s, and formatting/units logic scatters.
  Map to `core` domain models at the boundary.
- **Unscoped `.watch`** — an app-wide stream recomputes everything on every
  write. Scope by vehicle + window.
- **Full-history recompute on the UI thread** — jank and battery drain. Rollups +
  `Isolate.run` keyed by revision.
- **`OFFSET` pagination** — degrades badly on large ledgers. Keyset only.
