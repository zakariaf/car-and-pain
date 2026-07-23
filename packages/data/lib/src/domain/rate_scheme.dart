import 'dart:convert';

import 'package:core/core.dart';

/// A persisted mileage-rate scheme (M7-T3) plus the canonical codec that maps
/// its serialized revisions to and from the pure [MileageRateScheme] engine. The
/// revisions ride as locale-neutral JSON (effective dates as UTC epoch millis,
/// rates in thousandths of a minor unit) so a scheme round-trips through backup
/// and diffs cleanly.
class RateScheme {
  const RateScheme({
    required this.id,
    required this.name,
    required this.kind,
    required this.currencyCode,
    required this.unit,
    required this.taxYearStartMonth,
    required this.taxYearStartDay,
    required this.revisionsJson,
    required this.isBuiltIn,
  });

  final String id;
  final String name;
  final String kind; // irs | hmrc | custom
  final String currencyCode;
  final String unit; // mile | kilometre
  final int taxYearStartMonth;
  final int taxYearStartDay;
  final String revisionsJson;
  final bool isBuiltIn;

  /// Rehydrate the pure engine from the persisted row.
  MileageRateScheme toEngine() => MileageRateScheme(
        id: id,
        name: name,
        kind: _kindFrom(kind),
        currencyCode: currencyCode,
        unit: unit == 'kilometre'
            ? RateDistanceUnit.kilometre
            : RateDistanceUnit.mile,
        taxYearStartMonth: taxYearStartMonth,
        taxYearStartDay: taxYearStartDay,
        revisions: decodeRevisions(revisionsJson),
      );

  static RateKind _kindFrom(String s) => switch (s) {
        'irs' => RateKind.irs,
        'hmrc' => RateKind.hmrc,
        _ => RateKind.custom,
      };

  /// Encode revisions to canonical JSON (for persistence / backup).
  static String encodeRevisions(List<RateRevision> revisions) {
    final list = revisions
        .map((r) => {
              'effectiveFrom': r.effectiveFrom.toUtc().millisecondsSinceEpoch,
              'passengerRateThousandths': r.passengerRateThousandthsPerUnit,
              'tiers': {
                for (final entry in r.tiersByClass.entries)
                  entry.key.name: entry.value
                      .map((t) => {
                            'rate': t.rateThousandthsPerUnit,
                            if (t.upToMetres != null) 'upTo': t.upToMetres,
                          })
                      .toList(),
              },
            })
        .toList();
    return jsonEncode(list);
  }

  /// Decode canonical JSON back into engine revisions. Tolerant of an empty or
  /// malformed payload (returns an empty list rather than throwing across the
  /// boundary).
  static List<RateRevision> decodeRevisions(String raw) {
    if (raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().map((r) {
      final tiersRaw = r['tiers'];
      final tiersByClass = <MileageVehicleClass, List<RateTier>>{};
      if (tiersRaw is Map<String, dynamic>) {
        for (final entry in tiersRaw.entries) {
          final cls = _classFrom(entry.key);
          if (cls == null) continue;
          final tiers = (entry.value as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map((t) {
            return RateTier(
              rateThousandthsPerUnit: (t['rate'] as num).toInt(),
              upToMetres: t['upTo'] == null ? null : (t['upTo'] as num).toInt(),
            );
          }).toList();
          tiersByClass[cls] = tiers;
        }
      }
      return RateRevision(
        effectiveFrom: DateTime.fromMillisecondsSinceEpoch(
          (r['effectiveFrom'] as num).toInt(),
          isUtc: true,
        ),
        passengerRateThousandthsPerUnit:
            (r['passengerRateThousandths'] as num?)?.toInt() ?? 0,
        tiersByClass: tiersByClass,
      );
    }).toList();
  }

  static MileageVehicleClass? _classFrom(String s) => switch (s) {
        'car' => MileageVehicleClass.car,
        'van' => MileageVehicleClass.van,
        'motorcycle' => MileageVehicleClass.motorcycle,
        'bicycle' => MileageVehicleClass.bicycle,
        _ => null,
      };
}
