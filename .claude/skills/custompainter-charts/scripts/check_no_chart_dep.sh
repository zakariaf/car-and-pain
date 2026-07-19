#!/usr/bin/env bash
# Fail if any charting dependency is declared or imported. Car and Pain charts are hand-painted
# with CustomPainter — no fl_chart, Syncfusion, charts_flutter, graphic, or similar. Prints findings
# to stdout and exits non-zero on any hit.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT" || exit 2
echo "== no-chart-dependency check =="
echo "root: $ROOT"

BANNED='fl_chart|syncfusion|charts_flutter|charts_common|community_charts|graphic:|graphic/|mp_chart|k_chart|echarts|highcharts'
status=0

# 1. pubspec declarations
pubspecs=$(git ls-files '*pubspec.yaml' 2>/dev/null || find . -name pubspec.yaml -not -path '*/.*' 2>/dev/null)
if [ -n "$pubspecs" ]; then
  hits=$(grep -HnE "$BANNED" $pubspecs 2>/dev/null)
  if [ -n "$hits" ]; then
    echo "FAIL — banned chart package in pubspec:"; echo "$hits"; status=1
  else
    echo "ok — no banned chart package declared in pubspec(s)"
  fi
else
  echo "note — no pubspec.yaml yet (docs-only stage); skipping dependency scan"
fi

# 2. Dart imports
darts=$(git ls-files '*.dart' 2>/dev/null || find . -name '*.dart' -not -path '*/.*' 2>/dev/null)
if [ -n "$darts" ]; then
  hits=$(grep -HnE "import .*(${BANNED})" $darts 2>/dev/null)
  if [ -n "$hits" ]; then
    echo "FAIL — banned chart import in Dart:"; echo "$hits"; status=1
  else
    echo "ok — no banned chart import in Dart sources"
  fi
else
  echo "note — no .dart files yet; skipping import scan"
fi

[ "$status" -eq 0 ] && echo "PASS — charts stay CustomPainter-only" || echo "FOUND violations above"
exit "$status"
