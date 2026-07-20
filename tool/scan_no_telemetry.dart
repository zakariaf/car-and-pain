// Blocking CI gate: fail the build if any analytics / crash / telemetry SDK
// appears in the resolved dependency tree. Car and Pain ships NO telemetry —
// this is enforced, not promised.
//
// Usage: `dart run tool/scan_no_telemetry.dart` (from the repo root).
// Exit code 0 = clean, 1 = a banned package was found.

import 'dart:io';

/// Package-name fragments that must never appear in pubspec.lock. Matched as
/// substrings of the resolved package name (case-insensitive).
const _banned = <String>[
  'firebase',
  'crashlytics',
  'sentry',
  'datadog',
  'bugsnag',
  'instabug',
  'appcenter',
  'mixpanel',
  'amplitude',
  'segment',
  'google_analytics',
  'analytics', // catch-all: any *analytics* package
  'facebook',
  'appsflyer',
  'adjust_sdk',
  'flurry',
  'countly',
  'posthog',
];

void main() {
  final lock = File('pubspec.lock');
  if (!lock.existsSync()) {
    stderr.writeln('no-telemetry scan: pubspec.lock not found (run pub get).');
    exit(1);
  }

  // Package entries are the 2-space-indented keys under `packages:`.
  final nameLine = RegExp(r'^  ([a-z0-9_]+):\s*$');
  final offenders = <String>[];

  for (final line in lock.readAsLinesSync()) {
    final match = nameLine.firstMatch(line);
    if (match == null) continue;
    final name = match.group(1)!.toLowerCase();
    for (final bad in _banned) {
      if (name.contains(bad)) {
        offenders.add('$name (matched "$bad")');
        break;
      }
    }
  }

  if (offenders.isEmpty) {
    stdout.writeln('no-telemetry scan: OK — no analytics/crash SDK found.');
    exit(0);
  }

  stderr.writeln('no-telemetry scan: FAILED — banned package(s) present:');
  for (final o in offenders) {
    stderr.writeln('  - $o');
  }
  stderr.writeln('Car and Pain ships no telemetry. Remove the dependency.');
  exit(1);
}
