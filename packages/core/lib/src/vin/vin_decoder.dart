/// Offline ISO 3779 / ISO 3780 VIN decoder (M2-T3) — pure Dart, no network.
///
/// Validates the 17-character format and charset, computes the mod-11 check
/// digit, decodes the World Manufacturer Identifier (WMI → manufacturer/region)
/// from a bundled offline table, and derives the model year from position 10.
/// Full trim/options decode genuinely needs a network and is out of scope — the
/// UI surfaces that as an honest offline-degraded stub with free-text fallback.
library;

/// The broad manufacturing region from the first VIN character (ISO 3780).
enum VinRegion {
  africa,
  asia,
  europe,
  northAmerica,
  oceania,
  southAmerica,
  unknown
}

/// The outcome of decoding a VIN. Total and pure — every field is derivable
/// offline; anything needing a network is deliberately absent.
class VinDecodeResult {
  const VinDecodeResult({
    required this.vin,
    required this.wellFormed,
    required this.checkDigitValid,
    required this.wmi,
    required this.manufacturer,
    required this.region,
    required this.modelYear,
    required this.smallManufacturer,
  });

  /// The normalized (upper-cased, trimmed) VIN as decoded.
  final String vin;

  /// 17 chars, allowed charset only (no I/O/Q), so positions are meaningful.
  final bool wellFormed;

  /// ISO 3779 mod-11 check-digit (position 9) matches. Always `false` when not
  /// [wellFormed]. An invalid check digit warns but never blocks saving.
  final bool checkDigitValid;

  /// The first three characters — the World Manufacturer Identifier (or '').
  final String wmi;

  /// Manufacturer from the bundled table, or `null` when unknown (free-text).
  final String? manufacturer;

  /// Region from the first character (ISO 3780).
  final VinRegion region;

  /// Model year decoded from position 10, disambiguated by the position-7 rule
  /// (numeric → 1980–2009 cycle, alphabetic → 2010–2039). `null` if not
  /// well-formed or the code is not a valid year code.
  final int? modelYear;

  /// A small-volume manufacturer (WMI third char '9'); its identity is refined
  /// by VIN positions 12–14, which this offline table does not enumerate.
  final bool smallManufacturer;

  @override
  bool operator ==(Object other) =>
      other is VinDecodeResult &&
      other.vin == vin &&
      other.wellFormed == wellFormed &&
      other.checkDigitValid == checkDigitValid &&
      other.wmi == wmi &&
      other.manufacturer == manufacturer &&
      other.region == region &&
      other.modelYear == modelYear &&
      other.smallManufacturer == smallManufacturer;

  @override
  int get hashCode => Object.hash(vin, wellFormed, checkDigitValid, wmi,
      manufacturer, region, modelYear, smallManufacturer);
}

/// The pure VIN decoder. Stateless; inject nothing.
class VinDecoder {
  const VinDecoder();

  static const _allowed = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789';

  /// Transliteration values for the check-digit sum (I/O/Q excluded by charset).
  static const Map<String, int> _translit = {
    'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'F': 6, 'G': 7, 'H': 8, //
    'J': 1, 'K': 2, 'L': 3, 'M': 4, 'N': 5, 'P': 7, 'R': 9, //
    'S': 2, 'T': 3, 'U': 4, 'V': 5, 'W': 6, 'X': 7, 'Y': 8, 'Z': 9, //
    '0': 0, '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8,
    '9': 9,
  };

  /// Positional weights (positions 1..17). Position 9 (the check digit) is 0.
  static const List<int> _weights = [
    8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2, //
  ];

  /// Model-year code (position 10) → the base year of the 30-year cycle it
  /// opens. The concrete year is chosen by the position-7 rule in [decode].
  static const Map<String, int> _yearBase = {
    'A': 1980, 'B': 1981, 'C': 1982, 'D': 1983, 'E': 1984, 'F': 1985, //
    'G': 1986, 'H': 1987, 'J': 1988, 'K': 1989, 'L': 1990, 'M': 1991, //
    'N': 1992, 'P': 1993, 'R': 1994, 'S': 1995, 'T': 1996, 'V': 1997, //
    'W': 1998, 'X': 1999, 'Y': 2000, //
    '1': 2001, '2': 2002, '3': 2003, '4': 2004, '5': 2005, '6': 2006, //
    '7': 2007, '8': 2008, '9': 2009,
  };

