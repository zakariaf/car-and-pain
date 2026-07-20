import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Minimal **local-only** structured logger.
///
/// F1 routes to `dart:developer` (and `debugPrint` in debug) — on-device, no
/// network, no telemetry. NEVER a crash SaaS.
/// TODO: back this with a size-capped rotating `FileOutput` in the app-support
/// dir plus a user-initiated "Export diagnostics" affordance.
class AppLog {
  const AppLog();

  /// Log an error with its module tag, original error, and stack trace.
  void error(String module, Object error, StackTrace stack) {
    developer.log(
      error.toString(),
      name: 'car_and_pain.$module',
      error: error,
      stackTrace: stack,
      level: 1000, // SEVERE
    );
    if (kDebugMode) {
      debugPrint('[car_and_pain.$module] $error');
    }
  }
}
