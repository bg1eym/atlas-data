#!/usr/bin/env bash
# Atlas Final Activation Audit — Evidence-based root cause for TG/launchd issues.
# Output: tools/_out/atlas-activation-audit.json (stdout sync)
# No guessing; evidence must drive conclusion.root_cause.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT_DIR="${ROOT}/tools/_out"
OUT_FILE="${OUT_DIR}/atlas-activation-audit.json"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
GATEWAY_LOG="${GATEWAY_LOG:-$HOME/.openclaw/logs/gateway.log}"
ACTF_SIM_PATH="${ACTF_SIM_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"

mkdir -p "${OUT_DIR}"

# A) openclaw.json plugin path
PLUGIN_PATH=""
if [ -f "$OPENCLAW_JSON" ]; then
  PLUGIN_PATH=$(jq -r '.plugins.installs["oc-bind"].installPath // .plugins.installs["oc-bind"].sourcePath // .plugins.load.paths[0] // empty' "$OPENCLAW_JSON" 2>/dev/null || echo "")
fi

# B) launchd plist env (key presence only) — plist format varies, default {}
PLIST_ENV_JSON="{}"

# C) gateway.log — last 200 lines matching [oc-bind] atlas:
GATEWAY_ATLAS_JSON="[]"
if [ -f "$GATEWAY_LOG" ]; then
  GATEWAY_ATLAS_JSON=$(tail -200 "$GATEWAY_LOG" 2>/dev/null | grep -E '\[oc-bind\].*atlas:' 2>/dev/null | tail -20 | python3 -c "import sys,json; print(json.dumps([l.strip()[:500] for l in sys.stdin]))" 2>/dev/null || echo "[]")
fi

# D) Runtime probes
ATLAS_ROOT_VAL="${ATLAS_ROOT:-}"
NODE_BIN_VAL="${NODE_BIN:-/opt/homebrew/bin/node}"
PNPM_JS_VAL="${PNPM_JS:-/opt/homebrew/lib/node_modules/pnpm/bin/pnpm.cjs}"

NODE_EXISTS=false
NODE_EXECUTABLE=false
[ -n "$NODE_BIN_VAL" ] && [ -f "$NODE_BIN_VAL" ] && NODE_EXISTS=true && [ -x "$NODE_BIN_VAL" ] && NODE_EXECUTABLE=true

PNPM_EXISTS=false
[ -n "$PNPM_JS_VAL" ] && [ -f "$PNPM_JS_VAL" ] && PNPM_EXISTS=true

ATLAS_ROOT_EXISTS=false
ATLAS_ROOT_HAS_PKG=false
[ -n "$ATLAS_ROOT_VAL" ] && [ -d "$ATLAS_ROOT_VAL" ] && ATLAS_ROOT_EXISTS=true && [ -f "${ATLAS_ROOT_VAL}/package.json" ] && ATLAS_ROOT_HAS_PKG=true

# env -i sparse PATH: node <pnpm.cjs> -v
SPARSE_EXIT=127
SPARSE_STDERR=""
if [ "$NODE_EXISTS" = true ] && [ "$PNPM_EXISTS" = true ]; then
  TMP_ERR=$(mktemp)
  set +e
  env -i "PATH=${ACTF_SIM_PATH}" "$NODE_BIN_VAL" "$PNPM_JS_VAL" -v 1>/dev/null 2>"$TMP_ERR"
  SPARSE_EXIT=$?
  SPARSE_STDERR=$(head -c 500 "$TMP_ERR")
  set -e
  rm -f "$TMP_ERR"
fi

# Conclusion
ROOT_CAUSE="UNKNOWN"
NEXT_FIX=""

if [ -z "$ATLAS_ROOT_VAL" ]; then
  ROOT_CAUSE="ROOT_WRONG"
  NEXT_FIX="Set ATLAS_ROOT to atlas-radar project root"
elif [ "$ATLAS_ROOT_EXISTS" = false ]; then
  ROOT_CAUSE="ROOT_WRONG"
  NEXT_FIX="ATLAS_ROOT path does not exist; set to valid atlas-radar root"
