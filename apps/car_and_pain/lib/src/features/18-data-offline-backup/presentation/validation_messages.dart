import 'package:l10n/l10n.dart';

/// Localize a `FieldError`-style code into a user-facing warning. Every code a
/// validator or the ledger engine can emit maps to a localized message — no raw
/// code or English string ever reaches the user (F2-T13).
String validationMessage(AppLocalizations l10n, String code) => switch (code) {
      'regression' => l10n.validationOdometerRegression,
      'rollover' => l10n.validationOdometerRollover,
      'duplicate' => l10n.validationOdometerDuplicate,
      'over_capacity' => l10n.validationOverCapacity,
      'future_dated' => l10n.validationFutureDated,
      'outlier' => l10n.validationEconomyOutlier,
      _ => l10n.startupFailureUnknown,
    };
