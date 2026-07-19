#!/usr/bin/env bash
# new_feature.sh — scaffold one Car and Pain feature FOLDER from the assets/ templates.
#
# Usage:   scripts/new_feature.sh <feature-number> <feature-name-kebab>
# Example: scripts/new_feature.sh 7 trips-roadtrip
#          -> apps/car_and_pain/lib/src/features/07-trips-roadtrip/{presentation/view,application,domain}
#
# Substitutes $1/$2 into the templates and prints the two manual steps it cannot do
# (register the go_router route, add the six-ARB-file strings). Prints all actions to stdout.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL_DIR="$SCRIPT_DIR/../assets/templates"
FEATURES_ROOT="${FEATURES_ROOT:-apps/car_and_pain/lib/src/features}"

if [[ $# -ne 2 ]]; then
  echo "usage: $(basename "$0") <feature-number> <feature-name-kebab>" >&2
  echo "  e.g. $(basename "$0") 07 trips-roadtrip" >&2
  exit 2
fi

RAW_NUM="$1"
RAW_NAME="$2"

# --- Normalize the number to two digits (7 -> 07) ---------------------------------
if ! [[ "$RAW_NUM" =~ ^[0-9]{1,2}$ ]]; then
  echo "FAIL: feature-number must be 1-2 digits, got '$RAW_NUM'" >&2
  exit 2
fi
NUM=$(printf '%02d' "$((10#$RAW_NUM))")

# --- Validate + derive name casings ------------------------------------------------
if ! [[ "$RAW_NAME" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]]; then
  echo "FAIL: feature-name must be lower kebab-case (e.g. fuel-energy), got '$RAW_NAME'" >&2
  exit 2
fi
KEBAB="$RAW_NAME"
SNAKE="${KEBAB//-/_}"
# PascalCase: capitalize each dash-separated word.
PASCAL=""
TITLE=""
IFS='-' read -ra WORDS <<< "$KEBAB"
for w in "${WORDS[@]}"; do
  CAP="$(tr '[:lower:]' '[:upper:]' <<< "${w:0:1}")${w:1}"
  PASCAL+="$CAP"
  TITLE+="$CAP "
done
TITLE="${TITLE% }"
# camelCase: lowercase first char of Pascal.
CAMEL="$(tr '[:upper:]' '[:lower:]' <<< "${PASCAL:0:1}")${PASCAL:1}"

DEST="$FEATURES_ROOT/$NUM-$KEBAB"
if [[ -e "$DEST" ]]; then
  echo "FAIL: feature folder already exists: $DEST" >&2
  exit 1
fi

echo "== scaffold-feature-module =="
echo "number : $NUM"
echo "kebab  : $KEBAB   snake: $SNAKE   pascal: $PASCAL   camel: $CAMEL   title: $TITLE"
echo "dest   : $DEST"
echo

mkdir -p "$DEST/presentation/view" "$DEST/application" "$DEST/domain"

# render <template> <output> — substitutes all placeholder tokens.
render() {
  local src="$1" out="$2"
  sed \
    -e "s/__FEATURE_NUM__/$NUM/g" \
    -e "s/__FEATURE_KEBAB__/$KEBAB/g" \
    -e "s/__FEATURE_SNAKE__/$SNAKE/g" \
    -e "s/__FEATURE_PASCAL__/$PASCAL/g" \
    -e "s/__FEATURE_CAMEL__/$CAMEL/g" \
    -e "s/__FEATURE_TITLE__/$TITLE/g" \
    "$src" > "$out"
  echo "  wrote $out"
}

render "$TPL_DIR/notifier.dart.tmpl"     "$DEST/presentation/${SNAKE}_notifier.dart"
render "$TPL_DIR/view.dart.tmpl"         "$DEST/presentation/view/${SNAKE}_view.dart"
render "$TPL_DIR/domain_model.dart.tmpl" "$DEST/domain/${SNAKE}.dart"
render "$TPL_DIR/feature_readme.md.tmpl" "$DEST/README.md"
# application/ stays empty until logic genuinely spans >1 repository (add a use-case then).
touch "$DEST/application/.gitkeep"

echo
echo "== NEXT — two manual steps the generator cannot do =="
echo
echo "1) REGISTER THE ROUTE in apps/car_and_pain/lib/src/routing/routes.dart :"
echo "     @TypedGoRoute<${PASCAL}Route>(path: '/vehicles/:vehicleId/$KEBAB')"
echo "     class ${PASCAL}Route extends GoRouteData with _\$${PASCAL}Route { ... vehicleId ... }"
echo "     detail: path 'reminders'-style child with :${CAMEL}Id ; full-screen add/edit ->"
echo "     parentNavigatorKey: _rootNavigatorKey . Then regenerate typed routes with build_runner."
echo "     See references/routing-and-l10n.md."
echo
echo "2) ADD STRINGS across ALL SIX ARB files in packages/l10n/lib/l10n/ (template first):"
echo "     ${CAMEL}Title, ${CAMEL}EmptyTitle, ${CAMEL}EmptyBody  (+ the rest as you add them)"
echo "     app_en.arb FIRST (with @metadata), then mirror to de/fr/fa/ar/ckb (same placeholders/ICU)."
echo
echo "3) VERIFY:"
echo "     scripts/verify_feature.sh $NUM $KEBAB"
echo "     dart run build_runner build --delete-conflicting-outputs"
echo "     flutter analyze"
