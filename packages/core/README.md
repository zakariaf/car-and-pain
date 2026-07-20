# core

The pure-Dart foundation at the bottom of the Car and Pain dependency DAG.
**Zero Flutter, plugin, or IO dependencies** — no `flutter/*`, no `intl`, no
Drift, no `dart:io`. Conversion/formatting lives in `l10n`; persistence in
`data`. A compile wall here stops any widget doing raw unit math or float money.

## What lives here

- **The `Result`/`Failure` kernel** (`src/result/`) — the reliability spine.
- **Canonical value objects** (`src/money/`, `src/units/`, `src/time/`).
- **The `Clock` port** (`src/time/clock.dart`).
- Later: the pure engines (TCO, economy, projection, next-due, FX).

Import only the barrel: `import 'package:core/core.dart';`. Everything under
`src/` is private by convention.

## The module-boundary contract

**Return a `Result<T, F extends Failure>`; never throw across a boundary.**
Repositories, use-cases, services, and the canonical engines all hand back a
typed `Result`. Callers `switch` exhaustively with **no `default:`** so adding a
new failure branch is a compile error until every consumer handles it.

```dart
final result = Money.tryParseMajor(userInput, Currency.usd);
final label = switch (result) {
  Ok(:final value) => format(value),          // present it
  Err(:final failure) => localize(failure.code), // localize from the code
};
```

Exceptions are reserved for **bugs** (programmer error, truly-unrecoverable
state) — `ArgumentError`/`StateError`/`assert`, e.g. adding two different
currencies. They are caught by the global trio in `bootstrap.dart` and routed to
the local rotating log — never a crash SaaS.

Every `Failure` carries a **stable `code`** (e.g. `db.decrypt_failed`) and typed
params — **never a user-facing/localized string**. The UI localizes from the
code at the presentation edge.

## Canonical storage: store once, convert at the edge

| Quantity    | Canonical storage        | Type                   |
| ----------- | ------------------------ | ---------------------- |
| Distance    | whole **metres**         | `Distance` (`int`)     |
| Volume      | whole **millilitres**    | `Volume` (`int`)       |
| Engine-time | whole **minutes**        | `EngineHours` (`int`)  |
| Money       | integer **minor units**  | `Money` (`int` + code) |
| True instant| UTC epoch **millis**     | `Instant`              |
| Schedule    | wall-clock (no timezone) | `WallClockDateTime`    |

Preferences (units, currency, Rial/Toman, calendar, numerals) change the
*display projection* only — never a stored value. Conversion getters return
`double` and are called only at the presentation edge.

- **Money is `int` minor units + ISO code — never a `double`.** Minor-units-per
  -major is derived from the currency's **real ISO-4217 exponent**
  (`Currency.minorPerMajor`), never a hardcoded `100`. Unknown code →
  `Currency.tryParse` returns `null` and the caller emits a `Failure`.
- **Rial stays canonical; Toman is a display view** (`Money.fromToman`,
  `RialTomanView`). There is no `TOMAN` currency.
- **Instants ≠ schedules at the type level.** `Instant` is absolute UTC;
  `WallClockDateTime` is timezone-less and resolves to a zoned time only at
  (re)schedule time, so DST/timezone changes never shift a reminder.
- **Inject a `Clock`; never call `DateTime.now()` in an engine.** `SystemClock`
  is the single sanctioned adapter; `FixedClock` makes tests deterministic.

## Testing

Pure and deterministic — the highest-value suite in the app. Table-driven unit
tests cover every combinator, every failure variant's code, the exponent matrix
(0/2/3, incl. IRR/Toman), rounding, and conversion round-trips. Run with
`dart test` (or `flutter test` via `melos run test`).
