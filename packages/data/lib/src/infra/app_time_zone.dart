/// The resolved local IANA timezone, injected through `appTimeZoneProvider`.
///
/// Notifications resolve wall-clock schedules to a zoned time using this. For
/// F1 the bootstrap sets a placeholder (`UTC`).
/// TODO(F5): query the device zone via `flutter_timezone` and initialize the
/// `timezone` database.
final class AppTimeZone {
  const AppTimeZone(this.ianaName);

  /// e.g. `Asia/Tehran`, `Europe/Berlin`, or `UTC`.
  final String ianaName;

  @override
  String toString() => 'AppTimeZone($ianaName)';
}
