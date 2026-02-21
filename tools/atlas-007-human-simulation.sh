#!/usr/bin/env bash
# ATLAS-007: Human-Simulation Convergence Validation
# Simulates real user behavior; outputs tools/_out/atlas-007-evidence.json

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT_DIR="${ROOT}/tools/_out"
EVIDENCE_JSON="${OUT_DIR}/atlas-007-evidence.json"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
CONTEXT_JSON="${ROOT}/.project-control/iteration-context.json"

mkdir -p "${OUT_DIR}"

# Resolve oc-bind
PLUGIN_DIR=""
[ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ] && PLUGIN_DIR="$OC_BIND_ROOT"
[ -z "$PLUGIN_DIR" ] && [ -f "$OPENCLAW_JSON" ] && PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)
OC_LAB_ROOT=""
[ -n "$PLUGIN_DIR" ] && [ -d "$PLUGIN_DIR" ] && OC_LAB_ROOT="$(dirname "$PLUGIN_DIR")"

ATLAS_ROOT_VAL="${ATLAS_ROOT:-$ROOT}"
PREVIOUS_FAILURE_MODE=""
[ -f "$CONTEXT_JSON" ] && PREVIOUS_FAILURE_MODE=$(jq -r '.prior_failure_mode // ""' "$CONTEXT_JSON" 2>/dev/null || true)

# --- 1A: Telegram Debug Simulation ---
TELEGRAM_DEBUG_OK=false
TELEGRAM_DEBUG_RAW=""
TELEGRAM_DEBUG_FAILURE=""

if [ -n "$OC_LAB_ROOT" ] && [ -d "$OC_LAB_ROOT" ] && [ -f "${PLUGIN_DIR}/atlas-debug-simulate.ts" ]; then
  TELEGRAM_DEBUG_RAW=$(cd "$OC_LAB_ROOT" && ATLAS_ROOT="${ATLAS_ROOT_VAL}" npx tsx oc-bind/atlas-debug-simulate.ts 2>&1) || true
  if echo "$TELEGRAM_DEBUG_RAW" | grep -q "build:" && \
     echo "$TELEGRAM_DEBUG_RAW" | grep -q "process_execPath:" && \
     echo "$TELEGRAM_DEBUG_RAW" | grep -q "atlas_root_exists:" && \
     echo "$TELEGRAM_DEBUG_RAW" | grep -q "atlas_root_has_pkg_json:" && \
     echo "$TELEGRAM_DEBUG_RAW" | grep -q "pnpm_version_probe:"; then
    if echo "$TELEGRAM_DEBUG_RAW" | grep -q "atlas_root_exists: true" && \
       echo "$TELEGRAM_DEBUG_RAW" | grep -q "atlas_root_has_pkg_json: true" && \
       echo "$TELEGRAM_DEBUG_RAW" | grep -qE "pnpm_version_probe: ok:"; then
      TELEGRAM_DEBUG_OK=true
    else
      TELEGRAM_DEBUG_FAILURE="debug_fields_present_but_validation_failed"
    fi
  else
    TELEGRAM_DEBUG_FAILURE="missing_required_debug_fields"
  fi
else
  TELEGRAM_DEBUG_FAILURE="oc_bind_or_simulate_not_found"
fi

# --- 1B: Telegram Today Simulation (runAtlasToday) ---
TELEGRAM_TODAY_OK=false
TELEGRAM_TODAY_RAW=""
TELEGRAM_TODAY_FAILURE=""

