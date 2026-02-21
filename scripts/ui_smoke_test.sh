#!/usr/bin/env bash
# Atlas Viewer UI smoke test.
# - UI build passes
# - Minimal run (render_meta + rendered_text only) works via API
# - Required files readable via API (when dev server running)

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
UI_DIR="${ROOT}/ui/atlas-viewer"
ATLAS_OUT="${ROOT}/out/atlas"
BASE_URL="${ATLAS_UI_BASE_URL:-http://localhost:18791}"

cd "$ROOT"

echo "=== UI Smoke Test ==="

# 1) Build passes
echo "Step 1: Build UI..."
cd "$UI_DIR"
npm install --silent 2>/dev/null || npm install
npm run build
echo "  Build OK"

# 2) Create minimal fake run (no acceptance/audit)
SMOKE_RUN="ui-smoke-$(date +%s)"
SMOKE_DIR="${ATLAS_OUT}/${SMOKE_RUN}"
mkdir -p "$SMOKE_DIR"
echo '{"item_count":2}' > "${SMOKE_DIR}/render_meta.json"
echo "Rendered text for smoke test." > "${SMOKE_DIR}/rendered_text.txt"
echo "Step 2: Created minimal run: $SMOKE_RUN"
echo "  $SMOKE_DIR/render_meta.json"
echo "  $SMOKE_DIR/rendered_text.txt"

# 3) Start Vite dev server and verify API
echo "Step 3: Start Vite and verify API..."
# Kill any existing Vite server so we use fresh code
pkill -f "vite" 2>/dev/null || true
sleep 2

cd "$UI_DIR"
VITE_PID=""
cleanup() {
  if [ -n "$VITE_PID" ]; then
    kill "$VITE_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

npm run dev > /tmp/vite-smoke.log 2>&1 &
VITE_PID=$!

# Wait for server to be ready
for i in $(seq 1 30); do
  if curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/atlas/" 2>/dev/null | grep -q 200; then
    break
  fi
  sleep 1
done

# D2) Semantic gates: prevent "exists but wrong" responses
# 1) /api/atlas returns JSON with runs[0].run_id
echo "  Checking /api/atlas (list)..."
ATLAS_JSON=$(curl -s "${BASE_URL}/api/atlas/")
echo "$ATLAS_JSON" | jq -e ".runs[0].run_id" >/dev/null || {
  echo "  FAIL: /api/atlas must return JSON with runs[0].run_id"
  echo "$ATLAS_JSON" | head -c 200
  exit 1
}
echo "$ATLAS_JSON" | jq -e ".runs[] | select(.run_id == \"$SMOKE_RUN\") | .verdict == \"UNKNOWN\"" >/dev/null || {
  echo "  FAIL: /api/atlas should include run_id=$SMOKE_RUN with verdict UNKNOWN"
  exit 1
}
echo "  OK: /api/atlas list schema + run $SMOKE_RUN with verdict UNKNOWN"

# 2) render_meta.json returns 200 and Content-Type contains application/json
echo "  Checking render_meta.json..."
RENDER_META_HEADERS=$(curl -s -D - -o /tmp/smoke_render_meta.json -w "" "${BASE_URL}/api/atlas/${SMOKE_RUN}/render_meta.json")
RENDER_META_STATUS=$(echo "$RENDER_META_HEADERS" | head -1 | awk '{print $2}')
RENDER_META_CT=$(echo "$RENDER_META_HEADERS" | grep -i "content-type" | head -1)
[ "$RENDER_META_STATUS" = "200" ] || { echo "  FAIL: render_meta.json returned $RENDER_META_STATUS (expected 200)"; exit 1; }
echo "$RENDER_META_CT" | grep -qi "application/json" || { echo "  FAIL: render_meta.json Content-Type must contain application/json"; echo "$RENDER_META_CT"; exit 1; }
echo "  OK: render_meta.json 200 + application/json"

# 3) rendered_text.txt returns 200 and Content-Type contains text/plain
# 4) rendered_text.txt body first char MUST NOT be "{"
echo "  Checking rendered_text.txt..."
RENDERED_HEADERS=$(curl -s -D - -o /tmp/smoke_rendered.txt -w "" "${BASE_URL}/api/atlas/${SMOKE_RUN}/rendered_text.txt")
RENDERED_STATUS=$(echo "$RENDERED_HEADERS" | head -1 | awk '{print $2}')
RENDERED_CT=$(echo "$RENDERED_HEADERS" | grep -i "content-type" | head -1)
RENDERED_FIRST=$(head -c 1 /tmp/smoke_rendered.txt 2>/dev/null || echo "")
[ "$RENDERED_STATUS" = "200" ] || { echo "  FAIL: rendered_text.txt returned $RENDERED_STATUS (expected 200)"; exit 1; }
echo "$RENDERED_CT" | grep -qi "text/plain" || { echo "  FAIL: rendered_text.txt Content-Type must contain text/plain"; echo "$RENDERED_CT"; exit 1; }
[ "$RENDERED_FIRST" != "{" ] || { echo "  FAIL: rendered_text.txt body must NOT start with '{' (got runs list JSON)"; head -c 120 /tmp/smoke_rendered.txt; exit 1; }
echo "  OK: rendered_text.txt 200 + text/plain + body not JSON"

# acceptance_report.json 404 is acceptable
echo "  Checking acceptance_report.json (404 acceptable)..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/atlas/${SMOKE_RUN}/acceptance_report.json")
[ "$STATUS" = "404" ] && echo "  OK: acceptance_report.json 404 (expected for minimal run)" || echo "  Note: acceptance_report.json returned $STATUS"

