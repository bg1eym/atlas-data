#!/usr/bin/env bash
# RG-ATLAS-002: Build fingerprint must be present in TG reply code and runtime.
# A) Static: code contains appendFingerprint/getBuildFingerprint in reply path
# B) Logs: gateway logs contain build fingerprint (if logs available)
# C) Fallback: unit test asserts getBuildFingerprint() returns valid format

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
GATEWAY_LOG="${GATEWAY_LOG:-$HOME/.openclaw/logs/gateway.log}"

fail() {
  echo "RG-ATLAS-002 FAIL: $*" >&2
  exit 1
}

# Resolve oc-bind path
PLUGIN_DIR=""
if [ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ]; then
  PLUGIN_DIR="$OC_BIND_ROOT"
elif [ -f "$OPENCLAW_JSON" ]; then
  PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)
fi

if [ -z "$PLUGIN_DIR" ] || [ ! -d "$PLUGIN_DIR" ]; then
  echo "RG-ATLAS-002 SKIP: oc-bind plugin dir not found (set OC_BIND_ROOT or ensure openclaw.json has oc-bind)"
  exit 0
fi

# A) Static check: reply code uses build fingerprint
INDEX_TS="${PLUGIN_DIR}/index.ts"
if [ ! -f "$INDEX_TS" ]; then
  fail "index.ts not found: $INDEX_TS"
fi
if ! grep -q "appendFingerprint\|getBuildFingerprint" "$INDEX_TS"; then
  fail "index.ts does not contain appendFingerprint or getBuildFingerprint"
fi
if ! grep -q "build:" "$INDEX_TS"; then
  fail "index.ts does not contain build fingerprint pattern"
fi

# B) Log check (optional — if gateway log exists and has content)
if [ -f "$GATEWAY_LOG" ] && [ -s "$GATEWAY_LOG" ]; then
  if grep -q "build:.*PCK-.*oc-bind" "$GATEWAY_LOG" 2>/dev/null; then
    echo "RG-ATLAS-002: build fingerprint found in gateway logs"
  else
    echo "RG-ATLAS-002: gateway logs exist but no fingerprint yet (invoke /atlas help to populate)"
  fi
fi

# C) Fallback: unit test for getBuildFingerprint format
OC_LAB_ROOT="$(dirname "$PLUGIN_DIR")"
if [ -d "$OC_LAB_ROOT" ] && [ -f "$OC_LAB_ROOT/package.json" ]; then
  if (cd "$OC_LAB_ROOT" && npx tsx oc-bind/build-fingerprint-test.ts 2>/dev/null); then
    echo "RG-ATLAS-002 PASS: build fingerprint present and format valid"
  else
    fail "build-fingerprint-test.ts failed or not found"
  fi
else
  echo "RG-ATLAS-002 PASS: static check OK (unit test skipped, oc-personal-agent-lab not found)"
fi

exit 0
