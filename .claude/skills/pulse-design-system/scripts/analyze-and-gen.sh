#!/usr/bin/env bash
# Regenerate codegen then analyze the PULSE design system package.
# PULSE tokens/widgets live in packages/design_system; feature screens live in
# apps/car_and_pain/lib/src/features/*/presentation. Run from anywhere in the repo.
set -uo pipefail

repo_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }
ROOT="$(repo_root)"
cd "$ROOT" || exit 1

DS="packages/design_system"
if [[ ! -d "$DS" ]]; then
  echo "note: $DS not found yet (nothing to analyze); the package is created when the design system lands."
  exit 0
fi

echo "== build_runner (design_system codegen) =="
# Codegen runs at the workspace root in this monorepo; scope output to DS.
dart run build_runner build --delete-conflicting-outputs || {
  echo "FAIL: build_runner"; exit 1; }

echo "== flutter analyze ($DS) =="
flutter analyze --fatal-infos "$DS" || { echo "FAIL: analyze"; exit 1; }

echo "OK: design_system generated + analyzed clean."
