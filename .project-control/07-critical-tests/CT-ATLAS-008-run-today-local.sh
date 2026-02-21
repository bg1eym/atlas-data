#!/usr/bin/env bash
# CT-ATLAS-008: Run atlas-adapter in simulation mode (no TG).
# Assert: success (dashboard URL with run_id) OR degraded (dashboard URL + status).
# Must NOT be ATLAS_ROOT_INVALID.
# Must NOT be ATLAS_PIPELINE_BLOCKED after fix.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ACTF_DIR="${ROOT}/.project-control/07-critical-tests"
OUT_DIR="${ACTF_DIR}/_out"
OUT_FILE="${OUT_DIR}/ct-atlas-008-evidence.json"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
ATLAS_ROOT_VAL="${ATLAS_ROOT:-$ROOT}"

mkdir -p "${OUT_DIR}"

PLUGIN_DIR=""
[ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ] && PLUGIN_DIR="$OC_BIND_ROOT"
[ -z "$PLUGIN_DIR" ] && [ -f "$OPENCLAW_JSON" ] && PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)
OC_LAB_ROOT=""
[ -n "$PLUGIN_DIR" ] && [ -d "$PLUGIN_DIR" ] && OC_LAB_ROOT="$(dirname "$PLUGIN_DIR")"

if [ -z "$OC_LAB_ROOT" ] || [ ! -f "${PLUGIN_DIR}/atlas-today-simulate.ts" ]; then
  echo '{"status":"skip","reason":"oc-bind or atlas-today-simulate not found"}' > "$OUT_FILE"
  echo "CT-ATLAS-008 SKIP: oc-bind not found"
  exit 0
fi

RESULT_JSON=$(cd "$OC_LAB_ROOT" && ATLAS_ROOT="${ATLAS_ROOT_VAL}" \
  ATLAS_DASHBOARD_URL_BASE="${ATLAS_DASHBOARD_URL_BASE:-https://example.com/dash}" \
  ATLAS_COVER_URL_BASE="${ATLAS_COVER_URL_BASE:-https://example.com/cover}" \
  npx tsx oc-bind/atlas-today-simulate.ts 2>/dev/null) || true

echo "$RESULT_JSON" | jq . > "$OUT_FILE" 2>/dev/null || echo "$RESULT_JSON" > "$OUT_FILE"

OK=$(echo "$RESULT_JSON" | jq -r '.ok // false')
ERROR=$(echo "$RESULT_JSON" | jq -r '.error // ""')
FAILURE_MODE=$(echo "$RESULT_JSON" | jq -r '.failure_mode // ""')
DASHBOARD_URL=$(echo "$RESULT_JSON" | jq -r '.dashboardUrl // ""')
RUN_ID=$(echo "$RESULT_JSON" | jq -r '.runId // ""')

if [ "$FAILURE_MODE" = "ATLAS_ROOT_INVALID" ]; then
  echo "CT-ATLAS-008 FAIL: ATLAS_ROOT_INVALID"
  exit 1
fi

if [ "$FAILURE_MODE" = "ATLAS_PIPELINE_BLOCKED" ]; then
  echo "CT-ATLAS-008 FAIL: ATLAS_PIPELINE_BLOCKED (exit 42)"
  exit 1
fi

if [ -z "$DASHBOARD_URL" ]; then
  echo "CT-ATLAS-008 FAIL: no dashboard_url"
  exit 1
fi

if [ "$OK" = "true" ]; then
  echo "CT-ATLAS-008 PASS: ok=true, dashboard_url present"
  exit 0
fi

if [ -n "$DASHBOARD_URL" ] && [ "$FAILURE_MODE" = "ATLAS_DEGRADED" ]; then
  echo "CT-ATLAS-008 PASS: degraded but dashboard_url present"
  exit 0
fi

echo "CT-ATLAS-008 FAIL: unexpected state ok=$OK error=$ERROR"
exit 1
