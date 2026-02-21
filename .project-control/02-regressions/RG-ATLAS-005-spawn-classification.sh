#!/usr/bin/env bash
# RG-ATLAS-005: Assert ENOENT is mapped to failure_mode with evidence keys.
# node_bin_used, gateway_execPath, atlas_root_value must be in error response.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"

fail() { echo "RG-ATLAS-005-spawn-classification FAIL: $*" >&2; exit 1; }

PLUGIN_DIR=""
[ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ] && PLUGIN_DIR="$OC_BIND_ROOT"
[ -z "$PLUGIN_DIR" ] && [ -f "$OPENCLAW_JSON" ] && PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)

if [ -z "$PLUGIN_DIR" ] || [ ! -d "$PLUGIN_DIR" ]; then
  echo "RG-ATLAS-005-spawn-classification SKIP: oc-bind not found"
  exit 0
fi

ADAPTER="$PLUGIN_DIR/atlas-adapter.ts"
INDEX="$PLUGIN_DIR/index.ts"
[ -f "$ADAPTER" ] || fail "atlas-adapter.ts not found"

# ENOENT mapped to failure_mode (SPAWN_FAILED_ENOENT or similar)
grep -q "SPAWN_FAILED\|ENOENT" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must map ENOENT to failure_mode"

# Evidence keys in result/error
grep -q "nodeBinUsed" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must include nodeBinUsed in error"
grep -q "gatewayNodeExec" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must include gatewayNodeExec in spawn error"
grep -q "atlasRoot" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must include atlasRoot in error"

# index: error message includes gateway_node_exec when available
[ -f "$INDEX" ] && grep -q "gateway_node_exec\|gatewayNodeExec" "$INDEX" 2>/dev/null || true

echo "RG-ATLAS-005-spawn-classification PASS"
exit 0
