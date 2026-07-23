import 'package:core/core.dart';
import 'package:test/test.dart';

/// M4-T5 — the timed appointment `.ics` export. A timed VEVENT (DTSTART/DTEND
/// with a datetime), CRLF-terminated, values escaped, no server.
void main() {
  test('builds a timed VEVENT with start, end, location and description', () {
    final ics = buildAppointmentIcs(
      [
        IcsAppointment(
          uid: 'appt-1@car-and-pain',
          summary: 'Oil change; brakes',
          start: Instant.fromDateTime(DateTime.utc(2026, 7, 15, 9, 30)),
          durationMinutes: 90,
          location: "Bob's Garage",
          description: 'Bring the key',
        ),
      ],
      dtstamp: Instant.fromDateTime(DateTime.utc(2026, 7)),
    );

    expect(ics, contains('BEGIN:VEVENT'));
    expect(ics, contains('UID:appt-1@car-and-pain'));
    expect(ics, contains('DTSTART:20260715T093000Z'));
    // 9:30 + 90 min = 11:00.
    expect(ics, contains('DTEND:20260715T110000Z'));
    // The `;` in the summary is escaped per RFC-5545.
    expect(ics, contains(r'SUMMARY:Oil change\; brakes'));
    expect(ics, contains("LOCATION:Bob's Garage"));
    expect(ics, contains('DESCRIPTION:Bring the key'));
    // CRLF line endings.
    expect(ics, contains('\r\n'));
    expect(ics.trimRight().endsWith('END:VCALENDAR'), isTrue);
  });

  test('omits optional lines when absent', () {
    final ics = buildAppointmentIcs(
      [
        IcsAppointment(
          uid: 'a',
          summary: 'Service',
          start: Instant.fromDateTime(DateTime.utc(2026, 7, 15, 9)),
        ),
      ],
      dtstamp: Instant.fromDateTime(DateTime.utc(2026, 7)),
    );
    expect(ics.contains('LOCATION:'), isFalse);
    expect(ics.contains('DESCRIPTION:'), isFalse);
    // Default 60-minute duration.
    expect(ics, contains('DTEND:20260715T100000Z'));
  });
}
