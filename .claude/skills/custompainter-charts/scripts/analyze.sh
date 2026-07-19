#!/usr/bin/env bash
# Run the static analyzer (very_good_analysis: prefer_const + perf lints are treated as errors in
# this project). Also offers to regenerate build_runner output when a build.yaml exists. Prints
# findings to stdout. Degrades gracefully before the Flutter app is scaffolded.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT" || exit 2
echo "== flutter analyze =="

if ! command -v flutter >/dev/null 2>&1; then
  echo "note — flutter not on PATH; skipping analyze"
  exit 0
fi

# Find the nearest Flutter package (a pubspec with a flutter: section).
pkg=""
for p in $(git ls-files '*pubspec.yaml' 2>/dev/null || find . -name pubspec.yaml -not -path '*/.*' 2>/dev/null); do
  if grep -q 'flutter:' "$p"; then pkg="$(dirname "$p")"; break; fi
done

if [ -z "$pkg" ]; then
  echo "note — no Flutter package (pubspec with flutter:) yet; skipping analyze"
  exit 0
fi

echo "package: $pkg"
cd "$pkg" || exit 2

# Regenerate Drift/build_runner output if configured, so analyze sees fresh generated code.
if [ -f build.yaml ] || grep -q build_runner pubspec.yaml 2>/dev/null; then
  echo "-- dart run build_runner build --delete-conflicting-outputs"
  dart run build_runner build --delete-conflicting-outputs || echo "WARN — build_runner failed (continuing to analyze)"
fi

echo "-- flutter analyze"
flutter analyze
