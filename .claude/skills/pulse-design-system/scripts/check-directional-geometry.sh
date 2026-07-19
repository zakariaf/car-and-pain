#!/usr/bin/env bash
# RTL by construction. Flags non-directional geometry in the design system +
# presentation, AND a pulse-line / checkmark wrongly mirrored (those HOLD in RTL).
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

fail=0
scan() { grep -rnE "$1" --include='*.dart' "${EXISTING[@]}" 2>/dev/null \
         | grep -viE '\.g\.dart|\.freezed\.dart' || true; }

echo "== non-directional geometry (use *Directional / start / end) =="
geo="$(scan 'EdgeInsets\.only\([^)]*(left|right):|Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)|Positioned\([^)]*(left|right):|TextAlign\.(left|right)|Icons\.arrow_(back|forward)[^_]')"
if [[ -n "$geo" ]]; then echo "$geo"; echo "-> use EdgeInsetsDirectional / AlignmentDirectional / PositionedDirectional / TextAlign.start|end / Icons.adaptive.*"; fail=1; fi

echo "== the pulse-line / checkmark / logo must NOT be mirrored in RTL =="
mir="$(grep -rnE 'PulseLine|VitalsHero|pulse_line|checkmark|Icons\.check' --include='*.dart' "${EXISTING[@]}" 2>/dev/null \
       | grep -iE 'matrix4\.|scale\(\s*-1|textDirection.*rtl|Transform.*flip' || true)"
if [[ -n "$mir" ]]; then echo "$mir"; echo "-> the symmetric pulse-line, checkmarks and logo glyph HOLD in RTL (only placement mirrors)."; fail=1; fi

[[ $fail -eq 0 ]] && echo "OK: directional-only geometry; symmetric marks not mirrored."
exit $fail
