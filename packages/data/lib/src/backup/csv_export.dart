// Hand-written, dependency-free CSV export (F6-T3, built-in-first — no CSV
// package). Values are the canonical row maps from `CanonicalCodec.export`
// (SI base units, integer minor-unit money, UTC epoch millis, Western-ASCII
// numerals) so files diff cleanly and re-import losslessly; display formatting
// never enters the file.

/// Quote/escape one field per RFC-4180: a field containing a comma, quote, CR
/// or LF is wrapped in double-quotes with internal quotes doubled. A null → "".
String csvField(Object? value) {
  final s = value == null ? '' : value.toString();
  if (s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Render rows to an RFC-4180 CSV string with a DETERMINISTIC column order (the
/// sorted union of all row keys) and CRLF line endings, so a spreadsheet round-
/// trips it without corruption. An empty row list yields an empty string.
String rowsToCsv(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) return '';
  final columns = <String>{for (final r in rows) ...r.keys}.toList()..sort();
  final buffer = StringBuffer()
    ..write(columns.map(csvField).join(','))
    ..write('\r\n');
  for (final row in rows) {
    buffer
      ..write(columns.map((c) => csvField(row[c])).join(','))
      ..write('\r\n');
  }
  return buffer.toString();
}

/// Per-entity CSV from a canonical codec document: `{entity: csvString}`. Empty
/// entities are omitted.
Map<String, String> exportEntitiesToCsv(Map<String, dynamic> doc) {
  final entities = (doc['entities'] as Map).cast<String, dynamic>();
  final out = <String, String>{};
  for (final e in entities.entries) {
    final rows = [
      for (final r in (e.value as List)) (r as Map).cast<String, Object?>(),
    ];
    if (rows.isEmpty) continue;
    out[e.key] = rowsToCsv(rows);
  }
  return out;
}
