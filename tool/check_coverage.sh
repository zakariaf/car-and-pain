#!/usr/bin/env bash
# Coverage gate: fail if line coverage in an lcov.info is below a threshold.
# Usage: check_coverage.sh <path/to/lcov.info> <min-percent>
# 100% is enforced only on the logic packages; elsewhere it ratchets up.
set -euo pipefail

FILE="${1:?usage: check_coverage.sh <lcov.info> <min-percent>}"
MIN="${2:?usage: check_coverage.sh <lcov.info> <min-percent>}"

if [[ ! -f "$FILE" ]]; then
  echo "FAIL: coverage file $FILE not found (run: flutter test --coverage)."
  exit 1
fi

lf="$(awk -F: '/^LF:/ {s+=$2} END {print s+0}' "$FILE")"
lh="$(awk -F: '/^LH:/ {s+=$2} END {print s+0}' "$FILE")"

if [[ "$lf" -eq 0 ]]; then
  echo "FAIL: no lines found in $FILE."
  exit 1
fi

pct=$(( 100 * lh / lf ))
echo "coverage($FILE): ${lh}/${lf} lines = ${pct}% (min ${MIN}%)"

if [[ "$pct" -lt "$MIN" ]]; then
  echo "FAIL: coverage ${pct}% is below the ${MIN}% gate."
  exit 1
fi

echo "OK: coverage gate passed."
