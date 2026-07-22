import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('ByteSize.format', () {
    test('bytes below 1 KiB stay whole bytes with no decimals', () {
      final f = const ByteSize(512).format();
      expect(f.unit, ByteSizeUnit.b);
      expect(f.mantissa, 512);
      expect(f.fractionDigits, 0);
    });

    test('exactly 1 KiB is 1.0 KB', () {
      final f = const ByteSize(1024).format();
      expect(f.unit, ByteSizeUnit.kb);
      expect(f.mantissa, 10); // 1.0 scaled by 10^1
      expect(f.fractionDigits, 1);
    });

    test('12,897,485 bytes → 12.3 MB', () {
      final f = const ByteSize(12897485).format();
      expect(f.unit, ByteSizeUnit.mb);
      expect(f.mantissa, 123);
      expect(f.fractionDigits, 1);
    });

    test('rounds to one decimal (1,610,613 → 1.5 MB)', () {
      final f = const ByteSize(1610613).format(); // 1.536 MiB
      expect(f.unit, ByteSizeUnit.mb);
      expect(f.mantissa, 15);
    });

    test('scales into GB and TB', () {
      expect(
          const ByteSize(3221225472).format().unit, ByteSizeUnit.gb); // 3 GiB
      expect(
        const ByteSize(2199023255552).format().unit,
        ByteSizeUnit.tb, // 2 TiB
      );
    });

    test('caps at TB for enormous sizes', () {
      final f = const ByteSize(5 * 1024 * 1024 * 1024 * 1024 * 1024).format();
      expect(f.unit, ByteSizeUnit.tb);
    });

    test('zero is 0 B', () {
      final f = const ByteSize(0).format();
      expect(f.unit, ByteSizeUnit.b);
      expect(f.mantissa, 0);
    });
  });

  test('sizes add and compare by canonical bytes', () {
    expect(const ByteSize(100) + const ByteSize(24), const ByteSize(124));
    expect(const ByteSize(1024).compareTo(const ByteSize(512)), greaterThan(0));
    final list = [const ByteSize(50), const ByteSize(10), const ByteSize(30)]
      ..sort();
    expect(list.first, const ByteSize(10));
  });
}
