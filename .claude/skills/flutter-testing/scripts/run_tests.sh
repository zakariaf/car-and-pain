#!/usr/bin/env bash
# Mirror the Car and Pain CI test lanes locally and scan for the common
# testing-convention violations. Prints findings to stdout. Run from anywhere
# in the repo. Non-zero exit if analyze, tests, or any hard scan fails.
#
# Lanes mirrored (see docs/flutter/11-testing.md):
#   gen -> analyze -> unit/widget (coverage, exclude golden) -> golden CI (Ahem)
# Plus grep-based convention scans that CI would otherwise only catch at review.
set -uo pipefail

FAIL=0
note()  { printf '   %s\n' "$*"; }
head_() { printf '\n==> %s\n' "$*"; }

# --- Resolve the workspace root (dir with a root pubspec.yaml + workspace:) ----
find_root() {
  local d="$PWD"
  while [ "$d" != "/" ]; do
    if [ -f "$d/pubspec.yaml" ] && grep -q '^workspace:' "$d/pubspec.yaml"; then
      echo "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  echo "ERROR: workspace root (pubspec.yaml with 'workspace:') not found" >&2
  return 1
}
ROOT="$(find_root)" || exit 1
cd "$ROOT"
head_ "workspace root: $ROOT"

# Prefer FVM so the SDK matches .fvmrc (goldens are Flutter-version sensitive).
if command -v fvm >/dev/null 2>&1 && [ -f "$ROOT/.fvmrc" ]; then
  DART="fvm dart"; FLUTTER="fvm flutter"
else
  DART="dart"; FLUTTER="flutter"
fi
note "using: $DART / $FLUTTER"

RUN_TESTS="${RUN_TESTS:-1}" # set RUN_TESTS=0 to only run the static scans

# --- 1. Regenerate codegen (drift/freezed/riverpod/gen-l10n) ------------------
if [ "$RUN_TESTS" = "1" ]; then
  head_ "[1/4] build_runner (regenerate before analyze)"
  $DART run build_runner build --delete-conflicting-outputs || FAIL=1

  head_ "[2/4] flutter analyze --fatal-infos"
  $FLUTTER analyze --fatal-infos || FAIL=1

  head_ "[3/4] unit + widget lane (coverage, excluding golden tag)"
  $FLUTTER test --coverage --exclude-tags golden || FAIL=1
  note "feed coverage/lcov.info to Very Good Coverage; logic packages gate 100%"

  head_ "[4/4] golden CI lane (Alchemist Ahem, byte-stable)"
  $FLUTTER test --tags golden || FAIL=1
  note "run the real-font lane separately on the pinned OS with bundled fonts"
else
  note "RUN_TESTS=0 — skipping gen/analyze/test lanes, running scans only"
fi

# --- Convention scans ---------------------------------------------------------
# Only scan Dart source (lib/), never test/ — a fixed Clock in a test is fine.
LIB_DARTS=$(find . -type f -name '*.dart' -path '*/lib/*' \
  ! -name '*.g.dart' ! -name '*.freezed.dart' ! -name '*.drift.dart' 2>/dev/null)

head_ "SCAN: DateTime.now() / local timezone leaked into production logic"
LEAK=$(printf '%s\n' "$LIB_DARTS" | xargs grep -nE 'DateTime\.now\(\)|DateTime\.timestamp\(\)|tz\.TZDateTime\.now\(' 2>/dev/null)
if [ -n "$LEAK" ]; then
  note "VIOLATION: use clock.now(); inject a Clock. Offenders:"; printf '%s\n' "$LEAK"; FAIL=1
else note "OK: no leaked wall-clock reads in lib/"; fi

head_ "SCAN: mockito creeping in (mocktail is the only sanctioned mock lib)"
MOCKITO=$(grep -rn --include='pubspec.yaml' -E '^\s*mockito\s*:' . 2>/dev/null; \
          grep -rn --include='*.dart' -E "import 'package:mockito" . 2>/dev/null)
if [ -n "$MOCKITO" ]; then
  note "VIOLATION: remove mockito/@GenerateMocks; use mocktail. Offenders:"; printf '%s\n' "$MOCKITO"; FAIL=1
else note "OK: no mockito"; fi

head_ "SCAN: pumpAndSettle() (hangs on infinite splash/shimmer/spinner)"
PAS=$(grep -rn --include='*.dart' 'pumpAndSettle(' ./ 2>/dev/null | grep -Ei 'splash|shimmer|spinner|loading')
if [ -n "$PAS" ]; then
  note "WARN: pumpAndSettle near an infinite-animation screen — use timed pump/fakeAsync:"; printf '%s\n' "$PAS"
else note "OK: no pumpAndSettle near known infinite-animation screens"; fi

head_ "SCAN: any()/captureAny() with likely-missing registerFallbackValue"
# Files that use any()/captureAny() but never call registerFallbackValue.
for f in $(grep -rln --include='*.dart' -E 'captureAny\(|[^A-Za-z]any\(' ./ 2>/dev/null | grep '/test/'); do
  if ! grep -q 'registerFallbackValue' "$f"; then
    note "WARN: $f uses any()/captureAny() but has no registerFallbackValue"
  fi
done
note "(custom types crossing any()/captureAny() must be registered in setUpAll)"

head_ "SCAN: mocked DAO/SQL as a data-layer substitute (false confidence)"
MOCKDAO=$(grep -rn --include='*.dart' -E 'class\s+\w*(Mock|Fake)\w*(Dao|Database)\b|implements\s+\w*Dao\b' ./ 2>/dev/null | grep '/test/')
if [ -n "$MOCKDAO" ]; then
  note "WARN: possible mocked DAO/DB — the data layer must use NativeDatabase.memory:"; printf '%s\n' "$MOCKDAO"
else note "OK: no obvious mocked DAO/Database doubles"; fi

head_ "SCAN: golden tests missing the golden tag"
for f in $(grep -rln --include='*.dart' -E 'GoldenTestGroup|goldenTest\(|matchesGoldenFile' ./ 2>/dev/null); do
  if ! grep -q "@Tags(\['golden'\])" "$f"; then
    note "WARN: $f has golden assertions but no @Tags(['golden'])"
  fi
done

head_ "SCAN: hardcoded backup live-file copy (must be WAL-active export)"
COPY=$(grep -rn --include='*.dart' -E "File\([^)]*\)\.(copy|copySync)\(" ./ 2>/dev/null | grep -Ei 'backup|export|\.db')
if [ -n "$COPY" ]; then
  note "WARN: possible raw DB file copy for backup — use VACUUM INTO + round-trip:"; printf '%s\n' "$COPY"
else note "OK: no obvious raw DB-file copy for backup"; fi

# --- Summary ------------------------------------------------------------------
if [ "$FAIL" = "0" ]; then
  head_ "OK: lanes passed and no hard violations"
else
  head_ "FAIL: a lane failed or a hard violation was found (see above)"
fi
exit "$FAIL"
