#!/usr/bin/env bash
# Blocking CI gate: the prod/release Android manifest must NOT request INTERNET.
# (INTERNET lives only in the debug/profile manifests for dev tooling.)
set -euo pipefail

MANIFEST="apps/car_and_pain/android/app/src/main/AndroidManifest.xml"

if [[ ! -f "$MANIFEST" ]]; then
  echo "FAIL: manifest not found at $MANIFEST"
  exit 1
fi

# Match the actual <uses-permission … INTERNET> declaration, not comment text.
if grep -qE '<uses-permission[^>]*android\.permission\.INTERNET' "$MANIFEST"; then
  echo "FAIL: INTERNET permission declared in the release manifest ($MANIFEST)."
  echo "The prod flavor must ship without INTERNET so the OS enforces offline."
  exit 1
fi

echo "OK: release manifest omits INTERNET."
