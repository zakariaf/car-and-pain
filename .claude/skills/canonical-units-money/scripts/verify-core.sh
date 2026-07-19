#!/usr/bin/env bash
# Regenerate codegen, then analyze and run the packages/core unit tests with
# coverage. The core engine is held at 100% coverage — this is the fast gate.
# Prints progress + a coverage summary to stdout.
set -euo pipefail

find_root() {
  local d="$PWD"
  while [ "$d" != "/" ]; do
    if [ -f "$d/pubspec.yaml" ] && grep -q '^workspace:' "$d/pubspec.yaml"; then
      echo "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  echo "ERROR: workspace root (pubspec.yaml with 'workspace:') not found" >&2
  return 1
}
ROOT="$(find_root)"
cd "$ROOT"
echo "==> workspace root: $ROOT"

# Prefer FVM so the SDK matches .fvmrc; fall back to bare tools.
if command -v fvm >/dev/null 2>&1 && [ -f "$ROOT/.fvmrc" ]; then
  DART="fvm dart"; FLUTTER="fvm flutter"
else
  DART="dart"; FLUTTER="flutter"
fi
echo "==> using: $DART / $FLUTTER"

echo "==> [1/3] build_runner (drift/freezed/riverpod/json) at root"
$DART run build_runner build --delete-conflicting-outputs

echo "==> [2/3] flutter analyze --fatal-infos (packages/core)"
$FLUTTER analyze --fatal-infos packages/core

echo "==> [3/3] unit tests + coverage (packages/core)"
( cd packages/core && $FLUTTER test --coverage )

LCOV="packages/core/coverage/lcov.info"
if [ -f "$LCOV" ]; then
  total="$(grep -c '^DA:' "$LCOV" || echo 0)"
  hit="$(grep '^DA:' "$LCOV" | grep -vE ',0$' | wc -l | tr -d ' ')"
  echo "==> core coverage: $hit/$total lines hit"
  if [ "$total" -gt 0 ] && [ "$hit" -lt "$total" ]; then
    echo "   WARNING: packages/core is below 100% line coverage"
  fi
else
  echo "   (no lcov.info produced)"
fi

echo "==> OK: core regenerated, analyzed, and tested"
