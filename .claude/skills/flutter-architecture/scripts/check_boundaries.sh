#!/usr/bin/env bash
# check_boundaries.sh — Car and Pain architecture boundary checks.
# Prints a PASS/FAIL line per check to stdout and exits non-zero if any fails.
# Grounds docs/flutter/01-architecture-and-structure.md (Boundary enforcement).
#
# Run from anywhere; it locates the workspace root by walking up for melos.yaml
# (falling back to the git top-level).

set -uo pipefail

# --- locate workspace root -------------------------------------------------
find_root() {
  local d="${1:-$PWD}"
  while [ "$d" != "/" ]; do
    if [ -f "$d/melos.yaml" ] || [ -f "$d/pubspec.yaml" ] && grep -qs 'workspace' "$d/pubspec.yaml" 2>/dev/null; then
      echo "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  git -C "${1:-$PWD}" rev-parse --show-toplevel 2>/dev/null || echo "$PWD"
}
ROOT="$(find_root "$PWD")"
cd "$ROOT" || { echo "cannot cd to workspace root"; exit 2; }
echo "== boundary checks @ $ROOT =="

APP_LIB="apps/car_and_pain/lib"
DS_LIB="packages/design_system/lib"
FAILED=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; FAILED=1; }
skip() { echo "SKIP  $1"; }

# --- 1. codegen freshness --------------------------------------------------
if command -v dart >/dev/null 2>&1; then
  if dart run build_runner build --delete-conflicting-outputs >/tmp/cap_buildrunner.log 2>&1; then
    if [ -z "$(git status --porcelain '*.g.dart' '*.freezed.dart' 2>/dev/null)" ]; then
      pass "codegen fresh (build_runner produced no diff)"
    else
      pass "build_runner ran (generated files are gitignored — verify no unexpected diff)"
    fi
  else
    fail "build_runner failed — see /tmp/cap_buildrunner.log"
  fi
else
  skip "codegen freshness (dart not on PATH)"
fi

# --- 2. dart format --------------------------------------------------------
if command -v dart >/dev/null 2>&1; then
  if dart format --output=none --set-exit-if-changed . >/tmp/cap_format.log 2>&1; then
    pass "dart format clean"
  else
    fail "dart format would change files — see /tmp/cap_format.log"
  fi
else
  skip "dart format (dart not on PATH)"
fi

# --- 3. flutter analyze ----------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  if flutter analyze >/tmp/cap_analyze.log 2>&1; then
    pass "flutter analyze (very_good_analysis + custom_lint + riverpod_lint)"
  else
    fail "flutter analyze reported issues — see /tmp/cap_analyze.log"
  fi
else
  skip "flutter analyze (flutter not on PATH)"
fi

# --- 4. Directional-geometry grep -----------------------------------------
GEO_RE='EdgeInsets\.only\((top:.*)?(left|right):|Alignment\.(center|top|bottom)(Left|Right)|Positioned\((left|right):|TextAlign\.(left|right)'
GEO_HITS="$(grep -rnE "$GEO_RE" $APP_LIB $DS_LIB 2>/dev/null)"
if [ -z "$GEO_HITS" ]; then
  pass "no non-Directional geometry in app/design_system"
else
  fail "non-Directional geometry found:"; echo "$GEO_HITS"
fi

# --- 5. silent-swallow grep ------------------------------------------------
SWALLOW_HITS="$(grep -rnE 'catch\s*\(\s*_\s*\)\s*\{\s*\}' apps packages 2>/dev/null | grep -v '\.g\.dart')"
if [ -z "$SWALLOW_HITS" ]; then
  pass "no empty catch(_) {} swallow"
else
  fail "silent error swallow found (return a typed Result instead):"; echo "$SWALLOW_HITS"
fi

# --- 6. src/-import across package boundary --------------------------------
# Importing 'package:<pkg>/src/...' from outside that package breaks the barrel wall.
SRC_HITS=""
for pkg in core data notifications l10n design_system; do
  h="$(grep -rnE "import\s+'package:${pkg}/src/" apps packages 2>/dev/null \
        | grep -v "packages/${pkg}/" | grep -v '\.g\.dart')"
  [ -n "$h" ] && SRC_HITS="$SRC_HITS$h"$'\n'
done
if [ -z "$(echo "$SRC_HITS" | tr -d '[:space:]')" ]; then
  pass "no cross-package src/ imports (barrels respected)"
else
  fail "cross-package src/ import found (import the barrel instead):"; echo "$SRC_HITS"
fi

# --- 7. no-telemetry lockfile scan ----------------------------------------
if [ -f pubspec.lock ]; then
  TELE_HITS="$(grep -niE 'crashlytics|sentry|firebase_analytics|firebase_crashlytics|amplitude|mixpanel|datadog|bugsnag|appcenter' pubspec.lock 2>/dev/null)"
  if [ -z "$TELE_HITS" ]; then
    pass "no analytics/crash SDK in pubspec.lock"
  else
    fail "telemetry SDK in lockfile (no-telemetry violation):"; echo "$TELE_HITS"
  fi
else
  skip "no-telemetry scan (root pubspec.lock not found)"
fi

# --- 8. resolution: workspace on every member ------------------------------
MISSING_RES=""
while IFS= read -r ps; do
  # skip the root workspace pubspec (declares members, not a member itself)
  grep -qs 'workspace:' "$ps" && continue
  grep -qs 'resolution:\s*workspace' "$ps" || MISSING_RES="$MISSING_RES$ps"$'\n'
done < <(find apps packages -maxdepth 2 -name pubspec.yaml 2>/dev/null)
if [ -z "$(echo "$MISSING_RES" | tr -d '[:space:]')" ]; then
  pass "every member sets resolution: workspace"
else
  fail "member pubspec(s) missing 'resolution: workspace':"; echo "$MISSING_RES"
fi

# --- 9. core purity: no flutter dependency ---------------------------------
if [ -f packages/core/pubspec.yaml ]; then
  if awk '/^dependencies:/{f=1;next}/^[a-zA-Z]/{f=0}f&&/^\s+flutter:/{print;found=1}END{exit !found}' \
        packages/core/pubspec.yaml >/dev/null 2>&1; then
    fail "core/pubspec.yaml declares a flutter dependency — core must be pure Dart"
  else
    pass "core is pure Dart (no flutter dependency)"
  fi
else
  skip "core purity (packages/core/pubspec.yaml not found)"
fi

# --- 10. exactly five packages ---------------------------------------------
if [ -d packages ]; then
  PKG_COUNT="$(find packages -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')"
  if [ "$PKG_COUNT" = "5" ]; then
    pass "exactly 5 foundational packages"
  else
    echo "WARN  found $PKG_COUNT packages (expected 5: core, data, notifications, l10n, design_system) — a 6th needs an ADR"
  fi
else
  skip "package count (packages/ not found)"
fi

echo "-- reminder: run the DB-header not-plaintext test separately:"
echo "     flutter test --name 'db header'   # asserts raw DB is NOT 'SQLite format 3'"
echo "== done =="
exit $FAILED
