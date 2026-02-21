#!/usr/bin/env bash
# RG-ATLAS-005: Assert node resolution includes process.execPath before /opt/homebrew/bin/node.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"

fail() { echo "RG-ATLAS-005-node-execpath-fallback FAIL: $*" >&2; exit 1; }

PLUGIN_DIR=""
[ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ] && PLUGIN_DIR="$OC_BIND_ROOT"
[ -z "$PLUGIN_DIR" ] && [ -f "$OPENCLAW_JSON" ] && PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)

if [ -z "$PLUGIN_DIR" ] || [ ! -d "$PLUGIN_DIR" ]; then
  echo "RG-ATLAS-005-node-execpath-fallback SKIP: oc-bind not found"
  exit 0
fi

ADAPTER="$PLUGIN_DIR/atlas-adapter.ts"
[ -f "$ADAPTER" ] || fail "atlas-adapter.ts not found"

grep -q "process.execPath" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must use process.execPath in node resolution"
# execPath should appear before NODE_CANDIDATES (homebrew)
if grep -n "process.execPath\|NODE_CANDIDATES\|/opt/homebrew" "$ADAPTER" 2>/dev/null | head -20; then
  EXEC_LINE=$(grep -n "process.execPath" "$ADAPTER" 2>/dev/null | head -1 | cut -d: -f1)
  HOMEBREW_LINE=$(grep -n "/opt/homebrew/bin/node" "$ADAPTER" 2>/dev/null | head -1 | cut -d: -f1)
  [ -n "$EXEC_LINE" ] && [ -n "$HOMEBREW_LINE" ] && [ "$EXEC_LINE" -lt "$HOMEBREW_LINE" ] || fail "process.execPath must appear before /opt/homebrew in resolution order"
fi

echo "RG-ATLAS-005-node-execpath-fallback PASS"
exit 0
