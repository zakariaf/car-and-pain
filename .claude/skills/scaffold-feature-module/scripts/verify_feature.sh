#!/usr/bin/env bash
# verify_feature.sh — post-scaffold checks for one Car and Pain feature folder.
# Prints findings to stdout; exits non-zero if any check fails.
#
# Usage:   scripts/verify_feature.sh <feature-number> <feature-name-kebab>
# Example: scripts/verify_feature.sh 07 trips-roadtrip
#
# Checks (grep-based, no build needed):
#   1) folder shape (presentation/notifier + view, domain model present)
#   2) NO cross-feature imports (a feature must never import another feature folder)
#   3) NO non-Directional geometry (EdgeInsets.left/right, Alignment.*Left/Right, TextAlign.left/right)
#   4) NO raw Drift row/companion or float money leaking into presentation
#   5) NO hardcoded user-facing strings bypassing gen-l10n (heuristic)
#   6) ARB parity across the six files (delegates to the l10n skill's check if present)
# Then, if the Flutter toolchain is on PATH, runs build_runner + flutter analyze.
set -uo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $(basename "$0") <feature-number> <feature-name-kebab>" >&2
  exit 2
fi
NUM=$(printf '%02d' "$((10#$1))")
KEBAB="$2"
FEATURES_ROOT="${FEATURES_ROOT:-apps/car_and_pain/lib/src/features}"
DEST="$FEATURES_ROOT/$NUM-$KEBAB"
ARB_DIR="${ARB_DIR:-packages/l10n/lib/l10n}"

status=0
fail() { echo "  FAIL: $*"; status=1; }
ok()   { echo "  OK:   $*"; }

echo "== verify_feature: $DEST =="

# 1) Folder shape ------------------------------------------------------------------
echo "[1] folder shape"
if [[ ! -d "$DEST" ]]; then
  fail "feature folder not found: $DEST (run scripts/new_feature.sh first)"
  echo "verify: FAIL"; exit 1
fi
[[ -f "$DEST/presentation/${KEBAB//-/_}_notifier.dart" ]] && ok "notifier present" || fail "missing presentation/*_notifier.dart"
[[ -n "$(find "$DEST/presentation/view" -name '*_view.dart' 2>/dev/null)" ]] && ok "view present" || fail "missing presentation/view/*_view.dart"
[[ -n "$(find "$DEST/domain" -name '*.dart' 2>/dev/null)" ]] && ok "domain model present" || fail "missing domain/*.dart"
[[ -d "$DEST/data" ]] && fail "unexpected data/ folder — features read repositories from packages/data" || ok "no per-feature data/ folder"

# 2) Cross-feature imports ---------------------------------------------------------
echo "[2] no cross-feature imports"
XF=$(grep -rnE "import .*(src/features/|features/)[0-9]{2}-" "$DEST" 2>/dev/null \
      | grep -vE "/$NUM-$KEBAB/" || true)
if [[ -n "$XF" ]]; then fail "imports another feature folder:"; printf '        %s\n' "$XF"; else ok "none"; fi

# 3) Directional geometry ----------------------------------------------------------
echo "[3] Directional-only geometry"
GEO=$(grep -rnE 'EdgeInsets\.only\([^)]*(left|right):|Alignment\.(center|top|bottom)(Left|Right)|Positioned\((left|right):|TextAlign\.(left|right)' "$DEST" 2>/dev/null || true)
if [[ -n "$GEO" ]]; then fail "non-directional geometry (use EdgeInsetsDirectional / AlignmentDirectional):"; printf '        %s\n' "$GEO"; else ok "none"; fi

# 4) No Drift rows / float money in presentation -----------------------------------
echo "[4] no Drift rows / float money leaking into presentation"
LEAK=$(grep -rnE 'Companion|package:drift/|\bdouble .*[Pp]rice|\bdouble .*[Cc]ost|\bdouble .*[Aa]mount' "$DEST/presentation" 2>/dev/null || true)
if [[ -n "$LEAK" ]]; then fail "Drift class or float money in presentation (map to domain models; Money = integer minor units):"; printf '        %s\n' "$LEAK"; else ok "none"; fi

# 5) Hardcoded user-facing strings (heuristic) -------------------------------------
echo "[5] no hardcoded user-facing strings (route through gen-l10n)"
HARD=$(grep -rnE "(Text|title|label)\(\s*'[A-Za-z][^']{2,}'" "$DEST/presentation" 2>/dev/null \
        | grep -vE "AppLocalizations|l10n\.|context\.l10n" || true)
if [[ -n "$HARD" ]]; then fail "literal string not from AppLocalizations (add an ARB key):"; printf '        %s\n' "$HARD"; else ok "none obvious"; fi

# 6) ARB parity --------------------------------------------------------------------
echo "[6] ARB parity across the six files"
SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -x "$SKILLS_DIR/i18n-rtl-localization/scripts/check_arb_parity.sh" ]]; then
  "$SKILLS_DIR/i18n-rtl-localization/scripts/check_arb_parity.sh" "$ARB_DIR" || status=1
elif [[ -d "$ARB_DIR" ]]; then
  # Minimal fallback: assert all six files exist and have the same key count as the template.
  TMPL="$ARB_DIR/app_en.arb"
  if [[ -f "$TMPL" ]]; then
    tkeys=$(grep -oE '"[^"@][^"]*"[[:space:]]*:' "$TMPL" | sort -u | wc -l | tr -d ' ')
    for loc in de fr fa ar ckb; do
      f="$ARB_DIR/app_${loc}.arb"
      if [[ ! -f "$f" ]]; then fail "missing $f"; continue; fi
      lk=$(grep -oE '"[^"@][^"]*"[[:space:]]*:' "$f" | sort -u | wc -l | tr -d ' ')
      [[ "$lk" == "$tkeys" ]] && ok "app_${loc}.arb key count matches ($lk)" || fail "app_${loc}.arb has $lk keys, template has $tkeys"
    done
  else
    echo "  SKIP: template $TMPL not found"
  fi
else
  echo "  SKIP: ARB dir $ARB_DIR not found"
fi

# Toolchain checks (best-effort) ---------------------------------------------------
echo "[7] toolchain (build_runner + analyze)"
if command -v dart >/dev/null 2>&1; then
  echo "  running: dart run build_runner build --delete-conflicting-outputs"
  dart run build_runner build --delete-conflicting-outputs || fail "build_runner failed (codegen for riverpod/freezed/go_router/gen-l10n)"
fi
if command -v flutter >/dev/null 2>&1; then
  echo "  running: flutter analyze"
  flutter analyze || fail "flutter analyze reported issues"
else
  echo "  SKIP: flutter not on PATH"
fi

echo
if [[ "$status" -eq 0 ]]; then echo "verify: PASS"; else echo "verify: FAIL (see above)"; fi
exit "$status"
