import 'app_locations.dart';

/// Map a notification's opaque payload to a **safe** router location (M1-T6).
///
/// The payload arrives from the OS across a reboot/Doze boundary and must be
/// treated as untrusted: a tapped notification may only land the user on a
/// Room root or a content detail inside the Garage — never a gate flow
/// (`/lock`, `/splash`, `/onboarding`, `/startup-error`), a destructive flow
/// (`/trash`), or Settings. Anything unrecognised returns `null` (open the app
/// normally, no deep link). Pure and total, so it is exhaustively table-tested.
String? mapNotificationPayload(String? payload) {
  final p = payload?.trim();
  if (p == null || p.isEmpty) return null;
  // Our ids are plain path segments — a query, fragment, or percent-escape is
  // never legitimate here, so reject them outright rather than forwarding.
  if (p.contains('?') || p.contains('#') || p.contains('%')) return null;

  // A single Room root is always safe.
  const rooms = {
    AppLocations.cockpit,
    AppLocations.garage,
    AppLocations.pitlane
  };
  if (rooms.contains(p)) return p;

  // Content details live under the Garage Room: `/garage/<id>` and
  // `/garage/<id>/reminders/<id>`. Validate the shape rather than trusting it.
  final segments = p.split('/');
  // Must be an absolute path (leading '/' → empty segments[0]); no other
  // segment may be empty (rejects '/garage/' and trailing-slash forms).
  if (segments.length < 3 || segments[0].isNotEmpty) return null;
  if (segments[1] != 'garage') return null;
  if (segments.skip(1).any((s) => s.isEmpty)) return null;

  return switch (segments.length) {
    3 => p, // /garage/<vehicleId>
    5 when segments[3] == 'reminders' =>
      p, // /garage/<vehicleId>/reminders/<id>
    _ => null,
  };
}
