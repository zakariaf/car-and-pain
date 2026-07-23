/// M6-T2 · two pure engines: **lump-cost amortization** (spread a one-off cost
/// across a period or distance window so cost/distance + TCO reflect steady
/// consumption, not a spike) and **recurrence materialization** (upcoming bill
/// instances feeding budget projection + F5 reminders). Amortization is a derived
/// view over the canonical row — the ledger keeps the true cash-out date/amount;
/// schedules are recomputed, never stored as lossy duplicates. Integer minor
/// units, no I/O.
library;

import '../result/failures.dart';
import '../result/result.dart';
import '../result/validation.dart';
import '../scheduling/schedule_rule.dart';
import '../time/temporal.dart';

/// Spread a lump cost across a period or distance window (M6-T2). Deterministic;
/// the per-period parts sum back to the original minor-unit amount **exactly**
/// (the remainder is distributed to the earliest periods, so no rounding leaks).
final class LumpAmortizer {
  const LumpAmortizer();

  /// Split [amountMinor] into [periods] parts summing back exactly to it. Works
  /// for negatives (a refund spread): the remainder is applied one unit at a time
  /// to the earliest periods in the amount's direction.
  List<int> overPeriods(int amountMinor, int periods) {
    assert(periods > 0, 'periods must be positive');
    final base = amountMinor ~/ periods;
    final remainder = amountMinor - base * periods; // sign matches amount
    final sign = remainder.sign;
    final extra = remainder.abs();
    return [
      for (var i = 0; i < periods; i++) base + (i < extra ? sign : 0),
    ];
  }

  /// The amortized share of [amountMinor] — a cost covering [windowMetres] of
  /// driving — attributable to a [usedMetres] sub-window, round-half-up. Returns
  /// `Err(ValidationFailure)` when the window is non-positive (can't amortize).
  Result<int, ValidationFailure> forDistance({
    required int amountMinor,
    required int windowMetres,
    required int usedMetres,
  }) {
    if (windowMetres <= 0) {
      return (Validation()..add('window', 'non_positive')).build(0);
    }
    final used = usedMetres < 0 ? 0 : usedMetres;
    return Ok(_divRoundHalfUp(amountMinor * used, windowMetres));
  }

  static int _divRoundHalfUp(int numerator, int denominator) {
    if (numerator < 0) {
      return -((2 * -numerator + denominator) ~/ (2 * denominator));
    }
    return (2 * numerator + denominator) ~/ (2 * denominator);
  }
}

/// A recurring bill definition (M6-T2): a first occurrence [anchor] plus a
/// [Recurrence], optionally bounded by [endAt] and/or [maxOccurrences]. Months
/// and years advance Gregorian-correctly (end-of-month clamped); non-Gregorian
/// calendar recurrence is layered above in `l10n`, converting only for display.
final class RecurringBill {
  const RecurringBill({
    required this.anchor,
    required this.recurrence,
    this.endAt,
    this.maxOccurrences,
  }) : assert(maxOccurrences == null || maxOccurrences > 0,
            'maxOccurrences must be positive');

  final Instant anchor;
  final Recurrence recurrence;
  final Instant? endAt;
  final int? maxOccurrences;

  /// Materialise the occurrence instants from [anchor] up to and including
  /// [until], honouring [endAt] and [maxOccurrences]. The anchor is the first
  /// occurrence. Deterministic; never stored.
  List<Instant> occurrencesUntil(Instant until) {
    final out = <Instant>[];
    var current = anchor;
    final hardEnd = endAt == null
        ? until.epochMillis
        : (endAt!.epochMillis < until.epochMillis
            ? endAt!.epochMillis
            : until.epochMillis);
    while (current.epochMillis <= hardEnd) {
      out.add(current);
      if (maxOccurrences != null && out.length >= maxOccurrences!) break;
      current = recurrence.nextAfter(current);
    }
    return out;
  }
}
