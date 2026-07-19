#!/usr/bin/env bash
# Commitment 3: the aggregate halo is capped at saffron (u2); only the one aching
# card may reach u4. Flags AmbientHalo / halo-urgency usages that DON'T clamp, and
# any u3/u4 (temp[3]/temp[4]) fed into a halo.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

SCAN_DIRS=(packages/design_system/lib apps/car_and_pain/lib)
EXISTING=()
for d in "${SCAN_DIRS[@]}"; do [[ -d "$d" ]] && EXISTING+=("$d"); done
if [[ ${#EXISTING[@]} -eq 0 ]]; then
  echo "note: no PULSE source dirs yet; nothing to scan."
  exit 0
fi

fail=0

echo "== AmbientHalo constructions missing a cap (clamp(0,2) / haloClamped / haloMaxUrgency) =="
# Lines that build an AmbientHalo(urgency: ...) but show no cap on that same line.
# Case-SENSITIVE exclusion so the PulseTokens.halo() helper is allowed but the
# AmbientHalo( constructor itself is not treated as its own cap.
halo_hits="$(grep -rnE 'AmbientHalo\s*\(' --include='*.dart' "${EXISTING[@]}" 2>/dev/null \
             | grep -vE 'clamp\(\s*0\s*,\s*2\s*\)|haloClamped|haloMaxUrgency|\.halo\(' || true)"
if [[ -n "$halo_hits" ]]; then
  echo "$halo_hits"
  echo "-> AmbientHalo urgency must be capped at 2 (use .haloClamped or .clamp(0, 2))."
  fail=1
fi

echo "== u3 / u4 (ember / pomegranate) used in a halo context =="
hot_hits="$(grep -rnE 'temp\[\s*(3|4)\s*\]|Urgency\.(pressing|overdue)' --include='*.dart' "${EXISTING[@]}" 2>/dev/null \
            | grep -iE 'halo' || true)"
if [[ -n "$hot_hits" ]]; then
  echo "$hot_hits"
  echo "-> ember/pomegranate must never reach the ambient halo (field never goes hot)."
  fail=1
fi

if [[ $fail -eq 0 ]]; then
  echo "OK: halo cap respected (no unclamped halo, no hot stop in a halo)."
fi
exit $fail
