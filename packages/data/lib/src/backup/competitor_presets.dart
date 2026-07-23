// Field-mapping presets that coerce a foreign competitor CSV row into canonical
// values (F6-T5). Each preset names the source and maps its columns → canonical
// fields with unit/currency/date coercion. Unknown files fall back to a manual
// column mapping (the same [CsvFieldMap] machinery, built in the wizard).

/// Coerce one raw CSV string into a canonical value (int metres / ml / minor
/// units / epoch millis, or a passed-through string). Returns null on a blank.
typedef Coerce = Object? Function(String raw);

/// A single foreign-column → canonical-field mapping with optional coercion.
class CsvFieldMap {
  const CsvFieldMap(this.from, this.to, [this.coerce]);

  /// The foreign CSV column header.
  final String from;

  /// The canonical field name it maps to.
  final String to;

  /// Value coercion; identity (string pass-through) when null.
  final Coerce? coerce;
}

/// A named set of column mappings for one known source.
class CompetitorPreset {
  const CompetitorPreset({required this.name, required this.fields});

  final String name;
  final List<CsvFieldMap> fields;

  /// Map one header-keyed foreign row → a canonical field map. Columns the file
  /// omits are simply absent; coercion failures drop that field (reported by
  /// the wizard per row), never abort the whole import.
  Map<String, Object?> mapRow(Map<String, String> row) {
    final out = <String, Object?>{};
    for (final f in fields) {
      final raw = row[f.from];
      if (raw == null || raw.trim().isEmpty) continue;
      final value = f.coerce == null ? raw : _tryCoerce(f.coerce!, raw);
      if (value != null) out[f.to] = value;
    }
    return out;
  }

  static Object? _tryCoerce(Coerce c, String raw) {
    try {
      return c(raw);
    } on Object {
      return null; // malformed cell → skip that field, not the row
    }
  }
}

// ── Canonical coercions (pure, table-testable) ─────────────────────────────
const double _metresPerMile = 1609.344;
const double _mlPerUsGallon = 3785.411784;

/// Parse a decimal, stripping currency symbols, spaces and thousands commas.
double _decimal(String raw) =>
    double.parse(raw.replaceAll(RegExp(r'[^\d.\-]'), ''));

/// Miles (display) → canonical whole metres.
int milesToMetres(String raw) => (_decimal(raw) * _metresPerMile).round();

/// Kilometres (display) → canonical whole metres.
int kmToMetres(String raw) => (_decimal(raw) * 1000).round();

/// US gallons (display) → canonical millilitres.
int gallonsToMillilitres(String raw) =>
    (_decimal(raw) * _mlPerUsGallon).round();

/// A 2-decimal money string ("$41.20", "41,20"-free) → integer minor units.
int dollarsToMinorUnits(String raw) => (_decimal(raw) * 100).round();

/// An ISO `YYYY-MM-DD` (or full ISO-8601) date → UTC epoch millis. A zone-less
/// date is interpreted as UTC midnight (never the runner's local zone), so the
/// import is deterministic regardless of device timezone.
int isoDateToEpochMillis(String raw) {
  final d = DateTime.parse(raw.trim());
  return DateTime.utc(
    d.year,
    d.month,
    d.day,
    d.hour,
    d.minute,
    d.second,
    d.millisecond,
  ).millisecondsSinceEpoch;
}

/// Fuelly fuel-log preset — a representative column mapping (exact headers are
/// verified against a real export during on-device QA).
const fuellyFuelPreset = CompetitorPreset(
  name: 'Fuelly',
  fields: [
    CsvFieldMap('Date', 'filledAtUtcMillis', isoDateToEpochMillis),
    CsvFieldMap('Odometer', 'odometerMetres', milesToMetres),
    CsvFieldMap('Fill Amount', 'volumeMillilitres', gallonsToMillilitres),
    CsvFieldMap('Total Cost', 'totalCostMinorUnits', dollarsToMinorUnits),
    CsvFieldMap('Notes', 'note'),
  ],
);

/// Drivvo service-history preset (M4-T7) — representative column mapping onto the
/// canonical service_entries fields (exact headers verified in on-device QA).
const drivvoServicePreset = CompetitorPreset(
  name: 'Drivvo (service)',
  fields: [
    CsvFieldMap('Date', 'servicedAtUtcMillis', isoDateToEpochMillis),
    CsvFieldMap('Odometer (km)', 'odometerMetres', kmToMetres),
    CsvFieldMap('Total cost', 'totalCostMinorUnits', dollarsToMinorUnits),
    CsvFieldMap('Type of service', 'serviceType'),
    CsvFieldMap('Observation', 'note'),
  ],
);

/// aCar service-history preset (M4-T7).
const aCarServicePreset = CompetitorPreset(
  name: 'aCar (service)',
  fields: [
    CsvFieldMap('Date', 'servicedAtUtcMillis', isoDateToEpochMillis),
    CsvFieldMap('Odometer', 'odometerMetres', kmToMetres),
    CsvFieldMap('Total Cost', 'totalCostMinorUnits', dollarsToMinorUnits),
    CsvFieldMap('Services', 'serviceType'),
    CsvFieldMap('Notes', 'note'),
  ],
);

/// Fuelio cost/service-history preset (M4-T7).
const fuelioServicePreset = CompetitorPreset(
  name: 'Fuelio (costs)',
  fields: [
    CsvFieldMap('Date', 'servicedAtUtcMillis', isoDateToEpochMillis),
    CsvFieldMap('Odo (km)', 'odometerMetres', kmToMetres),
    CsvFieldMap('Cost', 'totalCostMinorUnits', dollarsToMinorUnits),
    CsvFieldMap('CategoryName', 'serviceType'),
    CsvFieldMap('Notes', 'note'),
  ],
);

/// The presets the import wizard offers (fuel + service history).
const competitorPresets = <CompetitorPreset>[
  fuellyFuelPreset,
  drivvoServicePreset,
  aCarServicePreset,
  fuelioServicePreset,
];
