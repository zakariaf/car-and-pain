import 'package:core/core.dart';
import 'package:test/test.dart';

Instant _utc(int y, int mo, int d) =>
    Instant.fromEpochMillis(DateTime.utc(y, mo, d).millisecondsSinceEpoch);

void main() {
  test('builds a CRLF VCALENDAR of all-day events (F5-T7)', () {
    final ics = buildIcsCalendar(
      [
        IcsEvent(uid: 'r1', summary: 'Oil change', date: _utc(2026, 6, 1)),
        IcsEvent(uid: 'r2', summary: 'Inspection', date: _utc(2026, 7, 15)),
      ],
      dtstamp: _utc(2026, 1, 1),
    );

    expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(ics, endsWith('END:VCALENDAR\r\n'));
    expect(ics, contains('DTSTART;VALUE=DATE:20260601'));
    expect(ics, contains('DTSTART;VALUE=DATE:20260715'));
    expect(ics, contains('SUMMARY:Oil change'));
    expect(ics, contains('DTSTAMP:20260101T000000Z'));
    expect('BEGIN:VEVENT'.allMatches(ics).length, 2);
  });

  test('escapes special characters in the summary', () {
    final ics = buildIcsCalendar(
      [
        IcsEvent(
            uid: 'x', summary: 'Tyres; front, rear', date: _utc(2026, 6, 1))
      ],
      dtstamp: _utc(2026, 1, 1),
    );
    expect(ics, contains(r'SUMMARY:Tyres\; front\, rear'));
  });
}
