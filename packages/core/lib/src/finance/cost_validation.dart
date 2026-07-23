/// M6-T10 · pure data-integrity guardrails for the cost module. Warn-with-
/// override for soft issues (a dubious FX rate, a likely duplicate) and typed
/// `ValidationFailure`s for hard-invalid inputs (a non-positive budget, an
/// un-amortizable financing). Odometer regression/duplicate on an expense's
/// ledger link reuses the shared `LedgerEngine.check` — not re-implemented here.
library;

import '../result/failures.dart';
import '../result/result.dart';
import '../result/validation.dart';

/// A candidate expense for the duplicate heuristic (M6-T10) — the natural key a
/// double-tap or double-import would repeat.
final class ExpenseKey {
  const ExpenseKey({
    required this.dayEpoch,
    required this.amountMinor,
    this.categoryId,
  });

  /// The spend day as a whole day-since-epoch (so same-day entries collide).
  final int dayEpoch;
  final int amountMinor;
  final String? categoryId;

  @override
  bool operator ==(Object other) =>
      other is ExpenseKey &&
      other.dayEpoch == dayEpoch &&
      other.amountMinor == amountMinor &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(dayEpoch, amountMinor, categoryId);
}

/// Pure cost-integrity validators (M6-T10). Table-testable, no I/O.
final class CostValidators {
  const CostValidators();

  /// Warn (dismissible, not a hard block) when a dated-FX rate is missing, zero,
  /// or wildly outside a sanity band for the pair. Rates are thousandths of base
  /// per foreign unit; [sanityLowThousandths]/[sanityHighThousandths] bound the
  /// plausible range. An empty list means the rate looks fine.
  List<FieldError> fxRate({
    required int? rateThousandths,
    int? sanityLowThousandths,
    int? sanityHighThousandths,
  }) {
    if (rateThousandths == null || rateThousandths <= 0) {
      return const [FieldError('fxRate', 'missing_or_zero')];
    }
    if (sanityLowThousandths != null &&
        rateThousandths < sanityLowThousandths) {
      return const [FieldError('fxRate', 'out_of_band')];
    }
    if (sanityHighThousandths != null &&
        rateThousandths > sanityHighThousandths) {
      return const [FieldError('fxRate', 'out_of_band')];
    }
    return const [];
  }

  /// Whether [candidate] likely duplicates one of the [existing] expenses (same
  /// day + amount + category) — a double-tap or double-import. A genuine repeat is
  /// still allowed; this only warns.
  bool isLikelyDuplicate(ExpenseKey candidate, Iterable<ExpenseKey> existing) =>
      existing.contains(candidate);

  /// A budget target must be strictly positive (M6-T10).
  Result<void, ValidationFailure> budgetTarget(int targetMinor) {
    if (targetMinor <= 0) {
      return (Validation()..add('target', 'non_positive')).build(null);
    }
    return const Ok(null);
  }

  /// Financing inputs must be amortizable: positive principal and term (M6-T10).
  Result<void, ValidationFailure> financingTerms({
    required int principalMinor,
    required int termMonths,
  }) {
    final v = Validation();
    if (principalMinor <= 0) v.add('principal', 'non_positive');
    if (termMonths <= 0) v.add('term', 'non_positive');
    return v.build(null);
  }
}
