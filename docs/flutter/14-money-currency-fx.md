# 💱 Money, Currency, Units & FX

> Governs the canonical value objects (Distance, Volume, EngineHours, Money), the integer-minor-unit money model keyed to real ISO-4217 exponents, the Rial/Toman storage-vs-display convention, and the offline user-entered dated FX table that feeds TCO and base-currency conversion.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · See also **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)** · **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)** · **[Canonical Data Model](../reference/data-model.md)**

## Decision

Model **money as integer minor units** (`int` amount + ISO currency code), where the number of minor units per major unit is derived from **each currency's real ISO-4217 exponent** — `0` for IRR/JPY/VND, `2` for USD/EUR/most, `3` for KWD/BHD/OMR — never a hardcoded two decimals and **never a `double`**. All value objects (`Money`, `Distance`, `Volume`, `EngineHours`) live in the Flutter-free **`core`** package as immutable, `Clock`-agnostic classes with pure conversion/rounding math and are exhaustively unit-tested. FX is **user-entered, dated, and staleness-flagged**: an offline app cannot fetch rates, so TCO/base-currency conversion reads the user's own dated rate table and surfaces "rate is N days old" rather than pretending to be live. The primary-audience **Rial/Toman** convention is a *designed display behaviour* — stored canonically in Rial (exponent 0), presented in Toman where the user prefers. Arithmetic uses the [`decimal`](https://pub.dev/packages/decimal) package where exactness across division is needed; digit/separator normalization to ASCII happens **before** any value reaches `core`.

## Why

A hardcoded 2-decimal assumption silently corrupts amounts for exactly the MENA/Iranian target currencies: IRR has exponent 0 (a "cent" of a Rial does not exist), and Gulf currencies KWD/BHD/OMR have exponent 3. Storing `12345` for "125.00 KWD" versus "12.345 KWD" is a 10× error that no test with only USD fixtures would catch. Toman ↔ Rial is the single most common real-world money-entry confusion for this audience (1 Toman = 10 Rial) and must be a *designed* behaviour, not a stream of bug reports. Being honest that FX is user-provided and dated keeps the TCO engine **deterministic** (the same inputs always produce the same base-currency total) and keeps the offline promise intact — there is no network tier to consult, ever.

**Alternatives considered and rejected:**

- **Floating-point money (`double`/`REAL`).** Rejected. Floating-point drift corrupts TCO totals over years of accumulation; `0.1 + 0.2 != 0.3` is a data-integrity bug in a ledger the user can never re-derive. Never persist, never compute with.
- **Hardcoded 2-decimal minor units for all currencies.** Rejected. Wrong for IRR/JPY (0) and KWD/BHD/OMR (3); guarantees silent corruption for the primary market.
- **A "dated FX source" the app fetches.** Rejected — impossible. There is no network and no telemetry; any auto-fetch violates the offline/no-collection posture and the omitted-`INTERNET`-permission enforcement.
- **Ignoring Rial/Toman.** Rejected. Guaranteed 10× user-entry error for the primary Iranian/MENA audience.
- **Persisting a formatted display string** (`"۱۲٬۳۴۵ ﷼"`). Rejected. Localized digits/separators and calendar-neutral canonical storage are non-negotiable — display strings break math, sorting, export round-trips, and cross-locale backup restore.

## How we do it

### Package placement

Everything here lives in `packages/core/` (zero Flutter/plugin/IO deps). Feature widgets receive **value objects**, never raw ints or strings; formatting lives only in `core` (math) and `l10n` (locale-aware rendering).

```text
packages/core/lib/src/
  money/
    currency.dart          # Currency: code + iso4217 exponent lookup table
    money.dart             # Money value object (minor units + Currency)
    money_rounding.dart    # RoundingMode + half-even/half-up helpers
  units/
    distance.dart          # Distance: canonical whole metres
    volume.dart            # Volume: canonical millilitres
    engine_hours.dart      # EngineHours: canonical whole minutes
  fx/
    fx_rate.dart           # dated rate: from/to code, rate (Decimal), asOf date
    fx_table.dart          # lookup + staleness classification (pure)
    fx_converter.dart      # convert(Money, targetCode, FxTable, Clock) -> Result
```

### Currency + exponent table

The exponent table is **explicit and data-driven** — never inferred. Only the currencies the app ships are listed; an unknown code is a typed failure, not a silent default-to-2.

```dart
/// ISO-4217 minor-unit exponents. Explicit — NEVER default to 2.
enum Currency {
  irr('IRR', 0), // Iranian Rial — exponent 0
  iqd('IQD', 3), // Iraqi Dinar — exponent 3
  kwd('KWD', 3), bhd('BHD', 3), omr('OMR', 3),
  jpy('JPY', 0), vnd('VND', 0),
  usd('USD', 2), eur('EUR', 2), aed('AED', 2),
  gbp('GBP', 2), try_('TRY', 2);

  const Currency(this.code, this.exponent);
  final String code;
  final int exponent;

  /// 10^exponent — minor units per major unit.
  int get minorPerMajor => switch (exponent) {
        0 => 1, 2 => 100, 3 => 1000,
        _ => throw StateError('unsupported exponent $exponent'),
      };

  static Currency? tryParse(String code) =>
      Currency.values.where((c) => c.code == code).firstOrNull;
}
```

### Money value object

```dart
/// Money is (integer minor units) + (currency). No floats, ever.
final class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currency);
  final int minorUnits;      // e.g. 12345 KWD = 12.345 KWD
  final Currency currency;

  /// Parse a normalized-ASCII major-unit string into exact minor units.
  /// Caller MUST have normalized digits + separators to ASCII first.
  factory Money.fromMajorString(String ascii, Currency c) {
    final scaled = (Decimal.parse(ascii) *
            Decimal.fromInt(c.minorPerMajor))
        .round(); // exact; Decimal has no binary-float error
    return Money(scaled.toBigInt().toInt(), c);
  }

  Money operator +(Money o) => _sameCurrency(o) &&
          (this.minorUnits + o.minorUnits) is int
      ? Money(minorUnits + o.minorUnits, currency)
      : throw ArgumentError('currency mismatch');

  bool _sameCurrency(Money o) => currency == o.currency;

  @override
  int compareTo(Money o) {
    assert(currency == o.currency, 'compare across currencies is a bug');
    return minorUnits.compareTo(o.minorUnits);
  }
}
```

Cross-currency arithmetic is **forbidden at the type level** — you cannot add IRR to USD. To combine currencies you must convert through the FX layer first, which is where provenance and staleness are enforced.

### Rial ⇄ Toman convention

Toman is **not a currency** — it is a display scaling of IRR (1 Toman = 10 Rial). Storage is always canonical IRR minor units (exponent 0). The Toman preference is a presentation flag persisted in settings and included in the backup.

```dart
/// Toman is a display view over canonical IRR. Storage stays IRR.
enum RialDisplay { rial, toman }

extension TomanView on Money {
  /// Returns the (value, unitLabelKey) to render, honoring the preference.
  (BigInt value, String unitKey) forRialDisplay(RialDisplay pref) {
    assert(currency == Currency.irr);
    if (pref == RialDisplay.toman) {
      // 1 Toman = 10 Rial. Integer division; keep remainder for sub-Toman.
      return (BigInt.from(minorUnits) ~/ BigInt.from(10), 'unit.toman');
    }
    return (BigInt.from(minorUnits), 'unit.rial');
  }
}
```

Symmetrically, when the user types an amount while the Toman view is active, the input pipeline multiplies by 10 **before** constructing the canonical `Money`. The stored row is byte-identical regardless of whether it was entered in Rial or Toman.

### Canonical units

Same discipline for physical quantities — canonical SI base, convert at the edge:

```dart
final class Distance { // canonical: whole metres
  const Distance.metres(this.metres);
  final int metres;
  double toKm() => metres / 1000;
  double toMiles() => metres / 1609.344;
  factory Distance.km(num km) => Distance.metres((km * 1000).round());
}

final class Volume { const Volume.millilitres(this.ml); final int ml;
  double toLitres() => ml / 1000; }        // canonical: millilitres

final class EngineHours { const EngineHours.minutes(this.minutes);
  final int minutes; double toHours() => minutes / 60; } // canonical: whole minutes
```

### FX: user-entered, dated, staleness-flagged

FX rates are rows the user creates. The table stores the raw rate as an exact `Decimal` string; conversion is pure and injected with a `Clock` so staleness is deterministic in tests.

```dart
final class FxRate {
  const FxRate({required this.from, required this.to,
    required this.rate, required this.asOf});
  final Currency from, to;
  final Decimal rate;        // 1 [from] = rate [to]
  final DateTime asOf;       // date the user tagged the rate (UTC)
}

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
    final dstMinor = (dstMajor *
            Decimal.fromInt(target.minorPerMajor))
        .round(); // banker's rounding at the conversion boundary only
    return Ok(ConvertedMoney(
        Money(dstMinor.toBigInt().toInt(), target), staleness,
        ageDays: ageDays));
  }
}
```

`FxTable.latestFor` picks the newest rate on or before "today" for the pair (and may invert a stored `to→from` rate rather than requiring both directions). TCO surfaces the **worst** staleness across all conversions in a report so the user sees a single honest badge.

### Parsing / normalization pipeline (input → canonical)

Every numeric field runs this before a value reaches `core`. Normalize **digits AND separators** — Persian decimal `٫` (U+066B) and grouping `٬` (U+066C), Arabic-Indic and Persian digit ranges — or parsing silently corrupts amounts.

```dart
/// l10n package. Fold Eastern digits + localized separators to ASCII.
String normalizeNumeric(String input) {
  final b = StringBuffer();
  for (final r in input.runes) {
    if (r >= 0x06F0 && r <= 0x06F9) { b.writeCharCode(r - 0x06F0 + 0x30); } // fa
    else if (r >= 0x0660 && r <= 0x0669) { b.writeCharCode(r - 0x0660 + 0x30); } // ar
    else if (r == 0x066B || r == 0x2E) { b.write('.'); } // decimal ٫ / .
    else if (r == 0x066C || r == 0x2C || r == 0x27) { /* drop grouping ٬ , ' */ }
    else { b.writeCharCode(r); }
  }
  return b.toString();
}
```

Rounding at display uses `NumberFormat(locale)` from `intl` (which re-emits native digits and locale separators). Rounding in *math* is explicit `RoundingMode` (default half-even / banker's) applied only at the conversion or final-total boundary — never on every intermediate add.

### Packages

```yaml
# packages/core/pubspec.yaml (no Flutter deps)
dependencies:
  decimal: ^3.0.0   # exact decimal arithmetic for FX division & parsing
  clock: ^1.1.1     # injected time for deterministic staleness
# formatting (intl NumberFormat) lives in packages/l10n, not core
```

## Rules

- **DO** store money as `int` minor units + ISO code. **DON'T** ever use `double`/`REAL`/`num` for money in storage or arithmetic.
- **DO** derive minor-units-per-major from the currency's ISO-4217 exponent. **DON'T** hardcode `* 100`, `/ 100`, or "2 decimal places" anywhere — a CI grep rejects the literal `100` next to `money`/`amount`/`price` in feature code.
- **DO** keep IRR canonical; treat Toman strictly as a display view (×10 in, ÷10 out). **DON'T** create a `TOMAN` currency or store Toman amounts.
- **DO** normalize digits **and** separators (`٫` `٬`) to ASCII before constructing any value object. **DON'T** call `int.parse`/`double.parse` on raw user input — it throws on `۱۲۳`.
- **DO** forbid cross-currency arithmetic at the type level; convert through `FxConverter` first. **DON'T** add `Money` of different currencies.
- **DO** tag every FX rate with an `asOf` date and surface staleness in TCO. **DON'T** fetch, scrape, or auto-refresh rates — there is no network path.
- **DO** apply rounding only at conversion/final-total boundaries with an explicit `RoundingMode`. **DON'T** round intermediate sums.
- **DO** keep all money/unit/FX math in `core` (pure Dart) and all formatting in `l10n`. **DON'T** format inside feature widgets or persist a formatted string.
- **CI**: `flutter analyze` + a lockfile scan (no networking SDK) + a grep gate for hardcoded `100` money scaling and for `double`-typed money fields.

## For Car and Pain specifically

- **Offline-first / no-telemetry.** User-entered dated FX is the *only* honest model with no server; the omitted `INTERNET` permission means the OS itself enforces that no rate can ever be fetched. TCO stays fully deterministic and reproducible from the encrypted DB alone.
- **Canonical storage.** Money minor units, `Distance` metres, `Volume` millilitres, and `EngineHours` minutes are stored byte-identically regardless of the user's chosen display units, currency-display (Rial/Toman), calendar, or numeral system — the canonical-invariance test asserts this. See [Local Database, Schema, Indexing & Migrations](./03-data-persistence.md).
- **RTL / i18n.** Native-digit rendering and `٫`/`٬` separator parsing are load-bearing for the fa/ar/ckb audience; a Persian-keyboard `۱۲٬۳۴۵٫۶۷` must round-trip to `12345.67` and back. Rendering (with bidi-isolated currency symbols) lives in [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md).
- **Backup / portability.** Amounts export as canonical minor-units + ISO code (locale-neutral, Western digits) so a backup made under a Persian+Toman profile restores identically on any device. FX rows export with their `asOf` dates so historical TCO stays reproducible. See [Backup, Export & Disaster Recovery](./13-backup-export-recovery.md).
- **Notifications.** Cost-based reminders (e.g. budget thresholds) read canonical minor units; no money math ever runs on a formatted string in a background isolate.

## Testing

All tests are fast, table-driven, Flutter-free unit tests in `packages/core` at 100% coverage (the highest-leverage decision in the app — pure engines, injected `Clock`).

- **Exponent correctness (table-driven):** `("125.00", KWD) → 125000 minor`; `("125", IRR) → 125 minor`; `("125", JPY) → 125 minor`; `("1.50", USD) → 150 minor`. Assert an unknown code returns a typed failure, never a defaulted 2-decimal parse.
- **Rial/Toman round-trip:** enter `500` in Toman view → stored `5000` IRR minor → re-display in Toman view = `500`; and in Rial view = `5000`. Byte-identical stored row for both entry modes.
- **Parse/normalize round-trip:** `normalizeNumeric("۱۲٬۳۴۵٫۶۷") == "12345.67"`; Arabic-Indic `١٢٣` → `123`; grouping `٬`/`,`/`'` dropped; decimal `٫`/`.` preserved. Property test: `format(parse(x)) == x` across locales.
- **FX conversion + staleness (fake clock):** with `Clock` fixed, a rate `asOf` 3 days ago → `fresh`; 20 days → `aging`; 45 days → `stale`; missing pair → `FxStaleness.missing`/typed `FxFailure.noRate`. Assert re-scaling across exponents (e.g. IRR→KWD hits exponent 0→3).
- **No-float invariance:** assert no `Money` API accepts or returns `double`; a large accumulation (10k adds) stays exact.
- **Rounding boundary:** half-even applied once at conversion; intermediate sums unrounded. Verify a known adversarial case (`0.1+0.2` style) is exact.
- **Canonical-invariance (data layer):** switching currency-display/unit/numeral leaves stored rows unchanged (asserted in `packages/data` against an in-memory Drift DB). See [Testing Strategy](./11-testing.md).

## Pitfalls

- **Hardcoded `* 100` / "2 decimals".** Silently 10×-corrupts KWD/BHD/OMR and 100×-corrupts IRR/JPY. Always go through `currency.minorPerMajor`.
- **`double` for money.** Floating-point drift corrupts multi-year TCO totals — a class of bug the user can never re-derive because there is no server copy. Never persist, never compute with.
- **Normalizing digits only, not separators.** The Persian decimal `٫` (U+066B) and grouping `٬` (U+066C) are distinct from digits; folding only the digit ranges leaves the separators un-parsed and corrupts entered amounts. Normalize both.
- **Treating Toman as a currency.** Storing Toman amounts (or an extra `TOMAN` enum) desyncs the canonical ledger; keep IRR canonical and scale only at the view.
- **Cross-currency addition without conversion.** Adding IRR to USD is a category error; enforce single-currency arithmetic at the type level and route mixed sums through `FxConverter`.
- **Pretending FX is live.** Any auto-fetch is both impossible offline and a no-telemetry violation; always show the dated, staleness-flagged provenance instead of a bare converted number.
- **Rounding every intermediate step.** Accumulates bias; round once at the conversion/final-total boundary with an explicit mode.
- **Formatting in storage/export.** Persisting `"۱۲٬۳۴۵"` breaks sorting, math, and backup restore; exports must be Western-digit, minor-unit, ISO-code, locale-neutral.

## Decisions to confirm

- **FX provenance & Rial/Toman default.** Confirm the user-entered-dated-rate model and the **default Rial-vs-Toman display** for the primary Iranian/MENA audience with a representative user *before* building the money-entry surface. (From `guide.open_questions` — this shapes the entry UI and the settings schema.)

## Related

- **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)** — how minor units / canonical rows and the FX rate table are stored and the canonical-invariance guarantee.
- **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)** — native-digit rendering, `٫`/`٬` parsing, and bidi-isolated currency/number display.
- **[Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)** — locale-neutral money export and FX-row round-trip.
- **[Error Handling & Never-Lose-Data](./08-error-handling.md)** — the sealed `FxFailure`/`ValidationFailure` cases surfaced by the converter.
- **[Testing Strategy](./11-testing.md)** — table-driven pure-engine tests and the fake-`Clock` pattern used for FX staleness.
- **[Canonical Data Model](../reference/data-model.md)** — the product-level definition of stored value fields and units.