if [ -n "$ATLAS_ROOT_VAL" ] && [ -d "$ATLAS_ROOT_VAL" ]; then
  if [ -n "$OC_LAB_ROOT" ] && [ -d "$OC_LAB_ROOT" ] && [ -f "${PLUGIN_DIR}/atlas-today-simulate.ts" ]; then
    TODAY_OUT=$(mktemp)
    set +e
    TODAY_JSON=$(cd "$OC_LAB_ROOT" && ATLAS_ROOT="${ATLAS_ROOT_VAL}" \
      ATLAS_DASHBOARD_URL_BASE="${ATLAS_DASHBOARD_URL_BASE:-https://example.com/dash}" \
      ATLAS_COVER_URL_BASE="${ATLAS_COVER_URL_BASE:-https://example.com/cover}" \
      npx tsx oc-bind/atlas-today-simulate.ts 2>"$TODAY_OUT")
    TODAY_RC=$?
    TELEGRAM_TODAY_RAW=$(cat "$TODAY_OUT" 2>/dev/null)
    rm -f "$TODAY_OUT"
    set -e
    if [ $TODAY_RC -eq 0 ] && [ -n "$TODAY_JSON" ]; then
      if echo "$TODAY_JSON" | jq -e '.ok == true' >/dev/null 2>&1; then
        TELEGRAM_TODAY_OK=true
      elif echo "$TODAY_JSON" | grep -q "ENOENT"; then
        TELEGRAM_TODAY_FAILURE="raw_ENOENT_in_output"
      elif echo "$TODAY_JSON" | jq -e '.error' >/dev/null 2>&1; then
        TELEGRAM_TODAY_FAILURE=$(echo "$TODAY_JSON" | jq -r '.error // "unknown"')
      else
        TELEGRAM_TODAY_FAILURE="pipeline_failed"
      fi
    else
      if echo "$TELEGRAM_TODAY_RAW" | grep -qi "ENOENT"; then
        TELEGRAM_TODAY_FAILURE="raw_ENOENT"
      else
        TELEGRAM_TODAY_FAILURE="run_failed"
      fi
    fi
  else
    # Fallback: direct pnpm run atlas:run
    set +e
    cd "$ATLAS_ROOT_VAL" && pnpm run atlas:run >/dev/null 2>&1
    DIRECT_RC=$?
    set -e
    if [ $DIRECT_RC -eq 0 ]; then
      TELEGRAM_TODAY_OK=true
    else
      TELEGRAM_TODAY_FAILURE="atlas_run_exit_${DIRECT_RC}"
    fi
  fi
else
  TELEGRAM_TODAY_FAILURE="ATLAS_ROOT_invalid"
fi

# --- 1C: Launchd Reality Check ---
LAUNCHD_CONSISTENT=true
LAUNCHD_NODE=""
DEBUG_EXECPATH=""

if [ -n "$TELEGRAM_DEBUG_RAW" ]; then
  DEBUG_EXECPATH=$(echo "$TELEGRAM_DEBUG_RAW" | grep "process_execPath:" | sed 's/.*process_execPath: *//' | tr -d ' ')
fi

LAUNCHD_OUT=$(launchctl print "gui/$(id -u)/ai.openclaw.gateway" 2>/dev/null || true)
if [ -n "$LAUNCHD_OUT" ]; then
  LAUNCHD_NODE=$(echo "$LAUNCHD_OUT" | grep -E "program = |executable" | head -1 | sed 's/.*= *//' | tr -d ' ' || true)
  if [ -n "$LAUNCHD_NODE" ] && [ -n "$DEBUG_EXECPATH" ]; then
    if [ "$LAUNCHD_NODE" != "$DEBUG_EXECPATH" ]; then
      LAUNCHD_CONSISTENT=false
    fi
  fi
fi

# --- 1D: Direct Atlas Execution ---
ATLAS_PIPELINE_OK=false
if [ -n "$ATLAS_ROOT_VAL" ] && [ -d "$ATLAS_ROOT_VAL" ]; then
  set +e
  cd "$ATLAS_ROOT_VAL" && pnpm run atlas:run >/dev/null 2>&1
  DIRECT_RC=$?
  set -e
  [ $DIRECT_RC -eq 0 ] && ATLAS_PIPELINE_OK=true
fi

# --- 2: Convergence Analysis ---
REPEATED_FAILURE=false
NEW_FAILURE_MODE=""
CONVERGENCE_STATUS="converged"

