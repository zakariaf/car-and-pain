#!/usr/bin/env bash
# Grep-based violation scan for the canonical-units-money invariants.
# Prints every offending file:line to stdout and exits non-zero on any hit,
# so it can double as a local pre-commit / CI gate. Read-only; changes nothing.
set -uo pipefail

# --- locate the repo root (dir with the root pubspec.yaml that has `workspace:`)
find_root() {
  local d="$PWD"
  while [ "$d" != "/" ]; do
    if [ -f "$d/pubspec.yaml" ] && grep -q '^workspace:' "$d/pubspec.yaml"; then
      echo "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  echo "$PWD" # fall back to CWD so the script still runs standalone
}
ROOT="$(find_root)"
cd "$ROOT"
echo "==> scanning canonical-units-money violations under: $ROOT"

fail=0
DART_FILES=$(find apps packages -name '*.dart' 2>/dev/null \
  | grep -v -E '\.(g|freezed|drift)\.dart$' || true)
[ -z "$DART_FILES" ] && { echo "   (no dart files found)"; exit 0; }

report() { # $1 = human label, remaining = grep hits on stdin
  local label="$1"; shift
  local hits
  hits="$(cat)"
  if [ -n "$hits" ]; then
    echo ""
    echo "VIOLATION: $label"
    echo "$hits" | sed 's/^/   /'
    fail=1
  fi
}

# 1) double / num typed money fields (double amount, num price, final double total…)
echo "$DART_FILES" | xargs grep -nE \
  '(double|num)[[:space:]]+[a-zA-Z_]*(amount|price|cost|money|total|balance|premium)' \
  2>/dev/null | report "double/num-typed money field (money must be int minor units)"

# 2) hardcoded *100 / /100 scaling next to a money word
echo "$DART_FILES" | xargs grep -nE \
  '(amount|price|cost|money|total|minor)[a-zA-Z_]*[[:space:]]*[*/][[:space:]]*100\b|[*/][[:space:]]*100[[:space:]]*[;)].*(amount|price|money)' \
  2>/dev/null | report "hardcoded *100 or /100 money scaling (use currency.minorPerMajor)"

# 3) DateTime.now() inside packages/core (must inject a Clock)
find packages/core -name '*.dart' 2>/dev/null \
  | grep -v -E '\.(g|freezed|drift)\.dart$' \
  | xargs grep -nE 'DateTime\.now\(\)' 2>/dev/null \
  | report "DateTime.now() in packages/core (inject a Clock instead)"

# 4) Flutter / intl / dart:io imports leaking into packages/core
find packages/core -name '*.dart' 2>/dev/null \
  | xargs grep -nE "import[[:space:]]+'(package:flutter/|package:intl/|dart:io)" 2>/dev/null \
  | report "Flutter/intl/dart:io import in packages/core (core is pure Dart; format in l10n)"

# 5) a literal TOMAN currency (Toman must stay a display view over IRR)
echo "$DART_FILES" | xargs grep -nE "'TOMAN'|toman[[:space:]]*\(" 2>/dev/null \
  | grep -iv 'forRialDisplay\|RialDisplay\|unit.toman\|TomanView' \
  | report "possible TOMAN currency (keep IRR canonical; Toman is display-only)"

echo ""
if [ "$fail" -eq 0 ]; then
  echo "==> OK: no canonical-units-money violations found"
else
  echo "==> FAIL: violations above must be fixed"
fi
exit "$fail"
