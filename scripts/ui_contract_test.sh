#!/usr/bin/env bash
# Atlas Viewer API contract test.
# Assumes dev server is running (npm run ui:dev).
# Asserts semantic/contract gates; on failure prints diagnostic info.
# Exit non-zero on any failed assertion.

set -euo pipefail

ROOT="${ATLAS_RADAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BASE_URL="${ATLAS_UI_BASE_URL:-http://localhost:5173}"

fail() {
  echo "CONTRACT FAIL: $1"
  shift
  while [ $# -gt 0 ]; do
    echo "  $1"
    shift
  done
  exit 1
}

echo "=== UI Contract Test (dev server must be running) ==="

# Check server reachable
curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/atlas/" 2>/dev/null | grep -q 200 || \
  fail "Cannot reach dev server at ${BASE_URL}. Start with: npm run ui:dev"

# 1) GET /api/atlas returns JSON object with key "runs" as array
echo "Assert 1: /api/atlas returns { runs: [...] }"
ATLAS_RESP=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/atlas/" 2>/dev/null || true)
ATLAS_BODY=$(echo "$ATLAS_RESP" | sed '$d')
ATLAS_STATUS=$(echo "$ATLAS_RESP" | tail -1)
ATLAS_CT=$(curl -s -I "${BASE_URL}/api/atlas/" 2>/dev/null | grep -i "content-type" | head -1 || echo "Content-Type: (unknown)")

echo "$ATLAS_BODY" | jq -e '.runs | type == "array"' >/dev/null 2>&1 || \
  fail "runs must be array" "URL: ${BASE_URL}/api/atlas/" "status: $ATLAS_STATUS" "content-type: $ATLAS_CT" "body (first 120): $(echo "$ATLAS_BODY" | head -c 120)"

# 2) runs[0].run_id exists and is non-empty
echo "Assert 2: runs[0].run_id exists and non-empty"
RUN_ID=$(echo "$ATLAS_BODY" | jq -r '.runs[0].run_id // empty')
[ -n "$RUN_ID" ] || \
  fail "runs[0].run_id must exist and be non-empty" "URL: ${BASE_URL}/api/atlas/" "status: $ATLAS_STATUS" "content-type: $ATLAS_CT" "body (first 120): $(echo "$ATLAS_BODY" | head -c 120)"

echo "  Using run_id: $RUN_ID"

# 3) GET /api/atlas/<run_id>/render_meta.json returns 200 and Content-Type contains application/json
echo "Assert 3: render_meta.json 200 + application/json"
curl -s -D /tmp/contract_meta_headers.txt -o /tmp/contract_meta_body.json "${BASE_URL}/api/atlas/${RUN_ID}/render_meta.json" 2>/dev/null || true
META_BODY=$(cat /tmp/contract_meta_body.json 2>/dev/null || echo "")
META_STATUS=$(head -1 /tmp/contract_meta_headers.txt 2>/dev/null | awk '{print $2}' || echo "000")
META_CT=$(grep -i "content-type" /tmp/contract_meta_headers.txt 2>/dev/null | head -1 || echo "Content-Type: (unknown)")

[ "$META_STATUS" = "200" ] || \
  fail "render_meta.json must return 200" "URL: ${BASE_URL}/api/atlas/${RUN_ID}/render_meta.json" "status: $META_STATUS" "content-type: $META_CT" "body (first 120): $(echo "$META_BODY" | head -c 120)"
echo "$META_CT" | grep -qi "application/json" || \
  fail "render_meta.json Content-Type must contain application/json" "URL: ${BASE_URL}/api/atlas/${RUN_ID}/render_meta.json" "status: $META_STATUS" "content-type: $META_CT" "body (first 120): $(echo "$META_BODY" | head -c 120)"

# 4) GET /api/atlas/<run_id>/rendered_text.txt returns 200 and Content-Type contains text/plain
# 5) rendered_text.txt first non-whitespace char MUST NOT be "{"
echo "Assert 4-5: rendered_text.txt 200 + text/plain + body not JSON"
curl -s -D /tmp/contract_rendered_headers.txt -o /tmp/contract_rendered_body.txt "${BASE_URL}/api/atlas/${RUN_ID}/rendered_text.txt" 2>/dev/null || true
RENDERED_BODY=$(cat /tmp/contract_rendered_body.txt 2>/dev/null || echo "")
RENDERED_STATUS=$(head -1 /tmp/contract_rendered_headers.txt 2>/dev/null | awk '{print $2}' || echo "000")
RENDERED_CT=$(grep -i "content-type" /tmp/contract_rendered_headers.txt 2>/dev/null | head -1 || echo "Content-Type: (unknown)")
RENDERED_FIRST=$(echo "$RENDERED_BODY" | sed 's/^[[:space:]]*//' | head -c 1)

[ "$RENDERED_STATUS" = "200" ] || \
  fail "rendered_text.txt must return 200" "URL: ${BASE_URL}/api/atlas/${RUN_ID}/rendered_text.txt" "status: $RENDERED_STATUS" "content-type: $RENDERED_CT" "body (first 120): $(echo "$RENDERED_BODY" | head -c 120)"
echo "$RENDERED_CT" | grep -qi "text/plain" || \
  fail "rendered_text.txt Content-Type must contain text/plain" "URL: ${BASE_URL}/api/atlas/${RUN_ID}/rendered_text.txt" "status: $RENDERED_STATUS" "content-type: $RENDERED_CT" "body (first 120): $(echo "$RENDERED_BODY" | head -c 120)"
[ "$RENDERED_FIRST" != "{" ] || \
  fail "rendered_text.txt body first non-whitespace char must NOT be '{' (got JSON/runs list)" "URL: ${BASE_URL}/api/atlas/${RUN_ID}/rendered_text.txt" "status: $RENDERED_STATUS" "content-type: $RENDERED_CT" "body (first 120): $(echo "$RENDERED_BODY" | head -c 120)"

# 6) At least one run with items: KPI item_count >0 (independent of TG config)
echo "Assert 6: at least one run has item_count > 0 (pipeline not masked by TG)"
RUNS_WITH_ITEMS=$(echo "$ATLAS_BODY" | jq '[.runs[] | select((.item_count // 0) > 0)] | length')
[ "$RUNS_WITH_ITEMS" -gt 0 ] || \
  fail "At least one run must have item_count > 0" "Pipeline item_count must not be 0 due to TG missing" "Run atlas:run first to create a fixture"

echo "=== Contract Test PASS ==="
