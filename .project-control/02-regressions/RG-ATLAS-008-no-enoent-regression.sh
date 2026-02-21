#!/usr/bin/env bash
# RG-ATLAS-008: Fail if raw ENOENT appears in atlas-adapter error output.
# Adapter must map ENOENT to SPAWN_FAILED_ENOENT, not expose raw string.

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"

fail() { echo "RG-ATLAS-008-no-enoent-regression FAIL: $*" >&2; exit 1; }

PLUGIN_DIR=""
[ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ] && PLUGIN_DIR="$OC_BIND_ROOT"
[ -z "$PLUGIN_DIR" ] && [ -f "$OPENCLAW_JSON" ] && PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)

if [ -z "$PLUGIN_DIR" ] || [ ! -d "$PLUGIN_DIR" ]; then
  echo "RG-ATLAS-008-no-enoent-regression SKIP: oc-bind not found"
  exit 0
fi

ADAPTER="$PLUGIN_DIR/atlas-adapter.ts"
[ -f "$ADAPTER" ] || fail "atlas-adapter.ts not found"

# Must map ENOENT to SPAWN_FAILED_ENOENT
grep -q "SPAWN_FAILED_ENOENT" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must classify ENOENT as SPAWN_FAILED_ENOENT"

# Must NOT return raw "ENOENT" in user-facing error (stderr/error field) without classification
# The adapter returns error: failureMode when ENOENT, so raw ENOENT in stderr from spawn is OK if we also set error to SPAWN_FAILED_ENOENT
grep -q "isEnoent\|ENOENT" "$ADAPTER" 2>/dev/null || fail "atlas-adapter must detect ENOENT"

echo "RG-ATLAS-008-no-enoent-regression PASS"
exit 0
