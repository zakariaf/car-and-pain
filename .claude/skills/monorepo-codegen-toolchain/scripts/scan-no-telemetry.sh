#!/usr/bin/env bash
# Gate 1 stand-in: fail if any analytics/crash/telemetry SDK is in pubspec.lock.
# The canonical CI gate is `dart run tool/scan_no_telemetry.dart`; this grep
# mirror is for a fast local check. Car and Pain is offline + no-telemetry.
set -uo pipefail

find_root() {
  local d="$PWD"
  while [ "$d" != "/" ]; do
    [ -f "$d/pubspec.lock" ] && { echo "$d"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}

ROOT="$(find_root)" || { echo "ERROR: pubspec.lock not found" >&2; exit 2; }
LOCK="$ROOT/pubspec.lock"
echo "==> scanning: $LOCK"

# Banned package name fragments (dependency names in the lockfile).
BANNED='firebase_analytics|firebase_crashlytics|crashlytics|sentry|sentry_flutter|mixpanel|amplitude|datadog|posthog|segment|appsflyer|adjust|bugsnag|instabug|google_analytics|firebase_performance|firebase_messaging|onesignal|flurry|countly'

HITS="$(grep -nE "^[[:space:]]{2}(${BANNED}):" "$LOCK" || true)"
if [ -n "$HITS" ]; then
  echo "   VIOLATION: telemetry/analytics/crash SDK found in lockfile:"
  echo "$HITS" | sed 's/^/     /'
  echo "==> FAILED: no-telemetry posture broken; remove the dependency" >&2
  exit 1
fi

echo "==> OK: no telemetry/analytics/crash SDK in the lockfile"
