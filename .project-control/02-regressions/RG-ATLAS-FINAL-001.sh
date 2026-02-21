#!/usr/bin/env bash
# RG-ATLAS-FINAL-001: Atlas final — no radar, critical-tests in sparse PATH.
# Static: forbid radar strings.
# Dynamic: env -i PATH minimal → critical-tests; classification must exist; failure_mode OK or ENV_MISSING or ROOT_MISSING (not UNKNOWN when unconfigured).

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ACTF_SIM_PATH="${ACTF_SIM_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
CRITICAL="${ROOT}/.project-control/04-gates/critical-tests.sh"
CLASS_FILE="${ROOT}/.project-control/07-critical-tests/_out/classification.json"

# Static: forbid radar strings
FORBIDDEN=("radar:run" "OPENCLAW_ROOT" "/atlas radar" "radar_daily" "ACTION_RADAR" "Atlas Radar")
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
PLUGIN_DIR=""
if [ -n "${OC_BIND_ROOT}" ] && [ -d "$OC_BIND_ROOT" ]; then
  PLUGIN_DIR="$OC_BIND_ROOT"
elif [ -f "$OPENCLAW_JSON" ]; then
  PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)
fi

if [ -n "$PLUGIN_DIR" ] && [ -d "$PLUGIN_DIR" ]; then
  for pat in "${FORBIDDEN[@]}"; do
    if grep -rn "$pat" "$PLUGIN_DIR" 2>/dev/null; then
      echo "RG-ATLAS-FINAL-001 FAIL: forbidden string '$pat' in $PLUGIN_DIR" >&2
      exit 1
    fi
  done
fi

# Also check atlas-radar runtime
RUNTIME="${ROOT}/runtime/atlas"
if [ -d "$RUNTIME" ]; then
  for pat in "${FORBIDDEN[@]}"; do
    if grep -rn "$pat" "$RUNTIME" 2>/dev/null; then
      echo "RG-ATLAS-FINAL-001 FAIL: forbidden string '$pat' in runtime" >&2
      exit 1
    fi
  done
fi

# Dynamic: run critical-tests (sparse PATH for child; need node for classifier)
# Add node dir to PATH so classifier can run; execution-sim uses env -i internally
NODE_DIR=""
if [ -n "${NODE_BIN:-}" ] && [ -x "${NODE_BIN}" ]; then
  NODE_DIR=$(dirname "$NODE_BIN")
fi
[ -z "$NODE_DIR" ] && [ -x "/opt/homebrew/bin/node" ] && NODE_DIR="/opt/homebrew/bin"
export PATH="${ACTF_SIM_PATH}${NODE_DIR:+:$NODE_DIR}"
export PCK_ROOT="${ROOT}"
unset ACTF_CMD 2>/dev/null || true
cd "${ROOT}"

if ! "$CRITICAL" 1>/dev/null 2>&1; then
  echo "RG-ATLAS-FINAL-001: critical-tests failed (may be expected if ATLAS_* unset)" >&2
fi

# classification.json must exist
if [ ! -f "$CLASS_FILE" ]; then
  echo "RG-ATLAS-FINAL-001 FAIL: classification.json not found" >&2
  exit 1
fi

# failure_mode must be OK, ENV_MISSING, or ROOT_MISSING (not UNKNOWN when unconfigured)
MODE=$(python3 -c "import json; print(json.load(open('$CLASS_FILE')).get('failure_mode',''))" 2>/dev/null || echo "")
if [ -z "$MODE" ]; then
  echo "RG-ATLAS-FINAL-001 FAIL: classification.json missing failure_mode" >&2
  exit 1
fi

# When ATLAS_ROOT is not set, UNKNOWN is not acceptable
if [ -z "${ATLAS_ROOT:-}" ]; then
  case "$MODE" in
    OK|ENV_MISSING|ROOT_MISSING) ;;
    *)
      echo "RG-ATLAS-FINAL-001 FAIL: when ATLAS_* unset, failure_mode must be OK/ENV_MISSING/ROOT_MISSING, got: $MODE" >&2
      exit 1
      ;;
  esac
fi

echo "RG-ATLAS-FINAL-001 PASS"
