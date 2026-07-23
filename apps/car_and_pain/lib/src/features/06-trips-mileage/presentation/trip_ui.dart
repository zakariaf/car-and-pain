import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:l10n/l10n.dart';

/// Shared trip presentation helpers (M7-T5/T6). Kept UI-side so the application
/// providers stay Flutter-free.

/// Resolve a per-vehicle distance-unit preference string to a [DistanceUnit],
/// defaulting to kilometres (the SI-friendly display default).
DistanceUnit distanceUnitOf(String? pref) => switch (pref) {
      'mile' => DistanceUnit.mile,
      'metre' => DistanceUnit.metre,
      _ => DistanceUnit.kilometre,
    };

/// The redundant status badge for a classification: a **distinct icon shape**
/// plus a **localized text label** — legible without colour.
(IconData, String) classificationBadge(
  AppLocalizations l10n,
  TripClassification c,
) =>
    switch (c) {
      TripClassification.business => (
          Icons.business_center_outlined,
          l10n.tripClassBusiness,
        ),
      TripClassification.personal => (
          Icons.person_outline,
          l10n.tripClassPersonal,
        ),
      TripClassification.commute => (
          Icons.commute_outlined,
          l10n.tripClassCommute,
        ),
      TripClassification.unclassified => (
          Icons.help_outline,
          l10n.tripClassUnclassified,
        ),
    };
