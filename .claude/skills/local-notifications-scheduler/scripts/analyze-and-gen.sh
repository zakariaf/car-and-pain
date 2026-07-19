#!/usr/bin/env bash
# Regenerate code and run static analysis for the notifications package.
set -euo pipefail

PKG="${1:-packages/notifications}"

echo "== build_runner + analyze for $PKG =="

if [ ! -d "$PKG" ]; then
  echo "SKIP: $PKG not found."
  exit 0
fi

cd "$PKG"

echo "-- dart run build_runner build --delete-conflicting-outputs --"
dart run build_runner build --delete-conflicting-outputs || {
  echo "build_runner failed (is build_runner a dev_dependency here?)"; exit 1;
}

echo "-- flutter analyze --"
flutter analyze
echo "OK: analyze clean."
