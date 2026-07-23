import '../time/temporal.dart';

/// One all-day calendar event for the read-only `.ics` export (F5-T7).
final class IcsEvent {
  const IcsEvent({
    required this.uid,
    required this.summary,
    required this.date,
  });

  final String uid;
  final String summary;

  /// The due instant; exported as an all-day event on its UTC date.
  final Instant date;
}

/// Build an RFC-5545 VCALENDAR of all-day events (F5-T7). A read-only
/// convenience for sharing due dates — it never touches the on-device engine.
/// Lines are CRLF-terminated and text values are escaped per the spec.
String buildIcsCalendar(List<IcsEvent> events, {required Instant dtstamp}) {
  final buf = StringBuffer();
  void line(String s) => buf.write('$s\r\n');

  line('BEGIN:VCALENDAR');
  line('VERSION:2.0');
  line('PRODID:-//Car and Pain//Reminders//EN');
  line('CALSCALE:GREGORIAN');
  final stamp = _dateTime(dtstamp);
  for (final e in events) {
    line('BEGIN:VEVENT');
    line('UID:${e.uid}');
    line('DTSTAMP:$stamp');
    line('DTSTART;VALUE=DATE:${_date(e.date)}');
    line('SUMMARY:${_escape(e.summary)}');
    line('END:VEVENT');
  }
  line('END:VCALENDAR');
  return buf.toString();
}

/// A **timed** calendar event — a service appointment (M4-T5). Unlike [IcsEvent]
/// (all-day), it carries a start instant + duration and an optional location, and
/// is exported as a timed VEVENT in UTC. The device calendar renders it in the
/// user's locale/calendar and first-day-of-week; the instant itself is absolute.
final class IcsAppointment {
  const IcsAppointment({
    required this.uid,
    required this.summary,
    required this.start,
    this.durationMinutes = 60,
    this.location,
    this.description,
  }) : assert(durationMinutes > 0, 'duration must be positive');

  final String uid;
  final String summary;
  final Instant start;
  final int durationMinutes;
  final String? location;
  final String? description;

  Instant get end =>
      Instant.fromEpochMillis(start.epochMillis + durationMinutes * 60000);
}

/// Build an RFC-5545 VCALENDAR of **timed** appointment VEVENTs (M4-T5). A local,
/// read-only file for handing a booked service to the device calendar — no server.
String buildAppointmentIcs(
  List<IcsAppointment> appointments, {
  required Instant dtstamp,
}) {
  final buf = StringBuffer();
  void line(String s) => buf.write('$s\r\n');

  line('BEGIN:VCALENDAR');
  line('VERSION:2.0');
  line('PRODID:-//Car and Pain//Appointments//EN');
  line('CALSCALE:GREGORIAN');
  final stamp = _dateTime(dtstamp);
  for (final a in appointments) {
    line('BEGIN:VEVENT');
    line('UID:${a.uid}');
    line('DTSTAMP:$stamp');
    line('DTSTART:${_dateTime(a.start)}');
    line('DTEND:${_dateTime(a.end)}');
    line('SUMMARY:${_escape(a.summary)}');
    if (a.location != null) line('LOCATION:${_escape(a.location!)}');
    if (a.description != null) line('DESCRIPTION:${_escape(a.description!)}');
    line('END:VEVENT');
  }
  line('END:VCALENDAR');
  return buf.toString();
}

String _date(Instant i) {
  final d = i.utc;
  return '${_pad(d.year, 4)}${_pad(d.month, 2)}${_pad(d.day, 2)}';
}

String _dateTime(Instant i) {
  final d = i.utc;
  return '${_date(i)}T${_pad(d.hour, 2)}${_pad(d.minute, 2)}${_pad(d.second, 2)}Z';
}

String _pad(int n, int width) => n.toString().padLeft(width, '0');

String _escape(String s) => s
    .replaceAll(r'\', r'\\')
    .replaceAll(',', r'\,')
    .replaceAll(';', r'\;')
    .replaceAll('\n', r'\n');
