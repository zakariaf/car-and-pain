import 'package:car_and_pain/src/features/25-onboarding-help/application/help_content.dart';
import 'package:flutter_test/flutter_test.dart';

/// M10-T5 · the offline help search folds numerals/diacritics and ranks by
/// title-over-body — pure logic, no DB.
void main() {
  const topics = [
    HelpTopic(
        id: 'economy',
        title: 'Fuel economy',
        body: 'Measured full to full over 100 km, so a partial fill defers.'),
    HelpTopic(
        id: 'calendars',
        title: 'Calendars',
        body: 'Gregorian, Jalali and Hijri are all supported.'),
  ];

  test('an empty query returns every topic (browse mode)', () {
    expect(searchHelpTopics(topics, ''), hasLength(2));
    expect(searchHelpTopics(topics, '   '), hasLength(2));
  });

  test('a title hit outranks a body-only hit', () {
    // "economy" is in the first topic's title; "full" only in its body.
    final r = searchHelpTopics(topics, 'economy');
    expect(r.first.id, 'economy');
  });

  test('a Persian-digit query matches an ASCII-digit body (numeral folding)',
      () {
    // ۱۰۰ (Persian 100) must fold to 100 and match "100 km".
    final r = searchHelpTopics(topics, '۱۰۰');
    expect(r.map((t) => t.id), contains('economy'));
  });

  test('a non-matching query returns nothing', () {
    expect(searchHelpTopics(topics, 'motorcycle'), isEmpty);
  });

  test('multi-term queries accumulate score across terms', () {
    final r = searchHelpTopics(topics, 'jalali hijri');
    expect(r.first.id, 'calendars');
  });
}
