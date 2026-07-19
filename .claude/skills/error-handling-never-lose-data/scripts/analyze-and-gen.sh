#!/usr/bin/env bash
# Regenerate codegen then analyze — the exhaustiveness + lint gate.
# Sealed Result/Failure switches surface missing branches as analyzer errors here.
# FVM-aware. Run from anywhere in the repo. Prints results to stdout.
set -uo pipefail

find_root() {
  local d="$PWD"
  while [ "$d" != "/" ]; do
    if [ -f "$d/pubspec.yaml" ] && grep -q '^workspace:' "$d/pubspec.yaml" 2>/dev/null; then
      echo "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  echo "ERROR: workspace root (pubspec.yaml with 'workspace:') not found" >&2
  return 1
}

ROOT="$(find_root)" || exit 1
cd "$ROOT"
echo "==> workspace root: $ROOT"

if command -v fvm >/dev/null 2>&1 && [ -f "$ROOT/.fvmrc" ]; then
  DART="fvm dart"; FLUTTER="fvm flutter"
else
  DART="dart"; FLUTTER="flutter"
fi
echo "==> using: $DART / $FLUTTER"

echo "==> [1/2] build_runner (Drift/JSON/Riverpod codegen)"
$DART run build_runner build --delete-conflicting-outputs
gen=$?
if [ "$gen" -ne 0 ]; then
  echo "!! codegen failed (exit $gen)" >&2
  exit "$gen"
fi

echo "==> [2/2] flutter analyze (sealed exhaustiveness = analyzer errors)"
$FLUTTER analyze
an=$?
if [ "$an" -ne 0 ]; then
  echo "!! analyze reported issues (exit $an) — a missing Failure branch shows up here" >&2
  exit "$an"
fi

echo "==> RESULT: codegen + analyze clean."
