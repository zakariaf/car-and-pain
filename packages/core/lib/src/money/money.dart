import '../result/failures.dart';
import '../result/result.dart';
import '../result/validation.dart';
import 'currency.dart';

/// Money as **integer minor units** + a [Currency] — never a `double`, never a
/// formatted string, never Toman. Floating-point drift silently corrupts the
/// multi-year totals a user can never re-derive (there is no server copy).
///
/// Arithmetic is single-currency only; combining currencies must first go
/// through the FX converter (added later) where provenance/staleness are
/// enforced. Cross-currency `+`/`compareTo` is a bug, guarded by `assert`.
final class Money implements Comparable<Money> {
  /// Trusted construction from an already-canonical minor-unit amount.
  const Money(this.minorUnits, this.currency);

  /// Zero in [currency].
  const Money.zero(this.currency) : minorUnits = 0;

  /// Build IRR from a Toman amount. Toman is a display unit only (1 Toman = 10
  /// Rial); the stored row is byte-identical whether the user entered Rial or
  /// Toman. [rial] carries the sub-Toman remainder (0–9).
  factory Money.fromToman(int toman, {int rial = 0}) =>
      Money(toman * 10 + rial, Currency.irr);

  /// e.g. `12345` with `KWD` (exponent 3) == 12.345 KWD.
  final int minorUnits;
  final Currency currency;

  /// Parse a **plain ASCII** decimal major-unit string (e.g. `"12.34"`) against
  /// the currency's exponent. Digits and `٫`/`٬` separators must already be
  /// normalized to ASCII upstream in `l10n` — this never calls
  /// `double.parse`/`int.parse` on raw locale input.
  ///
  /// Returns `Err(ValidationFailure)` when the string is not a number, or when
  /// it carries more fractional digits than the currency's exponent allows.
  static Result<Money, ValidationFailure> tryParseMajor(
    String source,
    Currency currency,
  ) {
    final v = Validation();
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      v.add('amount', 'not_a_number');
      return v.build(Money.zero(currency));
    }

    var body = trimmed;
    var negative = false;
    if (body.startsWith('-')) {
      negative = true;
      body = body.substring(1);
    } else if (body.startsWith('+')) {
      body = body.substring(1);
    }

    final parts = body.split('.');
    if (parts.length > 2) {
      v.add('amount', 'not_a_number');
      return v.build(Money.zero(currency));
    }

    final intPart = parts[0].isEmpty ? '0' : parts[0];
    final fracPart = parts.length == 2 ? parts[1] : '';

    if (!_isAsciiDigits(intPart) ||
        (fracPart.isNotEmpty && !_isAsciiDigits(fracPart))) {
      v.add('amount', 'not_a_number');
      return v.build(Money.zero(currency));
    }

    if (fracPart.length > currency.exponent) {
      v.add('amount', 'too_many_fraction_digits');
      return v.build(Money.zero(currency));
    }

    final scale = currency.minorPerMajor;
    final major = int.parse(intPart);
    final paddedFrac = fracPart.padRight(currency.exponent, '0');
    final frac = paddedFrac.isEmpty ? 0 : int.parse(paddedFrac);
    final magnitude = major * scale + frac;
    return v.build(Money(negative ? -magnitude : magnitude, currency));
  }

  /// Single-currency addition only.
  Money operator +(Money other) {
    assert(currency == other.currency, 'currency mismatch is a bug');
    return Money(minorUnits + other.minorUnits, currency);
  }

  /// Single-currency subtraction only.
  Money operator -(Money other) {
    assert(currency == other.currency, 'currency mismatch is a bug');
    return Money(minorUnits - other.minorUnits, currency);
  }

  /// Scale by an integer factor (e.g. quantity). Stays exact — no floats.
  Money operator *(int factor) => Money(minorUnits * factor, currency);

  /// Negation.
  Money operator -() => Money(-minorUnits, currency);

  /// True when the amount is negative.
  bool get isNegative => minorUnits < 0;

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

  @override
  String toString() => 'Money($minorUnits ${currency.code})';

  static bool _isAsciiDigits(String s) {
    if (s.isEmpty) return false;
    for (final code in s.codeUnits) {
      if (code < 0x30 || code > 0x39) return false;
    }
    return true;
  }
}

/// The Rial to Toman **display** view. Toman is never stored; this projects an
/// IRR [Money] into whole Toman + a 0–9 Rial remainder for presentation.
extension RialTomanView on Money {
  /// Whole Toman (Rial ÷ 10). IRR only.
  int get tomanWhole {
    assert(currency == Currency.irr, 'Toman view is IRR-only');
    return minorUnits ~/ 10;
  }

  /// The sub-Toman Rial remainder (Rial mod 10). IRR only.
  int get tomanRialRemainder {
    assert(currency == Currency.irr, 'Toman view is IRR-only');
    return minorUnits % 10;
  }
}
