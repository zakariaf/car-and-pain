#!/usr/bin/env bash
# Flag impurity in the pure scheduler/projector: wall-clock reads, plugin imports,
# or IO. All time must come from an injected Clock (package:clock).
set -euo pipefail

ROOT="${1:-packages/notifications/lib/src/scheduler}"
CORE="${2:-packages/core/lib/src}"

echo "== Checking purity of ReminderScheduler / UsageProjector =="

FILES=()
for p in \
  "$ROOT/reminder_scheduler.dart" \
  "$ROOT/usage_projector.dart" \
  "$CORE/usage_projector.dart"; do
  [ -f "$p" ] && FILES+=("$p")
done

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "OK: no pure-scheduler files present yet (nothing to check)."
  exit 0
fi

status=0
# Forbidden patterns -> reason
declare -a PATTERNS=(
  'DateTime\.now\(\)|clock is|Clock' # DateTime.now is banned; Clock is the injected alternative
)

check() {
  local pat="$1" reason="$2"
  for f in "${FILES[@]}"; do
    if grep -nE "$pat" "$f" >/dev/null 2>&1; then
      echo "VIOLATION [$reason] in $f:"
      grep -nE "$pat" "$f"
      status=1
    fi
  done
}

check 'DateTime\.now\(\)' 'use injected Clock.now(), never DateTime.now()'
check 'package:flutter_local_notifications' 'no plugin imports in pure math'
check "dart:io|package:drift|package:sqlite|rootBundle|File\(" 'no IO in pure math'

if [ "$status" -eq 0 ]; then
  echo "OK: scheduler/projector are pure (no DateTime.now, no plugin, no IO)."
fi
exit "$status"
