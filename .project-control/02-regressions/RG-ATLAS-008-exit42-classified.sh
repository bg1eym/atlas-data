#!/usr/bin/env bash
# RG-ATLAS-008: If exit 42 occurs, adapter must map to ATLAS_PIPELINE_BLOCKED with evidence fields.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"

fail() { echo "RG-ATLAS-008-exit42-classified FAIL: $*" >&2; exit 1; }

PLUGIN_DIR=""
[ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ] && PLUGIN_DIR="$OC_BIND_ROOT"
[ -z "$PLUGIN_DIR" ] && [ -f "$OPENCLAW_JSON" ] && PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)

if [ -z "$PLUGIN_DIR" ] || [ ! -d "$PLUGIN_DIR" ]; then
  echo "RG-ATLAS-008-exit42-classified SKIP: oc-bind not found"
  exit 0
fi

ADAPTER="$PLUGIN_DIR/atlas-adapter.ts"
[ -f "$ADAPTER" ] || fail "atlas-adapter.ts not found"

grep -q "ATLAS_PIPELINE_BLOCKED" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must map exit 42 to ATLAS_PIPELINE_BLOCKED"
grep -q "code === 42" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must detect exit code 42"
grep -q "stderr_snippet\|stdout_snippet" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must include stderr_snippet/stdout_snippet in BLOCKED evidence"

echo "RG-ATLAS-008-exit42-classified PASS"
exit 0
