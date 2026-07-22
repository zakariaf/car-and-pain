import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('csvField (RFC-4180 quoting)', () {
    test('plain values are unquoted', () {
      expect(csvField('Golf'), 'Golf');
      expect(csvField(42), '42');
      expect(csvField(null), '');
      expect(csvField(true), 'true');
    });

    test('a comma / newline forces quoting', () {
      expect(csvField('a,b'), '"a,b"');
      expect(csvField('line1\nline2'), '"line1\nline2"');
    });

    test('internal quotes are doubled', () {
      expect(csvField('say "hi"'), '"say ""hi"""');
    });
  });

  group('rowsToCsv', () {
    test('deterministic sorted columns + CRLF, header first', () {
      final csv = rowsToCsv([
        {'b': 2, 'a': 1},
        {'a': 3, 'b': 4},
      ]);
      expect(csv, 'a,b\r\n1,2\r\n3,4\r\n');
    });

    test('empty rows → empty string', () {
      expect(rowsToCsv(const []), '');
    });

    test('canonical values stay Western-ASCII; tricky fields survive', () {
      final csv = rowsToCsv([
        {'note': 'costs 1,234', 'money': -500, 'code': 'USD'},
      ]);
      // Money is the integer minor unit; the comma-bearing note is quoted.
      expect(csv, contains('"costs 1,234"'));
      expect(csv, contains('-500'));
    });
  });

  test('exportEntitiesToCsv emits one CSV per non-empty entity', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await VehiclesRepository(db).add(nickname: 'Golf');
    final doc = await CanonicalCodec(db).export();

    final csv = exportEntitiesToCsv(doc);
    expect(csv.keys, contains('vehicles'));
    expect(csv['vehicles'], contains('Golf'));
    // Empty entities are omitted.
    expect(csv.containsKey('fuel_entries'), isFalse);
  });
}
