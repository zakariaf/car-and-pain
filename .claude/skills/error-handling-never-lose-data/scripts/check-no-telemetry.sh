#!/usr/bin/env bash
# No-telemetry + fpdart-scope + dartz guard.
# 1) No crash/analytics SDK may appear in any pubspec or lockfile (no-telemetry promise).
# 2) fpdart is SELECTIVE — no TaskEither/Reader as return types.
# 3) dartz is banned outright.
# Prints findings to stdout; exits non-zero on any violation.
# Portable to bash 3.2 (macOS default): no mapfile, no set -u array pitfalls.
set -o pipefail

find_root() {
  local d="$PWD"
  while [ "$d" != "/" ]; do
    if [ -f "$d/pubspec.yaml" ] && grep -q '^workspace:' "$d/pubspec.yaml" 2>/dev/null; then
      echo "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  echo "$PWD"
}

ROOT="$(find_root)"
echo "==> repo root: $ROOT"
fail=0

echo "--- [1] crash/analytics SDKs in pubspec.yaml / pubspec.lock ---"
BANNED_PKGS='crashlytics|sentry|firebase_analytics|firebase_crashlytics|amplitude|mixpanel|datadog|posthog|google_analytics'
pubspecs=()
while IFS= read -r p; do pubspecs+=("$p"); done \
  < <(find "$ROOT" \( -name pubspec.yaml -o -name pubspec.lock \) 2>/dev/null)
if [ ${#pubspecs[@]} -eq 0 ]; then
  echo "ok: no pubspec/lockfile present yet (nothing to scan)"
elif grep -EnH "$BANNED_PKGS" "${pubspecs[@]}" 2>/dev/null; then
  echo "!! FAIL: a telemetry/crash SDK is declared. Car and Pain is telemetry-free — remove it." >&2
  fail=1
else
  echo "ok: no telemetry/crash SDK in any pubspec/lockfile"
fi

echo "--- [2] dartz (banned outright) ---"
dartz_scan=()
while IFS= read -r p; do dartz_scan+=("$p"); done < <(
  find "$ROOT/packages" "$ROOT/apps" \( -name pubspec.yaml -o -name '*.dart' \) 2>/dev/null \
    | grep -vE '\.g\.dart')
if [ ${#dartz_scan[@]} -eq 0 ]; then
  echo "ok: no Dart/pubspec sources yet (nothing to scan)"
elif grep -EnH '^[[:space:]]*dartz[[:space:]]*:|package:dartz/' "${dartz_scan[@]}" 2>/dev/null; then
  echo "!! FAIL: dartz is banned — use the hand-rolled sealed Result (packages/core)." >&2
  fail=1
else
  echo "ok: no dartz"
fi

echo "--- [3] fpdart TaskEither/Reader used as a default return type ---"
dart_files=()
while IFS= read -r p; do dart_files+=("$p"); done < <(
  find "$ROOT/packages" "$ROOT/apps" -name '*.dart' 2>/dev/null \
    | grep -vE '\.g\.dart|_test\.dart')
if [ ${#dart_files[@]} -eq 0 ]; then
  echo "ok: no Dart sources yet (nothing to scan)"
elif grep -EnH '\b(TaskEither|ReaderTaskEither|Reader)[[:space:]]*<' "${dart_files[@]}" 2>/dev/null; then
  echo "!! FAIL: fpdart TaskEither/Reader is out of scope. Only Option + applicative validation are allowed." >&2
  fail=1
else
  echo "ok: no TaskEither/Reader return types"
fi

if [ "$fail" -ne 0 ]; then
  echo "==> RESULT: policy violations found." >&2
  exit 1
fi
echo "==> RESULT: telemetry-free, dartz-free, fpdart within scope. clean."
