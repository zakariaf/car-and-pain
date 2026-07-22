/// The app's canonical route locations (M1-T1). Typed path builders keep detail
/// routes reconstructable from the URL alone — IDs travel in path params, never
/// `extra` (which is null after reboot/Doze/restore).
abstract final class AppLocations {
  // Shell Room roots (StatefulShellRoute branches, in logical order).
  static const cockpit = '/cockpit';
  static const garage = '/garage';
  static const pitlane = '/pitlane';

  // Full-screen gate flows (above the shell, on the root navigator).
  static const splash = '/splash';
  static const startupError = '/startup-error';
  static const lock = '/lock';
  static const onboarding = '/onboarding';

  /// A vehicle detail route inside the Garage Room.
  static String garageVehicle(String vehicleId) => '/garage/$vehicleId';

  /// A reminder detail route (the notification deep-link target).
  static String reminderDetail(String vehicleId, String reminderId) =>
      '/garage/$vehicleId/reminders/$reminderId';

  /// The add-vehicle form (full-screen flow above the shell).
  static const newVehicle = '/vehicle/new';

  /// The edit-vehicle form for [vehicleId] (full-screen flow above the shell).
  static String editVehicle(String vehicleId) => '/vehicle/$vehicleId/edit';

  /// The odometer ledger for [vehicleId] (full-screen flow above the shell).
  static String vehicleLedger(String vehicleId) => '/vehicle/$vehicleId/ledger';

  /// The gate locations the redirect owns — a fully-passed session sitting on one
  /// of these is sent home.
  static const gateLocations = <String>{
    splash,
    startupError,
    lock,
    onboarding,
  };
}
