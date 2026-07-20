import '../result/failures.dart';
import '../result/result.dart';
import '../result/validation.dart';
import '../time/clock.dart';
import '../time/temporal.dart';
import 'currency.dart';
import 'money.dart';

/// Rounding policy applied ONCE at a conversion/total boundary — never on
/// intermediate sums (that accumulates bias). Default is banker's (half-even).
enum RoundingMode { halfUp, halfEven, floor, ceil }

/// How stale a dated FX rate is, relative to an injected clock. TCO surfaces the
/// worst staleness across all conversions as one honest badge.
enum FxStaleness { fresh, aging, stale }

/// A single user-entered, **dated** FX rate: `1` unit of [from] = `rateNum/rateDen`
/// units of [to] as of [asOf]. Stored as an exact integer ratio — never a float.
/// Rates are never fetched; there is no network path.
final class FxRate {
  const FxRate({
    required this.from,
    required this.to,
    required this.rateNum,
    required this.rateDen,
    required this.asOf,
  }) : assert(rateDen != 0, 'rate denominator must be non-zero');

  /// Parse a plain-ASCII decimal rate string (e.g. `"1.0825"`) into an exact
  /// ratio. Digits/separators must already be normalized to ASCII upstream.
  static Result<FxRate, ValidationFailure> tryParse({
    required Currency from,
    required Currency to,
    required String decimal,
    required Instant asOf,
  }) {
    final v = Validation();
    final body = decimal.trim();
    final parts = body.split('.');
    if (parts.length > 2 || body.isEmpty) {
      v.add('rate', 'not_a_number');
      return v.build(
          FxRate(from: from, to: to, rateNum: 0, rateDen: 1, asOf: asOf));
    }
    final intPart = parts[0].isEmpty ? '0' : parts[0];
    final fracPart = parts.length == 2 ? parts[1] : '';
    if (!_digits(intPart) || (fracPart.isNotEmpty && !_digits(fracPart))) {
      v.add('rate', 'not_a_number');
      return v.build(
          FxRate(from: from, to: to, rateNum: 0, rateDen: 1, asOf: asOf));
    }
    final den = _pow10(fracPart.length);
    final num = int.parse('$intPart$fracPart');
    if (num == 0) {
      v.add('rate', 'zero_rate');
      return v.build(
          FxRate(from: from, to: to, rateNum: 0, rateDen: 1, asOf: asOf));
    }
    return v.build(
      FxRate(from: from, to: to, rateNum: num, rateDen: den, asOf: asOf),
    );
  }

  final Currency from;
  final Currency to;
  final int rateNum;
  final int rateDen;
  final Instant asOf;

  /// The reverse-direction rate (`to → from`), same date.
  FxRate get inverse => FxRate(
        from: to,
        to: from,
        rateNum: rateDen,
        rateDen: rateNum,
        asOf: asOf,
      );

  @override
  bool operator ==(Object other) =>
      other is FxRate &&
      other.from == from &&
      other.to == to &&
      other.rateNum == rateNum &&
      other.rateDen == rateDen &&
      other.asOf == asOf;

  @override
  int get hashCode => Object.hash(from, to, rateNum, rateDen, asOf);

  @override
  String toString() =>
      'FxRate(1 ${from.code} = $rateNum/$rateDen ${to.code} @${asOf.epochMillis})';

  static bool _digits(String s) {
    if (s.isEmpty) return false;
    for (final c in s.codeUnits) {
      if (c < 0x30 || c > 0x39) return false;
    }
    return true;
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}

/// A collection of dated FX rates. Resolves the rate effective at or before a
/// given date, considering a reverse-direction rate's inverse.
final class FxTable {
  const FxTable(this.rates);

  final List<FxRate> rates;

  /// The most recent rate for ([from] → [to]) effective at or before [asOf]
  /// (or the overall latest if [asOf] is null). Falls back to the inverse of a
  /// reverse-direction rate.
  FxRate? rateFor(Currency from, Currency to, {Instant? asOf}) {
    FxRate? best;
    for (final r in rates) {
      final candidate = r.from == from && r.to == to
          ? r
          : (r.from == to && r.to == from ? r.inverse : null);
      if (candidate == null) continue;
      if (asOf != null && candidate.asOf.epochMillis > asOf.epochMillis) {
        continue;
      }
      if (best == null || candidate.asOf.epochMillis > best.asOf.epochMillis) {
        best = candidate;
      }
    }
    return best;
  }
}

/// Converts money between currencies using dated, user-entered rates. Injected
/// with a [Clock] so staleness is deterministic in tests.
final class FxConverter {
  const FxConverter(this._table, {Clock clock = const SystemClock()})
      : _clock = clock;

  final FxTable _table;
  final Clock _clock;

  /// Convert [amount] into [to], using the rate effective at [asOf]. Same
  /// currency is a no-op. Rounds once, at this boundary.
  Result<Money, FxFailure> convert(
    Money amount,
    Currency to, {
    Instant? asOf,
    RoundingMode rounding = RoundingMode.halfEven,
  }) {
    if (amount.currency == to) return Ok(amount);
    final rate = _table.rateFor(amount.currency, to, asOf: asOf);
    if (rate == null) {
      return Err(NoFxRate(from: amount.currency.code, to: to.code));
    }
    final toMinor =
        _applyRate(amount.minorUnits, rate, amount.currency, to, rounding);
    return Ok(Money(toMinor, to));
  }

  /// How stale [rate] is relative to "now".
  FxStaleness stalenessOf(FxRate rate) {
    final ageMs =
        _clock.nowUtc().millisecondsSinceEpoch - rate.asOf.epochMillis;
    final ageDays = ageMs / Duration.millisecondsPerDay;
    if (ageDays < 7) return FxStaleness.fresh;
    if (ageDays < 30) return FxStaleness.aging;
    return FxStaleness.stale;
  }

  static int _applyRate(
    int fromMinor,
    FxRate rate,
    Currency from,
    Currency to,
    RoundingMode rounding,
  ) {
    // toMinor = fromMinor * rateNum * toScale / (rateDen * fromScale).
    // BigInt intermediate avoids int64 overflow for high-magnitude currencies.
    final numerator = BigInt.from(fromMinor) *
        BigInt.from(rate.rateNum) *
        BigInt.from(to.minorPerMajor);
    final denominator =
        BigInt.from(rate.rateDen) * BigInt.from(from.minorPerMajor);
    return _roundedDiv(numerator, denominator, rounding).toInt();
  }

  static BigInt _roundedDiv(
    BigInt numerator,
    BigInt denominator,
    RoundingMode mode,
  ) {
    var n = numerator;
    var d = denominator;
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final q = n ~/ d; // truncates toward zero
    final r = n - q * d; // remainder, sign of n
    if (r == BigInt.zero) return q;

    final negative = n.isNegative;
    final twiceR = r.abs() * BigInt.two;
    switch (mode) {
      case RoundingMode.floor:
        return negative ? q - BigInt.one : q;
      case RoundingMode.ceil:
        return negative ? q : q + BigInt.one;
      case RoundingMode.halfUp:
        if (twiceR >= d) return negative ? q - BigInt.one : q + BigInt.one;
        return q;
      case RoundingMode.halfEven:
        final cmp = twiceR.compareTo(d);
        if (cmp > 0 || (cmp == 0 && q.isOdd)) {
          return negative ? q - BigInt.one : q + BigInt.one;
        }
        return q;
    }
  }
}
