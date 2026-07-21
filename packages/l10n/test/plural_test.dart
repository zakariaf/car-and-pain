import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

/// Validates that the ARB ICU plural categories actually resolve per locale
/// through gen-l10n (F4-T8) — the point of highest risk being Arabic's full
/// six-form CLDR set. Digits are normalized out so we compare *templates*, not
/// the substituted count.
Future<AppLocalizations> _load(String lang) =>
    AppLocalizations.delegate.load(Locale(lang));

String _norm(String s) =>
    s.replaceAll(RegExp('[0-9٠-٩۰-۹]'), '#');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('English: =0 / one / other are distinct', () async {
    final l = await _load('en');
    expect(l.trashExpiresIn(0), 'Auto-deletes today');
    expect(l.trashExpiresIn(1), contains('1 day'));
    expect(l.trashExpiresIn(1), isNot(contains('days')));
    expect(l.trashExpiresIn(2), contains('days'));
  });

  test('Arabic resolves all SIX CLDR plural forms distinctly', () async {
    final l = await _load('ar');
    // zero/one/two/few/many/other must each pick a different template.
    final templates = [0, 1, 2, 3, 11, 100]
        .map((n) => _norm(l.trashExpiresIn(n)))
        .toSet();
    expect(templates, hasLength(6), reason: 'six Arabic forms: $templates');
    // Spot-check the fixed (placeholder-free) forms by their distinctive word.
    expect(l.trashExpiresIn(0), contains('اليوم')); // zero: "today"
    expect(l.trashExpiresIn(1), contains('واحد')); // one: "one"
    expect(l.trashExpiresIn(2), contains('يومين')); // two: dual
  });

  test('Persian: explicit =0 differs from the counted forms', () async {
    final l = await _load('fa');
    expect(l.trashExpiresIn(0), contains('امروز')); // "today"
    expect(_norm(l.trashExpiresIn(0)), isNot(_norm(l.trashExpiresIn(5))));
    expect(l.trashExpiresIn(5), isNotEmpty);
  });

  test('Sorani Kurdish: one / other resolve', () async {
    final l = await _load('ckb');
    expect(l.trashExpiresIn(1), contains('ڕۆژ'));
    expect(l.trashExpiresIn(5), contains('ڕۆژ'));
  });

  test('German and French resolve across boundary counts', () async {
    for (final lang in ['de', 'fr']) {
      final l = await _load(lang);
      for (final n in [0, 1, 2, 5, 100]) {
        expect(l.trashExpiresIn(n), isNotEmpty, reason: '$lang @ $n');
      }
    }
  });
}
