#!/usr/bin/env bash
# RG-ATLAS-008: Assert atlas-adapter validates package.json and scripts.atlas:run before spawn.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"

fail() { echo "RG-ATLAS-008-root-must-have-pkg-and-script FAIL: $*" >&2; exit 1; }

PLUGIN_DIR=""
[ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ] && PLUGIN_DIR="$OC_BIND_ROOT"
[ -z "$PLUGIN_DIR" ] && [ -f "$OPENCLAW_JSON" ] && PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)

if [ -z "$PLUGIN_DIR" ] || [ ! -d "$PLUGIN_DIR" ]; then
  echo "RG-ATLAS-008-root-must-have-pkg-and-script SKIP: oc-bind not found"
  exit 0
fi

ADAPTER="$PLUGIN_DIR/atlas-adapter.ts"
[ -f "$ADAPTER" ] || fail "atlas-adapter.ts not found"

grep -q "atlas:run\|scripts\.atlas" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must check scripts.atlas:run"
grep -q "package.json" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must validate package.json"

echo "RG-ATLAS-008-root-must-have-pkg-and-script PASS"
exit 0
