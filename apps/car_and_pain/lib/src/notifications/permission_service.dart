import 'package:permission_handler/permission_handler.dart';

/// A permission outcome, collapsed to the three states the UI reacts to.
enum PermissionState { granted, denied, permanentlyDenied }

PermissionState _map(PermissionStatus s) {
  if (s.isGranted || s.isLimited || s.isProvisional) {
    return PermissionState.granted;
  }
  if (s.isPermanentlyDenied) return PermissionState.permanentlyDenied;
  return PermissionState.denied;
}

/// The shared permission surface (F5-T6), used by both onboarding and the first
/// reminder-creation flow. Each request is preceded by a localized rationale
/// (shown by the caller) and is non-blocking, re-entrant, and degrades
/// gracefully — a denial never crashes the engine, it just fires inexactly / not
/// at all. Real OS prompts are device-only to verify.
final class PermissionService {
  const PermissionService();

  Future<PermissionState> notificationStatus() async =>
      _map(await Permission.notification.status);

  Future<PermissionState> requestNotification() async =>
      _map(await Permission.notification.request());

  Future<PermissionState> exactAlarmStatus() async =>
      _map(await Permission.scheduleExactAlarm.status);

  Future<PermissionState> requestExactAlarm() async =>
      _map(await Permission.scheduleExactAlarm.request());

  /// Ask the OS to exempt the app from Doze/battery optimization so alarms fire
  /// reliably. Returns whether it's now exempt.
  Future<bool> requestIgnoreBatteryOptimizations() async =>
      (await Permission.ignoreBatteryOptimizations.request()).isGranted;

  /// Deep-link into system settings (for a permanently-denied permission).
  Future<bool> openSettings() => openAppSettings();
}
