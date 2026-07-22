import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCsv (RFC-4180)', () {
    test('splits simple rows, tolerant of CRLF and a trailing newline', () {
      expect(parseCsv('a,b\r\n1,2\r\n'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
      expect(parseCsv('a,b\n1,2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('quoted fields carry commas, newlines and doubled quotes', () {
      final rows = parseCsv('name,note\r\n"Golf","a, b\nc ""x"""\r\n');
      expect(rows[1][0], 'Golf');
      expect(rows[1][1], 'a, b\nc "x"');
    });

    test('parseCsvToMaps keys by header and pads short rows', () {
      final maps = parseCsvToMaps('a,b,c\r\n1,2\r\n');
      expect(maps.single, {'a': '1', 'b': '2', 'c': ''});
    });
  });

  group('competitor presets + coercions', () {
    test('unit/currency/date coercions produce canonical values', () {
      expect(milesToMetres('100'), 160934); // 100 mi
      expect(gallonsToMillilitres('10'), 37854); // 10 US gal
      expect(dollarsToMinorUnits(r'$41.20'), 4120); // strips symbol
      expect(isoDateToEpochMillis('2026-01-01'),
          DateTime.utc(2026).millisecondsSinceEpoch);
    });

    test('the Fuelly preset maps a foreign row into canonical fields', () {
      final rows = parseCsvToMaps(
        'Date,Odometer,Fill Amount,Total Cost,Notes\r\n'
        '2026-03-15,"12,000",11.5,"\$48.30","topped, off"\r\n',
      );
      final mapped = fuellyFuelPreset.mapRow(rows.single);
      expect(mapped['filledAtUtcMillis'],
          DateTime.utc(2026, 3, 15).millisecondsSinceEpoch);
      expect(mapped['odometerMetres'], milesToMetres('12000'));
      expect(mapped['volumeMillilitres'], gallonsToMillilitres('11.5'));
      expect(mapped['totalCostMinorUnits'], 4830);
      expect(mapped['note'], 'topped, off');
    });

    test('a malformed cell is dropped, not fatal to the row', () {
      final mapped = fuellyFuelPreset.mapRow({
        'Date': '2026-01-01',
        'Odometer': 'not-a-number',
      });
      expect(mapped.containsKey('filledAtUtcMillis'), isTrue);
      expect(mapped.containsKey('odometerMetres'), isFalse); // skipped
    });
  });
}
