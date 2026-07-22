// Hand-written, dependency-free CSV parser (F6-T5, built-in-first) for reading
// the app's own exports and foreign competitor files. RFC-4180: quoted fields
// may contain commas, CR/LF and doubled quotes; rows end on an unquoted newline.

/// Parse RFC-4180 CSV text into rows of raw string fields. Tolerant of both LF
/// and CRLF line endings and of a trailing newline.
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var inQuotes = false;
  var sawAny = false;

  var i = 0;
  while (i < input.length) {
    final c = input[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      field.write(c);
      i++;
      continue;
    }
    switch (c) {
      case '"':
        inQuotes = true;
        sawAny = true;
      case ',':
        row.add(field.toString());
        field = StringBuffer();
        sawAny = true;
      case '\r':
        break; // swallow; the \n handles the row break
      case '\n':
        row.add(field.toString());
        rows.add(row);
        row = <String>[];
        field = StringBuffer();
        sawAny = false;
      default:
        field.write(c);
        sawAny = true;
    }
    i++;
  }
  // Flush a final unterminated row.
  if (sawAny || field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

/// Parse CSV into header-keyed maps — the first row is the header. Short rows
/// pad with empty strings; extra columns are ignored.
List<Map<String, String>> parseCsvToMaps(String input) {
  final rows = parseCsv(input);
  if (rows.isEmpty) return const [];
  final header = rows.first;
  return [
    for (final r in rows.skip(1))
      {
        for (var i = 0; i < header.length; i++)
          header[i]: i < r.length ? r[i] : '',
      },
  ];
}
