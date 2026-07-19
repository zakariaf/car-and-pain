#!/usr/bin/env bash
# Commitment 1: compose from tokens, never literals.
# Flags raw Color(0x..)/hex/Color.fromARGB used OUTSIDE the token source files.
# The ONLY place hex Colors may appear is the token definition files (their names
# match *token*.dart / pulse_colors*.dart / pulse_theme*.dart).
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

# Where PULSE UI code can live.
SCAN_DIRS=(packages/design_system/lib apps/car_and_pain/lib)
EXISTING=()
for d in "${SCAN_DIRS[@]}"; do [[ -d "$d" ]] && EXISTING+=("$d"); done
if [[ ${#EXISTING[@]} -eq 0 ]]; then
  echo "note: no PULSE source dirs yet (${SCAN_DIRS[*]}); nothing to scan."
  exit 0
fi

# Token-definition files are allowed to hold hex; everything else must not.
ALLOW_RE='(pulse_tokens|pulse_colors|pulse_theme|_tokens|design_tokens)\.dart$'

echo "== raw Color/hex literals outside the token files =="
hits="$(grep -rnE 'Color\(0x|Color\.fromARGB|Color\.fromRGBO' \
        --include='*.dart' "${EXISTING[@]}" 2>/dev/null \
        | grep -vE "$ALLOW_RE" \
        | grep -viE '\.g\.dart|\.freezed\.dart' || true)"

if [[ -n "$hits" ]]; then
  echo "$hits"
  n="$(printf '%s\n' "$hits" | grep -c .)"
  echo "FAIL: $n raw colour literal(s). Read PulseTokens.of(context) / ColorScheme instead."
  exit 1
fi
echo "OK: no raw colour literals outside the token source files."
