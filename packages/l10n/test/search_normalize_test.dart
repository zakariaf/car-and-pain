import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

void main() {
  test('folds case + digits so mixed forms compare equal', () {
    expect(normalizeForSearch('GOLF 2'), normalizeForSearch('golf ٢'));
    expect(normalizeForSearch('Civic ۱۰'), normalizeForSearch('civic 10'));
  });

  test('normalizes Arabic/Persian orthographic variants', () {
    // Alef hamza / bare alef collapse.
    expect(normalizeForSearch('أحمد'), normalizeForSearch('احمد'));
    // Arabic yeh vs Persian yeh; Arabic kaf vs Persian keheh.
    expect(normalizeForSearch('كيا'), normalizeForSearch('کیا'));
  });

  test('drops tatweel and combining marks', () {
    expect(normalizeForSearch('سـيـارة'), normalizeForSearch('سياره'));
  });

  test('is total on empty / whitespace input', () {
    expect(normalizeForSearch('   '), '');
    expect(normalizeForSearch(''), '');
  });
}
