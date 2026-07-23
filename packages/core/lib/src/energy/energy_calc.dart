/// Pure "enter-any-two" fill math (M3-T2): given any two of volume, unit price,
/// and total, derive the third at 3-decimal price precision using integers only
/// (no float money). Price is carried as **thousandths of a major currency unit
/// per litre** (e.g. €1.759/L → 1759); volume in millilitres; total in ISO-4217
/// minor units keyed to the currency's real exponent.
library;

/// The three fill amounts, all present and mutually consistent.
typedef FillAmounts = ({int volumeMl, int priceThousandths, int totalMinor});

int _pow10(int e) {
  var r = 1;
  for (var i = 0; i < e; i++) {
    r *= 10;
  }
  return r;
}

/// Complete a fill from any two of [volumeMl] / [priceThousandths] /
/// [totalMinor] at the currency's [exponent] (0/2/3). Returns null if fewer
/// than two are known. When all three are given they are returned unchanged
/// (the user-marked authoritative fields win — rounding never fights a receipt).
///
/// total_minor = volumeMl × priceThousandths × 10^exponent ÷ 1,000,000
FillAmounts? completeFill({
  required int exponent,
  int? volumeMl,
  int? priceThousandths,
  int? totalMinor,
}) {
  final known = (volumeMl != null ? 1 : 0) +
      (priceThousandths != null ? 1 : 0) +
      (totalMinor != null ? 1 : 0);
  if (known < 2) return null;

  // At most one of the three is missing here; the `??` branch fires only for
  // that one (the two provided fields are authoritative and pass through).
  final scale = _pow10(exponent);
  final vol = volumeMl ??
      (priceThousandths == 0
          ? 0
          : (totalMinor! * 1000000 / (priceThousandths! * scale)).round());
  final price = priceThousandths ??
      (volumeMl == 0
          ? 0
          : (totalMinor! * 1000000 / (volumeMl! * scale)).round());
  final total =
      totalMinor ?? (volumeMl! * priceThousandths! * scale / 1000000).round();
  return (volumeMl: vol, priceThousandths: price, totalMinor: total);
}
