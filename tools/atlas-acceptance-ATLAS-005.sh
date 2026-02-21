#!/usr/bin/env bash
# ATLAS-005 (Evidence-based) acceptance — deterministic, non-interactive.
# Exit 0 on correct setup; exit non-zero with classification JSON on failure.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT_DIR="${ROOT}/tools/_out"
CLASS_JSON="${ROOT}/.project-control/07-critical-tests/_out/classification.json"
mkdir -p "${OUT_DIR}"

FAILED=0

# 1) Run gates
echo "=== Gates ==="
bash "${ROOT}/.project-control/04-gates/preflight.sh" || FAILED=1
bash "${ROOT}/.project-control/04-gates/regress.sh" || FAILED=1
bash "${ROOT}/.project-control/04-gates/convergence.sh" || FAILED=1

# 2) Discovery
echo ""
echo "=== Atlas root discovery ==="
bash "${ROOT}/tools/atlas-root-discovery.sh" 2>&1 | tee "${OUT_DIR}/atlas-root-discovery.txt" || true

# 3) ATLAS_ROOT validation
ATLAS_ROOT_VAL="${ATLAS_ROOT:-}"
if [ -z "$ATLAS_ROOT_VAL" ]; then
  echo "ACCEPTANCE FAIL: ATLAS_ROOT not set"
  echo '{"failure_mode":"ATLAS_ROOT_INVALID","root_cause":"ATLAS_ROOT not set","recommended_fix":"Set ATLAS_ROOT to atlas-radar repo root"}' > "${OUT_DIR}/classification.json"
  exit 1
fi

if [ ! -d "$ATLAS_ROOT_VAL" ]; then
  echo "ACCEPTANCE FAIL: ATLAS_ROOT path does not exist: $ATLAS_ROOT_VAL"
  python3 -c "import json; json.dump({'failure_mode':'ATLAS_ROOT_INVALID','root_cause':'path does not exist','atlas_root_value':'$ATLAS_ROOT_VAL','recommended_fix':'Set ATLAS_ROOT to existing atlas-radar root'}, open('$OUT_DIR/classification.json','w'), indent=2)"
  exit 1
fi

if [ ! -f "${ATLAS_ROOT_VAL}/package.json" ]; then
  echo "ACCEPTANCE FAIL: ATLAS_ROOT lacks package.json"
  python3 -c "import json; json.dump({'failure_mode':'ATLAS_ROOT_INVALID','root_cause':'package.json missing','atlas_root_value':'$ATLAS_ROOT_VAL','recommended_fix':'Set ATLAS_ROOT to atlas-radar repo root'}, open('$OUT_DIR/classification.json','w'), indent=2)"
  exit 1
fi

# 4) Sparse env spawn proof (node + pnpm -v)
NODE_BIN="${NODE_BIN:-}"
[ -z "$NODE_BIN" ] && NODE_BIN="$(which node 2>/dev/null || true)"
[ -z "$NODE_BIN" ] && NODE_BIN="$(node -e 'console.log(process.execPath)' 2>/dev/null || true)"
PNPM_JS="${PNPM_JS:-}"
[ -z "$PNPM_JS" ] && [ -f "/opt/homebrew/lib/node_modules/pnpm/bin/pnpm.cjs" ] && PNPM_JS="/opt/homebrew/lib/node_modules/pnpm/bin/pnpm.cjs"
[ -z "$PNPM_JS" ] && [ -f "/usr/local/lib/node_modules/pnpm/bin/pnpm.cjs" ] && PNPM_JS="/usr/local/lib/node_modules/pnpm/bin/pnpm.cjs"
if [ -n "$NODE_BIN" ] && [ -n "$PNPM_JS" ]; then
  echo ""
  echo "=== Sparse env spawn proof ==="
  if env -i PATH=/usr/bin:/bin "$NODE_BIN" "$PNPM_JS" -v 2>&1; then
    echo "Spawn proof: PASS"
  else
    echo "Spawn proof: FAIL"
    FAILED=1
    python3 -c "import json; json.dump({'failure_mode':'SPAWN_FAILED','root_cause':'node+pnpm spawn failed','node_bin':'$NODE_BIN','pnpm_js':'$PNPM_JS','recommended_fix':'Check NODE_BIN, PNPM_JS'}, open('$OUT_DIR/classification.json','w'), indent=2)" 2>/dev/null || true
  fi
fi

# 5) Copy classification if from critical-tests
if [ -f "$CLASS_JSON" ]; then
  cp "$CLASS_JSON" "${OUT_DIR}/classification.json" 2>/dev/null || true
fi

if [ "$FAILED" -eq 1 ]; then
  echo "ACCEPTANCE FAIL"
  exit 1
fi

echo ""
echo "ACCEPTANCE PASS"
exit 0
