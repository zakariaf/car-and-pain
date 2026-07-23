/// M6-T4 · depreciation curves + equity/negative-equity. Pure, integer minor
/// units. Nets an estimated vehicle value against a loan balance to expose the
/// owner's equity position (surfaced when underwater, never silently clamped).
library;

import 'dart:math' as math;

/// The depreciation model.
enum DepreciationMethod { straightLine, decliningBalance }

/// A depreciation curve (M6-T4): estimated vehicle value over time from an
/// initial value down to a salvage floor. Straight-line spreads the loss evenly
/// over the useful life; declining-balance applies a constant annual rate.
final class DepreciationCurve {
  const DepreciationCurve({
    required this.initialValueMinor,
    required this.usefulLifeMonths,
    this.method = DepreciationMethod.straightLine,
    this.salvageValueMinor = 0,
    this.annualRateBps = 2000,
  })  : assert(initialValueMinor >= 0, 'value cannot be negative'),
        assert(usefulLifeMonths > 0, 'useful life must be positive'),
        assert(salvageValueMinor >= 0, 'salvage cannot be negative'),
        assert(annualRateBps > 0 && annualRateBps < 10000,
            'annual rate must be in (0, 100)%');

  final int initialValueMinor;
  final int usefulLifeMonths;
  final DepreciationMethod method;
  final int salvageValueMinor;

  /// Declining-balance annual depreciation rate in basis points (2000 = 20%/yr).
  final int annualRateBps;

  /// Estimated value [months] after acquisition (minor units), floored at the
  /// salvage value. Month 0 returns the initial value.
  int valueAt(int months) {
    final t = months < 0 ? 0 : months;
    return switch (method) {
      DepreciationMethod.straightLine => _straightLine(t),
      DepreciationMethod.decliningBalance => _decliningBalance(t),
    };
  }

  int _straightLine(int t) {
    if (t >= usefulLifeMonths) return salvageValueMinor;
    final depreciable = initialValueMinor - salvageValueMinor;
    return initialValueMinor - (depreciable * t / usefulLifeMonths).round();
  }

  int _decliningBalance(int t) {
    final years = t / 12;
    final rate = annualRateBps / 10000;
    final v = (initialValueMinor * math.pow(1 - rate, years)).round();
    return math.max(v, salvageValueMinor);
  }
}

/// An equity position (M6-T4): estimated value minus what is still owed. Negative
/// equity (underwater) is an explicit, labelled state — never clamped to zero.
final class EquityPosition {
  const EquityPosition({
    required this.valueMinor,
    required this.loanBalanceMinor,
  });

  final int valueMinor;
  final int loanBalanceMinor;

  /// value − balance. Negative when more is owed than the vehicle is worth.
  int get equityMinor => valueMinor - loanBalanceMinor;

  bool get isNegative => equityMinor < 0;
}
