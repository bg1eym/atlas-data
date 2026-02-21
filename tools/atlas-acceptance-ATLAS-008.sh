#!/usr/bin/env bash
# ATLAS-008 acceptance — preflight, regress, convergence, critical-tests, root discovery, atlas pipeline.
# Output: tools/_out/atlas-acceptance.json
# Exit 0 only if status in {ok,degraded} AND dashboard_url present.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT_DIR="${ROOT}/tools/_out"
OUT_JSON="${OUT_DIR}/atlas-acceptance.json"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"

mkdir -p "${OUT_DIR}"

# 1) Run gates
echo "=== Preflight ==="
bash "${ROOT}/.project-control/04-gates/preflight.sh" || { echo '{"status":"failed","failure_mode":"preflight"}' | jq . > "$OUT_JSON"; exit 1; }
echo ""
echo "=== Regress ==="
bash "${ROOT}/.project-control/04-gates/regress.sh" || { echo '{"status":"failed","failure_mode":"regress"}' | jq . > "$OUT_JSON"; exit 1; }
echo ""
echo "=== Convergence ==="
bash "${ROOT}/.project-control/04-gates/convergence.sh" || { echo '{"status":"failed","failure_mode":"convergence"}' | jq . > "$OUT_JSON"; exit 1; }
echo ""
echo "=== Critical tests ==="
bash "${ROOT}/.project-control/04-gates/critical-tests.sh" || { echo '{"status":"failed","failure_mode":"critical_tests"}' | jq . > "$OUT_JSON"; exit 1; }

# 2) Root discovery
echo ""
echo "=== Root discovery ==="
ATLAS_ROOT_VAL="${ATLAS_ROOT:-$ROOT}"
if [ ! -d "$ATLAS_ROOT_VAL" ] || [ ! -f "${ATLAS_ROOT_VAL}/package.json" ]; then
  DISCOVERY_OUT=$(bash "${ROOT}/tools/atlas-root-discovery.sh" 2>&1) || true
  if [ -f "${OUT_DIR}/atlas-root-discovery.json" ]; then
    ATLAS_ROOT_VAL=$(jq -r '.selected_root // empty' "${OUT_DIR}/atlas-root-discovery.json")
  fi
fi
[ -z "$ATLAS_ROOT_VAL" ] && ATLAS_ROOT_VAL="$ROOT"

# 3) Atlas pipeline via adapter simulate
echo ""
echo "=== Atlas pipeline (adapter simulate) ==="
PLUGIN_DIR=""
[ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ] && PLUGIN_DIR="$OC_BIND_ROOT"
[ -z "$PLUGIN_DIR" ] && [ -f "$OPENCLAW_JSON" ] && PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)
OC_LAB_ROOT=""
[ -n "$PLUGIN_DIR" ] && [ -d "$PLUGIN_DIR" ] && OC_LAB_ROOT="$(dirname "$PLUGIN_DIR")"

STATUS="failed"
RUN_ID=""
DASHBOARD_URL=""
FAILURE_MODE=""

if [ -n "$OC_LAB_ROOT" ] && [ -f "${PLUGIN_DIR}/atlas-today-simulate.ts" ]; then
  RESULT=$(cd "$OC_LAB_ROOT" && ATLAS_ROOT="${ATLAS_ROOT_VAL}" \
    ATLAS_DASHBOARD_URL_BASE="${ATLAS_DASHBOARD_URL_BASE:-https://example.com/dash}" \
    ATLAS_COVER_URL_BASE="${ATLAS_COVER_URL_BASE:-https://example.com/cover}" \
    npx tsx oc-bind/atlas-today-simulate.ts 2>/dev/null) || true
  OK=$(echo "$RESULT" | jq -r '.ok // false')
  RUN_ID=$(echo "$RESULT" | jq -r '.runId // ""')
  DASHBOARD_URL=$(echo "$RESULT" | jq -r '.dashboardUrl // ""')
  FAILURE_MODE=$(echo "$RESULT" | jq -r '.failure_mode // .error // ""')
  if [ "$OK" = "true" ]; then
    STATUS="degraded"
    [ -z "$FAILURE_MODE" ] && STATUS="ok"
  fi
else
  set +e
  cd "$ATLAS_ROOT_VAL" && PDF_EXTRACT_ALLOW_FALLBACK=1 pnpm run atlas:run 2>&1 | tail -5
  RC=$?
  set -e
  if [ $RC -eq 0 ]; then
    LATEST=$(ls -td "${ATLAS_ROOT_VAL}/out/atlas"/atlas-* 2>/dev/null | head -1)
    if [ -n "$LATEST" ] && [ -f "${LATEST}/result.json" ]; then
      RUN_ID=$(jq -r '.run_id // ""' "${LATEST}/result.json")
      DASHBOARD_URL="${ATLAS_DASHBOARD_URL_BASE:-https://example.com/dash}"
      [[ "$DASHBOARD_URL" == *"{{run_id}}"* ]] && DASHBOARD_URL="${DASHBOARD_URL//\{\{run_id\}\}/$RUN_ID}"
      [[ "$DASHBOARD_URL" != *"run_id"* ]] && DASHBOARD_URL="${DASHBOARD_URL}?run_id=${RUN_ID}"
      STATUS="ok"
    fi
  fi
fi

jq -n \
  --arg atlas_root "$ATLAS_ROOT_VAL" \
  --arg run_id "$RUN_ID" \
  --arg dashboard_url "$DASHBOARD_URL" \
  --arg status "$STATUS" \
  --arg failure_mode "$FAILURE_MODE" \
  '{ atlas_root: $atlas_root, run_id: $run_id, dashboard_url: $dashboard_url, status: $status, failure_mode: $failure_mode }' > "$OUT_JSON"

echo ""
echo "=== Acceptance output ==="
cat "$OUT_JSON"

if [ "$STATUS" != "ok" ] && [ "$STATUS" != "degraded" ]; then
  echo "ACCEPTANCE FAIL: status=$STATUS"
  exit 1
fi

if [ -z "$DASHBOARD_URL" ]; then
  echo "ACCEPTANCE FAIL: dashboard_url missing"
  exit 1
fi

echo "ACCEPTANCE PASS: status=$STATUS, dashboard_url present"
exit 0
