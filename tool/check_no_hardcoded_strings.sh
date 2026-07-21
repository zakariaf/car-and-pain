#!/usr/bin/env bash
# F4-T7 string-externalization gate: no hardcoded user-facing strings in UI code.
# Every user-facing string MUST come from gen-l10n (AppLocalizations.of(context)),
# never a literal. This is a blocking CI gate.
#
# Escape-hatch: for a genuinely non-localizable literal (a debug string, a
# canonical code, a key) append  // i18n-ignore  on the same line. Use sparingly.
#
# Heuristic by design (matches the repo's other grep gates). It targets the
# high-signal sites where user copy appears as a literal — Text(), field
# hint/label/helper text, and Tooltip/SnackBar messages — with a quoted literal
# that contains a letter. Variables and AppLocalizations calls are not literals,
# so they pass.
set -euo pipefail

# Feature/UI code. The dev-only gallery and generated sources are exempt.
ROOTS=("apps" "packages/design_system/lib")

PATTERN="(Text\(|hintText:|labelText:|helperText:|Tooltip\(message:|SnackBar\(content: *Text\()[[:space:]]*['\"][^'\"]*[A-Za-z]"

hits="$(grep -rnE "$PATTERN" "${ROOTS[@]}" --include="*.dart" 2>/dev/null \
  | grep -v '\.g\.dart' \
  | grep -v '/gallery/' \
  | grep -v 'i18n-ignore' \
  || true)"

if [ -n "$hits" ]; then
  echo "FAIL: hardcoded user-facing string(s) — route them through AppLocalizations (gen-l10n)."
  echo "      For a genuinely non-localizable literal, append  // i18n-ignore  on the line."
  echo
  echo "$hits"
  exit 1
fi

echo "OK: no hardcoded user-facing strings in UI code."