if [ "$TELEGRAM_DEBUG_OK" = false ] || [ "$TELEGRAM_TODAY_OK" = false ] || [ "$LAUNCHD_CONSISTENT" = false ] || [ "$ATLAS_PIPELINE_OK" = false ]; then
  CONVERGENCE_STATUS="failed"
  if [ -n "$TELEGRAM_DEBUG_FAILURE" ]; then
    NEW_FAILURE_MODE="$TELEGRAM_DEBUG_FAILURE"
  fi
  if [ -n "$TELEGRAM_TODAY_FAILURE" ]; then
    [ -n "$NEW_FAILURE_MODE" ] && NEW_FAILURE_MODE="${NEW_FAILURE_MODE};"
    NEW_FAILURE_MODE="${NEW_FAILURE_MODE}${TELEGRAM_TODAY_FAILURE}"
  fi
  if [ "$LAUNCHD_CONSISTENT" = false ]; then
    [ -n "$NEW_FAILURE_MODE" ] && NEW_FAILURE_MODE="${NEW_FAILURE_MODE};"
    NEW_FAILURE_MODE="${NEW_FAILURE_MODE}ENVIRONMENT_INCONSISTENT"
  fi
  if [ "$ATLAS_PIPELINE_OK" = false ]; then
    [ -n "$NEW_FAILURE_MODE" ] && NEW_FAILURE_MODE="${NEW_FAILURE_MODE};"
    NEW_FAILURE_MODE="${NEW_FAILURE_MODE}ATLAS_PIPELINE_FAILED"
  fi
  if [ -n "$PREVIOUS_FAILURE_MODE" ] && [ "$PREVIOUS_FAILURE_MODE" != "OK" ] && echo "$NEW_FAILURE_MODE" | grep -q "$PREVIOUS_FAILURE_MODE"; then
    REPEATED_FAILURE=true
    CONVERGENCE_STATUS="partial"
  fi
else
  CONVERGENCE_STATUS="converged"
fi

# --- 3: Evidence Output ---
jq -n \
  --argjson debug_ok "$([ "$TELEGRAM_DEBUG_OK" = true ] && echo true || echo false)" \
  --argjson today_ok "$([ "$TELEGRAM_TODAY_OK" = true ] && echo true || echo false)" \
  --argjson launchd_ok "$([ "$LAUNCHD_CONSISTENT" = true ] && echo true || echo false)" \
  --argjson pipeline_ok "$([ "$ATLAS_PIPELINE_OK" = true ] && echo true || echo false)" \
  --argjson repeated "$([ "$REPEATED_FAILURE" = true ] && echo true || echo false)" \
  --arg new_failure "$NEW_FAILURE_MODE" \
  --arg status "$CONVERGENCE_STATUS" \
  --arg debug_fail "$TELEGRAM_DEBUG_FAILURE" \
  --arg today_fail "$TELEGRAM_TODAY_FAILURE" \
  --arg prev_fail "$PREVIOUS_FAILURE_MODE" \
  '{
    telegram_debug_ok: $debug_ok,
    telegram_today_ok: $today_ok,
    launchd_consistent: $launchd_ok,
    atlas_pipeline_ok: $pipeline_ok,
    repeated_failure: $repeated,
    new_failure_mode: $new_failure,
    convergence_status: $status,
    telegram_debug_failure: $debug_fail,
    telegram_today_failure: $today_fail,
    previous_failure_mode: $prev_fail
  }' > "$EVIDENCE_JSON"

echo "=== ATLAS-007 Evidence ==="
cat "$EVIDENCE_JSON"
echo ""

if [ "$CONVERGENCE_STATUS" != "converged" ]; then
  echo "ATLAS-007: convergence_status=$CONVERGENCE_STATUS (regress will FAIL)"
  exit 1
fi
echo "ATLAS-007: convergence_status=converged"
exit 0