elif [ "$NODE_EXISTS" = false ] || [ "$NODE_EXECUTABLE" = false ]; then
  ROOT_CAUSE="NODE_NOT_EXECUTABLE"
  NEXT_FIX="Set NODE_BIN to executable node path; ensure launchd plist has EnvironmentVariables"
elif [ "$PNPM_EXISTS" = false ]; then
  ROOT_CAUSE="PNPM_NOT_EXECUTABLE"
  NEXT_FIX="Set PNPM_JS to pnpm.cjs path"
elif [ "$SPARSE_EXIT" -ne 0 ]; then
  if echo "$SPARSE_STDERR" | grep -qi "enoent\|command not found"; then
    ROOT_CAUSE="LAUNCHD_ENV_NOT_APPLIED"
    NEXT_FIX="launchd EnvironmentVariables not applied; add NODE_BIN/PNPM_JS to plist"
  else
    ROOT_CAUSE="LAUNCHD_ENV_NOT_APPLIED"
    NEXT_FIX="Sparse PATH execution failed"
  fi
else
  ROOT_CAUSE="OK"
  NEXT_FIX=""
fi

# Use env to pass vars (avoid escaping)
export ATLAS_AUDIT_OUT="$OUT_FILE"
export ATLAS_AUDIT_PLUGIN="$PLUGIN_PATH"
export ATLAS_AUDIT_PLIST="$PLIST_ENV_JSON"
export ATLAS_AUDIT_GATEWAY="$GATEWAY_ATLAS_JSON"
export ATLAS_AUDIT_NODE_EXISTS="$NODE_EXISTS"
export ATLAS_AUDIT_NODE_EXEC="$NODE_EXECUTABLE"
export ATLAS_AUDIT_PNPM_EXISTS="$PNPM_EXISTS"
export ATLAS_AUDIT_ROOT_EXISTS="$ATLAS_ROOT_EXISTS"
export ATLAS_AUDIT_ROOT_PKG="$ATLAS_ROOT_HAS_PKG"
export ATLAS_AUDIT_SPARSE_EXIT="$SPARSE_EXIT"
export ATLAS_AUDIT_SPARSE_ERR="$SPARSE_STDERR"
export ATLAS_AUDIT_RC="$ROOT_CAUSE"
export ATLAS_AUDIT_FIX="$NEXT_FIX"

python3 -c "
import json, os
def safe_json(s, default):
    try:
        return json.loads(s) if s else default
    except: return default
j = {
  'plugin_path': os.environ.get('ATLAS_AUDIT_PLUGIN', ''),
  'plist_env_present': safe_json(os.environ.get('ATLAS_AUDIT_PLIST',''), {}),
  'gateway_atlas_logs': safe_json(os.environ.get('ATLAS_AUDIT_GATEWAY',''), []),
  'probes': {
    'node_exists': os.environ.get('ATLAS_AUDIT_NODE_EXISTS') == 'true',
    'node_executable': os.environ.get('ATLAS_AUDIT_NODE_EXEC') == 'true',
    'pnpm_exists': os.environ.get('ATLAS_AUDIT_PNPM_EXISTS') == 'true',
    'atlas_root_exists': os.environ.get('ATLAS_AUDIT_ROOT_EXISTS') == 'true',
    'atlas_root_has_package_json': os.environ.get('ATLAS_AUDIT_ROOT_PKG') == 'true',
    'sparse_path_exit_code': int(os.environ.get('ATLAS_AUDIT_SPARSE_EXIT', '127')),
    'sparse_path_stderr': (os.environ.get('ATLAS_AUDIT_SPARSE_ERR') or '')[:500]
  },
  'conclusion': {
    'root_cause': os.environ.get('ATLAS_AUDIT_RC', 'UNKNOWN'),
    'next_fix': os.environ.get('ATLAS_AUDIT_FIX', '')
  }
}
out = os.environ.get('ATLAS_AUDIT_OUT', '')
if out:
    with open(out, 'w') as f:
        json.dump(j, f, indent=2)
print(json.dumps(j))
"
