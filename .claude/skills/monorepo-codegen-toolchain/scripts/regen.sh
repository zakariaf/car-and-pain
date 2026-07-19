#!/usr/bin/env bash
# Regenerate all codegen at the workspace root, then analyze.
# Mirrors the first two CI steps (gen -> analyze). Run from anywhere in the repo.
set -euo pipefail

# Resolve the repo root (dir containing the root pubspec.yaml with `workspace:`).
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

# Prefer FVM so the SDK matches .fvmrc; fall back to bare dart/flutter.
if command -v fvm >/dev/null 2>&1 && [ -f "$ROOT/.fvmrc" ]; then
  DART="fvm dart"; FLUTTER="fvm flutter"
else
  DART="dart"; FLUTTER="flutter"
fi
echo "==> using: $DART / $FLUTTER"

echo "==> [1/3] build_runner (drift/freezed/riverpod/json) at root"
$DART run build_runner build --delete-conflicting-outputs

echo "==> [2/3] gen-l10n"
$FLUTTER gen-l10n || echo "   (skipped: no l10n.yaml at root; l10n package may run it itself)"

echo "==> [3/3] flutter analyze --fatal-infos"
$FLUTTER analyze --fatal-infos

echo "==> OK: codegen regenerated and analysis clean"
