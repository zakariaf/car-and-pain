// Correct, illustrative FX converter for packages/core.
// Pure Dart: `decimal` for exact math, `clock` for injected time. No IO/network.
// FX rates are user-entered, dated, and staleness-flagged — never fetched.
import 'package:clock/clock.dart';
import 'package:decimal/decimal.dart';

import 'money.dart'; // Currency, Money from the sibling example

/// A sealed Result — the real one is owned by error-handling-never-lose-data.
/// Reproduced minimally here so this example compiles standalone.
sealed class Result<T, F> {
  const Result();
}

final class Ok<T, F> extends Result<T, F> {
  const Ok(this.value);
  final T value;
}

final class Err<T, F> extends Result<T, F> {
  const Err(this.failure);
  final F failure;
}

/// Typed FX failures — returned as Err(...), never thrown.
sealed class FxFailure {
  const FxFailure();
  const factory FxFailure.noRate() = _NoRate;
}

final class _NoRate extends FxFailure {
  const _NoRate();
}

enum FxStaleness { fresh, aging, stale, missing }

final class FxRate {
  const FxRate({
    required this.from,
    required this.to,
    required this.rate, // 1 [from] == rate [to]
    required this.asOf, // UTC date the user tagged the rate
  });
  final Currency from;
  final Currency to;
  final Decimal rate;
  final DateTime asOf;
}

final class FxTable {
  const FxTable(this._rates);
  final List<FxRate> _rates;

  /// Newest rate on or before today for the pair; may invert a stored to->from.
  FxRate? latestFor(Currency from, Currency to) {
    final direct = _rates.where((r) => r.from == from && r.to == to).toList()
      ..sort((a, b) => b.asOf.compareTo(a.asOf));
    if (direct.isNotEmpty) return direct.first;

    final inverse = _rates.where((r) => r.from == to && r.to == from).toList()
      ..sort((a, b) => b.asOf.compareTo(a.asOf));
    if (inverse.isEmpty) return null;
    final r = inverse.first;
    return FxRate(
      from: from,
      to: to,
      rate: (Decimal.one / r.rate).toDecimal(scaleOnInfinitePrecision: 20),
      asOf: r.asOf,
    );
  }
}

final class ConvertedMoney {
  const ConvertedMoney(this.money, this.staleness, {required this.ageDays});
  final Money money;
  final FxStaleness staleness;
  final int ageDays;
}

/// Pure. No IO. Injected clock -> deterministic staleness in tests.
final class FxConverter {
  const FxConverter(this._clock);
  final Clock _clock;

  Result<ConvertedMoney, FxFailure> convert(
    Money amount,
    Currency target,
    FxTable table,
  ) {
    if (amount.currency == target) {
      return Ok(ConvertedMoney(amount, FxStaleness.fresh, ageDays: 0));
    }

    final rate = table.latestFor(amount.currency, target);
    if (rate == null) return const Err(FxFailure.noRate());

    final ageDays = _clock.now().difference(rate.asOf).inDays;
    final staleness = switch (ageDays) {
      <= 7 => FxStaleness.fresh,
      <= 30 => FxStaleness.aging,
      _ => FxStaleness.stale,
    };

    // major = minor / minorPerMajor; convert; re-scale to the TARGET exponent.
    final srcMajor = (Decimal.fromInt(amount.minorUnits) /
            Decimal.fromInt(amount.currency.minorPerMajor))
        .toDecimal(scaleOnInfinitePrecision: 20);
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
