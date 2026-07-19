---
name: canonical-units-money
description: >-
  Governs Car and Pain's crown-jewel Flutter-free core package: storing distance,
  volume, engine-time, and money canonically (SI whole metres/millilitres/minutes,
  UTC instants, ISO-4217 integer minor units) and converting only at the
  presentation edge. Money is integer minor units keyed to each currency's
  ISO-4217 exponent (0 for IRR/JPY/VND, 2 for USD/EUR, 3 for KWD/BHD/OMR), never a
  double; Rial stays canonical and Toman is a display view (x10 in, /10 out); FX
  is user-entered, dated, and staleness-flagged, never live. Injects a
  Clock (package:clock, fake_async) instead of DateTime.now, uses the decimal
  package for exact division, and returns the Result/Failure model owned by
  error-handling-never-lose-data. Use when working in packages/core money, units,
  or fx; adding a Currency or FxRate; parsing or formatting an amount; converting
  odometer, fuel, or engine-hours; deciding whether a use-case that spans
  repositories is warranted; or fixing float-money, hardcoded-100, cross-currency,
  or Rial/Toman bugs.
metadata:
  project: car-and-pain
  area: core-money-units-fx
---

# Canonical Units & Money

Ground rules for `packages/core`, the pure-Dart engine at the bottom of the
Car and Pain dependency DAG. `core` has **zero** Flutter, plugin, or IO deps: no
`intl`, no `flutter/*`, no Drift. It holds the value objects (`Money`,
`Distance`, `Volume`, `EngineHours`), the FX engine, and any use-case that spans
repositories. Formatting lives in `packages/l10n`; persistence in `packages/data`.

Assume general Dart knowledge. What follows is only what is project-specific and
non-negotiable.

## The one law: canonical in, convert at the edge

Every quantity is **stored once, in one canonical form, and converted only when
shown or exported**. Preferences (units, currency, Rial/Toman, calendar, numerals)
change the *display projection* — never a stored value. This is what lets a user
flip any preference without corrupting a single historical row.

| Quantity | Canonical storage | Type | Never store |
| --- | --- | --- | --- |
| Distance | whole **metres** | `int` | km, miles |
| Volume | whole **millilitres** | `int` | litres, US/UK gallons |
| Engine-time | whole **minutes** | `int` | hours as double |
| Money | **integer minor units** + `Currency` | `int` | double, formatted string, Toman |
| Timestamp | **UTC ISO-8601 instant** | `DateTime` (UTC) | local time, display calendar |

Widgets receive **value objects**, never raw `int`s or strings. Conversion to a
display unit returns a `double` and happens at the presentation edge only. See
`references/value-objects.md` for the full conversion-factor tables and edge cases.

## Non-negotiable rules

- **Money is `int` minor units + ISO code — NEVER a `double`/`num`/`REAL`.**
  Floating-point drift silently corrupts multi-year TCO totals the user can never
  re-derive (there is no server copy). No `Money` API accepts or returns `double`.
- **Derive minor-units-per-major from the currency's real ISO-4217 exponent —
  NEVER hardcode `* 100`, `/ 100`, or "2 decimals".** IRR/JPY/VND are exponent 0,
  USD/EUR exponent 2, KWD/BHD/OMR exponent 3. A hardcoded `100` is a 100x error
  for IRR and a 10x error for KWD. Always route through `currency.minorPerMajor`.
  A CI grep rejects the literal `100` next to `money`/`amount`/`price` in features.
- **Unknown currency code is a typed failure, never a default-to-2.** The exponent
  table is explicit and lists only shipped currencies; `Currency.tryParse` returns
  null and the caller emits a `Failure`, never a silent 2-decimal parse.
- **Cross-currency arithmetic is forbidden at the type level.** You cannot add IRR
  to USD. To combine currencies, convert through `FxConverter` first, where
  provenance and staleness are enforced. `compareTo` across currencies is a bug.
- **Keep IRR canonical; Toman is a display view only (x10 in, /10 out).** Never
  create a `TOMAN` currency or store Toman amounts. 1 Toman = 10 Rial; the stored
  row is byte-identical whether the user entered Rial or Toman.
- **Normalize digits AND separators to ASCII BEFORE any value reaches `core`.**
  Fold Persian/Arabic-Indic digit ranges, the Persian decimal `٫` (U+066B) and
  grouping `٬` (U+066C). Never call `int.parse`/`double.parse` on raw input — it
  throws on `۱۲۳`. Normalization lives in `packages/l10n`, upstream of `core`.
- **FX is user-entered, dated, and staleness-flagged — NEVER fetched.** There is
  no network path (the `INTERNET` permission is omitted; a no-telemetry gate
  enforces it). Every `FxRate` carries an `asOf` date; TCO surfaces the worst
  staleness across all conversions as one honest badge.
