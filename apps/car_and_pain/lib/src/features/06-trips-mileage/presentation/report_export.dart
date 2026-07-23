import 'dart:convert';

import 'package:core/core.dart';

/// M7-T10 · pure, locale-neutral serialization of a [MileageReport] to CSV and
/// JSON — hand-written (built-in-first, no CSV dependency; JSON via dart:convert).
/// All values are canonical (SI metres, integer minor units, ASCII), so a file
/// diffs cleanly and re-imports losslessly regardless of display locale.

/// Deterministic CSV: a header, one row per (tax-year, rate) line, then a TOTAL
/// row. Fields are RFC-4180-quoted when needed.
String mileageReportToCsv(MileageReport report) {
  final buffer = StringBuffer()
    ..writeln('tax_year,rate_thousandths_per_unit,distance_metres,'
        'deduction_minor,currency');
  for (final line in report.lines) {
    buffer.writeln([
      line.taxYearLabel,
      line.rateThousandthsPerUnit,
      line.distanceMetres,
      line.deductionMinor,
      report.currencyCode,
    ].map(_csvField).join(','));
  }
  // Totals row (rate column blank; distance is business-deductible distance).
  buffer.writeln([
    'TOTAL',
    '',
    report.rollup.businessDistanceMetres,
    report.deductionMinor,
    report.currencyCode,
  ].map(_csvField).join(','));
  return buffer.toString();
}

/// Combined JSON covering the whole report with its compliance state.
String mileageReportToJson(MileageReport report) {
  return const JsonEncoder.withIndent('  ').convert({
    'format': 'mileage_report',
    'version': 1,
    'currency': report.currencyCode,
    'compliant': report.isCompliant,
    'non_contemporaneous_count': report.nonContemporaneousCount,
    'total_distance_metres': report.rollup.totalDistanceMetres,
    'business_distance_metres': report.rollup.businessDistanceMetres,
    'business_use_basis_points': report.rollup.businessUseBasisPoints,
    'base_deduction_minor': report.baseDeductionMinor,
    'passenger_deduction_minor': report.passengerDeductionMinor,
    'deduction_minor': report.deductionMinor,
    'lines': [
      for (final line in report.lines)
        {
          'tax_year': line.taxYearLabel,
          'rate_thousandths_per_unit': line.rateThousandthsPerUnit,
          'distance_metres': line.distanceMetres,
          'deduction_minor': line.deductionMinor,
        },
    ],
  });
}

String _csvField(Object? value) {
  final s = '$value';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}
