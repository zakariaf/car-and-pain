# 06 · Trips & Mileage Logbook

Feature **folder** (never a package). Product spec:
`docs/features/06-trips-mileage.md`.

## Layout

- `presentation/` — a dumb `View` (`ConsumerWidget`) + a Riverpod `@riverpod`
  `Notifier` (the ViewModel: state + commands). Widgets hold no business,
  conversion, or formatting logic.
- `application/` — feature-local use-cases, **only** when logic spans multiple
  repositories. Omit for trivial CRUD.
- `domain/` — feature-local Freezed models this feature owns.

`data/` is intentionally **absent** — this feature reads shared repositories
from `packages/data` and never touches Drift, secure storage, or a platform
channel directly. It never imports another feature folder (share via
`core`/`data`, or navigate by route ID).

Scaffold with `/scaffold-feature-module 06 trips-mileage`. Implemented in its
roadmap epic (see `docs/planning/`).