- **Use `decimal` for exact division/parsing; round only at the boundary.** Apply
  an explicit `RoundingMode` (default half-even / banker's) **once** at the
  conversion or final-total boundary — never on intermediate sums (accumulates
  bias). Display rounding uses `NumberFormat` in `l10n`, not `core`.
- **Inject a `Clock`; NEVER call `DateTime.now()` in `core`.** Every time-reading
  class takes a `Clock` (package:clock) constructor arg so `fake_async`/fixed
  clocks make staleness deterministic in tests. See `references/engines-and-clock.md`.
- **`core` stays Flutter-free and IO-free.** No `intl`, no `flutter/*`, no Drift,
  no `dart:io`. Only `decimal` and `clock`. Formatting is `l10n`; storage is `data`.

## Canonical snippet: exponent-keyed Money

This is the crown jewel — money as integer minor units keyed to the *real*
ISO-4217 exponent. Read it as the template for every rule above.

```dart
// packages/core/lib/src/money/currency.dart
/// ISO-4217 minor-unit exponents. Explicit table — NEVER default to 2.
enum Currency {
  irr('IRR', 0), jpy('JPY', 0), vnd('VND', 0),          // exponent 0
  usd('USD', 2), eur('EUR', 2), aed('AED', 2), gbp('GBP', 2), try_('TRY', 2),
  kwd('KWD', 3), bhd('BHD', 3), omr('OMR', 3), iqd('IQD', 3); // exponent 3

  const Currency(this.code, this.exponent);
  final String code;
  final int exponent;

  /// 10^exponent — minor units per major unit. The ONLY scaling source.
  int get minorPerMajor => switch (exponent) {
        0 => 1, 2 => 100, 3 => 1000,
        _ => throw StateError('unsupported exponent $exponent'),
      };

  static Currency? tryParse(String code) =>
      Currency.values.where((c) => c.code == code).firstOrNull;
}

// packages/core/lib/src/money/money.dart
/// Money is (integer minor units) + (currency). No floats, ever.
final class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currency);
  final int minorUnits;       // e.g. 12345 with KWD == 12.345 KWD
  final Currency currency;

  /// Single-currency addition only. Cross-currency is a compile-time-shaped bug.
  Money operator +(Money o) => currency == o.currency
      ? Money(minorUnits + o.minorUnits, currency)
      : throw ArgumentError('currency mismatch: $currency vs ${o.currency}');

  @override
  int compareTo(Money o) {
    assert(currency == o.currency, 'compare across currencies is a bug');
    return minorUnits.compareTo(o.minorUnits);
  }
}
```

Everything else — parsing via `decimal`, the Rial/Toman view extension, the FX
converter, and the physical value objects — follows the same shape. Those live in
the reference files below, not inline, to keep this page short.

## When a domain/use-case layer is warranted

Most reads/writes go feature Notifier → repository (in `packages/data`). Add a
**use-case** (a pure function or small class in `core`, taking repositories as
constructor args) ONLY when logic **spans multiple repositories** or is a
reusable domain rule worth unit-testing Flutter-free. Examples that earn one: the
TCO engine (fuel + service + expense + depreciation), EV-vs-ICE break-even,
full-to-full economy, FX-normalized totals. A single-repository CRUD call does
NOT earn a use-case — call the repository directly from the Notifier. Use-cases
return the `Result`/`Failure` model (see below), take an injected `Clock`, and
stay pure so they are table-driven unit-tested at 100% in `packages/core`.

## Errors: return Result/Failure, never throw across the boundary

The sealed `Result<T, F>` / `Failure` model is **owned by the
error-handling-never-lose-data skill** — invoke it for the definitions. Here: FX
and parsing surface typed failures (`FxFailure.noRate()`, `ValidationFailure`),
returned as `Err(...)`, never thrown. `core` throws only for *programmer errors*
(currency mismatch, unsupported exponent) via `ArgumentError`/`StateError`/
`assert` — those are bugs, not user-facing states.

## References

- `references/value-objects.md` — `Money.fromMajorString` parsing via `decimal`,
  the Rial/Toman view extension, `Distance`/`Volume`/`EngineHours` with full
  conversion-factor tables (metre, mile, US/UK gallon, engine-minute), the
  gallon-trap and high-magnitude-currency edge cases, and the exponent test matrix.
- `references/engines-and-clock.md` — the `Clock`-injected `FxConverter`, dated
  `FxRate` + `FxTable.latestFor` inversion, `FxStaleness` bands, the
  fake-clock/`fake_async` test pattern, when to add a use-case, and the
  Result/Failure boundary.

## Examples & assets

- `examples/money.dart` — a correct, runnable `Currency` + `Money` +
  `Money.fromMajorString` + Toman-view slice with `decimal`.
- `examples/fx_converter.dart` — the `Clock`-injected converter with staleness
  bands and exponent re-scaling, returning `Result`.
- `assets/value_object.dart.tmpl` — skeleton for a new canonical value object
  (canonical int field, `.fromDisplayUnit` factory, `toDisplayUnit()` getters).

## Scripts

- `scripts/check-money-violations.sh` — greps `apps/`+feature code for banned
  patterns: `double`/`num`-typed money fields, hardcoded `* 100`/`/ 100` scaling
  next to money/amount/price, `DateTime.now()` inside `packages/core`, and any
  Flutter/`intl`/`dart:io` import in `core`. Prints each hit with file:line.
- `scripts/verify-core.sh` — regenerates codegen, then runs `flutter analyze`
  and the `packages/core` unit tests with coverage (the 100%-coverage engine).
