# Value objects — parsing, Rial/Toman, physical units

All of these live in `packages/core/lib/src/` and are pure, immutable, and
Flutter-free. Only `decimal` (exact arithmetic) and `clock` are allowed deps.

```text
packages/core/lib/src/
  money/
    currency.dart          # Currency: code + iso4217 exponent (see SKILL.md)
    money.dart             # Money value object (minor units + Currency)
    money_rounding.dart    # RoundingMode + half-even/half-up helpers
    toman_view.dart        # RialDisplay + TomanView extension (display only)
  units/
    distance.dart          # Distance: canonical whole metres
    volume.dart            # Volume: canonical whole millilitres
    engine_hours.dart      # EngineHours: canonical whole minutes
  fx/                       # see references/engines-and-clock.md
```

## Parsing a major-unit string into exact minor units

The input must already be normalized to ASCII (digits + separators) by
`packages/l10n` — `core` never sees `۱۲٬۳۴۵٫۶۷`. Parse with `decimal` so there is
no binary-float error, then scale by the currency's `minorPerMajor`.

```dart
// packages/core/lib/src/money/money.dart
extension MoneyParse on Money {
  /// Parse a normalized-ASCII major-unit string into exact minor units.
  /// Caller MUST have normalized digits + separators to ASCII first.
  static Money fromMajorString(String ascii, Currency c) {
    final scaled = (Decimal.parse(ascii) * Decimal.fromInt(c.minorPerMajor))
        .round(); // exact; Decimal has no binary-float error
    return Money(scaled.toBigInt().toInt(), c);
  }
}
```

### Exponent test matrix (table-driven, assert these exactly)

| Input string | Currency | Exponent | Expected minor units |
| --- | --- | --- | --- |
| `"1.50"` | USD | 2 | `150` |
| `"125.00"` | KWD | 3 | `125000` |
| `"125"` | IRR | 0 | `125` |
| `"125"` | JPY | 0 | `125` |
| `"12.345"` | KWD | 3 | `12345` |
| `"0.001"` | OMR | 3 | `1` |
| any | unknown code | — | typed `Failure`, NEVER a defaulted 2-decimal parse |

## Rial ⇄ Toman — a display view, not a currency

Toman is **not** a currency: it is a scaling of IRR (1 Toman = 10 Rial). Storage
is always canonical IRR minor units (exponent 0). The Toman preference is a
presentation flag persisted in `Setting` and included in the backup.

```dart
// packages/core/lib/src/money/toman_view.dart
enum RialDisplay { rial, toman }

extension TomanView on Money {
  /// Returns (value, unitLabelKey) to render, honoring the preference.
  (BigInt value, String unitKey) forRialDisplay(RialDisplay pref) {
    assert(currency == Currency.irr, 'Toman view applies to IRR only');
    if (pref == RialDisplay.toman) {
      // 1 Toman = 10 Rial. Integer division; keep remainder for sub-Toman.
      return (BigInt.from(minorUnits) ~/ BigInt.from(10), 'unit.toman');
    }
    return (BigInt.from(minorUnits), 'unit.rial');
  }
}
```

On **input** while the Toman view is active, the pipeline multiplies the parsed
value by 10 **before** constructing the canonical `Money`. Round-trip invariant to
assert: enter `500` in Toman view → stored `5000` IRR minor → re-display Toman =
`500`, Rial = `5000`. The stored row is **byte-identical** for both entry modes.

## Physical value objects — SI base, convert at the edge

Same discipline as money: canonical integer field, `.from<DisplayUnit>` factory
rounding into canonical, `to<DisplayUnit>()` returning a `double` at the edge.

```dart
final class Distance { // canonical: whole metres
  const Distance.metres(this.metres);
  final int metres;
  factory Distance.km(num km) => Distance.metres((km * 1000).round());
  factory Distance.miles(num mi) => Distance.metres((mi * 1609.344).round());
  double toKm() => metres / 1000;
  double toMiles() => metres / 1609.344;
}

final class Volume { // canonical: whole millilitres
  const Volume.millilitres(this.ml);
  final int ml;
  factory Volume.litres(num l) => Volume.millilitres((l * 1000).round());
  factory Volume.usGallons(num g) => Volume.millilitres((g * 3785.411784).round());
  factory Volume.ukGallons(num g) => Volume.millilitres((g * 4546.09).round());
  double toLitres() => ml / 1000;
  double toUsGallons() => ml / 3785.411784;
  double toUkGallons() => ml / 4546.09;
}

final class EngineHours { // canonical: whole minutes
  const EngineHours.minutes(this.minutes);
  final int minutes;
  factory EngineHours.hours(num h) => EngineHours.minutes((h * 60).round());
  double toHours() => minutes / 60;
}
```

### Conversion factors (exact where an exact definition exists)

| Quantity | Display unit | To canonical | From canonical |
| --- | --- | --- | --- |
| Distance (m) | km | ×1000 | ÷1000 |
| Distance (m) | mile (intl) | ×1609.344 | ÷1609.344 |
| Volume (mL) | litre | ×1000 | ÷1000 |
| Volume (mL) | US gallon | ×3785.411784 | ÷3785.411784 |
| Volume (mL) | UK/imperial gallon | ×4546.09 | ÷4546.09 |
| Engine-time (min) | hour | ×60 | ÷60 |

### The gallon trap

US gallon (3.785 L) and UK gallon (4.546 L) differ by ~20%. Because volume is
stored canonically in millilitres, an MPG entered in US gallons and one entered
in UK gallons never silently corrupt each other — the distinction is preserved
through import, export, and unit switching. MPG itself is a **derived display
metric**, computed full-to-full from canonical distance + volume, never stored.

## Edge cases

- **High-magnitude currencies (IRR, TRY).** Large `minorUnits` must not overflow
  or drift. `int` on the Dart VM is 64-bit — sufficient — but use `BigInt` in the
  Toman view and any accumulation that could exceed 2^63. Never fall back to
  `double` for headroom.
- **Fuel-price precision.** Fuel `price_per_unit` carries 3 decimals throughout;
  parse it as `decimal`, not as a `Money` unless it is itself a currency amount.
- **Refunds / signed amounts.** Expenses store `amount_signed`; refunds net as
  negative `minorUnits`. Negative `Money` is valid; do not clamp at zero.
- **Rounding.** `RoundingMode` (default half-even) is applied ONCE at the parse
  boundary (`.round()` above) or the final-total/conversion boundary — never on
  intermediate sums. Display rounding is `NumberFormat` in `l10n`, not here.
- **Export.** Amounts export as canonical minor units + ISO code, Western digits,
  locale-neutral — so a backup made under a Persian+Toman profile restores
  identically anywhere.