  /// A bundled (non-exhaustive) WMI → manufacturer table for common makes; an
  /// unknown WMI falls back to free text. Keyed by the 3-char WMI.
  static const Map<String, String> _wmi = {
    '1G1': 'Chevrolet',
    '1G6': 'Cadillac',
    '1GC': 'Chevrolet',
    '1FA': 'Ford',
    '1FT': 'Ford',
    '1FM': 'Ford',
    '1HG': 'Honda',
    '19U': 'Acura',
    '1N4': 'Nissan',
    '1C3': 'Chrysler',
    '1C4': 'Chrysler',
    '2HG': 'Honda',
    '2T1': 'Toyota',
    '3FA': 'Ford',
    '3VW': 'Volkswagen',
    '4T1': 'Toyota',
    '4S3': 'Subaru',
    '5YJ': 'Tesla',
    '5TD': 'Toyota',
    '5NP': 'Hyundai',
    '5FN': 'Honda',
    'JHM': 'Honda',
    'JH4': 'Acura',
    'JN1': 'Nissan',
    'JN8': 'Nissan',
    'JTD': 'Toyota',
    'JT2': 'Toyota',
    'JT3': 'Toyota',
    'JF1': 'Subaru',
    'JM1': 'Mazda',
    'JMZ': 'Mazda',
    'JS1': 'Suzuki',
    'KMH': 'Hyundai',
    'KNA': 'Kia',
    'KND': 'Kia',
    'KL1': 'Daewoo/GM',
    'LFV': 'FAW-Volkswagen',
    'LSV': 'SAIC-Volkswagen',
    'SAL': 'Land Rover',
    'SAJ': 'Jaguar',
    'SCC': 'Lotus',
    'SCB': 'Bentley',
    'SB1': 'Toyota (UK)',
    'SFD': 'Alexander Dennis',
    'VF1': 'Renault',
    'VF3': 'Peugeot',
    'VF7': 'Citroën',
    'VF6': 'Renault',
    'VSS': 'SEAT',
    'VNK': 'Toyota (Turkey)',
    'WVW': 'Volkswagen',
    'WV1': 'Volkswagen',
    'WV2': 'Volkswagen',
    'WBA': 'BMW',
    'WBS': 'BMW M',
    'WBY': 'BMW i',
    'WDB': 'Mercedes-Benz',
    'WDD': 'Mercedes-Benz',
    'WDC': 'Mercedes-Benz',
    'WAU': 'Audi',
    'WA1': 'Audi',
    'WP0': 'Porsche',
    'WP1': 'Porsche',
    'WF0': 'Ford (Europe)',
    'WMW': 'MINI',
    'W0L': 'Opel',
    'W0V': 'Opel',
    'YV1': 'Volvo',
    'YV4': 'Volvo',
    'YS3': 'Saab',
    'YTN': 'Saab',
    'ZFA': 'Fiat',
    'ZFF': 'Ferrari',
    'ZAR': 'Alfa Romeo',
    'ZHW': 'Lamborghini',
    'ZAM': 'Maserati',
    'ZDM': 'Ducati',
    'TMB': 'Škoda',
    'TRU': 'Audi (Hungary)',
    'MAJ': 'Ford (India)',
    'MAT': 'Tata',
    'MBH': 'Maruti Suzuki',
    'MA1': 'Mahindra',
    'MHF': 'Toyota (Indonesia)',
    'NM0': 'Ford (Turkey)',
    'NMT': 'Toyota (Turkey)',
    '6H8': 'Holden',
    '6F4': 'Nissan (Australia)',
  };

  /// Decode [raw]. When the result is not well-formed the positional fields are
  /// still returned best-effort empty, and the check digit is reported invalid.
  VinDecodeResult decode(String raw) {
    final vin = raw.trim().toUpperCase();
    final wellFormed = _isWellFormed(vin);
    if (!wellFormed) {
      return VinDecodeResult(
        vin: vin,
        wellFormed: false,
        checkDigitValid: false,
        wmi: vin.length >= 3 ? vin.substring(0, 3) : '',
        manufacturer: null,
        region: vin.isEmpty ? VinRegion.unknown : _regionOf(vin[0]),
        modelYear: null,
        smallManufacturer: false,
      );
    }

    final wmi = vin.substring(0, 3);
    return VinDecodeResult(
      vin: vin,
      wellFormed: true,
      checkDigitValid: _checkDigitOf(vin) == vin[8],
      wmi: wmi,
      manufacturer: _wmi[wmi],
      region: _regionOf(vin[0]),
      modelYear: _modelYearOf(vin),
      smallManufacturer: wmi[2] == '9',
    );
  }

  /// The lone check-digit computation, exposed for validation and testing.
  /// Returns the expected position-9 character ('0'–'9' or 'X'); '' when the
  /// input is not well-formed.
  String checkDigit(String raw) {
    final vin = raw.trim().toUpperCase();
    return _isWellFormed(vin) ? _checkDigitOf(vin) : '';
  }

  bool _isWellFormed(String vin) =>
      vin.length == 17 && vin.split('').every(_allowed.contains);

  String _checkDigitOf(String vin) {
    var sum = 0;
    for (var i = 0; i < 17; i++) {
      sum += _translit[vin[i]]! * _weights[i];
    }
    final rem = sum % 11;
    return rem == 10 ? 'X' : '$rem';
  }

  int? _modelYearOf(String vin) {
    final base = _yearBase[vin[9]];
    if (base == null) return null;
    // Position 7 numeric → 1980–2009 cycle; alphabetic → 2010–2039.
    final isSecondCycle = _isAlpha(vin[6]);
    return isSecondCycle ? base + 30 : base;
  }

  bool _isAlpha(String c) {
    final u = c.codeUnitAt(0);
    return u >= 0x41 && u <= 0x5A; // A–Z
  }

  VinRegion _regionOf(String first) {
    if (_between(first, 'A', 'H')) return VinRegion.africa;
    if (_between(first, 'J', 'R')) return VinRegion.asia;
    if (_between(first, 'S', 'Z')) return VinRegion.europe;
    if (_between(first, '1', '5')) return VinRegion.northAmerica;
    if (_between(first, '6', '7')) return VinRegion.oceania;
    if (_between(first, '8', '9') || first == '0') {
      return VinRegion.southAmerica;
    }
    return VinRegion.unknown;
  }

  bool _between(String c, String lo, String hi) =>
      c.compareTo(lo) >= 0 && c.compareTo(hi) <= 0;
}
