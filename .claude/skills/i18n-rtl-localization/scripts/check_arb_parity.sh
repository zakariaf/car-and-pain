#!/usr/bin/env bash
# check_arb_parity.sh — verify every locale ARB has the same keys and placeholders
# as the template (app_en.arb). Prints findings to stdout; exits non-zero on mismatch.
#
# Usage: scripts/check_arb_parity.sh [arb-dir]
# Default arb-dir: packages/l10n/lib/l10n
set -euo pipefail

ARB_DIR="${1:-packages/l10n/lib/l10n}"
TEMPLATE="app_en.arb"
LOCALES=(de fr fa ar ckb)

if [[ ! -d "$ARB_DIR" ]]; then
  echo "FAIL: arb dir not found: $ARB_DIR" >&2
  exit 2
fi
cd "$ARB_DIR"
if [[ ! -f "$TEMPLATE" ]]; then
  echo "FAIL: template not found: $ARB_DIR/$TEMPLATE" >&2
  exit 2
fi

# Extract message keys (top-level keys that do NOT start with '@' and are not '@@...').
keys_of() {
  # Prefer jq if available for correctness; fall back to grep.
  if command -v jq >/dev/null 2>&1; then
    jq -r 'keys[] | select(startswith("@") | not)' "$1" | sort
  else
    grep -oE '"[^"@][^"]*"[[:space:]]*:' "$1" \
      | sed -E 's/^"//; s/"[[:space:]]*:$//' | sort -u
  fi
}

# Extract "key -> sorted placeholder names" from a template's @key metadata.
placeholders_of() {
  # $1 = file, $2 = key. Emits space-separated sorted placeholder names (may be empty).
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "@$2" '.[$k].placeholders // {} | keys | sort | join(" ")' "$1"
  else
    echo ""  # placeholder diffing requires jq
  fi
}

status=0
TEMPLATE_KEYS="$(keys_of "$TEMPLATE")"
TCOUNT="$(printf '%s\n' "$TEMPLATE_KEYS" | grep -c . || true)"
echo "== ARB parity check =="
echo "template: $TEMPLATE ($TCOUNT keys)"
echo

for loc in "${LOCALES[@]}"; do
  f="app_${loc}.arb"
  if [[ ! -f "$f" ]]; then
    echo "[$loc] FAIL: missing file $f"
    status=1
    continue
  fi
  LKEYS="$(keys_of "$f")"

  missing="$(comm -23 <(printf '%s\n' "$TEMPLATE_KEYS") <(printf '%s\n' "$LKEYS") || true)"
  extra="$(comm -13 <(printf '%s\n' "$TEMPLATE_KEYS") <(printf '%s\n' "$LKEYS") || true)"

  loc_status="OK"
  if [[ -n "$missing" ]]; then
    loc_status="FAIL"; status=1
    echo "[$loc] MISSING keys:"
    printf '    %s\n' $missing
  fi
  if [[ -n "$extra" ]]; then
    loc_status="FAIL"; status=1
    echo "[$loc] EXTRA keys (not in template):"
    printf '    %s\n' $extra
  fi

  # Placeholder parity: locale message must reference the same placeholder names the
  # template declares. Compare template @key placeholders against {names} used in locale value.
  if command -v jq >/dev/null 2>&1; then
    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      want="$(placeholders_of "$TEMPLATE" "$key")"
      [[ -z "$want" ]] && continue
      val="$(jq -r --arg k "$key" '.[$k] // ""' "$f")"
      for name in $want; do
        if [[ "$val" != *"{$name"* ]]; then
          loc_status="FAIL"; status=1
          echo "[$loc] key '$key' does not use placeholder {$name}"
        fi
      done
    done <<< "$TEMPLATE_KEYS"
  fi

  echo "[$loc] $loc_status"
done

echo
if [[ "$status" -eq 0 ]]; then
  echo "ARB parity: PASS"
else
  echo "ARB parity: FAIL (see above)"
fi
exit "$status"
