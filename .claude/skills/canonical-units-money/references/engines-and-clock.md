# FX engine, injected Clock, use-cases & the Result boundary

Everything here lives in `packages/core` (pure Dart, no IO). FX rates are rows the
user creates — there is no network path, ever. Conversion is pure and injected
with a `Clock` so staleness is deterministic in tests.

## Dated FX rate + table

```dart
// packages/core/lib/src/fx/fx_rate.dart
final class FxRate {
  const FxRate({
    required this.from,
    required this.to,
    required this.rate,   // exact Decimal: 1 [from] == rate [to]
    required this.asOf,   // UTC date the user tagged the rate
  });
  final Currency from;
  final Currency to;
  final Decimal rate;
  final DateTime asOf;
}
```

`FxTable.latestFor(from, to)` picks the **newest rate on or before today** for the
pair. It MAY invert a stored `to → from` rate (`1 / rate`) rather than requiring
the user to enter both directions. A missing pair yields `null` → the caller
returns a typed failure. Rates are stored as an exact `Decimal` **string** in the
DB, never a double.

## Injected Clock — never `DateTime.now()`

`core` classes that read time take a `Clock` (package:clock) constructor argument.
Production passes `const Clock()`; tests pass a fixed clock or drive `fake_async`.
This makes staleness bands assertable without waiting real time.

```dart
// packages/core/lib/src/fx/fx_converter.dart
enum FxStaleness { fresh, aging, stale, missing }

/// Pure. No IO. Injected clock -> deterministic staleness.
final class FxConverter {
  const FxConverter(this._clock);
  final Clock _clock;

  Result<ConvertedMoney, FxFailure> convert(
      Money amount, Currency target, FxTable table) {
    if (amount.currency == target) {
      return Ok(ConvertedMoney(amount, FxStaleness.fresh, ageDays: 0));
    }
    final rate = table.latestFor(amount.currency, target);
    if (rate == null) return const Err(FxFailure.noRate());

    final ageDays = _clock.now().difference(rate.asOf).inDays;
    final staleness = switch (ageDays) {
      <= 7  => FxStaleness.fresh,
      <= 30 => FxStaleness.aging,
      _     => FxStaleness.stale,
    };

    // major = minor / minorPerMajor; convert; re-scale to TARGET exponent.
    final srcMajor = Decimal.fromInt(amount.minorUnits) /
        Decimal.fromInt(amount.currency.minorPerMajor);
    final dstMajor = srcMajor * rate.rate;
    final dstMinor = (dstMajor * Decimal.fromInt(target.minorPerMajor))
        .round(); // banker's rounding at the conversion boundary ONLY

    return Ok(ConvertedMoney(
      Money(dstMinor.toBigInt().toInt(), target),
      staleness,
      ageDays: ageDays,
    ));
  }
}
```

Note the **exponent re-scale**: converting IRR (exponent 0) → KWD (exponent 3)
crosses scaling boundaries, so re-scaling through the *target's* `minorPerMajor`
is mandatory. A test must cover a 0→3 conversion.

### Staleness bands

| Age of newest rate | `FxStaleness` | TCO badge |
| --- | --- | --- |
| ≤ 7 days | `fresh` | none / green |
| 8–30 days | `aging` | "rate is N days old" (amber) |
| > 30 days | `stale` | "rate is N days old" (red) |
| pair missing | `missing` (`FxFailure.noRate`) | "no rate — cannot convert" |

TCO surfaces the **worst** staleness across all conversions in a report as one
honest badge. Never present a bare converted number without its provenance.

## Fake-clock test pattern

```dart
test('rate 20 days old is aging', () {
  final asOf = DateTime.utc(2026, 7, 1);
  final clock = Clock.fixed(DateTime.utc(2026, 7, 21)); // 20 days later
  final table = FxTable([FxRate(
      from: Currency.usd, to: Currency.irr,
      rate: Decimal.parse('600000'), asOf: asOf)]);

  final result = FxConverter(clock)
      .convert(const Money(150, Currency.usd), Currency.irr, table);

  expect(result, isA<Ok<ConvertedMoney, FxFailure>>());
  expect((result as Ok).value.staleness, FxStaleness.aging);
});
```

For elapsed-time logic (not just a fixed instant), wrap the code under test in
`fakeAsync((async) { ... async.elapse(Duration(days: 20)); ... })` so timers
advance without real waiting. All FX/staleness tests are Flutter-free unit tests
in `packages/core` at 100% coverage — the highest-leverage decision in the app.

## When a use-case (domain layer) is warranted

Default path: feature Notifier → repository (`packages/data`). Add a **use-case**
(a pure class/function in `core` taking repositories as constructor args) ONLY
when one of these holds:

- Logic **spans multiple repositories** — e.g. TCO reads fuel + service + expense
  + depreciation and normalizes them through `FxConverter`.
- It is a **reusable domain rule** worth isolating and unit-testing Flutter-free —
  full-to-full fuel economy, EV-vs-ICE break-even, whichever-first due-date `min`.
- It needs an **injected `Clock`** for deterministic time (projection, staleness).

Do NOT add a use-case for single-repository CRUD — the Notifier calls the
repository directly. Use-cases return `Result`/`Failure`, take `Clock` where time
matters, hold no Flutter/IO, and are table-driven tested.

```dart
// A use-case spans repositories and normalizes currency deterministically.
final class ComputeTco {
  const ComputeTco(this._fuel, this._service, this._expenses, this._fx, this._clock);
  // ... repositories + FxConverter + Clock ...

  Result<TcoReport, TcoFailure> call(String vehicleId, Currency base) {
    // gather Money per source, convert each via _fx, sum single-currency,
    // track worst FxStaleness, return Ok(TcoReport(...)) or Err(...).
  }
}
```

## The Result / Failure boundary

`Result<T, F>` (`Ok`/`Err`) and the sealed `Failure` hierarchy are **owned by the
error-handling-never-lose-data skill** — invoke it for the canonical definitions
and the sealed-case list. In this package:

- FX and parsing return typed failures (`FxFailure.noRate()`,
  `ValidationFailure.unknownCurrency(code)`) as `Err(...)`. Never throw them.
- `core` throws only for **programmer errors** — currency mismatch in `Money +`,
  unsupported exponent, Toman view on a non-IRR amount — via `ArgumentError`,
  `StateError`, or `assert`. Those are bugs to fix, not user-facing states.
- Repositories (in `data`) map DB rows → value objects and lift storage errors
  into `Failure`s; they never leak a Drift exception into a feature Notifier.
