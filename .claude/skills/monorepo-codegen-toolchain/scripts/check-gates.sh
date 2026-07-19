#!/usr/bin/env bash
# Local pre-flight for the blocking gates + workspace-hygiene parity checks.
# Prints findings to stdout; exits non-zero on any violation.
set -uo pipefail

find_root() {
  local d="$PWD"
  while [ "$d" != "/" ]; do
    if [ -f "$d/pubspec.yaml" ] && grep -q '^workspace:' "$d/pubspec.yaml"; then
      echo "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}

ROOT="$(find_root)" || { echo "ERROR: workspace root not found" >&2; exit 2; }
cd "$ROOT"
FAIL=0
echo "==> workspace root: $ROOT"

echo "==> [1] every member pubspec sets 'resolution: workspace'"
while IFS= read -r p; do
  [ "$p" = "./pubspec.yaml" ] && continue
  if ! grep -q '^resolution:[[:space:]]*workspace' "$p"; then
    echo "   VIOLATION: missing 'resolution: workspace' -> $p"; FAIL=1
  fi
done < <(find apps packages -name pubspec.yaml 2>/dev/null)

echo "==> [2] no per-package lockfiles (only the root pubspec.lock is tracked)"
while IFS= read -r l; do
  echo "   VIOLATION: stray lockfile -> $l"; FAIL=1
done < <(find apps packages -name pubspec.lock 2>/dev/null)

echo "==> [3] no generated code committed to git"
GEN="$(git ls-files 2>/dev/null \
  | grep -E '\.(g|freezed|drift|mocks)\.dart$|l10n/.*generated/' || true)"
if [ -n "$GEN" ]; then
  echo "   VIOLATION: generated files are tracked (must be gitignored):"
  echo "$GEN" | sed 's/^/     /'; FAIL=1
fi

echo "==> [4] non-Directional geometry in feature/design code (RTL discipline)"
BADGEO="$(grep -rnE 'EdgeInsets\.only\(([^)]*)(left|right):|Alignment\.(center|top|bottom)(Left|Right)|Positioned\((left|right):|TextAlign\.(left|right)' \
  apps/car_and_pain/lib packages/design_system/lib 2>/dev/null || true)"
if [ -n "$BADGEO" ]; then
  echo "   VIOLATION: use Directional geometry instead:"
  echo "$BADGEO" | sed 's/^/     /'; FAIL=1
fi

echo "==> [5] dart format --set-exit-if-changed"
if command -v fvm >/dev/null 2>&1 && [ -f "$ROOT/.fvmrc" ]; then DART="fvm dart"; else DART="dart"; fi
if ! $DART format --output=none --set-exit-if-changed . ; then
  echo "   VIOLATION: files are not formatted (run: dart format .)"; FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
  echo "==> OK: all parity/format gates pass"
else
  echo "==> FAILED: fix the violations above" >&2
fi
exit "$FAIL"
