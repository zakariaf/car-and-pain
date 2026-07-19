#!/usr/bin/env bash
# Heuristic hygiene scan for CustomPainter chart code. Prints findings to stdout; exits non-zero if
# any hard violation is found. Warnings (WARN) do not fail — they flag things to eyeball.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT" || exit 2
echo "== CustomPainter hygiene check =="

darts=$(git ls-files '*.dart' 2>/dev/null | grep -v '/\.claude/' || true)
if [ -z "$darts" ]; then
  echo "note — no .dart files yet (docs-only stage); nothing to scan"
  exit 0
fi

# Only scan files that actually declare a CustomPainter.
painters=$(grep -lE 'extends CustomPainter' $darts 2>/dev/null || true)
if [ -z "$painters" ]; then
  echo "note — no CustomPainter subclasses found yet"
  exit 0
fi
echo "scanning painters:"; echo "$painters" | sed 's/^/  /'
status=0

# 1. shouldRepaint(...) => true  — repaints every frame. Hard fail.
hits=$(grep -HnE 'shouldRepaint\([^)]*\)\s*(=>|\{[^}]*return)\s*true' $painters 2>/dev/null || true)
if [ -n "$hits" ]; then echo "FAIL — shouldRepaint returns true (repaints every frame):"; echo "$hits"; status=1
else echo "ok — no shouldRepaint => true"; fi

# 2. Hard-coded directional signs — RTL bug. Hard fail in painter/chart files.
hits=$(grep -HnE 'Alignment\.(centerRight|centerLeft|topRight|topLeft|bottomRight|bottomLeft)|EdgeInsets\.only\((left|right):|\.left\b|\.right\b' $painters 2>/dev/null || true)
if [ -n "$hits" ]; then echo "FAIL — hard-coded left/right (use Directionality / *Directional):"; echo "$hits"; status=1
else echo "ok — no hard-coded left/right in painters"; fi

# 3. Skeleton / shimmer / spinner in chart files — forbidden (offline data is instant).
chartfiles=$(grep -lEi 'CustomPaint|CustomPainter|Sparkline|CostBar|PulseLine|heatmap' $darts 2>/dev/null || true)
if [ -n "$chartfiles" ]; then
  hits=$(grep -HnEi 'Shimmer|Skeleton|CircularProgressIndicator|LinearProgressIndicator' $chartfiles 2>/dev/null || true)
  if [ -n "$hits" ]; then echo "FAIL — skeleton/spinner in chart code (paint real data, no loaders):"; echo "$hits"; status=1
  else echo "ok — no skeleton/spinner in chart code"; fi
fi

# 4. WARN: CustomPaint without a nearby RepaintBoundary in the same file.
for f in $(grep -lE 'CustomPaint\(' $darts 2>/dev/null || true); do
  grep -q 'RepaintBoundary' "$f" || echo "WARN — CustomPaint without RepaintBoundary in $f"
done

# 5. WARN: CustomPaint without ExcludeSemantics/Semantics in the same file.
for f in $(grep -lE 'CustomPaint\(' $darts 2>/dev/null || true); do
  grep -qE 'ExcludeSemantics|Semantics\(' "$f" || echo "WARN — CustomPaint without Semantics/ExcludeSemantics in $f"
done

[ "$status" -eq 0 ] && echo "PASS — no hard violations (review any WARN above)" || echo "FOUND hard violations above"
exit "$status"
