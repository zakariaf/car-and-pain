#!/usr/bin/env bash
# Fail on swallowed catches and non-exhaustive failure switches.
# Mirrors the CI gate from docs/flutter/08-error-handling.md.
# Prints every offending file:line to stdout; exits non-zero if any are found.
set -uo pipefail

find_root() {
  local d="$PWD"
  while [ "$d" != "/" ]; do
    if [ -f "$d/pubspec.yaml" ] && grep -q '^workspace:' "$d/pubspec.yaml" 2>/dev/null; then
      echo "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  echo "$PWD" # fall back to CWD if no workspace root marker
}

ROOT="$(find_root)"
echo "==> scanning under: $ROOT"
SCAN_DIRS=()
for d in packages apps lib; do
  [ -d "$ROOT/$d" ] && SCAN_DIRS+=("$ROOT/$d")
done
[ ${#SCAN_DIRS[@]} -eq 0 ] && SCAN_DIRS=("$ROOT")

GREP="grep -rnE --include=*.dart"
# Exclude generated files and tests-of-the-rule from the gate.
EXCL="--exclude=*.g.dart --exclude=*.freezed.dart --exclude=*.drift.dart"

fail=0

echo "--- [1] underscore catch: catch (_) ---"
if $GREP $EXCL 'catch\s*\(\s*_\s*\)' "${SCAN_DIRS[@]}"; then
  echo "!! FAIL: 'catch (_)' swallows type AND stack. Log the original + return a typed Failure." >&2
  fail=1
else
  echo "ok: no 'catch (_)'"
fi

echo "--- [2] bare 'catch (e)' WITHOUT (e, st) capture ---"
# bare catch(e) that does not also capture the stack trace loses it.
if $GREP $EXCL 'catch\s*\(\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\)' "${SCAN_DIRS[@]}"; then
  echo "!! FAIL: 'catch (e)' drops the stack trace. Use 'catch (e, st)' and log st." >&2
  fail=1
else
  echo "ok: no stackless 'catch (e)'"
fi

echo "--- [3] 'default:' near a Failure switch (possible exhaustiveness escape) ---"
# Heuristic: a `default:` in a file that switches over a *Failure type.
while IFS= read -r f; do
  if grep -qE 'switch\s*\(.*[Ff]ailure' "$f" 2>/dev/null && grep -qnE '^\s*default\s*:' "$f" 2>/dev/null; then
    grep -nE '^\s*default\s*:' "$f"
    echo "   ^ in $f — a sealed Failure switch must have NO default: (defeats compile-time exhaustiveness)" >&2
    fail=1
  fi
done < <(grep -rlE --include=*.dart $EXCL '[Ff]ailure' "${SCAN_DIRS[@]}" 2>/dev/null)
[ "$fail" -eq 0 ] && echo "ok: no default: on Failure switches"

if [ "$fail" -ne 0 ]; then
  echo "==> RESULT: violations found." >&2
  exit 1
fi
echo "==> RESULT: clean."
