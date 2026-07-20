/// The shipped ISO-4217 currencies, each keyed to its **real** minor-unit
/// exponent. This table is explicit and never defaults to 2 — a hardcoded `100`
/// is a 100x error for IRR (exponent 0) and a 10x error for KWD (exponent 3).
///
/// Toman is deliberately **absent**: it is a display view over IRR (1 Toman =
/// 10 Rial), never a stored currency. See `Money.fromToman` / the Rial-Toman
/// view extension.
enum Currency {
  // Exponent 0 — no minor unit (1 major = 1 minor).
  irr('IRR', 0),
  jpy('JPY', 0),
  vnd('VND', 0),

  // Exponent 2 — the common two-decimal currencies.
  usd('USD', 2),
  eur('EUR', 2),
  aed('AED', 2),
  gbp('GBP', 2),
  // `try` is a reserved word; the enum value is `try_`, the ISO code is 'TRY'.
  try_('TRY', 2),

  // Exponent 3 — the three-decimal Gulf/Iraqi dinars.
  kwd('KWD', 3),
  bhd('BHD', 3),
  omr('OMR', 3),
  iqd('IQD', 3);

  const Currency(this.code, this.exponent);

  /// The ISO-4217 alphabetic code, e.g. `USD`.
  final String code;

  /// The ISO-4217 minor-unit exponent: 0, 2, or 3 for shipped currencies.
  final int exponent;

  /// 10^[exponent] — minor units per major unit. The ONLY scaling source; never
  /// hardcode `* 100` / `/ 100`.
  int get minorPerMajor => switch (exponent) {
        0 => 1,
        2 => 100,
        3 => 1000,
        _ => throw StateError('unsupported ISO-4217 exponent $exponent'),
      };

  /// Resolve a code to a [Currency], or `null` for an unshipped/unknown code.
  /// The caller emits a typed failure — never a silent default-to-2 parse.
  static Currency? tryParse(String code) {
    for (final currency in Currency.values) {
      if (currency.code == code) return currency;
    }
    return null;
  }
}