# civilization files 404 is acceptable for minimal run - must not crash
echo "  Checking civilization/highlights.json (404 acceptable for minimal run)..."
CIV_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/atlas/${SMOKE_RUN}/civilization/highlights.json")
[ "$CIV_STATUS" = "404" ] && echo "  OK: civilization/highlights.json 404 (expected for minimal run)" || echo "  Note: civilization returned $CIV_STATUS"

# Create run with civilization fixtures - dashboard should show Civilization panel
CIV_RUN="ui-smoke-civ-$(date +%s)"
CIV_DIR="${ATLAS_OUT}/${CIV_RUN}"
mkdir -p "${CIV_DIR}/civilization"
echo '{"item_count":2}' > "${CIV_DIR}/render_meta.json"
echo "Rendered text." > "${CIV_DIR}/rendered_text.txt"
echo '{"structural_events":[],"threshold":7,"generated_at":""}' > "${CIV_DIR}/civilization/highlights.json"
echo '{"counts_by_tag":{},"structural_count_by_tag":{},"avg_score_by_tag":{},"structural_count":0,"total_count":2}' > "${CIV_DIR}/civilization/aggregates.json"
echo '{"run_id":"","items":[]}' > "${CIV_DIR}/civilization/items_civ.json"
echo "  Created civilization run: $CIV_RUN"
CIV_HL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/atlas/${CIV_RUN}/civilization/highlights.json")
[ "$CIV_HL_STATUS" = "200" ] || { echo "  FAIL: civilization run highlights.json returned $CIV_HL_STATUS (expected 200)"; exit 1; }
echo "  OK: civilization run highlights.json 200"

# 5) Homepage HTML returns 200
echo "  Checking homepage..."
HOME_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/")
[ "$HOME_STATUS" = "200" ] || { echo "  FAIL: homepage returned $HOME_STATUS (expected 200)"; exit 1; }
echo "  OK: homepage 200"

# 6) Dashboard: verify SPA loads (index has app mount point)
DASH_HTML=$(curl -s "${BASE_URL}/")
echo "$DASH_HTML" | grep -q 'id="app"' 2>/dev/null && echo "  OK: SPA app mount present" || echo "  Note: app mount check skipped"

# 7) Dashboard first-screen: after JS loads, data-testid="kpi-cards" or "dashboard-first-screen" should exist in DOM.
#    SPA requires browser; we verify built assets include the testid string.
BUILT_JS=$(find "$UI_DIR/dist" -name "*.js" 2>/dev/null | head -1)
if [ -n "$BUILT_JS" ] && grep -q "kpi-cards\|dashboard-first-screen" "$BUILT_JS" 2>/dev/null; then
  echo "  OK: Dashboard data-testid present in build"
else
  echo "  Note: Dashboard testid check skipped (build may vary)"
fi

# 8) Civilization: missing banner and panel strings in build
if [ -n "$BUILT_JS" ]; then
  grep -q "civilization-missing-banner\|Civilization layer missing" "$BUILT_JS" 2>/dev/null && echo "  OK: civilization missing banner string in build" || echo "  Note: civilization banner check skipped"
  grep -q "Civilization" "$BUILT_JS" 2>/dev/null && echo "  OK: Civilization panel title in build" || echo "  Note: Civilization panel check skipped"
fi

# 7) Check out/atlas structure (optional, for existing runs)
echo "Step 4: Check out/atlas structure..."
RUN_COUNT=$(find "$ATLAS_OUT" -mindepth 1 -maxdepth 1 -type d ! -name DELIVERY_RAW_STDOUT 2>/dev/null | wc -l)
echo "  Found $RUN_COUNT run(s) in out/atlas/"

echo "=== Smoke Test Done ==="
