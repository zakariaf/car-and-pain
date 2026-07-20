import 'package:core/core.dart';

/// Data-integrity validators invoked at the repository boundary (F2-T8).
///
/// **Warn-with-override**: each returns a stable-code [FieldError] (or null) —
/// never a user-facing string. The UI shows a dismissible warning; the write
/// still persists (and records that it was overridden). Odometer regression /
/// rollover / duplicate warnings come from `LedgerEngine.check`.
abstract final class IntegrityValidators {
  /// Fuel volume exceeds the vehicle's tank capacity.
  static FieldError? overCapacityFuel({
    required int volumeMl,
    required int? tankCapacityMl,
  }) {
    if (tankCapacityMl == null || tankCapacityMl <= 0) return null;
    return volumeMl > tankCapacityMl
        ? const FieldError('volume', 'over_capacity')
        : null;
  }

  /// An entry dated in the future (beyond `now`).
  static FieldError? futureDated({
    required int atMillis,
    required int nowMillis,
  }) =>
      atMillis > nowMillis ? const FieldError('date', 'future_dated') : null;

  /// Implausible fuel economy (litres/100km outside a sane band).
  static FieldError? economyOutlier({
    required double litresPer100Km,
    double min = 1,
    double max = 40,
  }) {
    if (litresPer100Km < min || litresPer100Km > max) {
      return const FieldError('economy', 'outlier');
    }
    return null;
  }

  /// Collapse a mixed list of warnings into a [ValidationFailure] (null = clean).
  static ValidationFailure? collect(List<FieldError?> warnings) {
    final errors = warnings.whereType<FieldError>().toList();
    return errors.isEmpty ? null : ValidationFailure(errors);
  }
}
