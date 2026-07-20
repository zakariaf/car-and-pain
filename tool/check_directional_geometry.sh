#!/usr/bin/env bash
# Blocking CI gate: reject non-Directional geometry in feature/design code.
# Use EdgeInsetsDirectional / AlignmentDirectional / PositionedDirectional /
# TextAlign.start|end / Icons.adaptive.* — the app must mirror correctly in RTL.
set -euo pipefail

TARGETS=("apps/car_and_pain/lib" "packages/design_system/lib")

# EdgeInsets.only(left:/right:), Alignment.centerLeft/topRight/…,
# Positioned(left:/right:), TextAlign.left/right.
PATTERN='EdgeInsets\.only\([^)]*(left|right):|Alignment\.(center|top|bottom)(Left|Right)|Positioned\((left|right):|TextAlign\.(left|right)\b'

hits="$(grep -rnE "$PATTERN" "${TARGETS[@]}" \
  --include='*.dart' \
  --exclude='*.g.dart' \
  --exclude='*.freezed.dart' || true)"

if [[ -n "$hits" ]]; then
  echo "FAIL: non-Directional geometry found (use *Directional / start|end):"
  echo "$hits"
  exit 1
fi

echo "OK: no non-Directional geometry in feature/design code."
