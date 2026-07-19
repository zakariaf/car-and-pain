// Correct RTL-safe feature widget for Car and Pain.
// Directional-only geometry + ICU strings + bidi-isolated technical IDs.
// Mirrors by construction when Directionality flips to RTL (fa/ar/ckb) — no conditionals.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:l10n/l10n.dart'; // AppLocalizations, isolateLtr, formatNumber

class VehicleSummaryCard extends StatelessWidget {
  const VehicleSummaryCard({
    super.key,
    required this.nickname, // UGC — preserved verbatim
    required this.plate,    // strong-LTR technical ID
    required this.odometerKm,
    required this.westernDigits,
  });

  final String nickname;
  final String plate;
  final num odometerKm;
  final bool westernDigits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context); // non-null: nullable-getter: false
    final locale = Localizations.localeOf(context).toString();

    return Padding(
      // GOOD: logical start/end — never EdgeInsets.only(left/right)
      padding: const EdgeInsetsDirectional.only(start: 16, end: 8, top: 12, bottom: 12),
      child: Row(
        // GOOD: start/end main-axis, not hardcoded for direction
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname, textAlign: TextAlign.start),
                // Plate is LTR even inside an RTL card — isolate it inline.
                Text(
                  '${l10n.plateLabel}: ${isolateLtr(plate)}',
                  textAlign: TextAlign.start,
                ),
                // Odometer: native digits per preference, formatted at the edge.
                Text(
                  l10n.odometerReading(
                    formatNumber(odometerKm, locale, westernDigits: westernDigits),
                  ),
                  textAlign: TextAlign.start,
                ),
              ],
            ),
          ),
          // Directional nav icon — auto-mirrors in RTL.
          IconButton(
            icon: Icon(Icons.adaptive.arrow_forward),
            onPressed: () {},
          ),
          // A custom directional glyph not in Icons.adaptive — flip manually.
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(
              Directionality.of(context) == TextDirection.rtl ? math.pi : 0,
            ),
            child: const Icon(Icons.trending_up),
          ),
        ],
      ),
    );
  }
}
