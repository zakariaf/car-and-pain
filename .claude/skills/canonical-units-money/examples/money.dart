// Correct, illustrative Money model for packages/core.
// Pure Dart: depends only on `decimal`. No Flutter, no intl, no dart:io.
import 'package:decimal/decimal.dart';

/// ISO-4217 minor-unit exponents. Explicit table — NEVER default to 2.
/// Only currencies the app ships are listed; an unknown code is a typed
/// failure at the call site, never a silent 2-decimal parse.
enum Currency {
  irr('IRR', 0),
  jpy('JPY', 0),
  vnd('VND', 0),
  usd('USD', 2),
  eur('EUR', 2),
  aed('AED', 2),
  gbp('GBP', 2),
  kwd('KWD', 3),
  bhd('BHD', 3),
  omr('OMR', 3);

  const Currency(this.code, this.exponent);
  final String code;
  final int exponent;

  /// 10^exponent — minor units per major unit. The ONLY scaling source.
  int get minorPerMajor => switch (exponent) {
        0 => 1,
        2 => 100,
        3 => 1000,
        _ => throw StateError('unsupported exponent $exponent for $code'),
      };

  static Currency? tryParse(String code) =>
      Currency.values.where((c) => c.code == code).firstOrNull;
}

/// Money is (integer minor units) + (currency). No floats, ever.
final class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currency);

  final int minorUnits; // e.g. 12345 with KWD == 12.345 KWD
  final Currency currency;

  /// Parse a normalized-ASCII major-unit string into exact minor units.
  /// The caller (packages/l10n) MUST have folded Eastern/Persian digits and
  /// separators to ASCII first — core never sees localized numerals.
  factory Money.fromMajorString(String ascii, Currency c) {
    final scaled = (Decimal.parse(ascii) * Decimal.fromInt(c.minorPerMajor))
        .round(); // exact; Decimal has no binary-float error
    return Money(scaled.toBigInt().toInt(), c);
  }

  /// Single-currency addition only. Adding across currencies is a category
  /// error — convert through the FX layer first.
  Money operator +(Money other) => currency == other.currency
      ? Money(minorUnits + other.minorUnits, currency)
      : throw ArgumentError('currency mismatch: $currency vs ${other.currency}');

  Money operator -(Money other) => currency == other.currency
      ? Money(minorUnits - other.minorUnits, currency)
      : throw ArgumentError('currency mismatch: $currency vs ${other.currency}');

  @override
  int compareTo(Money other) {
    assert(currency == other.currency, 'compare across currencies is a bug');
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);
}

/// Toman is a display view over canonical IRR (1 Toman = 10 Rial), NOT a
/// currency. Storage stays IRR minor units.
enum RialDisplay { rial, toman }

extension TomanView on Money {
  (BigInt value, String unitKey) forRialDisplay(RialDisplay pref) {
    assert(currency == Currency.irr, 'Toman view applies to IRR only');
    if (pref == RialDisplay.toman) {
      return (BigInt.from(minorUnits) ~/ BigInt.from(10), 'unit.toman');
    }
    return (BigInt.from(minorUnits), 'unit.rial');
  }
}

void main() {
  // Exponent correctness across currencies — the invariant that a hardcoded
  // "*100" would silently break for IRR (0) and KWD (3).
  assert(Money.fromMajorString('1.50', Currency.usd).minorUnits == 150);
  assert(Money.fromMajorString('125.00', Currency.kwd).minorUnits == 125000);
  assert(Money.fromMajorString('125', Currency.irr).minorUnits == 125);
  assert(Money.fromMajorString('125', Currency.jpy).minorUnits == 125);

  // Unknown code is a typed null, not a defaulted parse.
  assert(Currency.tryParse('ZZZ') == null);

  // Rial/Toman round-trip: 500 Toman entered -> stored 5000 IRR -> shows 500.
  const stored = Money(5000, Currency.irr);
  assert(stored.forRialDisplay(RialDisplay.toman).$1 == BigInt.from(500));
  assert(stored.forRialDisplay(RialDisplay.rial).$1 == BigInt.from(5000));

  // Single-currency arithmetic only.
  final sum = const Money(100, Currency.usd) + const Money(50, Currency.usd);
  assert(sum.minorUnits == 150);
}
