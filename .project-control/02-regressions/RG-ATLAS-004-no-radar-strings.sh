#!/usr/bin/env bash
# RG-ATLAS-004: No forbidden radar strings (extends RG-ATLAS-003).
# Fails if repo contains: radar:run, OPENCLAW_ROOT, /atlas radar, radar_daily, ACTION_RADAR

set -euo pipefail

ROOT="${PCK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OC_BIND_ROOT="${OC_BIND_ROOT:-}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
ATLAS_RADAR_ROOT="${ATLAS_RADAR_ROOT:-$ROOT}"

FORBIDDEN=(
  "radar:run"
  "OPENCLAW_ROOT"
  "/atlas radar"
  "radar_daily"
  "ACTION_RADAR"
)

fail() {
  echo "RG-ATLAS-004 FAIL: $*" >&2
  exit 1
}

# Resolve oc-bind
PLUGIN_DIR=""
if [ -n "${OC_BIND_ROOT:-}" ] && [ -d "$OC_BIND_ROOT" ]; then
  PLUGIN_DIR="$OC_BIND_ROOT"
elif [ -f "$OPENCLAW_JSON" ]; then
  PLUGIN_DIR=$(jq -r '.plugins.load.paths[0] // .plugins.installs["oc-bind"].installPath // empty' "$OPENCLAW_JSON" 2>/dev/null || true)
fi

# Check atlas-radar tg/runtime
for f in "${ATLAS_RADAR_ROOT}/runtime/atlas/tg_nl_router.ts" "${ATLAS_RADAR_ROOT}/runtime/atlas/tg_nl_handler.ts"; do
  [ -f "$f" ] || continue
  for pat in "${FORBIDDEN[@]}"; do
    if grep -q "$pat" "$f" 2>/dev/null; then
      fail "Forbidden '$pat' in $f"
    fi
  done
done

# Check oc-bind
if [ -n "$PLUGIN_DIR" ] && [ -d "$PLUGIN_DIR" ]; then
  for f in "$PLUGIN_DIR"/*.ts "$PLUGIN_DIR"/*.json; do
    [ -f "$f" ] || continue
    for pat in "${FORBIDDEN[@]}"; do
      if grep -q "$pat" "$f" 2>/dev/null; then
        fail "Forbidden '$pat' in $f"
      fi
    done
  done
  if [ -f "$PLUGIN_DIR/../README.md" ]; then
    for pat in "${FORBIDDEN[@]}"; do
      if grep -q "$pat" "$PLUGIN_DIR/../README.md" 2>/dev/null; then
        fail "Forbidden '$pat' in README.md"
      fi
    done
  fi
fi

echo "RG-ATLAS-004 PASS: No forbidden radar strings"
exit 0
