#!/usr/bin/env bash
# Commitment 2: status is never colour-only. Heuristic gate — flags widget files
# that consume the temperature ramp / status colour but show no sign of an
# accompanying text label AND icon (the redundant channels). A hint, not a proof;
# pair with the greyscale golden in references/redundant-encoding-a11y.md.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

SCAN_DIRS=(packages/design_system/lib apps/car_and_pain/lib)
EXISTING=()
for d in "${SCAN_DIRS[@]}"; do [[ -d "$d" ]] && EXISTING+=("$d"); done
if [[ ${#EXISTING[@]} -eq 0 ]]; then
  echo "note: no PULSE source dirs yet; nothing to scan."
  exit 0
fi

# Files that reference status colour / temperature (portable — no bash 4 mapfile).
fail=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # A colour-carrying widget should also carry a text label AND an icon.
  grep -qE 'Text\(|\.label|Semantics\(.*label' "$f" 2>/dev/null && has_label=1 || has_label=0
  grep -qE 'Icon\(|IconData|\.icon' "$f" 2>/dev/null && has_icon=1 || has_icon=0
  if [[ "$has_label" -eq 0 || "$has_icon" -eq 0 ]]; then
    miss=""
    [[ $has_label -eq 0 ]] && miss="a text label"
    [[ $has_label -eq 0 && $has_icon -eq 0 ]] && miss="$miss and "
    [[ $has_icon -eq 0 ]] && miss="${miss}an icon"
    echo "WARN $f : uses status colour but missing $miss."
    fail=1
  fi
done < <(grep -rlE 'temp\[|\.color\(|Urgency\.|warnText|critText|okText|StatusPill|status.*[Cc]olor' \
         --include='*.dart' "${EXISTING[@]}" 2>/dev/null \
         | grep -viE '\.g\.dart|\.freezed\.dart|pulse_tokens|pulse_colors|pulse_theme')

if [[ $fail -eq 0 ]]; then
  echo "OK: every status-colour widget also carries a label + icon (redundant channels present)."
else
  echo "-> status must ALSO be icon + text label + shape + position. See references/redundant-encoding-a11y.md."
fi
exit $fail
