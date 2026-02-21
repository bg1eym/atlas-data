#!/usr/bin/env bash
# RG-ATLAS-005: Assert atlas-adapter checks ATLAS_ROOT existence before spawn.
# Assert /atlas debug prints atlas_root_value and atlas_root_exists.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"

fail() { echo "RG-ATLAS-005-atlas-root-validated FAIL: $*" >&2; exit 1; }

PLUGIN_DIR=""
[ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ] && PLUGIN_DIR="$OC_BIND_ROOT"
[ -z "$PLUGIN_DIR" ] && [ -f "$OPENCLAW_JSON" ] && PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)

if [ -z "$PLUGIN_DIR" ] || [ ! -d "$PLUGIN_DIR" ]; then
  echo "RG-ATLAS-005-atlas-root-validated SKIP: oc-bind not found"
  exit 0
fi

ADAPTER="$PLUGIN_DIR/atlas-adapter.ts"
INDEX="$PLUGIN_DIR/index.ts"
[ -f "$ADAPTER" ] || fail "atlas-adapter.ts not found"

# atlas-adapter: ATLAS_ROOT validation before spawn (existsSync)
grep -q "ATLAS_ROOT_INVALID\|existsSync\|!atlasRoot" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must validate ATLAS_ROOT before spawn"

# index: /atlas debug prints atlas_root_value and atlas_root_exists
[ -f "$INDEX" ] || fail "index.ts not found"
grep -q "atlas_root_value\|atlas_root_exists" "$INDEX" 2>/dev/null || fail "index.ts /atlas debug must print atlas_root_value and atlas_root_exists"

echo "RG-ATLAS-005-atlas-root-validated PASS"
exit 0
