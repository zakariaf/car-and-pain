import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

String _cp(int c) => String.fromCharCode(c);

void main() {
  const vin = 'WVWZZZ1KZAW000001';

  group('bidi isolation (F4-T5)', () {
    test('ltrIsolate wraps with LRI … PDI, content intact', () {
      final wrapped = ltrIsolate(vin);
      expect(wrapped.codeUnitAt(0), 0x2066); // LRI
      expect(wrapped.codeUnitAt(wrapped.length - 1), 0x2069); // PDI
      expect(wrapped.substring(1, wrapped.length - 1), vin);
    });

    test('rtlIsolate and first-strong isolate use the right controls', () {
      expect(rtlIsolate('x').codeUnitAt(0), 0x2067); // RLI
      expect(isolate('x').codeUnitAt(0), 0x2068); // FSI
    });

    test('stripBidi round-trips an isolate and removes every control', () {
      expect(stripBidi(ltrIsolate(vin)), vin);
      // RLM + embedding + pop + LRM around visible text — all removed.
      final noisy =
          '${_cp(0x200F)}ABC${_cp(0x202B)}12${_cp(0x202C)}${_cp(0x200E)}';
      expect(stripBidi(noisy), 'ABC12');
    });
  });
}
