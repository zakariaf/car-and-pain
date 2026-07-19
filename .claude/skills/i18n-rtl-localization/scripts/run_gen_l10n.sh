#!/usr/bin/env bash
# run_gen_l10n.sh — regenerate AppLocalizations from the ARB files, run build_runner
# (Drift/Riverpod codegen), then analyze. Prints findings to stdout.
#
# Usage: scripts/run_gen_l10n.sh [l10n-package-dir]
# Default package dir: packages/l10n
set -euo pipefail

PKG_DIR="${1:-packages/l10n}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "FAIL: flutter not on PATH" >&2
  exit 2
fi
if [[ ! -d "$PKG_DIR" ]]; then
  echo "FAIL: package dir not found: $PKG_DIR" >&2
  exit 2
fi

echo "== gen-l10n regenerate =="
echo "package: $PKG_DIR"
cd "$PKG_DIR"

# 1) Ensure deps are present (uses the SDK-pinned intl; no google_fonts).
echo "-- flutter pub get"
flutter pub get

# 2) Generate AppLocalizations from ARB (l10n.yaml drives arb-dir/output-class).
#    'generate: true' in pubspec makes gen-l10n run on build, but invoke explicitly
#    so failures surface here rather than mid-build.
echo "-- flutter gen-l10n"
flutter gen-l10n

# 3) Any build_runner-backed codegen in the package (kept in sync, --delete-conflicting).
if grep -q "build_runner" pubspec.yaml 2>/dev/null; then
  echo "-- dart run build_runner build --delete-conflicting-outputs"
  dart run build_runner build --delete-conflicting-outputs
else
  echo "-- (no build_runner dependency; skipping)"
fi

# 4) Static analysis — a missing ARB key is a compile error via generated getters.
echo "-- flutter analyze"
flutter analyze

echo
echo "gen-l10n: DONE — AppLocalizations regenerated and analyzed."
