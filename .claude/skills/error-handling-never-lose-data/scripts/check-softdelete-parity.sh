#!/usr/bin/env bash
# Soft-delete parity check: analytics / TCO / chart queries must read through the
# shared deleted-filter view/builder, never the base table directly.
# Prints suspected offenders to stdout; exits non-zero if any are found.
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
DATA="$ROOT/packages/data"
[ -d "$DATA" ] || DATA="$ROOT"
echo "==> scanning analytics/TCO/chart query code under: $DATA"

# Tables that carry is_deleted and must be read via *_active views / activeOnly().
GUARDED='fills|services|expenses|reminders|trips|odometer_readings|documents'
# The sanctioned filtered access points.
SANCTIONED='_active|activeOnly|deletedFilter|is_deleted|isDeleted'

# Files that look like report/analytics/chart producers.
files=()
while IFS= read -r f; do files+=("$f"); done < <(
  grep -rilE --include=*.dart 'tco|analytics|consumption|rollup|chart|projection|stat' \
    "$DATA" 2>/dev/null | grep -vE '\.g\.dart|\.drift\.dart|_test\.dart')

if [ ${#files[@]} -eq 0 ]; then
  echo "ok: no analytics/TCO/chart query files present yet (nothing to scan)"
  exit 0
fi

fail=0
for f in "${files[@]}"; do
  # Lines that select from a guarded base table...
  hits="$(grep -nE "select\(.*($GUARDED)|from[[:space:]]+($GUARDED)|\b($GUARDED)\b" "$f" 2>/dev/null)"
  [ -z "$hits" ] && continue
  # ...but the file never references a sanctioned filtered access point.
  if ! grep -qE "$SANCTIONED" "$f" 2>/dev/null; then
    echo "!! $f reads a guarded table but never uses the shared deleted-filter:" >&2
    echo "$hits" | sed 's/^/     /'
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "==> RESULT: possible soft-delete leaks — deleted rows may pollute analytics/TCO/charts." >&2
  echo "    Route every read through the *_active view or activeOnly() builder." >&2
  exit 1
fi
echo "==> RESULT: all analytics/TCO/chart readers reference the shared deleted-filter. clean."
