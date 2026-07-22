import 'package:core/core.dart';
import 'package:test/test.dart';

PriceObservation _o(int ms, int price, [String? station]) => PriceObservation(
      at: Instant.fromEpochMillis(ms),
      priceThousandths: price,
      station: station,
    );

void main() {
  test('latestByStation keeps the newest price per station', () {
    final m = PriceMemory([
      _o(1000, 1699, 'Aral'),
      _o(3000, 1759, 'Aral'), // newer Aral wins
      _o(2000, 1650, 'Shell'),
    ]);
    expect(m.latestByStation(), {'Aral': 1759, 'Shell': 1650});
  });

  test('latestOverall is the single most recent price', () {
    final m = PriceMemory([
      _o(1000, 1699, 'Aral'),
      _o(3000, 1759, 'Shell'),
      _o(2000, 1650, 'Esso'),
    ]);
    expect(m.latestOverall(), 1759);
  });

  test('latestFor prefers the station, falls back to overall', () {
    final m = PriceMemory([
      _o(1000, 1699, 'Aral'),
      _o(3000, 1759, 'Shell'),
    ]);
    expect(m.latestFor('Aral'), 1699); // station-specific
    expect(m.latestFor('Unknown'), 1759); // falls back to overall latest
    expect(m.latestFor(null), 1759);
  });

  test('empty history yields nothing', () {
    const m = PriceMemory([]);
    expect(m.latestByStation(), isEmpty);
    expect(m.latestOverall(), isNull);
    expect(m.latestFor('Aral'), isNull);
  });
}
